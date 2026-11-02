import Combine
import Foundation

@MainActor
final class TranslateModel: ObservableObject {
    enum State: Equatable {
        case idle
        case translating(done: Int, total: Int)
        case done
        case failed(String)
    }

    // Gemini's free tier is slow and rate limited, and the whole file is held in memory
    static let maxCharacters = 400_000

    let file: URL
    let source: String?
    @Published var language = TranslateLanguage.common[0]
    @Published var customName = ""
    @Published private(set) var state = State.idle
    @Published private(set) var result = ""
    @Published private(set) var savedURL: URL?
    @Published private(set) var missingKey = false
    @Published private(set) var startedAt: Date?
    // a wait worth explaining, e.g. Google asking us to slow down
    @Published private(set) var note = ""
    private var task: Task<Void, Never>?

    init(file: URL) {
        self.file = file
        if let text = try? String(contentsOf: file, encoding: .utf8) {
            source = text
            if text.count > Self.maxCharacters { state = .failed("The file is too long (limit \(Self.maxCharacters / 1000)k characters).") }
        } else {
            source = nil
            state = .failed("Cannot read this file as UTF-8 text.")
        }
    }

    var target: TranslateLanguage? { language == .custom ? TranslateLanguage.typed(customName) : language }
    var translating: Bool { if case .translating = state { return true } else { return false } }
    var canStart: Bool {
        guard source != nil, target != nil, !translating else { return false }
        return (source?.count ?? 0) <= Self.maxCharacters
    }

    func start() {
        guard canStart, let source, let target else { return }
        guard let key = KeychainStore.read(TranslateSettings.account) else {
            missingKey = true
            state = .failed("Add your Gemini API key in Settings > Translate.")
            return
        }
        missingKey = false
        result = ""
        savedURL = nil
        var client = GeminiClient(apiKey: key, model: TranslateSettings.shared.effectiveModel)
        var recovered = false
        let chunks = TranslateChunker.split(source)
        state = .translating(done: 0, total: chunks.count)
        startedAt = Date()
        note = ""
        task = Task {
            do {
                var output = ""
                for (index, chunk) in chunks.enumerated() {
                    try Task.checkCancellation()
                    if chunk.allSatisfy(\.isWhitespace) {
                        output += chunk
                    } else {
                        let translated: String
                        do {
                            translated = try await client.translate(chunk, to: target.name, onRetry: retryNote)
                        } catch GeminiError.http(404, let message) where !recovered {
                            // the saved model was retired: switch to what the key can use, once, and say so in Settings
                            recovered = true
                            guard let pick = GeminiClient.pickDefault(try await client.listModels()), pick != client.model else {
                                throw GeminiError.http(404, message)
                            }
                            TranslateSettings.shared.model = pick
                            client = GeminiClient(apiKey: key, model: pick)
                            translated = try await client.translate(chunk, to: target.name, onRetry: retryNote)
                        }
                        note = ""
                        output += TranslateChunker.restoreEdges(of: chunk, in: translated)
                    }
                    result = output
                    state = .translating(done: index + 1, total: chunks.count)
                }
                state = .done
            } catch is CancellationError {
                state = result.isEmpty ? .idle : .failed("Stopped. The text so far is shown, not saved.")
            } catch let error as URLError where error.code == .cancelled {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private var retryNote: @Sendable () -> Void {
        { [weak self] in Task { @MainActor in self?.note = "Google asked us to slow down, retrying…" } }
    }

    func cancel() {
        task?.cancel()
    }

    // next to the original, never over an existing file
    func save() -> URL? {
        guard state == .done, let target else { return nil }
        let url = TranslateChunker.outputURL(for: file, code: target.code)
        do {
            try Data(result.utf8).write(to: url, options: .withoutOverwriting)
            savedURL = url
            return url
        } catch {
            state = .failed("Cannot save: \(error.localizedDescription)")
            return nil
        }
    }
}

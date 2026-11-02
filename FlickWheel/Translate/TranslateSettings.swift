import Combine
import Foundation

// the Gemini key (Keychain) and model name (UserDefaults) that the Translate window and Settings share
@MainActor
final class TranslateSettings: ObservableObject {
    static let shared = TranslateSettings()
    static let account = "gemini-api-key"
    private static let modelKey = "geminiModel"
    private static let hintKey = "geminiKeyHint"

    @Published private(set) var hasKey = KeychainStore.exists(TranslateSettings.account)
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Self.modelKey) }
    }
    // last 4 characters, so the saved key is recognisable without reading the Keychain
    @Published private(set) var keyHint = UserDefaults.standard.string(forKey: TranslateSettings.hintKey) ?? ""
    // models the key can use, filled by Check key
    @Published private(set) var available: [String] = []
    @Published var status = ""
    @Published var checking = false

    private init() {
        model = UserDefaults.standard.string(forKey: Self.modelKey) ?? GeminiClient.defaultModel
    }

    var effectiveModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? GeminiClient.defaultModel : trimmed
    }

    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasKey = KeychainStore.save(trimmed, account: Self.account)
        if hasKey {
            keyHint = String(trimmed.suffix(4))
            UserDefaults.standard.set(keyHint, forKey: Self.hintKey)
        }
        status = hasKey ? "Key saved to your Keychain." : "Could not save the key to the Keychain."
    }

    func removeKey() {
        KeychainStore.delete(Self.account)
        hasKey = false
        keyHint = ""
        UserDefaults.standard.removeObject(forKey: Self.hintKey)
        status = "Key removed."
    }

    func check() {
        guard let key = KeychainStore.read(Self.account) else {
            status = "Save a key first."
            return
        }
        checking = true
        status = "Checking…"
        let client = GeminiClient(apiKey: key, model: effectiveModel)
        Task {
            do {
                let names = try await client.listModels()
                available = GeminiClient.textModels(names)
                let current = effectiveModel.hasPrefix("models/") ? String(effectiveModel.dropFirst(7)) : effectiveModel
                if names.contains(current) {
                    status = "Key works and \(current) is available."
                } else if let pick = GeminiClient.pickDefault(names) {
                    status = "\(current) is not available for this key. Switched to \(pick)."
                    model = pick
                } else {
                    status = "Key works, but it has no Gemini text model."
                }
            } catch {
                status = error.localizedDescription
            }
            checking = false
        }
    }
}

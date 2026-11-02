import Combine
import Foundation

// git's progress output: "\r" redraws the line being written, "\n" finishes it
struct CloneLog: Equatable {
    private(set) var lines: [String] = []
    private(set) var live = ""
    private var rewrite = false

    var text: String { (lines + (live.isEmpty ? [] : [live])).joined(separator: "\n") }

    // iterate scalars: Swift fuses "\r\n" into one Character
    mutating func feed(_ chunk: String) {
        for scalar in chunk.unicodeScalars {
            switch scalar {
            case "\n":
                lines.append(live)
                live = ""
                rewrite = false
            case "\r":
                rewrite = true
            default:
                if rewrite {
                    live = ""
                    rewrite = false
                }
                live.unicodeScalars.append(scalar)
            }
        }
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
    }
}

@MainActor
final class CloneModel: ObservableObject {
    enum State: Equatable {
        case idle, running, done
        case failed(String)
    }

    let parent: URL
    @Published var url = ""
    // empty = use the name taken from the URL
    @Published var customName = ""
    @Published private(set) var log = CloneLog()
    @Published private(set) var state = State.idle
    // progress of the git phase now running ("Receiving objects", "Resolving deltas"), nil until git reports one
    @Published private(set) var fraction: Double?
    @Published private(set) var phase = ""
    var onFinish: ((Bool) -> Void)?

    private var process: Process?
    private var cancelled = false

    init(parent: URL) {
        self.parent = parent
    }

    var trimmedURL: String { url.trimmingCharacters(in: .whitespacesAndNewlines) }
    var defaultName: String { Self.repoName(from: trimmedURL) }
    var folderName: String { customName.isEmpty ? defaultName : customName.trimmingCharacters(in: .whitespaces) }
    var target: URL { parent.appendingPathComponent(folderName, isDirectory: true) }
    var running: Bool { state == .running }

    // what to tell the user about the form; nil when it is fine (or still empty)
    var problem: String? {
        if !trimmedURL.isEmpty, let bad = Self.urlProblem(trimmedURL) { return bad }
        if trimmedURL.isEmpty { return nil }
        if let bad = Self.nameProblem(folderName) { return bad }
        if FileManager.default.fileExists(atPath: target.path) { return "\(folderName) already exists in \(parent.lastPathComponent)"}
        return nil
    }

    var canStart: Bool { !running && !trimmedURL.isEmpty && problem == nil }

    // https, http, ssh and git URLs, plus scp-style git@host:owner/repo; nothing else reaches git; a host starting with "-" would be read by ssh as an option
    nonisolated static func urlProblem(_ url: String) -> String? {
        let ok = url.range(of: #"^(https?|ssh|git)://[^\s/-][^\s/]*/\S+$"#, options: .regularExpression) != nil
            || url.range(of: #"^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+:\S+$"#, options: .regularExpression) != nil
        return ok ? nil : "Use an https:// or ssh URL, e.g. git@github.com:owner/repo.git"
    }

    nonisolated static func nameProblem(_ name: String) -> String? {
        if name.isEmpty { return "Name the folder" }
        if name == "." || name == ".." || name.contains("/") || name.contains(":") { return "Folder name cannot contain / or :" }
        return nil
    }

    // https://host/owner/repo.git, git@host:owner/repo, ... -> repo
    nonisolated static func repoName(from url: String) -> String {
        var text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        if text.hasSuffix(".git") { text.removeLast(4) }
        return text.split(whereSeparator: { $0 == "/" || $0 == ":" }).last.map(String.init) ?? ""
    }

    func start() {
        guard canStart else { return }
        log = CloneLog()
        fraction = nil
        phase = ""
        cancelled = false
        state = .running

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // the URL and target go through the environment, never into the command string
        process.arguments = ["-lc", #"git clone --progress -- "$FW_URL" "$FW_TARGET""#]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        // no tty to answer a credential or host-key question: fail with a message instead of hanging
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_SSH_COMMAND"] = environment["GIT_SSH_COMMAND"] ?? "ssh -o BatchMode=yes"
        environment["GIT_ALLOW_PROTOCOL"] = "https:http:ssh:git"
        environment["FW_URL"] = trimmedURL
        environment["FW_TARGET"] = target.path
        process.environment = environment
        process.currentDirectoryURL = parent

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self?.feed(text) }
        }
        process.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            let rest = (try? pipe.fileHandleForReading.readToEnd()).map { String(decoding: $0, as: UTF8.self) } ?? ""
            let status = finished.terminationStatus
            Task { @MainActor in
                self?.feed(rest)
                self?.finished(status: status)
            }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            state = .failed(error.localizedDescription)
            onFinish?(false)
        }
    }

    func cancel() {
        guard running, let process, process.isRunning else { return }
        cancelled = true
        RunHandle.terminate(process)
    }

    private func feed(_ text: String) {
        guard !text.isEmpty else { return }
        log.feed(text)
        let line = log.live.isEmpty ? (log.lines.last ?? "") : log.live
        if let range = line.range(of: #"\d{1,3}(?=%)"#, options: .regularExpression), let percent = Double(line[range]) {
            fraction = min(percent, 100) / 100
            phase = line.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
        }
    }

    private func finished(status: Int32) {
        process = nil
        if cancelled {
            // validated as non-existent at start, so anything there is git's half-written clone
            try? FileManager.default.removeItem(at: target)
            state = .failed("Stopped")
        } else if status == 0 {
            fraction = 1
            state = .done
        } else {
            state = .failed(log.lines.last(where: { !$0.isEmpty }) ?? "git exited with status \(status)")
        }
        onFinish?(state == .done)
    }
}

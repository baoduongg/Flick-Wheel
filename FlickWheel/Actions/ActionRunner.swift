import Foundation
import UserNotifications

struct ActionResult: Equatable, Sendable {
    let exitCode: Int32
    let stderr: String
    let timedOut: Bool
    var cancelled = false
    var stdout = ""
    // an output path handed out by fw_out that nothing wrote (sips exits 0 after "not a valid file - skipping")
    var missingOutput: String? = nil

    var succeeded: Bool { exitCode == 0 && !timedOut && !cancelled && missingOutput == nil }

    // one readable line for the failure notification
    func explanation(for file: URL) -> String {
        let said = (stderr + "\n" + stdout)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("ffmpeg version") } ?? ""
        if let missingOutput {
            var text = "Nothing was written to \(URL(fileURLWithPath: missingOutput).lastPathComponent)."
            if !said.isEmpty { text += " \(said)." }
            if said.contains("not a valid file") {
                text += " FlickWheel may not be allowed to read this folder (System Settings > Privacy & Security > Files & Folders)."
            }
            return String(text.prefix(280))
        }
        // the cause is at the end of a tool's output (ffmpeg prints its banner first)
        let tail = stderr.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .suffix(3)
            .joined(separator: " ")
        return tail.isEmpty ? "\(file.lastPathComponent): exit \(exitCode)" : String(tail.suffix(220))
    }
}

// lets the menu bar stop a running command (and the ffmpeg or npx it started)
final class RunHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func attach(_ process: Process) {
        lock.lock()
        self.process = process
        let already = cancelled
        lock.unlock()
        if already { Self.terminate(process) }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let current = process
        lock.unlock()
        if let current { Self.terminate(current) }
    }

    // zsh may not exec its last command, so stop the children first
    static func terminate(_ process: Process) {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-TERM", "-P", String(process.processIdentifier)]
        try? pkill.run()
        pkill.waitUntilExit()
        process.terminate()
    }
}

enum ActionRunner {
    // defined before every command so actions can write to a name that is never taken:
    //   ffmpeg -i "$INPUT" "$(fw_out "$DIR/$NAME.gif")"   ->   name.gif, then "name 2.gif", ...
    // FW_OUTLOG lists every name handed out, so the runner can check that each one was really written
    static let prelude = #"fw_out() { local f=$1 n=2 d=${1:h} b=${1:t} s e; if [[ $b == *.* ]]; then s=${b%.*}; e=.${b##*.}; else s=$b; e=; fi; while [[ -e $f ]]; do f="$d/$s $n$e"; n=$((n+1)); done; [[ -n $FW_OUTLOG ]] && print -r -- "$f" >> "$FW_OUTLOG"; print -r -- "$f"; }"# + "\n"

    // a Finder-launched app has no LANG, which makes pbcopy mangle non-ASCII text such as Vietnamese file names
    static func environment(for file: URL, all: [URL]? = nil, inherited: [String: String]) -> [String: String] {
        inherited.merging([
            "PATH": "/opt/homebrew/bin:/usr/local/bin:" + (inherited["PATH"] ?? "/usr/bin:/bin"),
            "LANG": inherited["LANG"] ?? "en_US.UTF-8",
            "INPUT": file.path,
            "INPUTS": (all ?? [file]).map(\.path).joined(separator: "\n"),
            "DIR": file.deletingLastPathComponent().path,
            "NAME": file.deletingPathExtension().lastPathComponent,
        ]) { _, new in new }
    }

    static func run(_ action: WheelAction, on file: URL, all: [URL]? = nil, timeout: TimeInterval = 120,
                    handle: RunHandle? = nil) async -> ActionResult {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("flickwheel-\(UUID().uuidString).outlog")
        var environment = environment(for: file, all: all, inherited: ProcessInfo.processInfo.environment)
        environment["FW_OUTLOG"] = log.path
        let command = action.command
        var result: ActionResult = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: execute(command, environment: environment, timeout: timeout, handle: handle))
            }
        }
        if result.succeeded {
            result.missingOutput = firstMissingOutput(in: log)
        } else {
            // fw_out only hands out names that were free, so whatever sits there now is a half-written leftover
            for path in loggedOutputs(in: log) { try? FileManager.default.removeItem(atPath: path) }
        }
        try? FileManager.default.removeItem(at: log)
        return result
    }

    private static func loggedOutputs(in log: URL) -> [String] {
        guard let text = try? String(contentsOf: log, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    private static func firstMissingOutput(in log: URL) -> String? {
        loggedOutputs(in: log).first { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return true }
            // a folder (unzip) only has to exist; a file has to have content
            if isDirectory.boolValue { return false }
            return ((try? URL(fileURLWithPath: path).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) == 0
        }
    }

    @MainActor
    static func runAndNotify(_ action: WheelAction, on files: [URL]) async {
        for group in action.multi == true ? [files] : files.map({ [$0] }) {
            let file = group[0]
            let dir = file.deletingLastPathComponent()
            let handle = RunHandle()
            let job = JobCenter.shared.begin(title: action.label, file: file.lastPathComponent, handle: handle)
            let before = OutputProbe.snapshot(dir)
            let result = await run(action, on: file, all: group, timeout: action.timeout ?? 120, handle: handle)
            let output = OutputProbe.newest(in: dir, since: before, excluding: file)
            if result.cancelled {
                JobCenter.shared.finish(job, state: .cancelled, output: output)
            } else if result.succeeded {
                JobCenter.shared.finish(job, state: .succeeded, output: output)
                notify(title: action.label, body: output.map { "\($0.lastPathComponent) ready" } ?? "\(file.lastPathComponent) done", file: output)
            } else {
                let detail = result.explanation(for: file)
                JobCenter.shared.finish(job, state: .failed, detail: detail)
                notify(title: "\(action.label) failed", body: detail)
            }
        }
    }

    // `file` makes the notification reveal that file in Finder when clicked
    static func notify(title: String, body: String, file: URL? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let file { content.userInfo = ["path": file.path] }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private final class PipeCapture: @unchecked Sendable {
        var data = Data()
    }

    private static func execute(_ command: String, environment: [String: String], timeout: TimeInterval, handle: RunHandle?) -> ActionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", prelude + command]
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe()
        let pipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = pipe
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            return ActionResult(exitCode: -1, stderr: error.localizedDescription, timedOut: false)
        }
        handle?.attach(process)

        let capture = PipeCapture()
        let outCapture = PipeCapture()
        let reading = DispatchGroup()
        reading.enter()
        DispatchQueue.global().async {
            capture.data = pipe.fileHandleForReading.readDataToEndOfFile()
            reading.leave()
        }
        reading.enter()
        DispatchQueue.global().async {
            outCapture.data = outPipe.fileHandleForReading.readDataToEndOfFile()
            reading.leave()
        }

        var timedOut = false
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            RunHandle.terminate(process)
            if exited.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                exited.wait()
            }
        }

        // a surviving grandchild can hold the pipe open, so never wait unbounded after a kill
        let cancelled = handle?.isCancelled ?? false
        let drained = reading.wait(timeout: timedOut || cancelled ? .now() + 1 : .distantFuture) == .success
        let stderr = timedOut
            ? "Timed out after \(Int(timeout)) s"
            : (drained ? String(decoding: capture.data, as: UTF8.self) : "")
        let stdout = drained && !timedOut ? String(decoding: outCapture.data.prefix(4000), as: UTF8.self) : ""
        return ActionResult(exitCode: process.terminationStatus, stderr: stderr, timedOut: timedOut, cancelled: cancelled, stdout: stdout)
    }
}

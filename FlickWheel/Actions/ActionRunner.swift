import Foundation
import UserNotifications

struct ActionResult: Equatable, Sendable {
    let exitCode: Int32
    let stderr: String
    let timedOut: Bool

    var succeeded: Bool { exitCode == 0 && !timedOut }
}

enum ActionRunner {
    static func run(_ action: WheelAction, on file: URL, timeout: TimeInterval = 120) async -> ActionResult {
        let inherited = ProcessInfo.processInfo.environment
        let environment = inherited.merging([
            "PATH": "/opt/homebrew/bin:/usr/local/bin:" + (inherited["PATH"] ?? "/usr/bin:/bin"),
            "INPUT": file.path,
            "DIR": file.deletingLastPathComponent().path,
            "NAME": file.deletingPathExtension().lastPathComponent,
        ]) { _, new in new }
        let command = action.command
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: execute(command, environment: environment, timeout: timeout))
            }
        }
    }

    static func runAndNotify(_ action: WheelAction, on files: [URL]) async {
        for file in files {
            let result = await run(action, on: file)
            if result.succeeded {
                notify(title: action.label, body: "\(file.lastPathComponent) done")
            } else {
                let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = stderr.isEmpty ? "\(file.lastPathComponent): exit \(result.exitCode)" : String(stderr.prefix(200))
                notify(title: "\(action.label) failed", body: detail)
            }
        }
    }

    static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private final class StderrCapture: @unchecked Sendable {
        var data = Data()
    }

    private static func execute(_ command: String, environment: [String: String], timeout: TimeInterval) -> ActionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardError = pipe
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            return ActionResult(exitCode: -1, stderr: error.localizedDescription, timedOut: false)
        }

        let capture = StderrCapture()
        let reading = DispatchGroup()
        reading.enter()
        DispatchQueue.global().async {
            capture.data = pipe.fileHandleForReading.readDataToEndOfFile()
            reading.leave()
        }

        var timedOut = false
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if exited.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                exited.wait()
            }
        }

        // a surviving grandchild can hold the pipe open, so never wait unbounded after a kill
        let drained = reading.wait(timeout: timedOut ? .now() + 1 : .distantFuture) == .success
        let stderr = timedOut
            ? "Timed out after \(Int(timeout)) s"
            : (drained ? String(decoding: capture.data, as: UTF8.self) : "")
        return ActionResult(exitCode: process.terminationStatus, stderr: stderr, timedOut: timedOut)
    }
}

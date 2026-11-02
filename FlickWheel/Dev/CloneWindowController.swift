import AppKit
import Combine
import SwiftUI

@MainActor
final class CloneWindowController: NSObject, NSWindowDelegate {
    var onClose: ((CloneWindowController) -> Void)?

    private let window: NSWindow
    private let model: CloneModel
    private var jobID: UUID?
    private var windowClosed = false
    private var subscriptions: [AnyCancellable] = []

    init(into folder: URL) {
        model = CloneModel(parent: folder)
        // a copied repo URL is almost always why the wheel was opened
        if let copied = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           CloneModel.urlProblem(copied) == nil {
            model.url = copied
        }
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Clone Repository"
        window.isReleasedWhenClosed = false
        window.delegate = self
        // closing the window while git runs leaves it running in the menu bar; this object lives until it ends
        subscriptions = [
            model.$state.sink { [weak self] in self?.stateChanged($0) },
            model.$fraction.sink { [weak self] in self?.progressChanged($0) },
        ]
        model.onFinish = { [weak self] succeeded in
            guard let self else { return }
            if succeeded {
                ActionRunner.notify(title: "Cloned", body: model.folderName, file: model.target)
            } else if windowClosed, case .failed(let message) = model.state, message != "Stopped" {
                ActionRunner.notify(title: "Clone failed", body: message)
            }
            if windowClosed { onClose?(self) }
        }
        window.contentViewController = NSHostingController(rootView: CloneView(
            model: model,
            reveal: { [weak self] in
                guard let self else { return }
                NSWorkspace.shared.activateFileViewerSelecting([model.target])
            },
            openTerminal: { [weak self] in
                guard let self else { return }
                NSWorkspace.shared.open([model.target],
                                        withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                        configuration: NSWorkspace.OpenConfiguration())
            },
            close: { [weak self] in self?.window.close() }))
        window.center()
    }

    func show() {
        window.showCentered()
    }

    func windowWillClose(_ notification: Notification) {
        windowClosed = true
        if !model.running { onClose?(self) }
    }

    private func stateChanged(_ state: CloneModel.State) {
        let jobs = JobCenter.shared
        switch state {
        case .running:
            jobID = jobs.begin(title: "Clone", file: model.folderName) { [weak self] in self?.model.cancel() }
        case .done:
            finishJob(.succeeded)
        case .failed(let message):
            finishJob(message == "Stopped" ? .cancelled : .failed, detail: message)
        case .idle:
            break
        }
    }

    private func finishJob(_ state: JobCenter.State, detail: String? = nil) {
        guard let id = jobID else { return }
        JobCenter.shared.finish(id, state: state, output: state == .succeeded ? model.target : nil, detail: detail)
        jobID = nil
    }

    private func progressChanged(_ fraction: Double?) {
        guard let id = jobID, let fraction else { return }
        JobCenter.shared.update(id, progress: fraction, status: "\(model.phase.isEmpty ? "Cloning" : model.phase) \(Int(fraction * 100))%")
    }
}

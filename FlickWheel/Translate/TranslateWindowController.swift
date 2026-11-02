import AppKit
import Combine
import SwiftUI

// Closing the window while a translation runs does not stop it: the job lives in the menu bar and the result is
// saved beside the file when it finishes. This object stays alive until then.
@MainActor
final class TranslateWindowController: NSObject, NSWindowDelegate {
    var onClose: ((TranslateWindowController) -> Void)?
    var onOpenSettings: (() -> Void)?

    private let window: NSWindow
    private let model: TranslateModel
    private var jobID: UUID?
    // the finished job, so a later Save can attach the file to it
    private var lastJobID: UUID?
    private var windowClosed = false
    private var subscription: AnyCancellable?

    init(file: URL) {
        model = TranslateModel(file: file)
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Translate"
        window.isReleasedWhenClosed = false
        window.delegate = self
        subscription = model.$state.sink { [weak self] state in self?.stateChanged(state) }
        window.contentViewController = NSHostingController(rootView: TranslateView(
            model: model,
            copy: { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.result, forType: .string)
            },
            save: { [weak self] in self?.save() },
            reveal: { [weak self] in
                guard let self, let url = model.savedURL else { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            },
            openSettings: { [weak self] in self?.onOpenSettings?() },
            close: { [weak self] in self?.window.close() }))
        window.center()
    }

    func show() {
        window.showCentered()
    }

    func windowWillClose(_ notification: Notification) {
        windowClosed = true
        if !model.translating { onClose?(self) }
    }

    @discardableResult
    private func save() -> URL? {
        guard let url = model.save() else { return nil }
        if let lastJobID { JobCenter.shared.attach(output: url, to: lastJobID) }
        ActionRunner.notify(title: "Translated", body: url.lastPathComponent, file: url)
        return url
    }

    private func stateChanged(_ state: TranslateModel.State) {
        let jobs = JobCenter.shared
        switch state {
        case .translating(let done, let total):
            if jobID == nil {
                lastJobID = nil
                jobID = jobs.begin(title: "Translate", file: model.file.lastPathComponent) { [weak self] in self?.model.cancel() }
            }
            let fraction = Double(done) / Double(max(total, 1))
            if let jobID { jobs.update(jobID, progress: fraction, status: "\(Int(fraction * 100))%") }
        case .done:
            finishJob(.succeeded)
            // nobody is looking at the window: keep the result instead of losing it
            if windowClosed { save() }
            releaseIfClosed()
        case .failed(let message):
            let stopped = message.hasPrefix("Stopped")
            finishJob(stopped ? .cancelled : .failed, detail: message)
            if windowClosed && !stopped { ActionRunner.notify(title: "Translate failed", body: message) }
            releaseIfClosed()
        case .idle:
            finishJob(.cancelled)
            releaseIfClosed()
        }
    }

    private func finishJob(_ state: JobCenter.State, detail: String? = nil) {
        guard let id = jobID else { return }
        JobCenter.shared.finish(id, state: state, detail: detail)
        if state == .succeeded { lastJobID = id }
        jobID = nil
    }

    private func releaseIfClosed() {
        if windowClosed { onClose?(self) }
    }
}

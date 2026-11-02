import AppKit
import SwiftUI

@MainActor
final class LinesWindowController: NSObject, NSWindowDelegate {
    var onClose: ((LinesWindowController) -> Void)?

    private let window: NSWindow
    private let model: LinesModel

    init(folder: URL) {
        model = LinesModel(folder: folder)
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Lines of Code"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: LinesView(
            model: model,
            copy: { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.text, forType: .string)
            },
            close: { [weak self] in self?.window.close() }))
        window.center()
        model.scan()
    }

    func show() {
        window.showCentered()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }
}

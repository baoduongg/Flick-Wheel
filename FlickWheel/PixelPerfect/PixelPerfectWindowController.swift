import AppKit
import SwiftUI

@MainActor
final class PixelPerfectWindowController: NSObject, NSWindowDelegate {
    var onClose: ((PixelPerfectWindowController) -> Void)?

    private let window: NSWindow
    private let model: PixelPerfectModel
    private let source: URL

    init?(files: [URL]) {
        guard files.count == 2, let base = ImageCropper.load(files[0]), let overlay = ImageCropper.load(files[1]) else {
            return nil
        }
        source = files[0]
        model = PixelPerfectModel(base: base, overlay: overlay,
                                      baseName: files[0].lastPathComponent, overlayName: files[1].lastPathComponent)
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = "Pixel Perfect"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: PixelPerfectView(model: model) { [weak self] in self?.save() })
        window.center()
    }

    func show() {
        window.showCentered()
    }

    private func save() {
        guard let rendered = PixelPerfectCanvas.render(model) else {
            ActionRunner.notify(title: "Pixel Perfect failed", body: "Cannot render the comparison")
            return
        }
        do {
            let output = try ImageCropper.write(rendered, beside: source, suffix: "-compare")
            ActionRunner.notify(title: "Comparison saved", body: output.lastPathComponent)
            window.close()
        } catch {
            ActionRunner.notify(title: "Pixel Perfect failed", body: error.localizedDescription)
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }
}

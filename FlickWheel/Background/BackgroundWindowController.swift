import AppKit
import SwiftUI

@MainActor
final class BackgroundWindowController: NSObject, NSWindowDelegate {
    var onClose: ((BackgroundWindowController) -> Void)?

    private let window: NSWindow
    private let model: BackgroundModel
    private let image: CGImage
    private let source: URL

    init?(file: URL) {
        guard let image = ImageCropper.load(file) else { return nil }
        self.image = image
        source = file
        model = BackgroundModel(imageSize: CGSize(width: image.width, height: image.height))
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = "Add BG"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: BackgroundView(model: model, image: image) { [weak self] in self?.save() })
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func save() {
        guard let rendered = BackgroundRenderView.render(image: image, model: model) else {
            ActionRunner.notify(title: "Add BG failed", body: "Cannot render the image")
            return
        }
        do {
            let output = try ImageCropper.write(rendered, beside: source, suffix: "-bg")
            ActionRunner.notify(title: "Background added", body: output.lastPathComponent)
            window.close()
        } catch {
            ActionRunner.notify(title: "Add BG failed", body: error.localizedDescription)
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }
}

import AppKit
import SwiftUI

@MainActor
final class CropWindowController: NSObject, NSWindowDelegate {
    var onClose: ((CropWindowController) -> Void)?

    private let window: NSWindow
    private let model: CropModel
    private let image: CGImage
    private let source: URL

    init?(file: URL) {
        guard let image = ImageCropper.load(file) else { return nil }
        self.image = image
        source = file
        model = CropModel(imageSize: CGSize(width: image.width, height: image.height))
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Crop Image"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: CropView(model: model, image: image) { [weak self] in self?.apply() })
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func apply() {
        do {
            let output = try ImageCropper.crop(image, to: model.pixelRect, source: source)
            ActionRunner.notify(title: "Crop done", body: output.lastPathComponent)
            window.close()
        } catch {
            ActionRunner.notify(title: "Crop failed", body: error.localizedDescription)
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }
}

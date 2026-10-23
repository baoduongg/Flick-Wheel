import AppKit
import SwiftUI

@MainActor
final class AnnotateWindowController: NSObject, NSWindowDelegate {
    var onClose: ((AnnotateWindowController) -> Void)?

    private let window: NSWindow
    private let model: AnnotateModel
    private let image: CGImage
    private let source: URL
    private let suffix: String

    init?(file: URL, tool: AnnotationTool = .arrow) {
        guard let image = ImageCropper.load(file) else { return nil }
        self.image = image
        source = file
        suffix = tool == .redact ? "-redacted" : "-annotated"
        model = AnnotateModel(imageSize: CGSize(width: image.width, height: image.height), tool: tool)
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = "Annotate Photo"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: AnnotateView(model: model, image: image) { [weak self] in self?.save() })
        window.center()
    }

    func show() {
        window.showCentered()
    }

    private func save() {
        model.finishEditing()
        guard let rendered = AnnotatedImageView.render(image: image, annotations: model.annotations, base: model.base) else {
            ActionRunner.notify(title: "Annotate failed", body: "Cannot render the image")
            return
        }
        do {
            let output = try ImageCropper.write(rendered, beside: source, suffix: suffix)
            ActionRunner.notify(title: "Copy saved", body: output.lastPathComponent)
            window.close()
        } catch {
            ActionRunner.notify(title: "Annotate failed", body: error.localizedDescription)
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }
}

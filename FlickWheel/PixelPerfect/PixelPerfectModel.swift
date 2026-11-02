import Combine
import CoreGraphics

enum ComparisonMode: String, CaseIterable, Identifiable {
    case overlay = "Overlay"
    case difference = "Difference"
    case swipe = "Swipe"

    var id: String { rawValue }
}

@MainActor
final class PixelPerfectModel: ObservableObject {
    @Published private(set) var base: CGImage
    @Published private(set) var overlay: CGImage
    @Published private(set) var baseName: String
    @Published private(set) var overlayName: String
    @Published var mode: ComparisonMode = .overlay
    @Published var opacity = 0.5
    // swipe divider, 0...1 of the canvas width
    @Published var split = 0.5
    // overlay shift in base pixels
    @Published var offset = CGPoint.zero
    // 1 = whole base fits the window
    @Published var zoom = 1.0
    // marks live in base pixels; forwarded below so one observer sees every change
    @Published private(set) var annotate: AnnotateModel
    private var forward: AnyCancellable?

    init(base: CGImage, overlay: CGImage, baseName: String, overlayName: String) {
        self.base = base
        self.overlay = overlay
        self.baseName = baseName
        self.overlayName = overlayName
        annotate = Self.makeAnnotate(for: base)
        track()
    }

    private static func makeAnnotate(for image: CGImage) -> AnnotateModel {
        AnnotateModel(imageSize: CGSize(width: image.width, height: image.height), tool: .rectangle)
    }

    private func track() {
        forward = annotate.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var baseSize: CGSize { CGSize(width: base.width, height: base.height) }

    // the overlay is scaled to the base width, so a 3x phone screenshot lines up with a 1x design
    var overlaySize: CGSize {
        let ratio = baseSize.width / Double(overlay.width)
        return CGSize(width: baseSize.width, height: Double(overlay.height) * ratio)
    }

    var isAligned: Bool { offset == .zero }

    func nudge(_ dx: Double, _ dy: Double) {
        offset = CGPoint(x: offset.x + dx, y: offset.y + dy)
    }

    // marks are in base pixels, so they would land on the wrong spot once the roles trade places
    var canSwap: Bool { annotate.annotations.isEmpty }

    func swap() {
        guard canSwap else { return }
        (base, overlay) = (overlay, base)
        (baseName, overlayName) = (overlayName, baseName)
        offset = .zero
        annotate = Self.makeAnnotate(for: base)
        track()
    }
}

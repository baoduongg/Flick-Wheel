import Combine
import CoreGraphics

@MainActor
final class BackgroundModel: ObservableObject {
    let imageSize: CGSize
    @Published var backdrop: Backdrop = .gradient(0)
    @Published var customImage: CGImage?
    @Published var padding: Double
    @Published var corners: Double
    @Published var shadow: Double
    @Published var ratio: BackgroundRatio = .auto

    private let defaults: (padding: Double, corners: Double, shadow: Double)

    init(imageSize: CGSize) {
        self.imageSize = imageSize
        let longest = max(imageSize.width, imageSize.height)
        defaults = ((longest * 0.06).rounded(), (longest * 0.01).rounded(), (longest * 0.012).rounded())
        padding = defaults.padding
        corners = defaults.corners
        shadow = defaults.shadow
    }

    private var longest: Double { max(imageSize.width, imageSize.height) }

    var paddingRange: ClosedRange<Double> { 0...(longest * 0.5).rounded() }
    var cornerRange: ClosedRange<Double> { 0...(min(imageSize.width, imageSize.height) / 2).rounded() }
    var shadowRange: ClosedRange<Double> { 0...(longest * 0.1).rounded() }

    // the canvas only ever grows to reach the ratio, so the photo is never cropped
    var canvasSize: CGSize {
        let w = imageSize.width + 2 * padding
        let h = imageSize.height + 2 * padding
        guard let r = ratio.value else { return CGSize(width: w, height: h) }
        return w / h < r ? CGSize(width: (h * r).rounded(), height: h) : CGSize(width: w, height: (w / r).rounded())
    }

    var isDefault: Bool {
        backdrop == .gradient(0) && padding == defaults.padding && corners == defaults.corners
            && shadow == defaults.shadow && ratio == .auto
    }

    func reset() {
        backdrop = .gradient(0)
        padding = defaults.padding
        corners = defaults.corners
        shadow = defaults.shadow
        ratio = .auto
    }
}

import SwiftUI

// one drawing path for the live stage (scale <= zoomed fit) and the saved copy
struct PixelPerfectCanvas: View {
    @ObservedObject var model: PixelPerfectModel
    let annotations: [Annotation]
    let scale: CGFloat
    var selection: CGRect?

    private static let exportLongest: CGFloat = 1600

    // small designs are upscaled so the saved copy stays legible
    @MainActor
    static func render(_ model: PixelPerfectModel) -> CGImage? {
        let base = model.baseSize
        let scale = max(1, (exportLongest / max(base.width, base.height)).rounded(.up))
        let renderer = ImageRenderer(content: PixelPerfectCanvas(model: model, annotations: model.annotate.annotations, scale: scale))
        renderer.scale = 1
        return renderer.cgImage
    }

    var body: some View {
        let base = model.baseSize
        let overlay = model.overlaySize
        let size = CGSize(width: base.width * scale, height: base.height * scale)
        let interpolation: Image.Interpolation = scale > 1 ? .none : .high
        ZStack(alignment: .topLeading) {
            Image(decorative: model.base, scale: 1)
                .resizable()
                .interpolation(interpolation)
                .frame(width: size.width, height: size.height)
            ZStack(alignment: .topLeading) {
                Image(decorative: model.overlay, scale: 1)
                    .resizable()
                    .interpolation(interpolation)
                    .frame(width: overlay.width * scale, height: overlay.height * scale)
                    .offset(x: model.offset.x * scale, y: model.offset.y * scale)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .mask(alignment: .leading) {
                Rectangle().frame(width: model.mode == .swipe ? size.width * model.split : size.width)
            }
            .opacity(model.mode == .overlay ? model.opacity : 1)
            .blendMode(model.mode == .difference ? .difference : .normal)
            AnnotationLayer(pixelSize: base, annotations: annotations, base: model.annotate.base,
                            scale: scale, selection: selection)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .compositingGroup()
    }
}

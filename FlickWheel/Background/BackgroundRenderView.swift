import SwiftUI

// one composition for both the live preview (scale < 1) and the full-resolution export (scale 1)
struct BackgroundRenderView: View {
    let image: CGImage
    let canvas: CGSize
    let padding: Double
    let corners: Double
    let shadow: Double
    let backdrop: Backdrop
    let customImage: CGImage?
    let scale: CGFloat

    @MainActor
    static func render(image: CGImage, model: BackgroundModel) -> CGImage? {
        let view = BackgroundRenderView(image: image, canvas: model.canvasSize, padding: model.padding,
                                        corners: model.corners, shadow: model.shadow, backdrop: model.backdrop,
                                        customImage: model.customImage, scale: 1)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.cgImage
    }

    var body: some View {
        let size = CGSize(width: canvas.width * scale, height: canvas.height * scale)
        ZStack {
            backdropLayer(size)
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                .clipShape(RoundedRectangle(cornerRadius: corners * scale, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: shadow * scale, x: 0, y: shadow * scale * 0.4)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func backdropLayer(_ size: CGSize) -> some View {
        switch backdrop {
        case .gradient(let index):
            LinearGradient(colors: Backdrop.gradients[index].map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .solid(let color):
            Color(red: color.r, green: color.g, blue: color.b)
        case .image:
            if let customImage {
                Image(decorative: customImage, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Color.white
            }
        }
    }
}

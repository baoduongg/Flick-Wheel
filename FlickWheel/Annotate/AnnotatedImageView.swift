import SwiftUI

// one drawing path for both the live preview (scale < 1) and the full-resolution export (scale 1)
struct AnnotatedImageView: View {
    let image: CGImage
    let annotations: [Annotation]
    let base: CGFloat
    let scale: CGFloat
    var selection: CGRect?

    private var size: CGSize {
        CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    }

    @MainActor
    static func render(image: CGImage, annotations: [Annotation], base: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: AnnotatedImageView(image: image, annotations: annotations, base: base, scale: 1))
        renderer.scale = 1
        return renderer.cgImage
    }

    var body: some View {
        ZStack {
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: size.width, height: size.height)
            AnnotationLayer(pixelSize: CGSize(width: image.width, height: image.height),
                            annotations: annotations, base: base, scale: scale, selection: selection)
        }
        .frame(width: size.width, height: size.height)
    }
}

// just the marks, so other windows can draw them over their own picture
struct AnnotationLayer: View {
    let pixelSize: CGSize
    let annotations: [Annotation]
    let base: CGFloat
    let scale: CGFloat
    var selection: CGRect?

    var body: some View {
        Canvas { context, _ in
            for annotation in annotations {
                draw(annotation, in: &context)
            }
            if let selection {
                let rect = CGRect(x: selection.minX * scale, y: selection.minY * scale,
                                  width: selection.width * scale, height: selection.height * scale)
                context.stroke(Path(rect), with: .color(.white),
                               style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .frame(width: pixelSize.width * scale, height: pixelSize.height * scale)
    }

    private func draw(_ a: Annotation, in context: inout GraphicsContext) {
        let color = Color(red: a.color.r, green: a.color.g, blue: a.color.b)
        let p = a.points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
        let w = base * scale
        let round = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
        switch a.tool {
        case .arrow:
            let tail = p[0], head = p[1]
            let angle = atan2(head.y - tail.y, head.x - tail.x)
            let length = w * 5
            let spread = CGFloat.pi / 7
            var line = Path()
            line.move(to: tail)
            line.addLine(to: CGPoint(x: head.x - length * 0.8 * cos(angle), y: head.y - length * 0.8 * sin(angle)))
            context.stroke(line, with: .color(color), style: round)
            var tip = Path()
            tip.move(to: head)
            tip.addLine(to: CGPoint(x: head.x - length * cos(angle - spread), y: head.y - length * sin(angle - spread)))
            tip.addLine(to: CGPoint(x: head.x - length * cos(angle + spread), y: head.y - length * sin(angle + spread)))
            tip.closeSubpath()
            context.fill(tip, with: .color(color))
        case .rectangle:
            context.stroke(Path(box(p)), with: .color(color), style: round)
        case .redact:
            context.fill(Path(box(p)), with: .color(color))
        case .ellipse:
            context.stroke(Path(ellipseIn: box(p)), with: .color(color), style: round)
        case .pen:
            context.stroke(polyline(p), with: .color(color), style: round)
        case .highlighter:
            context.stroke(polyline(p), with: .color(color.opacity(0.35)),
                           style: StrokeStyle(lineWidth: w * 5, lineCap: .round, lineJoin: .round))
        case .text:
            context.draw(Text(a.text).font(.system(size: w * 8, weight: .bold)).foregroundColor(color),
                         at: p[0], anchor: .topLeading)
        case .badge:
            let r = w * 5
            context.fill(Path(ellipseIn: CGRect(x: p[0].x - r, y: p[0].y - r, width: 2 * r, height: 2 * r)),
                         with: .color(color))
            context.draw(Text("\(a.number)").font(.system(size: w * 6, weight: .bold)).foregroundColor(.white),
                         at: p[0], anchor: .center)
        }
    }

    private func box(_ p: [CGPoint]) -> CGRect {
        CGRect(x: min(p[0].x, p[1].x), y: min(p[0].y, p[1].y), width: abs(p[1].x - p[0].x), height: abs(p[1].y - p[0].y))
    }

    private func polyline(_ p: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: p[0])
        p.dropFirst().forEach { path.addLine(to: $0) }
        if p.count == 1 { path.addLine(to: p[0]) }
        return path
    }
}

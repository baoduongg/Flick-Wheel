import CoreGraphics
import Foundation

struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    static let red = RGB(r: 0.93, g: 0.24, b: 0.24)
}

// points live in image pixels with a top-left origin; base is the stroke unit derived from the image size
struct Annotation: Identifiable, Equatable {
    let id = UUID()
    let tool: AnnotationTool
    var color: RGB
    var points: [CGPoint]
    var text = ""
    var number = 0

    static func textSize(_ text: String, base: CGFloat) -> CGSize {
        let fontSize = base * 8
        return CGSize(width: max(fontSize, CGFloat(text.count) * fontSize * 0.6), height: fontSize * 1.25)
    }

    func bounds(base: CGFloat) -> CGRect {
        switch tool {
        case .text:
            return CGRect(origin: points[0], size: Self.textSize(text, base: base))
        case .badge:
            let r = base * 5
            return CGRect(x: points[0].x - r, y: points[0].y - r, width: 2 * r, height: 2 * r)
        default:
            let xs = points.map(\.x), ys = points.map(\.y)
            return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                          width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
        }
    }

    // distance from p to the visible mark: outlines only for shapes, so drawing inside one doesn't grab it
    func distance(to p: CGPoint, base: CGFloat) -> CGFloat {
        switch tool {
        case .arrow, .pen, .highlighter:
            guard points.count > 1 else { return hypot(p.x - points[0].x, p.y - points[0].y) }
            return zip(points, points.dropFirst()).map { Self.segmentDistance(p, $0, $1) }.min() ?? .infinity
        case .rectangle, .redact:
            let r = bounds(base: base)
            let dx = max(r.minX - p.x, 0, p.x - r.maxX)
            let dy = max(r.minY - p.y, 0, p.y - r.maxY)
            if dx > 0 || dy > 0 { return hypot(dx, dy) }
            return min(p.x - r.minX, r.maxX - p.x, p.y - r.minY, r.maxY - p.y)
        case .ellipse:
            let r = bounds(base: base)
            let a = max(r.width / 2, 1), b = max(r.height / 2, 1)
            return abs(hypot((p.x - r.midX) / a, (p.y - r.midY) / b) - 1) * min(a, b)
        case .text:
            let r = bounds(base: base)
            return hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
        case .badge:
            return max(0, hypot(p.x - points[0].x, p.y - points[0].y) - base * 5)
        }
    }

    mutating func translate(by delta: CGSize) {
        points = points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
    }

    private static func segmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared, 0), 1)
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

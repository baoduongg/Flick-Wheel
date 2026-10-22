import Combine
import CoreGraphics

enum CropHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

// rect lives in image pixels with a top-left origin, the same space CGImage.cropping(to:) uses
@MainActor
final class CropModel: ObservableObject {
    static let minSize: CGFloat = 16

    let imageSize: CGSize
    @Published private(set) var rect: CGRect
    @Published var ratio: CropRatio = .free {
        didSet { applyRatio() }
    }

    init(imageSize: CGSize) {
        self.imageSize = imageSize
        rect = CGRect(origin: .zero, size: imageSize)
    }

    var pixelRect: CGRect {
        CGRect(x: rect.minX.rounded(), y: rect.minY.rounded(), width: rect.width.rounded(), height: rect.height.rounded())
    }

    func reset() {
        ratio = .free
        rect = CGRect(origin: .zero, size: imageSize)
    }

    func move(from start: CGRect, by delta: CGSize) {
        rect = clamped(start.offsetBy(dx: delta.width, dy: delta.height))
    }

    func setWidth(_ value: Int) {
        var w = min(max(CGFloat(value), Self.minSize), imageSize.width)
        var h = rect.height
        if let r = ratio.value {
            h = w / r
            if h > imageSize.height {
                h = imageSize.height
                w = h * r
            }
        }
        rect = clamped(CGRect(x: rect.minX, y: rect.minY, width: w, height: h))
    }

    func setHeight(_ value: Int) {
        var h = min(max(CGFloat(value), Self.minSize), imageSize.height)
        var w = rect.width
        if let r = ratio.value {
            w = h * r
            if w > imageSize.width {
                w = imageSize.width
                h = w / r
            }
        }
        rect = clamped(CGRect(x: rect.minX, y: rect.minY, width: w, height: h))
    }

    func resize(_ handle: CropHandle, to point: CGPoint) {
        let p = CGPoint(x: min(max(point.x, 0), imageSize.width), y: min(max(point.y, 0), imageSize.height))
        if let r = ratio.value {
            rect = fixedRatioRect(handle, p, r)
        } else {
            rect = freeRect(handle, p)
        }
    }

    private func applyRatio() {
        guard let r = ratio.value else { return }
        var w = imageSize.width
        var h = w / r
        if h > imageSize.height {
            h = imageSize.height
            w = h * r
        }
        rect = clamped(CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
    }

    private func clamped(_ r: CGRect) -> CGRect {
        CGRect(x: min(max(r.minX, 0), imageSize.width - r.width),
               y: min(max(r.minY, 0), imageSize.height - r.height),
               width: r.width, height: r.height)
    }

    private func freeRect(_ handle: CropHandle, _ p: CGPoint) -> CGRect {
        let m = Self.minSize
        var minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        switch handle {
        case .left, .topLeft, .bottomLeft: minX = min(p.x, maxX - m)
        case .right, .topRight, .bottomRight: maxX = max(p.x, minX + m)
        case .top, .bottom: break
        }
        switch handle {
        case .top, .topLeft, .topRight: minY = min(p.y, maxY - m)
        case .bottom, .bottomLeft, .bottomRight: maxY = max(p.y, minY + m)
        case .left, .right: break
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func fixedRatioRect(_ handle: CropHandle, _ p: CGPoint, _ r: CGFloat) -> CGRect {
        let m = Self.minSize
        switch handle {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            let sx: CGFloat = (handle == .topLeft || handle == .bottomLeft) ? -1 : 1
            let sy: CGFloat = (handle == .topLeft || handle == .topRight) ? -1 : 1
            let anchor = CGPoint(x: sx < 0 ? rect.maxX : rect.minX, y: sy < 0 ? rect.maxY : rect.minY)
            let availW = sx < 0 ? anchor.x : imageSize.width - anchor.x
            let availH = sy < 0 ? anchor.y : imageSize.height - anchor.y
            var w = max((p.x - anchor.x) * sx, (p.y - anchor.y) * sy * r)
            w = max(min(w, availW, availH * r), m)
            let h = w / r
            return CGRect(x: sx < 0 ? anchor.x - w : anchor.x, y: sy < 0 ? anchor.y - h : anchor.y, width: w, height: h)
        case .left, .right:
            let edge = handle == .left ? rect.maxX : rect.minX
            let availW = handle == .left ? edge : imageSize.width - edge
            let cy = rect.midY
            var w = handle == .left ? edge - p.x : p.x - edge
            w = max(min(w, availW, 2 * min(cy, imageSize.height - cy) * r), m)
            let h = w / r
            return CGRect(x: handle == .left ? edge - w : edge, y: cy - h / 2, width: w, height: h)
        case .top, .bottom:
            let edge = handle == .top ? rect.maxY : rect.minY
            let availH = handle == .top ? edge : imageSize.height - edge
            let cx = rect.midX
            var h = handle == .top ? edge - p.y : p.y - edge
            h = max(min(h, availH, 2 * min(cx, imageSize.width - cx) / r), m)
            let w = h * r
            return CGRect(x: cx - w / 2, y: handle == .top ? edge - h : edge, width: w, height: h)
        }
    }
}

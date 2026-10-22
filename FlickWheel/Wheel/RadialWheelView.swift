import SwiftUI

struct RadialWheelView: View {
    static let ringThickness: CGFloat = 90

    // the ring grows with the segment count so neighbouring labels never overlap
    static func radii(count: Int) -> (inner: CGFloat, outer: CGFloat) {
        let mid = max(110, CGFloat(count) * 92 / (2 * .pi))
        return (mid - ringThickness / 2, mid + ringThickness / 2)
    }

    static func size(count: Int) -> CGFloat {
        2 * radii(count: count).outer + 20
    }

    // Finder draws the dragged file name on a horizontal band through the cursor; keep segment labels off that band
    static func startDegrees(count: Int) -> Double {
        count % 4 == 0 ? 0 : -180.0 / Double(count)
    }

    let actions: [WheelAction]
    let hovered: Int?

    var body: some View {
        ZStack {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                RingSegment(index: index, count: actions.count)
                    .fill(index == hovered ? Color.accentColor : Color(white: 0.1, opacity: 0.92))
                    .overlay(RingSegment(index: index, count: actions.count).stroke(Color.white.opacity(0.2), lineWidth: 1))
                label(action.label, at: index)
            }
        }
        .frame(width: Self.size(count: actions.count), height: Self.size(count: actions.count))
        .allowsHitTesting(false)
    }

    private func label(_ text: String, at index: Int) -> some View {
        let radii = Self.radii(count: actions.count)
        let radius = (radii.inner + radii.outer) / 2
        let step = 2 * Double.pi / Double(actions.count)
        let theta = Self.startDegrees(count: actions.count) * .pi / 180 + (Double(index) + 0.5) * step
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.6), radius: 1)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .frame(width: 88)
            .offset(x: radius * CGFloat(sin(theta)), y: -radius * CGFloat(cos(theta)))
    }
}

private struct RingSegment: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let step = 360.0 / Double(count)
        let gap = count > 1 ? 1.5 : 0.0
        let origin = -90 + RadialWheelView.startDegrees(count: count)
        let start = Angle.degrees(origin + Double(index) * step + gap)
        let end = Angle.degrees(origin + Double(index + 1) * step - gap)
        let radii = RadialWheelView.radii(count: count)
        var path = Path()
        path.addArc(center: center, radius: radii.outer,
                    startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: radii.inner,
                    startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

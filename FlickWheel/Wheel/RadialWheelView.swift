import SwiftUI

struct RadialWheelView: View {
    static let ringThickness: CGFloat = 90

    // the ring grows with the segment count so neighbouring labels never overlap
    static func radii(count: Int) -> (inner: CGFloat, outer: CGFloat) {
        let mid = max(110, CGFloat(count) * 92 / (2 * .pi))
        return (mid - ringThickness / 2, mid + ringThickness / 2)
    }

    static func size(count: Int) -> CGFloat {
        2 * radii(count: count).outer + 48
    }

    // Finder draws the dragged file name on a horizontal band through the cursor; keep segment labels off that band
    static func startDegrees(count: Int) -> Double {
        count % 4 == 0 ? 0 : -180.0 / Double(count)
    }

    @ObservedObject var state: WheelState

    var body: some View {
        let size = Self.size(count: state.actions.count)
        ZStack {
            CenterDisc(radius: Self.radii(count: state.actions.count).inner - 6, shown: state.shown)
            ForEach(Array(state.actions.enumerated()), id: \.element.id) { index, action in
                GlassSegment(action: action, index: index, count: state.actions.count,
                             hovered: state.hovered == index, shown: state.shown)
            }
            if let hovered = state.hovered, state.actions.indices.contains(hovered),
               let description = state.actions[hovered].description {
                Text(description)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .frame(width: 96)
            }
            // own observed object: cursor moves must not re-evaluate the segments above
            PuckLayer(puck: state.puck)
        }
        .frame(width: size, height: size)
        // glass reads best over a dark tint whatever the system appearance is
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
    }
}

// opaque-ish backdrop so the description stays legible over any window behind the wheel
private struct CenterDisc: View {
    let radius: CGFloat
    let shown: Bool

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.62))
            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(shown ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: shown)
    }
}

private struct PuckLayer: View {
    @ObservedObject var puck: PuckState

    var body: some View {
        Group {
            if let cursor = puck.cursor, let icon = puck.icon {
                DragPuck(icon: icon, count: puck.fileCount)
                    .position(cursor)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: puck.cursor != nil)
    }
}

// stands in for Finder's drag image: icon only, never the file name
private struct DragPuck: View {
    let icon: NSImage
    let count: Int

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: 8, y: -6)
                }
            }
    }
}

final class WheelState: ObservableObject {
    @Published var actions: [WheelAction] = []
    @Published var hovered: Int?
    @Published var shown = false
    let puck = PuckState()
}

// drag puck: cursor in the wheel view's top-left coordinates
final class PuckState: ObservableObject {
    @Published var cursor: CGPoint?
    @Published var icon: NSImage?
    @Published var fileCount = 0
}

private struct GlassSegment: View {
    let action: WheelAction
    let index: Int
    let count: Int
    let hovered: Bool
    let shown: Bool

    private var size: CGFloat { RadialWheelView.size(count: count) }

    private var theta: Double {
        let step = 2 * Double.pi / Double(count)
        return RadialWheelView.startDegrees(count: count) * .pi / 180 + (Double(index) + 0.5) * step
    }

    private var midRadius: CGFloat {
        let radii = RadialWheelView.radii(count: count)
        return (radii.inner + radii.outer) / 2
    }

    var body: some View {
        let shape = RingSegment(index: index, count: count)
        ZStack {
            shape.fill(.regularMaterial)
            // faint top light, like the vibrancy on menus and popovers
            shape.fill(LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom))
            // selection reads like a menu highlight: solid system accent, white content
            shape.fill(Color.accentColor.opacity(hovered ? 0.92 : 0))
            shape.stroke(Color.white.opacity(hovered ? 0.35 : 0.16), lineWidth: 0.5)
            label
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        // pop out of the ring from the segment centre
        .scaleEffect(hovered ? 1.08 : 1, anchor: UnitPoint(x: 0.5 + midRadius * CGFloat(sin(theta)) / size,
                                                          y: 0.5 - midRadius * CGFloat(cos(theta)) / size))
        .offset(x: hovered ? 6 * CGFloat(sin(theta)) : 0, y: hovered ? -6 * CGFloat(cos(theta)) : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: hovered)
        // staggered entrance from the wheel centre
        .scaleEffect(shown ? 1 : 0.6)
        .opacity(shown ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(index) * 0.012), value: shown)
    }

    private var label: some View {
        VStack(spacing: 4) {
            Image(systemName: ActionIcon.symbol(for: action))
                .font(.system(size: 22, weight: .regular))
                .symbolRenderingMode(.hierarchical)
            Text(action.label)
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
        .frame(width: 76)
        .offset(x: midRadius * CGFloat(sin(theta)), y: -midRadius * CGFloat(cos(theta)))
    }
}

private struct RingSegment: Shape {
    static let seam: CGFloat = 4
    static let corner: CGFloat = 9

    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let step = 360.0 / Double(count)
        let origin = -90 + RadialWheelView.startDegrees(count: count)
        let corner = Self.corner
        let radii = RadialWheelView.radii(count: count)
        let inner = radii.inner + corner, outer = radii.outer - corner
        // constant-width seam: the angular inset shrinks with radius, so edges stay parallel instead of wedge-shaped
        func inset(_ radius: CGFloat) -> Double {
            count > 1 ? asin(Double((Self.seam / 2 + corner) / radius)) * 180 / .pi : 0
        }
        func point(_ radius: CGFloat, _ degrees: Double) -> CGPoint {
            CGPoint(x: center.x + radius * CGFloat(cos(degrees * .pi / 180)),
                    y: center.y + radius * CGFloat(sin(degrees * .pi / 180)))
        }
        let from = origin + Double(index) * step
        let to = origin + Double(index + 1) * step
        let a1 = from + inset(outer), a2 = to - inset(outer)
        let a3 = to - inset(inner), a4 = from + inset(inner)
        // outer arc, then a round corner at each of the four vertices of the inset core
        var path = Path()
        path.addArc(center: center, radius: outer + corner, startAngle: .degrees(a1), endAngle: .degrees(a2), clockwise: false)
        path.addArc(center: point(outer, a2), radius: corner, startAngle: .degrees(a2), endAngle: .degrees(to + 90), clockwise: false)
        path.addArc(center: point(inner, a3), radius: corner, startAngle: .degrees(to + 90), endAngle: .degrees(a3 + 180), clockwise: false)
        path.addArc(center: center, radius: inner - corner, startAngle: .degrees(a3), endAngle: .degrees(a4), clockwise: true)
        path.addArc(center: point(inner, a4), radius: corner, startAngle: .degrees(a4 + 180), endAngle: .degrees(from + 270), clockwise: false)
        path.addArc(center: point(outer, a1), radius: corner, startAngle: .degrees(from - 90), endAngle: .degrees(a1), clockwise: false)
        path.closeSubpath()
        return path
    }
}

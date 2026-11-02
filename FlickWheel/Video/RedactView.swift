import AppKit
import SwiftUI

struct RedactView: View {
    let session: VideoSession
    @ObservedObject var model: VideoModel
    let onApply: () -> Void

    private static let labelWidth: CGFloat = 22
    private static let rowHeight: CGFloat = 22

    private var color: Binding<Color> {
        Binding(get: { Color(red: model.redactColor.r, green: model.redactColor.g, blue: model.redactColor.b) },
                set: {
                    let c = NSColor($0).usingColorSpace(.sRGB) ?? .black
                    model.redactColor = VideoColor(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent))
                })
    }

    var body: some View {
        VStack(spacing: 12) {
            VideoPane(player: session.player.player, height: 340)
                .overlay { RedactOverlay(model: model) }
            HStack {
                Text("Style")
                Spacer()
                Picker("Style", selection: $model.redactStyle) {
                    ForEach(RedactStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 140)
            }
            if model.redactStyle == .solid {
                HStack {
                    Text("Color")
                    Spacer()
                    ColorPicker("Color", selection: color, supportsOpacity: false).labelsHidden()
                }
            }
            Text("Redactions").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
            tracks
            HStack(spacing: 8) {
                Image(systemName: "film").font(VideoStyle.small).foregroundColor(.secondary).frame(width: Self.labelWidth)
                FilmstripView(strip: session.filmstrip, model: model, session: session, height: 44)
            }
            TransportRow(model: model, player: session.player, session: session)
            ApplyRow(title: "Save Redacted Copy", enabled: !model.boxes.isEmpty, action: onApply)
        }
        .font(.system(size: 12))
    }

    private var tracks: some View {
        let rows = model.boxes.count + 1
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(Array(model.boxes.enumerated()), id: \.element.id) { index, box in
                    row(index + 1) { w in bar(box, index: index + 1, width: w) }
                }
                row(rows) { w in addTrack(width: w) }
            }
        }
        .frame(height: min(CGFloat(rows) * (Self.rowHeight + 4), 4 * (Self.rowHeight + 4)))
    }

    private func row<Content: View>(_ number: Int, @ViewBuilder content: @escaping (CGFloat) -> Content) -> some View {
        HStack(spacing: 8) {
            Text("\(number)").font(VideoStyle.small).foregroundColor(.secondary).frame(width: Self.labelWidth)
            GeometryReader { geo in
                content(geo.size.width)
                    .frame(width: geo.size.width, height: Self.rowHeight)
                    .coordinateSpace(name: "track")
            }
            .frame(height: Self.rowHeight)
        }
    }

    private func bar(_ box: RedactBox, index: Int, width w: CGFloat) -> some View {
        let sx = CGFloat(box.start / model.duration) * w
        let ex = CGFloat(box.end / model.duration) * w
        let selected = box.id == model.selectedBox
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.07))
            RoundedRectangle(cornerRadius: 6)
                .fill(VideoStyle.accent.opacity(selected ? 0.85 : 0.55))
                .frame(width: max(ex - sx, 24))
                .overlay {
                    HStack(spacing: 4) {
                        Image(systemName: model.redactStyle == .solid ? "square.fill" : "drop.fill").font(.system(size: 8))
                        Text("Box \(index)").font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.black.opacity(0.8))
                    .allowsHitTesting(false)
                }
                .offset(x: sx)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("track")).onChanged { v in
                    model.selectedBox = box.id
                    model.shiftBox(box.id, start: box.start + Double((v.location.x - v.startLocation.x) / w) * model.duration)
                })
            edge().offset(x: sx + 3)
                .gesture(trackDrag(w) { model.setBoxStart(box.id, $0) })
            edge().offset(x: max(ex, sx + 24) - 8)
                .gesture(trackDrag(w) { model.setBoxEnd(box.id, $0) })
        }
    }

    private func edge() -> some View {
        Capsule().fill(Color.white).frame(width: 3, height: 14).padding(.vertical, 4).padding(.horizontal, 5)
            .contentShape(Rectangle())
    }

    private func trackDrag(_ w: CGFloat, _ change: @escaping (Double) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track")).onChanged {
            change(Double(min(max($0.location.x, 0), w) / w) * model.duration)
        }
    }

    // dragging across the empty track adds a redaction over that time range
    private func addTrack(width w: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05))
            Text("Drag to add").font(.system(size: 10)).foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("track")).onEnded { v in
            let a = Double(min(max(v.startLocation.x, 0), w) / w) * model.duration
            let b = Double(min(max(v.location.x, 0), w) / w) * model.duration
            model.addBox(start: min(a, b), end: abs(b - a) < 0.2 ? a + 2 : max(a, b))
        })
    }
}

struct RedactOverlay: View {
    @ObservedObject var model: VideoModel
    @State private var moveStart: CGRect?

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / model.size.width, geo.size.height / model.size.height)
            let origin = CGPoint(x: (geo.size.width - model.size.width * scale) / 2,
                                 y: (geo.size.height - model.size.height * scale) / 2)
            ZStack(alignment: .topLeading) {
                ForEach(model.boxes) { box in
                    let selected = box.id == model.selectedBox
                    if box.isActive(at: model.current) || selected {
                        boxView(box, selected: selected, scale: scale, origin: origin)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .coordinateSpace(name: "video")
        }
    }

    private func fill(_ active: Bool) -> Color {
        let base = model.redactStyle == .solid
            ? Color(red: model.redactColor.r, green: model.redactColor.g, blue: model.redactColor.b)
            : Color.white
        return base.opacity(active ? (model.redactStyle == .solid ? 1 : 0.45) : 0.2)
    }

    @ViewBuilder
    private func boxView(_ box: RedactBox, selected: Bool, scale: CGFloat, origin: CGPoint) -> some View {
        let r = CGRect(x: origin.x + box.rect.minX * scale, y: origin.y + box.rect.minY * scale,
                       width: box.rect.width * scale, height: box.rect.height * scale)
        Rectangle()
            .fill(fill(box.isActive(at: model.current)))
            .overlay { if selected { Rectangle().stroke(VideoStyle.accent, lineWidth: 2) } }
            .frame(width: r.width, height: r.height)
            .contentShape(Rectangle())
            .position(x: r.midX, y: r.midY)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    model.selectedBox = box.id
                    let start = moveStart ?? box.rect
                    moveStart = start
                    model.updateBox(box.id) {
                        $0.move(by: CGSize(width: value.translation.width / scale, height: value.translation.height / scale),
                                from: start, in: model.size)
                    }
                }
                .onEnded { _ in moveStart = nil })
        if selected {
            ForEach(CropHandle.allCases, id: \.self) { handle in
                RoundedRectangle(cornerRadius: 3)
                    .fill(VideoStyle.accent)
                    .frame(width: 10, height: 10)
                    .padding(8)
                    .contentShape(Rectangle())
                    .position(handle.point(in: r))
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("video")).onChanged { value in
                        model.updateBox(box.id) {
                            $0.resize(handle, to: CGPoint(x: (value.location.x - origin.x) / scale,
                                                          y: (value.location.y - origin.y) / scale), in: model.size)
                        }
                    })
            }
        }
    }
}

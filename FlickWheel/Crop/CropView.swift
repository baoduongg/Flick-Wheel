import SwiftUI

struct CropView: View {
    @ObservedObject var model: CropModel
    let image: CGImage
    let onApply: () -> Void

    @State private var moveStart: CGRect?

    private static let accent = Color(red: 1, green: 0.4, blue: 0.2)

    private var width: Binding<Int> {
        Binding(get: { Int(model.rect.width.rounded()) }, set: { model.setWidth($0) })
    }

    private var height: Binding<Int> {
        Binding(get: { Int(model.rect.height.rounded()) }, set: { model.setHeight($0) })
    }

    var body: some View {
        VStack(spacing: 16) {
            preview
                .frame(height: 400)
            HStack {
                Text("Aspect ratio")
                Picker("Aspect ratio", selection: $model.ratio) {
                    ForEach(CropRatio.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            HStack {
                Text("W")
                TextField("W", value: width, format: .number.grouping(.never))
                    .frame(width: 70)
                Text("H")
                TextField("H", value: height, format: .number.grouping(.never))
                    .frame(width: 70)
                Text("px").foregroundColor(.secondary)
                Spacer()
            }
            Divider()
            HStack {
                Button("Reset") { model.reset() }
                Spacer()
                Button("Apply", action: onApply)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var preview: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / model.imageSize.width, geo.size.height / model.imageSize.height)
            let shown = CGSize(width: model.imageSize.width * scale, height: model.imageSize.height * scale)
            let origin = CGPoint(x: (geo.size.width - shown.width) / 2, y: (geo.size.height - shown.height) / 2)
            let frame = CGRect(origin: origin, size: shown)
            let crop = CGRect(x: origin.x + model.rect.minX * scale, y: origin.y + model.rect.minY * scale,
                              width: model.rect.width * scale, height: model.rect.height * scale)
            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .position(x: frame.midX, y: frame.midY)
                Path { path in
                    path.addRect(frame)
                    path.addRect(crop)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
                Rectangle()
                    .stroke(Self.accent, lineWidth: 2)
                    .frame(width: crop.width, height: crop.height)
                    .position(x: crop.midX, y: crop.midY)
                    .allowsHitTesting(false)
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: crop.width, height: crop.height)
                    .position(x: crop.midX, y: crop.midY)
                    .gesture(DragGesture()
                        .onChanged { value in
                            let start = moveStart ?? model.rect
                            moveStart = start
                            model.move(from: start, by: CGSize(width: value.translation.width / scale,
                                                               height: value.translation.height / scale))
                        }
                        .onEnded { _ in moveStart = nil })
                ForEach(CropHandle.allCases, id: \.self) { handle in
                    handleView(handle)
                        .position(handlePoint(handle, in: crop))
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("preview"))
                            .onChanged { value in
                                model.resize(handle, to: CGPoint(x: (value.location.x - origin.x) / scale,
                                                                 y: (value.location.y - origin.y) / scale))
                            })
                }
            }
            .coordinateSpace(name: "preview")
        }
    }

    private func handlePoint(_ handle: CropHandle, in r: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: r.minX, y: r.minY)
        case .top: return CGPoint(x: r.midX, y: r.minY)
        case .topRight: return CGPoint(x: r.maxX, y: r.minY)
        case .right: return CGPoint(x: r.maxX, y: r.midY)
        case .bottomRight: return CGPoint(x: r.maxX, y: r.maxY)
        case .bottom: return CGPoint(x: r.midX, y: r.maxY)
        case .bottomLeft: return CGPoint(x: r.minX, y: r.maxY)
        case .left: return CGPoint(x: r.minX, y: r.midY)
        }
    }

    private func handleView(_ handle: CropHandle) -> some View {
        let size: CGSize
        switch handle {
        case .top, .bottom: size = CGSize(width: 28, height: 7)
        case .left, .right: size = CGSize(width: 7, height: 28)
        default: size = CGSize(width: 12, height: 12)
        }
        return RoundedRectangle(cornerRadius: 3)
            .fill(Self.accent)
            .frame(width: size.width, height: size.height)
            .padding(10)
            .contentShape(Rectangle())
    }
}

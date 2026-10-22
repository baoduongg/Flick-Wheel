import AppKit
import SwiftUI

struct BackgroundView: View {
    @ObservedObject var model: BackgroundModel
    let image: CGImage
    let onSave: () -> Void

    private static let accent = Color(red: 1, green: 0.4, blue: 0.2)

    private var customColor: Binding<Color> {
        Binding(
            get: {
                if case .solid(let c) = model.backdrop { return Color(red: c.r, green: c.g, blue: c.b) }
                return .white
            },
            set: { newValue in
                guard let c = NSColor(newValue).usingColorSpace(.sRGB) else { return }
                model.backdrop = .solid(RGB(r: c.redComponent, g: c.greenComponent, b: c.blueComponent))
            })
    }

    var body: some View {
        VStack(spacing: 14) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.07)))
            HStack(alignment: .top, spacing: 12) {
                Text("Background").frame(width: 80, alignment: .leading)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(Backdrop.gradients.indices, id: \.self) { index in
                            swatch(selected: model.backdrop == .gradient(index)) {
                                LinearGradient(colors: Backdrop.gradients[index].map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            } action: { model.backdrop = .gradient(index) }
                        }
                        Button(action: pickImage) {
                            Image(systemName: "photo.badge.plus")
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Self.accent, lineWidth: model.backdrop == .image ? 2.5 : 0))
                        }
                        .buttonStyle(.plain)
                        .help("Use an image as background")
                    }
                    HStack(spacing: 8) {
                        ForEach(Backdrop.solids.indices, id: \.self) { index in
                            let c = Backdrop.solids[index]
                            swatch(selected: model.backdrop == .solid(c)) {
                                Color(red: c.r, green: c.g, blue: c.b)
                            } action: { model.backdrop = .solid(c) }
                        }
                        ColorPicker("Custom color", selection: customColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }
            slider("Padding", value: $model.padding, range: model.paddingRange)
            slider("Corners", value: $model.corners, range: model.cornerRange)
            slider("Shadow", value: $model.shadow, range: model.shadowRange)
            HStack {
                Text("Ratio").frame(width: 80, alignment: .leading)
                Spacer()
                Picker("Ratio", selection: $model.ratio) {
                    ForEach(BackgroundRatio.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
            Divider()
            HStack {
                Button("Reset") { model.reset() }
                    .disabled(model.isDefault)
                Spacer()
                Button("Save with Background", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 540, maxWidth: .infinity,
               minHeight: 600, idealHeight: 720, maxHeight: .infinity)
    }

    private var preview: some View {
        GeometryReader { geo in
            let canvas = model.canvasSize
            let scale = min((geo.size.width - 40) / canvas.width, (geo.size.height - 40) / canvas.height)
            BackgroundRenderView(image: image, canvas: canvas, padding: model.padding, corners: model.corners,
                                 shadow: model.shadow, backdrop: model.backdrop, customImage: model.customImage,
                                 scale: max(scale, 0.01))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func swatch<Fill: View>(selected: Bool, @ViewBuilder fill: () -> Fill, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            fill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.accent, lineWidth: selected ? 2.5 : 0).padding(-2))
        }
        .buttonStyle(.plain)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            Slider(value: value, in: range)
            Text("\(Int(value.wrappedValue.rounded())) px").frame(width: 64, alignment: .trailing)
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let picked = ImageCropper.load(url) else { return }
        model.customImage = picked
        model.backdrop = .image
    }
}

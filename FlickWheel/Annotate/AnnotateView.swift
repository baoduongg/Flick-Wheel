import AppKit
import SwiftUI

struct AnnotateView: View {
    @ObservedObject var model: AnnotateModel
    let image: CGImage
    let onSave: () -> Void

    @State private var dragging = false
    @State private var zoom: CGFloat?
    @State private var pinchBase: CGFloat?
    @State private var fitScale: CGFloat = 1
    @FocusState private var textFocused: Bool

    private static let accent = Color(red: 1, green: 0.4, blue: 0.2)

    private var color: Binding<Color> {
        Binding(
            get: { Color(red: model.color.r, green: model.color.g, blue: model.color.b) },
            set: { newValue in
                guard let c = NSColor(newValue).usingColorSpace(.sRGB) else { return }
                model.setColor(RGB(r: c.redComponent, g: c.greenComponent, b: c.blueComponent))
            })
    }

    var body: some View {
        VStack(spacing: 14) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 6) {
                ForEach(AnnotationTool.allCases) { toolButton($0) }
            }
            HStack {
                ColorPicker("Color", selection: color, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
                zoomControls
                Spacer()
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(model.undoStack.isEmpty)
                Button { model.deleteSelected() } label: { Image(systemName: "trash") }
                    .disabled(model.selectedID == nil)
            }
            Text(model.tool.hint)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            HStack {
                Button("Reset") { model.reset() }
                Spacer()
                Button("Save Annotated Copy", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.annotations.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 780, maxWidth: .infinity,
               minHeight: 560, idealHeight: 760, maxHeight: .infinity)
    }

    private var currentScale: CGFloat { zoom ?? fitScale }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button { setZoom(currentScale / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .keyboardShortcut("-", modifiers: .command)
            Text("\(Int((currentScale * 100).rounded()))%")
                .font(.system(size: 12).monospacedDigit())
                .frame(width: 44)
            Button { setZoom(currentScale * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .keyboardShortcut("=", modifiers: .command)
            Button("Fit") { zoom = nil }
                .keyboardShortcut("0", modifiers: .command)
            Button("100%") { zoom = 1 }
        }
    }

    private func setZoom(_ value: CGFloat) {
        zoom = min(max(value, fitScale * 0.5), 8)
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        let selected = model.tool == tool
        return Button { model.tool = tool } label: {
            Group {
                if let symbol = tool.symbol {
                    Image(systemName: symbol)
                } else {
                    Text("Aa").font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundColor(selected ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Self.accent : Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private var preview: some View {
        GeometryReader { geo in
            let fit = min(geo.size.width / model.imageSize.width, geo.size.height / model.imageSize.height)
            let scale = zoom ?? fit
            let shown = CGSize(width: model.imageSize.width * scale, height: model.imageSize.height * scale)
            ScrollView([.horizontal, .vertical]) {
                // gestures live inside this image-sized ZStack, so locations are already image-relative
                ZStack(alignment: .topLeading) {
                    AnnotatedImageView(image: image,
                                       annotations: model.annotations.filter { $0.id != model.editingTextID },
                                       base: model.base, scale: scale, selection: model.selectedBounds)
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: shown.width, height: shown.height)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !dragging {
                                    dragging = true
                                    model.begin(at: imagePoint(value.startLocation, scale), tolerance: 10 / scale)
                                }
                                model.drag(to: imagePoint(value.location, scale))
                            }
                            .onEnded { _ in
                                dragging = false
                                model.end()
                            })
                    if model.editingTextID == nil, let box = model.selectedBounds {
                        removeButton
                            .position(x: min(max(box.maxX * scale, 12), shown.width - 12),
                                      y: min(max(box.minY * scale, 12), shown.height - 12))
                    }
                    if let id = model.editingTextID, let annotation = model.annotations.first(where: { $0.id == id }) {
                        textField(for: annotation, scale: scale)
                    }
                }
                .frame(width: shown.width, height: shown.height)
                .frame(minWidth: geo.size.width, minHeight: geo.size.height)
            }
            .simultaneousGesture(MagnificationGesture()
                .onChanged { value in
                    let base = pinchBase ?? scale
                    pinchBase = base
                    setZoom(base * value)
                }
                .onEnded { _ in pinchBase = nil })
            .onAppear { fitScale = fit }
            .onChange(of: geo.size) { _ in fitScale = min(geo.size.width / model.imageSize.width, geo.size.height / model.imageSize.height) }
        }
    }

    private var removeButton: some View {
        Button { model.deleteSelected() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black.opacity(0.8)))
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .help("Remove")
    }

    private func textField(for annotation: Annotation, scale: CGFloat) -> some View {
        let size = Annotation.textSize(annotation.text, base: model.base)
        let fontSize = max(12, model.base * 8 * scale)
        let width = max(80, size.width * scale + 20)
        return TextField("Text", text: Binding(get: { annotation.text }, set: { model.setText($0, for: annotation.id) }))
            .textFieldStyle(.plain)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(Color(red: annotation.color.r, green: annotation.color.g, blue: annotation.color.b))
            .focused($textFocused)
            .onSubmit { model.finishEditing() }
            .onAppear { textFocused = true }
            .frame(width: width)
            .position(x: annotation.points[0].x * scale + width / 2,
                      y: annotation.points[0].y * scale + fontSize * 0.7)
    }

    private func imagePoint(_ point: CGPoint, _ scale: CGFloat) -> CGPoint {
        CGPoint(x: point.x / scale, y: point.y / scale)
    }
}

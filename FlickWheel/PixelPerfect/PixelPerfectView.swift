import AppKit
import SwiftUI

struct PixelPerfectView: View {
    @ObservedObject var model: PixelPerfectModel
    let onSave: () -> Void
    @State private var dragStart: CGPoint?
    @State private var drawing = false
    @State private var annotating = false
    @FocusState private var textFocused: Bool

    private static let accent = Color(red: 1, green: 0.4, blue: 0.2)

    private var annotate: AnnotateModel { model.annotate }

    private var color: Binding<Color> {
        Binding(
            get: { Color(red: annotate.color.r, green: annotate.color.g, blue: annotate.color.b) },
            set: { newValue in
                guard let c = NSColor(newValue).usingColorSpace(.sRGB) else { return }
                annotate.setColor(RGB(r: c.redComponent, g: c.greenComponent, b: c.blueComponent))
            })
    }

    var body: some View {
        VStack(spacing: 12) {
            legend
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.07)))
            controls
        }
        .padding(20)
        .frame(minWidth: 640, idealWidth: 960, maxWidth: .infinity,
               minHeight: 680, idealHeight: 880, maxHeight: .infinity)
        .background(annotating ? nil : nudgeKeys)
    }

    private var legend: some View {
        HStack {
            caption("Base", model.baseName, model.baseSize)
            Spacer()
            caption("Overlay", model.overlayName, CGSize(width: model.overlay.width, height: model.overlay.height))
        }
    }

    private func caption(_ role: String, _ name: String, _ size: CGSize) -> some View {
        Text("\(role): \(name) (\(Int(size.width)) × \(Int(size.height)))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var stage: some View {
        GeometryReader { geo in
            let base = model.baseSize
            let fit = min((geo.size.width - 24) / base.width, (geo.size.height - 24) / base.height)
            let scale = max(fit, 0.01) * model.zoom
            ScrollView([.horizontal, .vertical]) {
                canvas(scale: scale)
                    .padding(12)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height)
            }
        }
    }

    private func canvas(scale: Double) -> some View {
        let size = CGSize(width: model.baseSize.width * scale, height: model.baseSize.height * scale)
        return ZStack(alignment: .topLeading) {
            PixelPerfectCanvas(model: model, annotations: annotate.annotations.filter { $0.id != annotate.editingTextID },
                               scale: scale, selection: annotating ? annotate.selectedBounds : nil)
            // gestures live inside this canvas-sized ZStack, so locations are already canvas-relative
            Color.clear
                .contentShape(Rectangle())
                .frame(width: size.width, height: size.height)
                .gesture(alignGesture(scale: scale), including: annotating ? .none : .all)
                .gesture(drawGesture(scale: scale), including: annotating ? .all : .none)
            if annotating {
                if annotate.editingTextID == nil, let box = annotate.selectedBounds {
                    removeButton
                        .position(x: min(max(box.maxX * scale, 12), size.width - 12),
                                  y: min(max(box.minY * scale, 12), size.height - 12))
                }
                if let id = annotate.editingTextID, let annotation = annotate.annotations.first(where: { $0.id == id }) {
                    textField(for: annotation, scale: scale)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .overlay(Rectangle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
    }

    private func alignGesture(scale: Double) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? model.offset
                dragStart = start
                model.offset = CGPoint(x: (start.x + value.translation.width / scale).rounded(),
                                       y: (start.y + value.translation.height / scale).rounded())
            }
            .onEnded { _ in dragStart = nil }
    }

    private func drawGesture(scale: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !drawing {
                    drawing = true
                    annotate.begin(at: pixel(value.startLocation, scale), tolerance: 10 / scale)
                }
                annotate.drag(to: pixel(value.location, scale))
            }
            .onEnded { _ in
                drawing = false
                annotate.end()
            }
    }

    private func pixel(_ point: CGPoint, _ scale: Double) -> CGPoint {
        CGPoint(x: point.x / scale, y: point.y / scale)
    }

    private var removeButton: some View {
        Button { annotate.deleteSelected() } label: {
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

    private func textField(for annotation: Annotation, scale: Double) -> some View {
        let size = Annotation.textSize(annotation.text, base: annotate.base)
        let fontSize = max(12, annotate.base * 8 * scale)
        let width = max(80, size.width * scale + 20)
        return TextField("Text", text: Binding(get: { annotation.text }, set: { annotate.setText($0, for: annotation.id) }))
            .textFieldStyle(.plain)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(Color(red: annotation.color.r, green: annotation.color.g, blue: annotation.color.b))
            .focused($textFocused)
            .onSubmit { annotate.finishEditing() }
            .onAppear { textFocused = true }
            .frame(width: width)
            .position(x: annotation.points[0].x * scale + width / 2,
                      y: annotation.points[0].y * scale + fontSize * 0.7)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Mode", selection: $model.mode) {
                    ForEach(ComparisonMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)
                Spacer()
                Button {
                    model.swap()
                } label: {
                    Label("Swap", systemImage: "arrow.up.arrow.down")
                }
                .disabled(!model.canSwap)
                .help(model.canSwap ? "Swap base and overlay" : "Remove the marks to swap")
            }
            switch model.mode {
            case .overlay:
                slider("Opacity", value: $model.opacity, range: 0...1, text: "\(Int((model.opacity * 100).rounded()))%")
            case .swipe:
                slider("Divider", value: $model.split, range: 0...1, text: "\(Int((model.split * 100).rounded()))%")
            case .difference:
                HStack {
                    Text("Black pixels match. Anything lit differs.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            slider("Zoom", value: $model.zoom, range: 1...8, text: String(format: "%.1f×", model.zoom))
            Divider()
            HStack {
                Picker("Drag to", selection: $annotating) {
                    Text("Align").tag(false)
                    Text("Annotate").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: annotating) { _ in annotate.finishEditing() }
                Spacer()
                Button("Save Comparison") {
                    annotate.finishEditing()
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            if annotating { annotateControls } else { alignControls }
        }
    }

    private var alignControls: some View {
        HStack {
            Text("Drag the image or use arrow keys (⇧ for 10 px) to align the overlay.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Offset \(Int(model.offset.x)), \(Int(model.offset.y)) px")
                .font(.callout.monospacedDigit())
            Button("Reset") { model.offset = .zero }
                .disabled(model.isAligned)
        }
    }

    private var annotateControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(AnnotationTool.allCases.filter { $0 != .redact }) { toolButton($0) }
                ColorPicker("Color", selection: color, supportsOpacity: false)
                    .labelsHidden()
                Button { annotate.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(annotate.undoStack.isEmpty)
                Button { annotate.deleteSelected() } label: { Image(systemName: "trash") }
                    .disabled(annotate.selectedID == nil)
            }
            Text(annotate.tool.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        let selected = annotate.tool == tool
        return Button { annotate.tool = tool } label: {
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

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        HStack {
            Text(title).frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
            Text(text).monospacedDigit().frame(width: 56, alignment: .trailing)
        }
    }

    private var nudgeKeys: some View {
        Group {
            nudgeKey(.leftArrow, -1, 0)
            nudgeKey(.rightArrow, 1, 0)
            nudgeKey(.upArrow, 0, -1)
            nudgeKey(.downArrow, 0, 1)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    private func nudgeKey(_ key: KeyEquivalent, _ dx: Double, _ dy: Double) -> some View {
        Group {
            Button("") { model.nudge(dx, dy) }.keyboardShortcut(key, modifiers: [])
            Button("") { model.nudge(dx * 10, dy * 10) }.keyboardShortcut(key, modifiers: .shift)
        }
    }
}

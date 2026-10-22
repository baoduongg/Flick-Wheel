import Combine
import CoreGraphics
import Foundation

@MainActor
final class AnnotateModel: ObservableObject {
    let imageSize: CGSize
    @Published private(set) var annotations: [Annotation] = []
    @Published private(set) var selectedID: UUID?
    @Published private(set) var editingTextID: UUID?
    @Published private(set) var undoStack: [[Annotation]] = []
    @Published var tool: AnnotationTool
    @Published private(set) var color: RGB

    private var drawingID: UUID?
    private var movingID: UUID?
    private var lastPoint = CGPoint.zero
    private var moved = false

    init(imageSize: CGSize, tool: AnnotationTool = .arrow) {
        self.imageSize = imageSize
        self.tool = tool
        color = tool == .redact ? RGB(r: 0, g: 0, b: 0) : .red
    }

    var base: CGFloat {
        max(2, max(imageSize.width, imageSize.height) * 0.004)
    }

    var selectedBounds: CGRect? {
        annotations.first { $0.id == selectedID }?.bounds(base: base).insetBy(dx: -base * 2, dy: -base * 2)
    }

    func begin(at point: CGPoint, tolerance: CGFloat) {
        finishEditing()
        pushUndo()
        if let hit = annotations.last(where: { $0.distance(to: point, base: base) <= max(tolerance, base * 2) }) {
            selectedID = hit.id
            movingID = hit.id
            lastPoint = point
            moved = false
            return
        }
        switch tool {
        case .text:
            add(Annotation(tool: .text, color: color, points: [point]))
            editingTextID = selectedID
        case .badge:
            let next = (annotations.map(\.number).max() ?? 0) + 1
            add(Annotation(tool: .badge, color: color, points: [point], number: next))
        case .pen, .highlighter:
            add(Annotation(tool: tool, color: color, points: [point]))
            drawingID = selectedID
        case .arrow, .rectangle, .ellipse, .redact:
            add(Annotation(tool: tool, color: color, points: [point, point]))
            drawingID = selectedID
        }
    }

    func drag(to point: CGPoint) {
        if let id = drawingID, let i = index(of: id) {
            if annotations[i].tool == .pen || annotations[i].tool == .highlighter {
                annotations[i].points.append(point)
            } else {
                annotations[i].points[1] = point
            }
        } else if let id = movingID, let i = index(of: id) {
            let delta = CGSize(width: point.x - lastPoint.x, height: point.y - lastPoint.y)
            annotations[i].translate(by: delta)
            lastPoint = point
            moved = moved || delta != .zero
        }
    }

    func end() {
        if let id = drawingID, let i = index(of: id) {
            let size = annotations[i].bounds(base: base)
            if max(size.width, size.height) < base * 2 {
                annotations.remove(at: i)
                selectedID = nil
                popUndo()
            }
        }
        if movingID != nil, !moved { popUndo() }
        if movingID == nil { selectedID = editingTextID }
        drawingID = nil
        movingID = nil
    }

    func setText(_ text: String, for id: UUID) {
        if let i = index(of: id) { annotations[i].text = text }
    }

    func finishEditing() {
        guard let id = editingTextID else { return }
        editingTextID = nil
        selectedID = nil
        if let i = index(of: id), annotations[i].text.trimmingCharacters(in: .whitespaces).isEmpty {
            annotations.remove(at: i)
            popUndo()
        }
    }

    func setColor(_ newColor: RGB) {
        color = newColor
        if let id = selectedID, let i = index(of: id) { annotations[i].color = newColor }
    }

    func deleteSelected() {
        guard let id = selectedID, let i = index(of: id) else { return }
        pushUndo()
        annotations.remove(at: i)
        selectedID = nil
        editingTextID = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        annotations = previous
        selectedID = nil
        editingTextID = nil
    }

    func reset() {
        annotations = []
        undoStack = []
        selectedID = nil
        editingTextID = nil
    }

    private func add(_ annotation: Annotation) {
        annotations.append(annotation)
        selectedID = annotation.id
    }

    private func index(of id: UUID) -> Int? {
        annotations.firstIndex { $0.id == id }
    }

    private func pushUndo() {
        undoStack.append(annotations)
    }

    private func popUndo() {
        _ = undoStack.popLast()
    }
}

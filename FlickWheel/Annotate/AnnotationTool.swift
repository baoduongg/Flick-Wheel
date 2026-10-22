enum AnnotationTool: CaseIterable, Identifiable {
    case arrow, highlighter, text, rectangle, ellipse, pen, badge, redact

    var id: Self { self }

    var symbol: String? {
        switch self {
        case .arrow: return "arrow.up.left"
        case .highlighter: return "highlighter"
        case .text: return nil
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .pen: return "pencil"
        case .badge: return "1.circle"
        case .redact: return "eye.slash"
        }
    }

    var hint: String {
        switch self {
        case .arrow: return "Drag from the tail toward the arrowhead. Drag an annotation to move it."
        case .highlighter: return "Drag over the area to highlight. Drag an annotation to move it."
        case .text: return "Click to place text, type, then press Return. Drag text to move it."
        case .rectangle: return "Drag from corner to corner. Drag an outline to move it."
        case .ellipse: return "Drag across the area to circle. Drag an outline to move it."
        case .pen: return "Drag to draw freehand. Drag a stroke to move it."
        case .badge: return "Click to drop a numbered marker. Drag a marker to move it."
        case .redact: return "Drag over what to hide. The saved copy covers it with a solid block in the picked color."
        }
    }
}

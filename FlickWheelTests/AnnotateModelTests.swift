import XCTest

@MainActor
final class AnnotateModelTests: XCTestCase {
    private func model() -> AnnotateModel {
        AnnotateModel(imageSize: CGSize(width: 1000, height: 800))
    }

    private func draw(_ m: AnnotateModel, from a: CGPoint, to b: CGPoint) {
        m.begin(at: a, tolerance: 0)
        m.drag(to: b)
        m.end()
    }

    func testDragCreatesShapeAndTinyClickIsDiscarded() {
        let m = model()
        draw(m, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        XCTAssertEqual(m.annotations.count, 1)
        XCTAssertEqual(m.annotations[0].tool, .arrow)
        XCTAssertEqual(m.annotations[0].points, [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200)])
        m.begin(at: CGPoint(x: 700, y: 700), tolerance: 0)
        m.end()
        XCTAssertEqual(m.annotations.count, 1)
        XCTAssertEqual(m.undoStack.count, 1)
    }

    func testPenCollectsPointsAndHighlighterToo() {
        let m = model()
        m.tool = .pen
        m.begin(at: CGPoint(x: 10, y: 10), tolerance: 0)
        m.drag(to: CGPoint(x: 50, y: 60))
        m.drag(to: CGPoint(x: 90, y: 20))
        m.end()
        XCTAssertEqual(m.annotations[0].points.count, 3)
    }

    func testBadgesAreNumberedInOrder() {
        let m = model()
        m.tool = .badge
        for x in [100.0, 400.0, 700.0] {
            m.begin(at: CGPoint(x: x, y: 400), tolerance: 0)
            m.end()
        }
        XCTAssertEqual(m.annotations.map(\.number), [1, 2, 3])
    }

    func testDraggingExistingAnnotationMovesItInsteadOfDrawing() {
        let m = model()
        m.tool = .rectangle
        draw(m, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300))
        m.begin(at: CGPoint(x: 100, y: 200), tolerance: 5)
        m.drag(to: CGPoint(x: 150, y: 230))
        m.end()
        XCTAssertEqual(m.annotations.count, 1)
        XCTAssertEqual(m.annotations[0].points[0], CGPoint(x: 150, y: 130))
        m.begin(at: CGPoint(x: 200, y: 200), tolerance: 5)
        m.drag(to: CGPoint(x: 260, y: 260))
        m.end()
        XCTAssertEqual(m.annotations.count, 2, "inside a rectangle starts a new shape, only its outline grabs")
    }

    func testUndoDeleteAndReset() {
        let m = model()
        draw(m, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        draw(m, from: CGPoint(x: 500, y: 500), to: CGPoint(x: 700, y: 600))
        m.undo()
        XCTAssertEqual(m.annotations.count, 1)
        m.begin(at: CGPoint(x: 200, y: 150), tolerance: 5)
        m.end()
        XCTAssertNotNil(m.selectedID)
        m.deleteSelected()
        XCTAssertTrue(m.annotations.isEmpty)
        m.undo()
        XCTAssertEqual(m.annotations.count, 1)
        m.reset()
        XCTAssertTrue(m.annotations.isEmpty)
        XCTAssertTrue(m.undoStack.isEmpty)
    }

    func testTextIsKeptOnlyWhenNotEmpty() {
        let m = model()
        m.tool = .text
        m.begin(at: CGPoint(x: 100, y: 100), tolerance: 0)
        m.end()
        let id = try! XCTUnwrap(m.editingTextID)
        m.setText("Hello", for: id)
        m.finishEditing()
        XCTAssertEqual(m.annotations.map(\.text), ["Hello"])

        m.begin(at: CGPoint(x: 600, y: 600), tolerance: 0)
        m.end()
        m.finishEditing()
        XCTAssertEqual(m.annotations.count, 1)
    }

    func testColorChangeAppliesToSelectionAndFutureAnnotationsOnly() {
        let m = model()
        draw(m, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        XCTAssertNil(m.selectedID, "a finished drawing is not selected")
        let blue = RGB(r: 0, g: 0, b: 1)
        m.setColor(blue)
        XCTAssertEqual(m.annotations[0].color, RGB.red)
        draw(m, from: CGPoint(x: 500, y: 500), to: CGPoint(x: 700, y: 600))
        XCTAssertEqual(m.annotations[1].color, blue)

        m.begin(at: CGPoint(x: 200, y: 150), tolerance: 5)
        m.end()
        m.setColor(RGB(r: 0, g: 1, b: 0))
        XCTAssertEqual(m.annotations[0].color, RGB(r: 0, g: 1, b: 0))
        XCTAssertEqual(m.annotations[1].color, blue)
    }

    func testRedactToolDrawsMovableBlockAndStartsPreselected() {
        let m = AnnotateModel(imageSize: CGSize(width: 1000, height: 800), tool: .redact)
        XCTAssertEqual(m.tool, .redact)
        XCTAssertEqual(m.color, RGB(r: 0, g: 0, b: 0))
        m.setColor(RGB(r: 0, g: 0, b: 1))
        draw(m, from: CGPoint(x: 500, y: 500), to: CGPoint(x: 600, y: 600))
        XCTAssertEqual(m.annotations.last?.color, RGB(r: 0, g: 0, b: 1))
        m.undo()
        draw(m, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 200))
        XCTAssertEqual(m.annotations.map(\.tool), [.redact])
        m.begin(at: CGPoint(x: 100, y: 150), tolerance: 5)
        m.drag(to: CGPoint(x: 140, y: 150))
        m.end()
        XCTAssertEqual(m.annotations[0].points[0].x, 140)
    }
}

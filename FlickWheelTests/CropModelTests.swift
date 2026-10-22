import XCTest

@MainActor
final class CropModelTests: XCTestCase {
    private func model() -> CropModel {
        CropModel(imageSize: CGSize(width: 1066, height: 1600))
    }

    func testStartsWithFullImage() {
        XCTAssertEqual(model().rect, CGRect(x: 0, y: 0, width: 1066, height: 1600))
    }

    func testRatioFitsLargestCenteredRect() {
        let m = model()
        m.ratio = .square
        XCTAssertEqual(m.rect, CGRect(x: 0, y: 267, width: 1066, height: 1066))
        m.ratio = .wide
        XCTAssertEqual(m.rect.width / m.rect.height, 16.0 / 9.0, accuracy: 0.001)
        XCTAssertEqual(m.rect.width, 1066)
    }

    func testFreeResizeClampsToImageAndMinimumSize() {
        let m = model()
        m.resize(.bottomRight, to: CGPoint(x: 5000, y: 5000))
        XCTAssertEqual(m.rect, CGRect(x: 0, y: 0, width: 1066, height: 1600))
        m.resize(.topLeft, to: CGPoint(x: 300, y: 400))
        XCTAssertEqual(m.rect, CGRect(x: 300, y: 400, width: 766, height: 1200))
        m.resize(.right, to: CGPoint(x: 0, y: 0))
        XCTAssertEqual(m.rect.width, CropModel.minSize)
    }

    func testFixedRatioCornerKeepsRatioInsideImage() {
        let m = model()
        m.ratio = .square
        m.resize(.topLeft, to: CGPoint(x: -50, y: 700))
        XCTAssertEqual(m.rect.width, m.rect.height, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(m.rect.minX, 0)
        XCTAssertLessThanOrEqual(m.rect.maxY, 1600)
        m.resize(.right, to: CGPoint(x: 600, y: 0))
        XCTAssertEqual(m.rect.width, m.rect.height, accuracy: 0.001)
    }

    func testSetWidthAndHeightFollowRatio() {
        let m = model()
        m.setWidth(500)
        XCTAssertEqual(m.pixelRect, CGRect(x: 0, y: 0, width: 500, height: 1600))
        m.ratio = .square
        m.setHeight(400)
        XCTAssertEqual(m.rect.size, CGSize(width: 400, height: 400))
        m.setWidth(99999)
        XCTAssertEqual(m.rect.width, 1066)
        XCTAssertEqual(m.rect.height, 1066)
    }

    func testMoveStaysInsideImageAndResetRestores() {
        let m = model()
        m.setWidth(500)
        m.move(from: m.rect, by: CGSize(width: 9999, height: -9999))
        XCTAssertEqual(m.rect.origin, CGPoint(x: 566, y: 0))
        m.reset()
        XCTAssertEqual(m.rect, CGRect(x: 0, y: 0, width: 1066, height: 1600))
        XCTAssertEqual(m.ratio, .free)
    }
}

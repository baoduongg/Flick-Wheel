import XCTest

@MainActor
final class BackgroundModelTests: XCTestCase {
    private func model() -> BackgroundModel {
        BackgroundModel(imageSize: CGSize(width: 1000, height: 500))
    }

    func testDefaultsScaleWithTheImage() {
        let m = model()
        XCTAssertEqual(m.padding, 60)
        XCTAssertEqual(m.corners, 10)
        XCTAssertEqual(m.shadow, 12)
        XCTAssertEqual(m.canvasSize, CGSize(width: 1120, height: 620))
        XCTAssertTrue(m.isDefault)
    }

    func testRatioOnlyGrowsTheCanvas() {
        let m = model()
        m.padding = 0
        m.ratio = .square
        XCTAssertEqual(m.canvasSize, CGSize(width: 1000, height: 1000))
        m.ratio = .wide
        XCTAssertEqual(m.canvasSize.width / m.canvasSize.height, 16.0 / 9.0, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(m.canvasSize.width, 1000)
        XCTAssertGreaterThanOrEqual(m.canvasSize.height, 500)
        m.ratio = .portrait
        XCTAssertEqual(m.canvasSize, CGSize(width: 1000, height: 1250))
    }

    func testResetRestoresEverythingAndRangesFollowTheImage() {
        let m = model()
        m.backdrop = .solid(RGB.red)
        m.padding = 200
        m.corners = 40
        m.shadow = 5
        m.ratio = .square
        XCTAssertFalse(m.isDefault)
        m.reset()
        XCTAssertTrue(m.isDefault)
        XCTAssertEqual(m.paddingRange, 0...500)
        XCTAssertEqual(m.cornerRange, 0...250)
        XCTAssertEqual(m.shadowRange, 0...100)
    }
}

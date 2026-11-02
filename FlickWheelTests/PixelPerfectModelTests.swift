import CoreGraphics
import XCTest

@MainActor
final class PixelPerfectModelTests: XCTestCase {
    private func image(_ width: Int, _ height: Int) -> CGImage {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            .makeImage()!
    }

    func testOverlayScalesToBaseWidth() {
        let m = PixelPerfectModel(base: image(390, 844), overlay: image(1170, 2532), baseName: "design", overlayName: "shot")
        XCTAssertEqual(m.overlaySize, CGSize(width: 390, height: 844))
    }

    func testSwapExchangesRolesAndResetsOffset() {
        let m = PixelPerfectModel(base: image(100, 200), overlay: image(300, 600), baseName: "a", overlayName: "b")
        m.nudge(3, -2)
        XCTAssertFalse(m.isAligned)
        m.swap()
        XCTAssertEqual(m.baseName, "b")
        XCTAssertEqual(m.baseSize, CGSize(width: 300, height: 600))
        XCTAssertTrue(m.isAligned)
    }

    func testMarksAreInBasePixelsAndBlockSwap() {
        let m = PixelPerfectModel(base: image(100, 200), overlay: image(300, 600), baseName: "a", overlayName: "b")
        XCTAssertEqual(m.annotate.imageSize, CGSize(width: 100, height: 200))
        m.annotate.begin(at: CGPoint(x: 10, y: 10), tolerance: 1)
        m.annotate.drag(to: CGPoint(x: 60, y: 80))
        m.annotate.end()
        XCTAssertEqual(m.annotate.annotations.count, 1)
        XCTAssertFalse(m.canSwap)
        m.swap()
        XCTAssertEqual(m.baseName, "a")
    }

    func testSwapStartsAFreshAnnotationSpaceForTheNewBase() {
        let m = PixelPerfectModel(base: image(100, 200), overlay: image(300, 600), baseName: "a", overlayName: "b")
        m.swap()
        XCTAssertEqual(m.annotate.imageSize, CGSize(width: 300, height: 600))
    }
}

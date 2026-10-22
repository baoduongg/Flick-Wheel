import ImageIO
import UniformTypeIdentifiers
import XCTest

final class ImageCropperTests: XCTestCase {
    private func makePNG(in dir: URL, name: String, width: Int, height: Int) throws -> URL {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let url = dir.appendingPathComponent(name)
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    func testCropWritesSizedFileBesideSourceAndNeverOverwrites() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let source = try makePNG(in: dir, name: "my pic.png", width: 100, height: 60)
        let image = try XCTUnwrap(ImageCropper.load(source))
        XCTAssertEqual(image.width, 100)

        let first = try ImageCropper.crop(image, to: CGRect(x: 10, y: 10, width: 40, height: 30), source: source)
        let second = try ImageCropper.crop(image, to: CGRect(x: 0, y: 0, width: 20, height: 20), source: source)
        XCTAssertEqual(first.lastPathComponent, "my pic-crop.png")
        XCTAssertEqual(second.lastPathComponent, "my pic-crop 2.png")
        let out = try XCTUnwrap(ImageCropper.load(first))
        XCTAssertEqual(out.width, 40)
        XCTAssertEqual(out.height, 30)
    }
}

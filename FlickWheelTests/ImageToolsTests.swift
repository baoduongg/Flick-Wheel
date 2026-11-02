import CoreGraphics
import CoreImage
import CoreText
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class ImageToolsTests: XCTestCase {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func bitmap(_ width: Int, _ height: Int, alpha: Bool = false, draw: ((CGContext) -> Void)? = nil) -> CGImage {
        let info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha ? 0 : 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw?(ctx)
        return ctx.makeImage()!
    }

    private func write(_ image: CGImage, to url: URL, type: UTType, properties: [CFString: Any] = [:]) {
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }

    private func properties(_ url: URL) -> [CFString: Any] {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
    }

    private func taggedJPEG(in dir: URL, width: Int = 200, height: Int = 100) -> URL {
        let url = dir.appendingPathComponent("photo.jpg")
        write(bitmap(width, height), to: url, type: .jpeg, properties: [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 10.5, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "secret"],
        ])
        return url
    }

    func testStripRemovesGPSAndExifAndBakesOrientation() throws {
        let dir = try tempDir()
        let input = taggedJPEG(in: dir)
        XCTAssertNotNil(properties(input)[kCGImagePropertyGPSDictionary], "the fixture must carry GPS")

        let output = try ImageTools.stripMetadata(input)
        XCTAssertEqual(output.lastPathComponent, "photo-clean.jpg")
        let props = properties(output)
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
        XCTAssertNil((props[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifUserComment])
        // orientation 6 turns 200x100 into 100x200 pixels
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 100)
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 200)
        XCTAssertEqual(try ImageTools.stripMetadata(input).lastPathComponent, "photo-clean 2.jpg")
    }

    func testSendShrinksToTheLongestSideAndStaysOpaqueJPEG() throws {
        let dir = try tempDir()
        let big = dir.appendingPathComponent("shot.png")
        write(bitmap(3200, 2000, alpha: true) { $0.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)); $0.fill(CGRect(x: 0, y: 0, width: 3200, height: 2000)) },
              to: big, type: .png)
        let output = try ImageTools.prepareToSend(big)
        XCTAssertEqual(output.pathExtension, "jpg", "an alpha channel that is fully opaque becomes a JPEG")
        let props = properties(output)
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 1600)
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 1000)

        let small = try ImageTools.prepareToSend(taggedJPEG(in: dir))
        XCTAssertEqual(properties(small)[kCGImagePropertyPixelHeight] as? Int, 200, "never upscaled")
        XCTAssertNil(properties(small)[kCGImagePropertyGPSDictionary])
    }

    func testSendKeepsTransparencyAsPNG() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("logo.png")
        write(bitmap(50, 50, alpha: true), to: url, type: .png)
        XCTAssertFalse(ImageTools.isOpaque(bitmap(50, 50, alpha: true)))
        XCTAssertEqual(try ImageTools.prepareToSend(url).pathExtension, "png")
    }

    func testUnreadableFilesFailWithAMessage() throws {
        let dir = try tempDir()
        let text = dir.appendingPathComponent("notes.png")
        try Data("not an image".utf8).write(to: text)
        XCTAssertThrowsError(try ImageTools.stripMetadata(text)) { XCTAssertTrue("\($0.localizedDescription)".contains("notes.png")) }
    }

    func testOCRReadsRenderedText() throws {
        let dir = try tempDir()
        let image = bitmap(900, 220) { ctx in
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Hello FlickWheel 2026", attributes: [
                .font: CTFontCreateWithName("Helvetica-Bold" as CFString, 72, nil),
                .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            ]))
            ctx.textPosition = CGPoint(x: 30, y: 80)
            CTLineDraw(line, ctx)
        }
        let url = dir.appendingPathComponent("text.png")
        write(image, to: url, type: .png)
        let text = try TextRecognizer.recognize(url)
        XCTAssertTrue(text.contains("Hello"), text)
        XCTAssertTrue(text.contains("2026"), text)

        let blank = dir.appendingPathComponent("blank.png")
        write(bitmap(300, 300), to: blank, type: .png)
        XCTAssertThrowsError(try TextRecognizer.recognize(blank))
    }

    func testDiffMarksChangedPixelsAndReportsThePercentage() throws {
        let dir = try tempDir()
        let a = dir.appendingPathComponent("before.png"), b = dir.appendingPathComponent("after.png")
        write(bitmap(100, 100), to: a, type: .png)
        write(bitmap(100, 100) { $0.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)); $0.fill(CGRect(x: 0, y: 0, width: 20, height: 25)) },
              to: b, type: .png)
        let result = try ImageDiff.compare(a, b)
        XCTAssertEqual(result.changedPixels, 500)
        XCTAssertEqual(result.percent, 5, accuracy: 0.001)
        XCTAssertNil(result.sizeMismatch)
        let output = try XCTUnwrap(result.output)
        XCTAssertEqual(output.lastPathComponent, "before-diff.png")
        XCTAssertEqual(properties(output)[kCGImagePropertyPixelWidth] as? Int, 100)

        let same = try ImageDiff.compare(a, a)
        XCTAssertEqual(same.changedPixels, 0)
        XCTAssertNil(same.output, "identical images leave no file behind")
        XCTAssertEqual(try BuiltinTool.diff.run(on: [a, a]).message, "No pixels differ")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("before-diff 2.png").path))
    }

    func testDiffReportsSizeMismatchAndNeedsTwoImages() throws {
        let dir = try tempDir()
        let a = dir.appendingPathComponent("a.png"), b = dir.appendingPathComponent("b.png")
        write(bitmap(100, 100), to: a, type: .png)
        write(bitmap(50, 50), to: b, type: .png)
        let result = try ImageDiff.compare(a, b)
        XCTAssertEqual(result.sizeMismatch?.0, CGSize(width: 100, height: 100))
        XCTAssertEqual(result.sizeMismatch?.1, CGSize(width: 50, height: 50))
        XCTAssertEqual(result.changedPixels, 0, "a plain image scaled up is still the same colour")
        XCTAssertThrowsError(try BuiltinTool.diff.run(on: [a]))
        XCTAssertTrue(try BuiltinTool.diff.run(on: [a, b]).message.contains("Sizes differ: 100x100 vs 50x50"))
    }

    func testQRReaderDecodesAGeneratedCode() throws {
        let dir = try tempDir()
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data("https://example.com/flick?x=1".utf8), forKey: "inputMessage")
        let scaled = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let cg = CIContext().createCGImage(scaled, from: scaled.extent)!
        let url = dir.appendingPathComponent("qr.png")
        write(cg, to: url, type: .png)
        XCTAssertEqual(try QRReader.read(url), ["https://example.com/flick?x=1"])
        XCTAssertTrue(try BuiltinTool.qr.run(on: [url]).clipboard == "https://example.com/flick?x=1")
        let blank = dir.appendingPathComponent("blank.png")
        write(bitmap(200, 200), to: blank, type: .png)
        XCTAssertThrowsError(try QRReader.read(blank))
    }
}

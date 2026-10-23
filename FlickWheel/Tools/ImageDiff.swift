import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

// QC helpers that need pixels: compare two screenshots, read a QR code
enum ImageDiff {
    struct Result {
        let output: URL
        let changedPixels: Int
        let totalPixels: Int
        let sizeMismatch: (CGSize, CGSize)?

        var percent: Double { totalPixels == 0 ? 0 : Double(changedPixels) * 100 / Double(totalPixels) }
    }

    // a pixel counts as changed when any colour channel differs by more than this (out of 255)
    static let tolerance = 16

    // writes "<first>-diff.png": the first image faded, every changed pixel red. The second image is scaled to the
    // first one's size when they differ, and the mismatch is reported because it is a finding on its own.
    static func compare(_ a: URL, _ b: URL) throws -> Result {
        let first = try load(a), second = try load(b)
        let w = first.width, h = first.height
        var left = try pixels(first, width: w, height: h)
        let right = try pixels(second, width: w, height: h)
        var changed = 0
        for i in stride(from: 0, to: left.count, by: 4) {
            let delta = max(abs(Int(left[i]) - Int(right[i])), abs(Int(left[i + 1]) - Int(right[i + 1])), abs(Int(left[i + 2]) - Int(right[i + 2])))
            if delta > tolerance {
                changed += 1
                left[i] = 255; left[i + 1] = 0; left[i + 2] = 0; left[i + 3] = 255
            } else {
                // fade the unchanged parts so the red stands out
                for c in 0..<3 { left[i + c] = UInt8(128 + Int(left[i + c]) / 2) }
                left[i + 3] = 255
            }
        }
        let output = ImageTools.uniqueURL(beside: a, suffix: "-diff", ext: "png")
        guard let image = left.withUnsafeMutableBytes({ buffer -> CGImage? in
            CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }), let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ToolFailure(message: "Cannot write \(output.lastPathComponent)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ToolFailure(message: "Cannot write \(output.lastPathComponent)") }
        let mismatch = first.width == second.width && first.height == second.height
            ? nil : (CGSize(width: first.width, height: first.height), CGSize(width: second.width, height: second.height))
        return Result(output: output, changedPixels: changed, totalPixels: w * h, sizeMismatch: mismatch)
    }

    private static func load(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 8192,
              ] as CFDictionary)
        else { throw ToolFailure(message: "Cannot read \(url.lastPathComponent) as an image") }
        return image
    }

    // RGBA, premultiplied, drawn into a w x h canvas (scaling when the size differs)
    private static func pixels(_ image: CGImage, width w: Int, height h: Int) throws -> [UInt8] {
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ok = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { throw ToolFailure(message: "Not enough memory for \(w)x\(h) pixels") }
        return data
    }
}

enum QRReader {
    static func read(_ url: URL) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        do {
            try VNImageRequestHandler(url: url).perform([request])
        } catch {
            throw ToolFailure(message: "Cannot read the image: \(error.localizedDescription)")
        }
        let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
        guard !payloads.isEmpty else { throw ToolFailure(message: "No QR code or barcode found in \(url.lastPathComponent)") }
        return payloads
    }
}

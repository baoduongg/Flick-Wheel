import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

// small image jobs that run inside the app (no ffmpeg needed): OCR, shrink for sending, strip metadata
enum BuiltinTool: String, CaseIterable {
    case ocr, send, strip, qr, diff

    var title: String {
        switch self {
        case .ocr: return "Text"
        case .send: return "Send-ready"
        case .strip: return "Clean"
        case .qr: return "QR"
        case .diff: return "Image diff"
        }
    }

    struct Outcome {
        var output: URL?
        var clipboard: String?
        var message: String
    }

    func run(on files: [URL]) throws -> Outcome {
        guard let file = files.first else { throw ToolFailure(message: "No file") }
        switch self {
        case .ocr:
            let text = try TextRecognizer.recognize(file)
            let preview = text.replacingOccurrences(of: "\n", with: " ").prefix(80)
            return Outcome(clipboard: text, message: "Copied \(text.count) characters: \(preview)")
        case .send:
            let out = try ImageTools.prepareToSend(file)
            return Outcome(output: out, message: "\(out.lastPathComponent) ready")
        case .strip:
            let out = try ImageTools.stripMetadata(file)
            return Outcome(output: out, message: "\(out.lastPathComponent) ready, no EXIF or GPS")
        case .qr:
            let codes = try QRReader.read(file)
            let text = codes.joined(separator: "\n")
            return Outcome(clipboard: text, message: "Copied \(codes.count == 1 ? "the code" : "\(codes.count) codes"): \(text.replacingOccurrences(of: "\n", with: " ").prefix(80))")
        case .diff:
            guard files.count == 2 else { throw ToolFailure(message: "Drop exactly two images to compare") }
            let result = try ImageDiff.compare(files[0], files[1])
            var message = result.output == nil ? "No pixels differ"
                : String(format: "%.2f%% of pixels differ (%d of %d)", result.percent, result.changedPixels, result.totalPixels)
            if let (a, b) = result.sizeMismatch {
                message += ". Sizes differ: \(Int(a.width))x\(Int(a.height)) vs \(Int(b.width))x\(Int(b.height))"
            }
            return Outcome(output: result.output, message: message)
        }
    }
}

struct ToolFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum TextRecognizer {
    static func recognize(_ url: URL) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        do {
            try VNImageRequestHandler(url: url).perform([request])
        } catch {
            throw ToolFailure(message: "Cannot read the image: \(error.localizedDescription)")
        }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        guard !lines.isEmpty else { throw ToolFailure(message: "No text found in \(url.lastPathComponent)") }
        return lines.joined(separator: "\n")
    }
}

enum ImageTools {
    // longest side, JPEG quality; a screenshot that is really opaque still becomes a JPEG
    static func prepareToSend(_ url: URL, maxSide: Int = 1600, quality: Double = 0.75) throws -> URL {
        try export(url, maxSide: maxSide, quality: quality, suffix: "-send", keepFormat: false)
    }

    // re-encodes the pixels only, so EXIF, GPS, TIFF and IPTC never reach the copy; orientation is baked in
    static func stripMetadata(_ url: URL) throws -> URL {
        try export(url, maxSide: nil, quality: 0.95, suffix: "-clean", keepFormat: true)
    }

    private static func export(_ url: URL, maxSide: Int?, quality: Double, suffix: String, keepFormat: Bool) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw ToolFailure(message: "Cannot read \(url.lastPathComponent) as an image") }
        let longest = max(width, height)
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxSide ?? longest, longest),
        ] as CFDictionary) else { throw ToolFailure(message: "Cannot decode \(url.lastPathComponent)") }

        let sourceType = CGImageSourceGetType(source).flatMap { UTType($0 as String) }
        let writable = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        let type: UTType
        if keepFormat, let sourceType, writable.contains(sourceType.identifier) {
            type = sourceType
        } else {
            type = isOpaque(image) ? .jpeg : .png
        }
        // keep the original spelling (JPG, jpeg) when the format did not change
        let original = url.pathExtension
        let ext = !original.isEmpty && UTType(filenameExtension: original.lowercased()) == type
            ? original : (type == .jpeg ? "jpg" : (type.preferredFilenameExtension ?? "jpg"))
        let output = uniqueURL(beside: url, suffix: suffix, ext: ext)
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw ToolFailure(message: "Cannot write \(output.lastPathComponent)")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: output)
            throw ToolFailure(message: "Cannot write \(output.lastPathComponent)")
        }
        return output
    }

    // true when no pixel is see-through (screenshots carry an alpha channel they never use)
    static func isOpaque(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return true
        default: break
        }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return false }
        return stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 }
    }

    static func uniqueURL(beside source: URL, suffix: String, ext: String) -> URL {
        let directory = source.deletingLastPathComponent()
        let name = source.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(name)\(suffix)").appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name)\(suffix) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }
}

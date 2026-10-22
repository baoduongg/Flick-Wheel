import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageCropper {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
        ] as CFDictionary)
    }

    static func crop(_ image: CGImage, to rect: CGRect, source: URL) throws -> URL {
        guard let cropped = image.cropping(to: rect) else { throw Failure(message: "Invalid crop area") }
        return try write(cropped, beside: source, suffix: "-crop")
    }

    static func write(_ image: CGImage, beside source: URL, suffix: String) throws -> URL {
        guard let type = UTType(filenameExtension: source.pathExtension.lowercased()) else {
            throw Failure(message: "Unsupported format .\(source.pathExtension)")
        }
        let output = uniqueURL(for: source, suffix: suffix)
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw Failure(message: "Cannot write \(output.lastPathComponent)")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw Failure(message: "Cannot write \(output.lastPathComponent)")
        }
        return output
    }

    private static func uniqueURL(for source: URL, suffix: String) -> URL {
        let directory = source.deletingLastPathComponent()
        let name = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = directory.appendingPathComponent("\(name)\(suffix)").appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name)\(suffix) \(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }
}

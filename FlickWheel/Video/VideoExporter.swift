import CoreGraphics
import Foundation

enum VideoJob: Equatable {
    case trim(start: Double, end: Double)
    case clip(start: Double, end: Double, index: Int)
    case frame(at: Double)
    case crop(CGRect)
    case speed(Double)
    case redact(boxes: [RedactBox], style: RedactStyle, color: VideoColor)

    var title: String {
        switch self {
        case .trim: return "Trim"
        case .clip: return "Split"
        case .frame: return "Frame"
        case .crop: return "Crop"
        case .speed: return "Speed"
        case .redact: return "Redact"
        }
    }

    var suffix: String {
        switch self {
        case .trim: return "-trim"
        case .clip(_, _, let index): return "-part\(index)"
        case .frame(let t): return "-frame-\(String(format: "%.2f", t))s"
        case .crop: return "-crop"
        case .speed(let s): return "-\(String(format: "%g", s))x"
        case .redact: return "-redacted"
        }
    }

    var fileExtension: String {
        if case .frame = self { return "png" }
        return "mp4"
    }
}

enum VideoExporter {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let base = ["-hide_banner", "-loglevel", "error", "-y"]
    private static let encode = ["-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
                                 "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart"]
    // libx264 refuses odd dimensions
    private static let even = "scale='trunc(iw/2)*2':'trunc(ih/2)*2'"

    static func arguments(_ job: VideoJob, input: URL, output: URL) -> [String] {
        switch job {
        case .trim(let start, let end), .clip(let start, let end, _):
            return base + ["-i", input.path, "-ss", seconds(start), "-t", seconds(end - start), "-vf", even] + encode + [output.path]
        case .frame(let time):
            return base + ["-ss", seconds(time), "-i", input.path, "-frames:v", "1", output.path]
        case .crop(let rect):
            let x = Int(rect.minX) / 2 * 2, y = Int(rect.minY) / 2 * 2
            let w = max(Int(rect.width) / 2 * 2, 2), h = max(Int(rect.height) / 2 * 2, 2)
            return base + ["-i", input.path, "-vf", "crop=\(w):\(h):\(x):\(y)"] + encode + [output.path]
        case .speed(let factor):
            let f = String(format: "%g", factor)
            return base + ["-i", input.path, "-filter:v", "setpts=PTS/\(f),\(even)", "-filter:a", "atempo=\(f)"] + encode + [output.path]
        case .redact(let boxes, let style, let color):
            let items = boxes.map { b in
                (x: max(Int(b.rect.minX), 0), y: max(Int(b.rect.minY), 0), w: max(Int(b.rect.width), 2), h: max(Int(b.rect.height), 2),
                 s: seconds(b.start), e: seconds(b.end))
            }
            switch style {
            case .solid:
                let chain = items.map {
                    "drawbox=x=\($0.x):y=\($0.y):w=\($0.w):h=\($0.h):color=\(color.ffmpegHex):t=fill:enable='between(t,\($0.s),\($0.e))'"
                } + [even]
                return base + ["-i", input.path, "-vf", chain.joined(separator: ",")] + encode + [output.path]
            case .blur:
                var graph: [String] = []
                var current = "0:v"
                for (i, b) in items.enumerated() {
                    let radius = max(1, min(b.w, b.h) / 5)
                    graph.append("[\(current)]split=2[a\(i)][t\(i)]")
                    graph.append("[t\(i)]crop=\(b.w):\(b.h):\(b.x):\(b.y),boxblur=\(radius):3[c\(i)]")
                    graph.append("[a\(i)][c\(i)]overlay=\(b.x):\(b.y):enable='between(t,\(b.s),\(b.e))'[v\(i)]")
                    current = "v\(i)"
                }
                graph.append("[\(current)]\(even)[out]")
                return base + ["-i", input.path, "-filter_complex", graph.joined(separator: ";"), "-map", "[out]", "-map", "0:a?"]
                    + encode + [output.path]
            }
        }
    }

    static func export(_ job: VideoJob, source: URL) async throws -> URL {
        guard let ffmpeg = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        else { throw Failure(message: "ffmpeg not found (brew install ffmpeg)") }
        let output = uniqueURL(beside: source, suffix: job.suffix, ext: job.fileExtension)
        let args = arguments(job, input: source, output: output)
        let error: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ffmpeg)
                process.arguments = args
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = FileHandle.nullDevice
                let pipe = Pipe()
                process.standardError = pipe
                do { try process.run() } catch {
                    continuation.resume(returning: error.localizedDescription)
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: process.terminationStatus == 0 ? nil : String(text.prefix(200)))
            }
        }
        if let error {
            try? FileManager.default.removeItem(at: output)
            throw Failure(message: error.isEmpty ? "ffmpeg failed" : error)
        }
        guard (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 > 0 else {
            try? FileManager.default.removeItem(at: output)
            throw Failure(message: "No output (is the time inside the video?)")
        }
        return output
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

    private static func seconds(_ t: Double) -> String { String(format: "%.3f", max(t, 0)) }
}

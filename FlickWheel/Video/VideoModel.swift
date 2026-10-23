import Combine
import CoreGraphics
import Foundation

enum VideoMode: String, CaseIterable {
    case trim, frame, crop, speed, split, redact

    var title: String {
        switch self {
        case .trim: return "Trim Video"
        case .frame: return "Video Snapshots"
        case .crop: return "Crop Video"
        case .speed: return "Change Speed"
        case .split: return "Split Video"
        case .redact: return "Redact Video"
        }
    }
}

enum VideoTime {
    // m:ss.cc, or h:mm:ss.cc from an hour up
    static func format(_ t: Double) -> String {
        let c = Int((max(t, 0) * 100).rounded())
        let h = c / 360_000, m = c / 6000 % 60, s = c / 100 % 60, cs = c % 100
        return h > 0 ? String(format: "%d:%02d:%02d.%02d", h, m, s, cs) : String(format: "%d:%02d.%02d", m, s, cs)
    }
}

enum RedactStyle: String, CaseIterable {
    case solid = "Solid"
    case blur = "Blur"
}

struct VideoColor: Equatable {
    var r: Double, g: Double, b: Double
    static let black = VideoColor(r: 0, g: 0, b: 0)

    var ffmpegHex: String {
        String(format: "0x%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

struct VideoClip: Equatable {
    let start: Double
    let end: Double
}

// rect lives in video pixels with a top-left origin; start/end are seconds
struct RedactBox: Equatable, Identifiable {
    static let minSize: CGFloat = 16

    let id = UUID()
    var rect: CGRect
    var start: Double
    var end: Double

    func isActive(at t: Double) -> Bool { t >= start && t <= end }

    mutating func move(by delta: CGSize, from origin: CGRect, in size: CGSize) {
        rect = CGRect(x: min(max(origin.minX + delta.width, 0), size.width - origin.width),
                      y: min(max(origin.minY + delta.height, 0), size.height - origin.height),
                      width: origin.width, height: origin.height)
    }

    mutating func resize(_ handle: CropHandle, to point: CGPoint, in size: CGSize) {
        let p = CGPoint(x: min(max(point.x, 0), size.width), y: min(max(point.y, 0), size.height))
        let m = Self.minSize
        var minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        switch handle {
        case .left, .topLeft, .bottomLeft: minX = min(p.x, maxX - m)
        case .right, .topRight, .bottomRight: maxX = max(p.x, minX + m)
        case .top, .bottom: break
        }
        switch handle {
        case .top, .topLeft, .topRight: minY = min(p.y, maxY - m)
        case .bottom, .bottomLeft, .bottomRight: maxY = max(p.y, minY + m)
        case .left, .right: break
        }
        rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// times are seconds
@MainActor
final class VideoModel: ObservableObject {
    static let minTrim = 0.1
    // atempo (the audio side of the export) only accepts 0.5 to 100
    static let speeds: [Double] = [0.5, 0.75, 1.25, 1.5, 2, 3, 4, 8]

    let duration: Double
    let size: CGSize
    let frameRate: Double
    @Published var current = 0.0
    @Published private(set) var start = 0.0
    @Published private(set) var end: Double
    @Published var speed = 2.0
    @Published private(set) var splits: [Double] = []
    @Published private(set) var snapshots: [Double] = []
    @Published private(set) var boxes: [RedactBox] = []
    @Published var selectedBox: UUID?
    @Published var redactStyle = RedactStyle.solid
    @Published var redactColor = VideoColor.black

    init(duration: Double, size: CGSize, frameRate: Double = 30) {
        self.duration = duration
        self.size = size
        self.frameRate = frameRate > 0 ? frameRate : 30
        end = duration
    }

    func clampCurrent(_ value: Double) -> Double {
        min(max(value, 0), duration)
    }

    // trim

    func setStart(_ value: Double) {
        start = min(max(value, 0), max(end - Self.minTrim, 0))
    }

    func setEnd(_ value: Double) {
        end = min(max(value, start + Self.minTrim), duration)
    }

    var trimmedLength: Double { end - start }
    var spedUpLength: Double { duration / speed }

    // split

    @discardableResult
    func addSplit(_ t: Double) -> Bool {
        guard t > Self.minTrim, t < duration - Self.minTrim,
              !splits.contains(where: { abs($0 - t) < Self.minTrim }) else { return false }
        splits = (splits + [t]).sorted()
        return true
    }

    func removeSplit(at index: Int) {
        guard splits.indices.contains(index) else { return }
        splits.remove(at: index)
    }

    func setEqualSplits(_ count: Int) {
        let n = max(count, 2)
        splits = (1..<n).map { duration * Double($0) / Double(n) }
    }

    var clips: [VideoClip] {
        let edges = [0] + splits + [duration]
        return zip(edges, edges.dropFirst()).map { VideoClip(start: $0, end: $1) }
    }

    // snapshots

    func addSnapshot(_ t: Double) {
        let t = clampCurrent(t)
        guard !snapshots.contains(where: { abs($0 - t) < 0.5 / frameRate }) else { return }
        snapshots = (snapshots + [t]).sorted()
    }

    func removeSnapshot(at index: Int) {
        guard snapshots.indices.contains(index) else { return }
        snapshots.remove(at: index)
    }

    // redact

    @discardableResult
    func addBox(start a: Double, end b: Double) -> UUID {
        let e = min(max(max(a, b), min(a, b) + Self.minTrim), duration)
        let s = min(max(min(a, b), 0), max(e - Self.minTrim, 0))
        let w = size.width * 0.3, h = size.height * 0.2
        let shift = CGFloat(boxes.count % 5) * 24
        let rect = CGRect(x: min((size.width - w) / 2 + shift, size.width - w),
                          y: min((size.height - h) / 2 + shift, size.height - h), width: w, height: h)
        let box = RedactBox(rect: rect, start: s, end: e)
        boxes.append(box)
        selectedBox = box.id
        return box.id
    }

    func updateBox(_ id: UUID, _ change: (inout RedactBox) -> Void) {
        guard let i = boxes.firstIndex(where: { $0.id == id }) else { return }
        change(&boxes[i])
    }

    func setBoxStart(_ id: UUID, _ t: Double) {
        updateBox(id) { $0.start = min(max(t, 0), $0.end - Self.minTrim) }
    }

    func setBoxEnd(_ id: UUID, _ t: Double) {
        updateBox(id) { $0.end = min(max(t, $0.start + Self.minTrim), duration) }
    }

    // moves the whole time range, keeping its length
    func shiftBox(_ id: UUID, start t: Double) {
        updateBox(id) {
            let length = $0.end - $0.start
            $0.start = min(max(t, 0), max(duration - length, 0))
            $0.end = $0.start + length
        }
    }

    func removeBox(_ id: UUID) {
        boxes.removeAll { $0.id == id }
        if selectedBox == id { selectedBox = nil }
    }
}

import CoreGraphics
import XCTest

@MainActor
final class VideoModelTests: XCTestCase {
    private let src = URL(fileURLWithPath: "/tmp/a b.mov")
    private let out = URL(fileURLWithPath: "/tmp/out.mp4")

    func testTimeFormat() {
        XCTAssertEqual(VideoTime.format(0), "0:00.00")
        XCTAssertEqual(VideoTime.format(75.46), "1:15.46")
        XCTAssertEqual(VideoTime.format(1.6), "0:01.60")
        XCTAssertEqual(VideoTime.format(3725.0), "1:02:05.00")
        XCTAssertEqual(VideoTime.format(-3), "0:00.00")
    }

    func testTrimMarksNeverCross() {
        let m = VideoModel(duration: 10, size: CGSize(width: 100, height: 100))
        m.setEnd(4)
        m.setStart(9)
        XCTAssertEqual(m.start, 3.9, accuracy: 0.001)
        m.setEnd(1)
        XCTAssertEqual(m.end, 4.0, accuracy: 0.001)
        m.setEnd(99)
        XCTAssertEqual(m.end, 10)
        m.setStart(-5)
        XCTAssertEqual(m.start, 0)
        XCTAssertEqual(m.trimmedLength, 10)
    }

    func testArguments() {
        let trim = VideoExporter.arguments(.trim(start: 1.5, end: 4), input: src, output: out)
        XCTAssertEqual(Array(trim[4...9]), ["-i", "/tmp/a b.mov", "-ss", "1.500", "-t", "2.500"])
        XCTAssertEqual(trim.last, "/tmp/out.mp4")

        let frame = VideoExporter.arguments(.frame(at: 2), input: src, output: out)
        XCTAssertEqual(Array(frame[4...]), ["-ss", "2.000", "-i", "/tmp/a b.mov", "-frames:v", "1", "/tmp/out.mp4"])

        let crop = VideoExporter.arguments(.crop(CGRect(x: 11, y: 5, width: 301, height: 99)), input: src, output: out)
        XCTAssertTrue(crop.contains("crop=300:98:10:4"))

        let speed = VideoExporter.arguments(.speed(0.75), input: src, output: out)
        XCTAssertTrue(speed.contains("atempo=0.75"))
        XCTAssertTrue(speed.contains { $0.hasPrefix("setpts=PTS/0.75,") })
    }

    func testSplitsAndClips() {
        let m = VideoModel(duration: 9, size: CGSize(width: 100, height: 100))
        XCTAssertFalse(m.addSplit(0.05))
        XCTAssertTrue(m.addSplit(6))
        XCTAssertTrue(m.addSplit(3))
        XCTAssertFalse(m.addSplit(3.05))
        XCTAssertEqual(m.splits, [3, 6])
        XCTAssertEqual(m.clips, [VideoClip(start: 0, end: 3), VideoClip(start: 3, end: 6), VideoClip(start: 6, end: 9)])
        m.setEqualSplits(2)
        XCTAssertEqual(m.splits, [4.5])
        m.removeSplit(at: 0)
        XCTAssertEqual(m.clips, [VideoClip(start: 0, end: 9)])
    }

    func testSnapshotsAreSortedAndDeduped() {
        let m = VideoModel(duration: 4, size: CGSize(width: 100, height: 100), frameRate: 30)
        m.addSnapshot(2)
        m.addSnapshot(0)
        m.addSnapshot(2.001)
        m.addSnapshot(99)
        XCTAssertEqual(m.snapshots, [0, 2, 4])
        m.removeSnapshot(at: 1)
        XCTAssertEqual(m.snapshots, [0, 4])
    }

    func testRedactBoxes() {
        let m = VideoModel(duration: 10, size: CGSize(width: 200, height: 100))
        let id = m.addBox(start: 3, end: 3.01)
        XCTAssertEqual(m.selectedBox, id)
        XCTAssertEqual(m.boxes[0].end - m.boxes[0].start, 0.1, accuracy: 0.001)
        m.setBoxEnd(id, 8)
        m.setBoxStart(id, 9)
        XCTAssertEqual(m.boxes[0].start, 7.9, accuracy: 0.001)
        m.shiftBox(id, start: 99)
        XCTAssertEqual(m.boxes[0].end, 10, accuracy: 0.001)
        m.shiftBox(id, start: -4)
        XCTAssertEqual(m.boxes[0].start, 0, accuracy: 0.001)
        m.updateBox(id) { $0.move(by: CGSize(width: 999, height: 999), from: $0.rect, in: m.size) }
        XCTAssertEqual(m.boxes[0].rect.maxX, 200)
        XCTAssertEqual(m.boxes[0].rect.maxY, 100)
        m.updateBox(id) { $0.resize(.topLeft, to: CGPoint(x: 999, y: 999), in: m.size) }
        XCTAssertEqual(m.boxes[0].rect.width, RedactBox.minSize)
        m.removeBox(id)
        XCTAssertTrue(m.boxes.isEmpty)
        XCTAssertNil(m.selectedBox)
    }

    func testRedactArguments() {
        let box = RedactBox(rect: CGRect(x: 10, y: 20, width: 100, height: 50), start: 1, end: 3)
        let solid = VideoExporter.arguments(.redact(boxes: [box], style: .solid, color: VideoColor(r: 1, g: 0, b: 0)), input: src, output: out)
        XCTAssertTrue(solid.joined(separator: " ").contains("drawbox=x=10:y=20:w=100:h=50:color=0xFF0000:t=fill:enable='between(t,1.000,3.000)'"))
        let blur = VideoExporter.arguments(.redact(boxes: [box, box], style: .blur, color: .black), input: src, output: out)
        let graph = blur[blur.firstIndex(of: "-filter_complex")! + 1]
        XCTAssertTrue(graph.contains("[0:v]split=2[a0][t0];[t0]crop=100:50:10:20,boxblur=10:3[c0];[a0][c0]overlay=10:20:enable='between(t,1.000,3.000)'[v0]"))
        XCTAssertTrue(graph.contains("[v0]split=2[a1][t1]"))
        XCTAssertTrue(graph.hasSuffix("[v1]scale='trunc(iw/2)*2':'trunc(ih/2)*2'[out]"))
        XCTAssertTrue(blur.contains("0:a?"))
    }

    func testOutputNames() {
        XCTAssertEqual(VideoJob.speed(2).suffix, "-2x")
        XCTAssertEqual(VideoJob.clip(start: 0, end: 1, index: 3).suffix, "-part3")
        XCTAssertEqual(VideoJob.frame(at: 1.6).suffix, "-frame-1.60s")
        XCTAssertEqual(VideoJob.speed(0.5).suffix, "-0.5x")
        XCTAssertEqual(VideoJob.frame(at: 1).fileExtension, "png")
        XCTAssertEqual(VideoJob.trim(start: 0, end: 1).fileExtension, "mp4")
    }

    func testExportTrimWithRealFFmpeg() async throws {
        let ffmpeg = "/opt/homebrew/bin/ffmpeg"
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: ffmpeg))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("clip.mp4")
        let make = Process()
        make.executableURL = URL(fileURLWithPath: ffmpeg)
        make.arguments = ["-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=321x181:rate=30:duration=3",
                          "-c:v", "mpeg4", "-pix_fmt", "yuv420p", input.path]
        try make.run()
        make.waitUntilExit()
        let trimmed = try await VideoExporter.export(.trim(start: 1, end: 2), source: input)
        XCTAssertEqual(trimmed.lastPathComponent, "clip-trim.mp4")
        let frame = try await VideoExporter.export(.frame(at: 1), source: input)
        XCTAssertEqual(frame.lastPathComponent, "clip-frame-1.00s.png")
        for style in [RedactStyle.solid, .blur] {
            let box = RedactBox(rect: CGRect(x: 11, y: 7, width: 101, height: 61), start: 0.5, end: 2)
            let redacted = try await VideoExporter.export(.redact(boxes: [box], style: style, color: .black), source: input)
            XCTAssertGreaterThan((try redacted.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0, 0)
        }
        let part = try await VideoExporter.export(.clip(start: 0, end: 1.5, index: 1), source: input)
        XCTAssertEqual(part.lastPathComponent, "clip-part1.mp4")
        do {
            _ = try await VideoExporter.export(.frame(at: 99), source: input)
            XCTFail("frame past the end must fail")
        } catch {}
    }
}

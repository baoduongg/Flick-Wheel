import AVFoundation
import AppKit
import SwiftUI

@MainActor
final class VideoWindowController: NSObject, NSWindowDelegate {
    var onClose: ((VideoWindowController) -> Void)?

    private enum Content {
        case session(VideoSession)
        case crop(CropModel)
    }

    private let window: NSWindow
    private let mode: VideoMode
    private let source: URL
    private let model: VideoModel
    private var content: Content

    // nil when AVFoundation cannot play the file (mkv, webm, avi)
    static func make(file: URL, mode: VideoMode) async -> VideoWindowController? {
        let asset = AVURLAsset(url: file)
        guard (try? await asset.load(.isPlayable)) == true,
              let duration = try? await asset.load(.duration), duration.seconds.isFinite, duration.seconds > 0,
              let track = try? await asset.loadTracks(withMediaType: .video).first,
              let natural = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform)
        else { return nil }
        let rotated = natural.applying(transform)
        let size = CGSize(width: abs(rotated.width), height: abs(rotated.height))
        let fps = Double((try? await track.load(.nominalFrameRate)) ?? 30)
        let model = VideoModel(duration: duration.seconds, size: size, frameRate: fps)
        if mode == .crop {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.maximumSize = CGSize(width: 1280, height: 1280)
            guard let first = try? await generator.image(at: .zero).image else { return nil }
            return VideoWindowController(file: file, mode: mode, model: model) { controller in
                let crop = CropModel(imageSize: model.size)
                controller.content = .crop(crop)
                return AnyView(VideoCropView(model: model, crop: crop, generator: generator, image: first) { [weak controller] in
                    controller?.apply()
                })
            }
        }
        return VideoWindowController(file: file, mode: mode, model: model) { controller in
            let session = VideoSession(mode: mode, model: model, asset: asset)
            controller.content = .session(session)
            return AnyView(VideoContent(session: session) { [weak controller] in controller?.apply() })
        }
    }

    private init(file: URL, mode: VideoMode, model: VideoModel, build: (VideoWindowController) -> AnyView) {
        self.mode = mode
        source = file
        self.model = model
        content = .crop(CropModel(imageSize: model.size))
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.contentViewController = NSHostingController(rootView: build(self))
        window.title = mode.title
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    func show() {
        window.showCentered()
    }

    private func jobs() -> [VideoJob] {
        switch mode {
        case .trim: return [.trim(start: model.start, end: model.end)]
        case .frame: return model.snapshots.map { .frame(at: $0) }
        case .crop:
            if case .crop(let crop) = content { return [.crop(crop.pixelRect)] }
            return []
        case .speed: return [.speed(model.speed)]
        case .split: return model.clips.enumerated().map { .clip(start: $1.start, end: $1.end, index: $0 + 1) }
        case .redact: return [.redact(boxes: model.boxes, style: model.redactStyle, color: model.redactColor)]
        }
    }

    private func apply() {
        let jobs = jobs()
        guard !jobs.isEmpty else { return }
        let source = source
        let title = mode == .frame ? "Snapshots" : jobs[0].title
        if mode != .frame {
            ActionRunner.notify(title: "\(title) started", body: "Exporting \(source.lastPathComponent)")
        }
        let tracked = JobCenter.shared.begin(title: title, file: source.lastPathComponent)
        Task {
            var outputs: [URL] = []
            do {
                for job in jobs { outputs.append(try await VideoExporter.export(job, source: source)) }
                JobCenter.shared.finish(tracked, state: .succeeded, output: outputs.last)
                ActionRunner.notify(title: "\(title) done",
                                    body: outputs.count == 1 ? outputs[0].lastPathComponent : "\(outputs.count) files in \(source.deletingLastPathComponent().lastPathComponent)",
                                    file: outputs.last)
            } catch {
                JobCenter.shared.finish(tracked, state: .failed, detail: error.localizedDescription)
                ActionRunner.notify(title: "\(title) failed", body: error.localizedDescription)
            }
        }
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        if case .session(let session) = content { session.stop() }
        onClose?(self)
    }
}

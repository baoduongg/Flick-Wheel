import AVFoundation
import SwiftUI

// everything a player-based window needs besides the model: playback, filmstrip and thumbnails
@MainActor
final class VideoSession: ObservableObject {
    let mode: VideoMode
    let model: VideoModel
    let player: PlayerController
    let filmstrip: Filmstrip
    let thumbs: ThumbnailSource

    init(mode: VideoMode, model: VideoModel, asset: AVAsset) {
        self.mode = mode
        self.model = model
        player = PlayerController(asset: asset)
        filmstrip = Filmstrip(asset: asset, duration: model.duration)
        thumbs = ThumbnailSource(asset: asset)
        if mode == .frame { model.addSnapshot(0) }
        player.onTick = { [weak self] time in self?.tick(time) }
        player.onEnd = { [weak self] in
            if self?.mode == .trim, let self { self.player.seek(self.model.start) }
        }
    }

    func jump(_ seconds: Double) {
        model.current = seconds
        player.seek(seconds)
    }

    func scrub(_ seconds: Double) {
        player.scrubbing = true
        if player.isPlaying { player.pause() }
        jump(seconds)
    }

    func endScrub() {
        player.scrubbing = false
    }

    func step(_ frames: Int) {
        player.pause()
        jump(model.clampCurrent(model.current + Double(frames) / model.frameRate))
    }

    func togglePlay() {
        if player.isPlaying { player.pause(); return }
        if mode == .trim {
            if model.current < model.start || model.current >= model.end { jump(model.start) }
        } else if model.current >= model.duration - 0.05 {
            jump(0)
        }
        player.play(rate: mode == .speed ? Float(model.speed) : 1)
    }

    private func tick(_ time: Double) {
        model.current = time
        // trim previews loop inside the chosen range
        if mode == .trim, player.isPlaying, time >= model.end { jump(model.start) }
    }

    func stop() { player.stop() }
}

@MainActor
final class Filmstrip: ObservableObject {
    static let count = 8

    @Published private(set) var images: [CGImage?] = Array(repeating: nil, count: Filmstrip.count)
    private let generator: AVAssetImageGenerator
    private let duration: Double
    private var started = false

    init(asset: AVAsset, duration: Double) {
        self.duration = duration
        generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
    }

    func load() async {
        guard !started else { return }
        started = true
        for i in 0..<Self.count {
            let t = duration * (Double(i) + 0.5) / Double(Self.count)
            images[i] = try? await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image
        }
    }
}

@MainActor
final class ThumbnailSource {
    private let generator: AVAssetImageGenerator

    init(asset: AVAsset) {
        generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
    }

    func image(at seconds: Double) async -> CGImage? {
        try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
    }
}

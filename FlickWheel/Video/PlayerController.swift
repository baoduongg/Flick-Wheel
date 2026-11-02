import AVFoundation
import AVKit
import SwiftUI

@MainActor
final class PlayerController: ObservableObject {
    let player: AVPlayer
    @Published private(set) var isPlaying = false
    // ignore time ticks while the user drags a slider
    var scrubbing = false
    var onTick: ((Double) -> Void)?
    var onEnd: (() -> Void)?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(asset: AVAsset) {
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.scrubbing, time.isNumeric else { return }
                self.onTick?(time.seconds)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.onEnd?()
            }
        }
    }

    func seek(_ seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func play(rate: Float = 1) {
        player.rate = rate
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func setRate(_ rate: Float) {
        if isPlaying { player.rate = rate }
    }

    func stop() {
        pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
}

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}
}

import AVFoundation
import SwiftUI

enum VideoStyle {
    static let accent = Color(red: 1, green: 0.4, blue: 0.2)
    static let width: CGFloat = 440
    static let small = Font.system(size: 11)
}

struct VideoPane: View {
    let player: AVPlayer
    var height: CGFloat = 320

    var body: some View {
        VideoPlayerView(player: player)
            .frame(height: height)
            .background(Color(white: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TransportRow: View {
    @ObservedObject var model: VideoModel
    @ObservedObject var player: PlayerController
    let session: VideoSession
    var showsPlay = true

    var body: some View {
        HStack(spacing: 14) {
            Button { session.step(-1) } label: { Image(systemName: "backward.frame") }
            if showsPlay {
                Button { session.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 14)
                }
            }
            Button { session.step(1) } label: { Image(systemName: "forward.frame") }
            Spacer()
            Text("\(VideoTime.format(model.current)) / \(VideoTime.format(model.duration))")
                .font(VideoStyle.small).monospacedDigit().foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
    }
}

struct FilmstripView<Overlay: View>: View {
    @ObservedObject var strip: Filmstrip
    @ObservedObject var model: VideoModel
    let session: VideoSession
    var height: CGFloat = 56
    let overlay: (CGFloat) -> Overlay

    init(strip: Filmstrip, model: VideoModel, session: VideoSession, height: CGFloat = 56,
         @ViewBuilder overlay: @escaping (CGFloat) -> Overlay) {
        self.strip = strip
        self.model = model
        self.session = session
        self.height = height
        self.overlay = overlay
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0..<strip.images.count, id: \.self) { i in
                        ZStack {
                            Color(white: 0.2)
                            if let image = strip.images[i] {
                                Image(decorative: image, scale: 1).resizable().scaledToFill()
                            }
                        }
                        .frame(width: w / CGFloat(strip.images.count), height: height)
                        .clipped()
                    }
                }
                overlay(w)
                Rectangle().fill(Color.white)
                    .frame(width: 2, height: height)
                    .offset(x: CGFloat(model.current / model.duration) * w - 1)
                    .allowsHitTesting(false)
            }
            .frame(width: w, height: height)
            .coordinateSpace(name: "strip")
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { session.scrub(time(at: $0.location.x, width: w)) }
                .onEnded { _ in session.endScrub() })
        }
        .frame(height: height)
        .task { await strip.load() }
    }

    func time(at x: CGFloat, width: CGFloat) -> Double {
        Double(min(max(x / width, 0), 1)) * model.duration
    }
}

extension FilmstripView where Overlay == EmptyView {
    init(strip: Filmstrip, model: VideoModel, session: VideoSession, height: CGFloat = 56) {
        self.init(strip: strip, model: model, session: session, height: height) { _ in EmptyView() }
    }
}

extension CropHandle {
    func point(in r: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: r.minX, y: r.minY)
        case .top: return CGPoint(x: r.midX, y: r.minY)
        case .topRight: return CGPoint(x: r.maxX, y: r.minY)
        case .right: return CGPoint(x: r.maxX, y: r.midY)
        case .bottomRight: return CGPoint(x: r.maxX, y: r.maxY)
        case .bottom: return CGPoint(x: r.midX, y: r.maxY)
        case .bottomLeft: return CGPoint(x: r.minX, y: r.maxY)
        case .left: return CGPoint(x: r.minX, y: r.midY)
        }
    }
}

struct ApplyRow: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Divider()
            HStack {
                Spacer()
                Button(title, action: action)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!enabled)
            }
        }
    }
}

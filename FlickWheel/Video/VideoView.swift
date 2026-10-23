import AVFoundation
import SwiftUI

struct VideoContent: View {
    let session: VideoSession
    let onApply: () -> Void

    var body: some View {
        Group {
            switch session.mode {
            case .trim: TrimView(session: session, model: session.model, onApply: onApply)
            case .frame: SnapshotsView(session: session, model: session.model, onApply: onApply)
            case .split: SplitView(session: session, model: session.model, onApply: onApply)
            case .redact: RedactView(session: session, model: session.model, onApply: onApply)
            case .speed: SpeedView(session: session, model: session.model, onApply: onApply)
            case .crop: EmptyView()
            }
        }
        .padding(20)
        .frame(width: VideoStyle.width)
    }
}

struct TrimView: View {
    let session: VideoSession
    @ObservedObject var model: VideoModel
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VideoPane(player: session.player.player)
            HStack {
                Text("Drag the ends to trim")
                Spacer()
                Text("\(VideoTime.format(model.trimmedLength)) selected")
            }
            .font(VideoStyle.small).foregroundColor(.secondary)
            FilmstripView(strip: session.filmstrip, model: model, session: session) { w in overlay(w) }
            HStack {
                Text("Start \(VideoTime.format(model.start))")
                Spacer()
                Text("End \(VideoTime.format(model.end))")
            }
            .font(VideoStyle.small).monospacedDigit().foregroundColor(.secondary)
            TransportRow(model: model, player: session.player, session: session)
            ApplyRow(title: "Apply", action: onApply)
        }
    }

    private func overlay(_ w: CGFloat) -> some View {
        let sx = CGFloat(model.start / model.duration) * w
        let ex = CGFloat(model.end / model.duration) * w
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55).frame(width: sx).allowsHitTesting(false)
            Color.black.opacity(0.55).frame(width: max(w - ex, 0)).offset(x: ex).allowsHitTesting(false)
            Rectangle().strokeBorder(VideoStyle.accent, lineWidth: 3)
                .frame(width: max(ex - sx, 0)).offset(x: sx).allowsHitTesting(false)
            handle().offset(x: sx)
                .gesture(drag(w) { model.setStart($0); session.jump(model.start) })
            handle().offset(x: ex - 14)
                .gesture(drag(w) { model.setEnd($0); session.jump(model.end) })
        }
    }

    private func handle() -> some View {
        ZStack {
            VideoStyle.accent
            Capsule().fill(Color.white).frame(width: 3, height: 22)
        }
        .frame(width: 14)
    }

    private func drag(_ w: CGFloat, _ change: @escaping (Double) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("strip")).onChanged { value in
            change(Double(min(max(value.location.x, 0), w) / w) * model.duration)
        }
    }
}

struct SnapshotsView: View {
    let session: VideoSession
    @ObservedObject var model: VideoModel
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VideoPane(player: session.player.player)
            Slider(value: Binding(get: { model.current }, set: { session.scrub($0) }), in: 0...model.duration) { editing in
                if !editing { session.endScrub() }
            }
            TransportRow(model: model, player: session.player, session: session, showsPlay: false)
            Divider()
            HStack {
                Text("\(model.snapshots.count) selected")
                    .font(VideoStyle.small).foregroundColor(.secondary)
                Spacer()
                Button("Add Frame") { model.addSnapshot(model.current) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(model.snapshots.enumerated()), id: \.element) { index, time in
                        SnapshotThumb(time: time, thumbs: session.thumbs,
                                      onSelect: { session.jump(time) }, onRemove: { model.removeSnapshot(at: index) })
                    }
                }
            }
            .frame(height: 52)
            ApplyRow(title: model.snapshots.count == 1 ? "Save 1 Frame" : "Save \(model.snapshots.count) Frames",
                     enabled: !model.snapshots.isEmpty, action: onApply)
        }
    }
}

private struct SnapshotThumb: View {
    let time: Double
    let thumbs: ThumbnailSource
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Color(white: 0.2)
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFill() }
        }
        .frame(width: 72, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .bottomLeading) {
            Text(VideoTime.format(time))
                .font(.system(size: 9, weight: .medium)).monospacedDigit().foregroundColor(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.black.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(3)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                    .frame(width: 14, height: 14).background(Color.black.opacity(0.7)).clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(3)
        }
        .onTapGesture(perform: onSelect)
        .task(id: time) { image = await thumbs.image(at: time) }
    }
}

struct SplitView: View {
    let session: VideoSession
    @ObservedObject var model: VideoModel
    let onApply: () -> Void
    @State private var equal = 2

    var body: some View {
        VStack(spacing: 14) {
            VideoPane(player: session.player.player)
            HStack {
                Text(model.splits.count == 1 ? "1 split point" : "\(model.splits.count) split points")
                    .font(VideoStyle.small).foregroundColor(.secondary)
                Spacer()
                Button { model.addSplit(model.current) } label: { Label("Add Split", systemImage: "scissors") }
            }
            FilmstripView(strip: session.filmstrip, model: model, session: session) { w in markers(w) }
            TransportRow(model: model, player: session.player, session: session, showsPlay: false)
            Divider()
            HStack {
                Text("Equal clips").font(VideoStyle.small).foregroundColor(.secondary)
                Spacer()
                Stepper(value: $equal, in: 2...20) { Text("\(equal)").monospacedDigit() }
                Button("Set") { model.setEqualSplits(equal) }
            }
            ApplyRow(title: "Split Video", enabled: !model.splits.isEmpty, action: onApply)
        }
    }

    // tap a marker to remove it
    private func markers(_ w: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.splits.enumerated()), id: \.element) { index, time in
                let x = CGFloat(time / model.duration) * w
                ZStack {
                    Color.clear
                    Rectangle().fill(VideoStyle.accent).frame(width: 3)
                }
                .frame(width: 16)
                .contentShape(Rectangle())
                .offset(x: x - 8)
                .onTapGesture { model.removeSplit(at: index) }
            }
        }
    }
}

struct SpeedView: View {
    let session: VideoSession
    @ObservedObject var model: VideoModel
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VideoPane(player: session.player.player)
            Picker("Speed", selection: $model.speed) {
                ForEach(VideoModel.speeds, id: \.self) { Text("\(String(format: "%g", $0))x").tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: model.speed) { session.player.setRate(Float($0)) }
            HStack {
                Text("Result length \(VideoTime.format(model.spedUpLength))")
                    .font(VideoStyle.small).foregroundColor(.secondary)
                Spacer()
            }
            FilmstripView(strip: session.filmstrip, model: model, session: session)
            TransportRow(model: model, player: session.player, session: session)
            ApplyRow(title: "Apply", action: onApply)
        }
    }
}

struct VideoCropView: View {
    @ObservedObject var model: VideoModel
    @ObservedObject var crop: CropModel
    let generator: AVAssetImageGenerator
    @State var image: CGImage
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Frame")
                Slider(value: $model.current, in: 0...model.duration)
                Text(VideoTime.format(model.current)).monospacedDigit().frame(width: 64, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            CropView(model: crop, image: image, onApply: onApply)
        }
        .frame(width: 460)
        .task(id: Int(model.current * 10)) {
            if let result = try? await generator.image(at: CMTime(seconds: model.current, preferredTimescale: 600)) {
                image = result.image
            }
        }
    }
}

import AppKit
import SwiftUI

@MainActor
final class WheelDropView: NSView {
    var onDrop: ((WheelAction, [URL]) -> Void)?
    var onEnd: (() -> Void)?

    private let hosting = NSHostingView(rootView: RadialWheelView(actions: [], hovered: nil))
    private var actions: [WheelAction] = []
    private var hovered: Int? {
        didSet { render() }
    }

    init() {
        let size = RadialWheelView.size(count: 0)
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(actions: [WheelAction]) {
        self.actions = actions
        hovered = nil
        render()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        track(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        track(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        hovered = nil
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let index = segmentIndex(for: sender),
              let urls = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty
        else {
            onEnd?()
            return false
        }
        onDrop?(actions[index], urls)
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onEnd?()
    }

    private func track(_ sender: NSDraggingInfo) -> NSDragOperation {
        hovered = segmentIndex(for: sender)
        // accept anywhere in the panel so a release off-segment still reaches performDragOperation and hides the wheel
        return actions.isEmpty ? [] : .copy
    }

    private func render() {
        hosting.rootView = RadialWheelView(actions: actions, hovered: hovered)
    }

    private func segmentIndex(for sender: NSDraggingInfo) -> Int? {
        guard !actions.isEmpty else { return nil }
        let point = convert(sender.draggingLocation, from: nil)
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        let radius = hypot(dx, dy)
        let radii = RadialWheelView.radii(count: actions.count)
        guard radius >= radii.inner, radius <= radii.outer else { return nil }
        let step = 360.0 / Double(actions.count)
        var angle = Double(atan2(dx, dy)) * 180 / .pi - RadialWheelView.startDegrees(count: actions.count)
        angle = angle.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return min(Int(angle / step), actions.count - 1)
    }
}

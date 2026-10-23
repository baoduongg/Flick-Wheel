import AppKit
import SwiftUI

@MainActor
final class WheelDropView: NSView {
    var onDrop: ((WheelAction, [URL]) -> Void)?
    var onEnd: (() -> Void)?

    private let state = WheelState()
    private lazy var hosting = NSHostingView(rootView: RadialWheelView(state: state))
    private var actions: [WheelAction] { state.actions }
    private var dragImageShrunk = false
    private var hovered: Int? {
        get { state.hovered }
        set { state.hovered = newValue }
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
        dragImageShrunk = false
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            state.shown = false
            state.cursor = nil
            state.hovered = nil
            state.actions = actions
        }
    }

    // flip after the first layout so the entrance animation runs from the collapsed state
    func present() {
        DispatchQueue.main.async { [state] in state.shown = true }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        track(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        track(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragImageShrunk = false
        state.cursor = nil
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
        dragImageShrunk = false
        onEnd?()
    }

    // Finder's drag image carries the file name; a long name makes a wide band that hides segments.
    // Blank it and draw our own icon at the cursor instead (see RadialWheelView).
    private func replaceDragImage(_ sender: NSDraggingInfo) {
        sender.enumerateDraggingItems(options: [], for: self, classes: [NSURL.self],
                                      searchOptions: [.urlReadingFileURLsOnly: true]) { item, _, _ in
            item.draggingFrame = NSRect(x: 0, y: 0, width: 1, height: 1)
            item.imageComponentsProvider = { [] }
        }
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        state.icon = urls.first.map { NSWorkspace.shared.icon(forFile: $0.path) }
        state.fileCount = urls.count
    }

    private func track(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !dragImageShrunk {
            dragImageShrunk = true
            replaceDragImage(sender)
        }
        let cursor = convert(sender.draggingLocation, from: nil)
        state.cursor = CGPoint(x: cursor.x, y: bounds.height - cursor.y)
        hovered = segmentIndex(for: sender)
        // accept anywhere in the panel so a release off-segment still reaches performDragOperation and hides the wheel
        return actions.isEmpty ? [] : .copy
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

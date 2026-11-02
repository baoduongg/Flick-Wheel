import AppKit

@MainActor
final class DragKeyMonitor {
    var onWheel: ((WheelKind, [URL]) -> Void)?
    var onDragEnd: (() -> Void)?
    var onRelease: (() -> Void)?
    // a fresh click or key press means no drag is in progress: dismiss a stuck wheel
    var onCancel: (() -> Void)?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var monitors: [Any] = []
    private var draggedURLs: [URL] = []
    private var seenChangeCount = 0

    func start() {
        guard monitors.isEmpty else { return }
        seenChangeCount = dragPasteboard.changeCount
        let handlers: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = [
            (.leftMouseDragged, { [weak self] _ in
                Task { @MainActor in self?.handleDrag() }
            }),
            (.leftMouseDown, { [weak self] _ in
                Task { @MainActor in self?.onCancel?() }
            }),
            (.keyDown, { [weak self] _ in
                Task { @MainActor in self?.onCancel?() }
            }),
            (.leftMouseUp, { [weak self] _ in
                Task { @MainActor in self?.handleMouseUp() }
            }),
            (.flagsChanged, { [weak self] event in
                let flags = event.modifierFlags
                Task { @MainActor in self?.handleFlags(flags) }
            }),
        ]
        monitors = handlers.compactMap { NSEvent.addGlobalMonitorForEvents(matching: $0.0, handler: $0.1) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        draggedURLs = []
    }

    func reset() {
        draggedURLs = []
        seenChangeCount = dragPasteboard.changeCount
    }

    private func handleDrag() {
        guard draggedURLs.isEmpty, dragPasteboard.changeCount != seenChangeCount else { return }
        let objects = dragPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        draggedURLs = (objects as? [URL]) ?? []
    }

    private func handleMouseUp() {
        reset()
        onDragEnd?()
    }

    private func handleFlags(_ flags: NSEvent.ModifierFlags) {
        guard !draggedURLs.isEmpty else { return }
        if flags.intersection([.shift, .command, .control]).isEmpty {
            onRelease?()
            return
        }
        let kind: WheelKind
        switch flags.intersection(.deviceIndependentFlagsMask) {
        case .shift: kind = .shift
        case .command: kind = .command
        case .control: kind = .control
        default: return
        }
        onWheel?(kind, draggedURLs)
    }
}

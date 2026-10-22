import AppKit

@MainActor
final class WheelPanelController {
    var onSelect: ((WheelAction, [URL]) -> Void)?
    var onFinish: (() -> Void)?

    private let panel: NSPanel
    private let dropView = WheelDropView()

    init() {
        panel = NSPanel(contentRect: dropView.frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        // must stay below the drag-image window: AppKit skips windows above it when picking a drop target
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = dropView
        dropView.onDrop = { [weak self] action, urls in
            self?.onSelect?(action, urls)
        }
        dropView.onEnd = { [weak self] in
            self?.hide()
            self?.onFinish?()
        }
    }

    func show(actions: [WheelAction], at point: NSPoint) {
        let size = RadialWheelView.size(count: actions.count)
        dropView.configure(actions: actions)
        panel.setFrame(NSRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        dropView.configure(actions: [])
    }

    func contains(_ screenPoint: NSPoint) -> Bool {
        panel.isVisible && panel.frame.contains(screenPoint)
    }
}

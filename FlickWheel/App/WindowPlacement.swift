import AppKit

extension NSWindow {
    // NSHostingController sizes the window lazily, so centring right after creating it lands off-centre:
    // fit the window to its content first, then centre and show
    func showCentered() {
        if let view = contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            setContentSize(view.fittingSize)
        }
        center()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}

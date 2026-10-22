import SwiftUI

@main
struct FlickWheelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("FlickWheel", systemImage: "circle.grid.cross") {
            Button("Reload actions") { delegate.reloadActions() }
            Button("Open actions.json") { delegate.openActions() }
            Button("Accessibility status: \(delegate.accessibilityTrusted ? "granted" : "not granted")") {
                delegate.checkAccessibility()
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

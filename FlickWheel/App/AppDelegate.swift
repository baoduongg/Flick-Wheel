import AppKit
import ApplicationServices
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var accessibilityTrusted = false

    private let registry = ActionRegistry()
    private let monitor = DragKeyMonitor()
    private let wheel = WheelPanelController()
    private var cropWindows: [CropWindowController] = []
    private var annotateWindows: [AnnotateWindowController] = []
    private var backgroundWindows: [BackgroundWindowController] = []
    private let airDrop = AirDropSender()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        reloadActions()

        wheel.onSelect = { [weak self] action, urls in
            Task { await ActionRunner.runAndNotify(action, on: urls) }
            self?.monitor.reset()
        }
        wheel.onFinish = { [weak self] in
            self?.monitor.reset()
        }
        monitor.onWheel = { [weak self] kind, urls in
            guard let self else { return }
            let actions = registry.actions(for: kind, files: urls)
            if actions.isEmpty {
                wheel.hide()
            } else {
                wheel.show(actions: actions, at: NSEvent.mouseLocation)
            }
        }
        monitor.onRelease = { [weak self] in
            self?.wheel.hide()
        }
        monitor.onDragEnd = { [weak self] in
            guard let self, !wheel.contains(NSEvent.mouseLocation) else { return }
            wheel.hide()
        }

        accessibilityTrusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        monitor.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "flickwheel" {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let file = items.first { $0.name == "path" }?.value.map { URL(fileURLWithPath: $0) }
            let tool = AnnotationTool.allCases.first { String(describing: $0) == items.first { $0.name == "tool" }?.value }
            switch url.host {
            case "crop": openCrop(file)
            case "annotate": openAnnotate(file, tool: tool ?? .arrow)
            case "background": openBackground(file)
            case "airdrop": if let file { airDrop.send(file) }
            default: break
            }
        }
    }

    private func openCrop(_ file: URL?) {
        guard let file, let controller = CropWindowController(file: file) else {
            ActionRunner.notify(title: "Crop failed", body: "Cannot open the image")
            return
        }
        controller.onClose = { [weak self] closed in
            self?.cropWindows.removeAll { $0 === closed }
        }
        cropWindows.append(controller)
        controller.show()
    }

    private func openAnnotate(_ file: URL?, tool: AnnotationTool) {
        guard let file, let controller = AnnotateWindowController(file: file, tool: tool) else {
            ActionRunner.notify(title: "Annotate failed", body: "Cannot open the image")
            return
        }
        controller.onClose = { [weak self] closed in
            self?.annotateWindows.removeAll { $0 === closed }
        }
        annotateWindows.append(controller)
        controller.show()
    }

    private func openBackground(_ file: URL?) {
        guard let file, let controller = BackgroundWindowController(file: file) else {
            ActionRunner.notify(title: "Add BG failed", body: "Cannot open the image")
            return
        }
        controller.onClose = { [weak self] closed in
            self?.backgroundWindows.removeAll { $0 === closed }
        }
        backgroundWindows.append(controller)
        controller.show()
    }

    func reloadActions() {
        let problems = registry.load()
        if !problems.isEmpty {
            ActionRunner.notify(title: "Skipped \(problems.count) invalid action(s)", body: problems.joined(separator: "\n"))
        }
    }

    func openActions() {
        NSWorkspace.shared.open(registry.url)
    }

    func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
            monitor.stop()
            monitor.start()
        }
        if !trusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

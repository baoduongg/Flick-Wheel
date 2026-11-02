import AppKit
import ApplicationServices
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    @Published private(set) var accessibilityTrusted = false

    let registry = ActionRegistry()
    private var settingsWindow: NSWindow?
    private let monitor = DragKeyMonitor()
    private let wheel = WheelPanelController()
    private var cropWindows: [CropWindowController] = []
    private var annotateWindows: [AnnotateWindowController] = []
    private var backgroundWindows: [BackgroundWindowController] = []
    private var pixelPerfectWindows: [PixelPerfectWindowController] = []
    private var videoWindows: [VideoWindowController] = []
    private var cloneWindows: [CloneWindowController] = []
    private var linesWindows: [LinesWindowController] = []
    private var translateWindows: [TranslateWindowController] = []
    private let airDrop = AirDropSender()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
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
        monitor.onCancel = { [weak self] in
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
            case "pixelperfect": openPixelPerfect(items.filter { $0.name == "path" }.compactMap(\.value).map { URL(fileURLWithPath: $0) })
            case "clone": openClone(file)
            case "lines": openLines(file)
            case "translate": openTranslate(file)
            case "video": openVideo(file, mode: VideoMode(rawValue: items.first { $0.name == "mode" }?.value ?? ""))
            case "settings": openSettings(tab: items.first { $0.name == "tab" }?.value)
            case "tool": runTool(BuiltinTool(rawValue: items.first { $0.name == "name" }?.value ?? ""),
                                 items.filter { $0.name == "path" }.compactMap(\.value).map { URL(fileURLWithPath: $0) })
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

    private func openClone(_ file: URL?) {
        guard let file else {
            ActionRunner.notify(title: "Clone failed", body: "Missing destination folder")
            return
        }
        let folder = WheelAction.isFolder(file) ? file : file.deletingLastPathComponent()
        let controller = CloneWindowController(into: folder)
        controller.onClose = { [weak self] closed in
            self?.cloneWindows.removeAll { $0 === closed }
        }
        cloneWindows.append(controller)
        controller.show()
    }

    private func openTranslate(_ file: URL?) {
        guard let file else {
            ActionRunner.notify(title: "Translate failed", body: "Missing file")
            return
        }
        let controller = TranslateWindowController(file: file)
        controller.onOpenSettings = { [weak self] in self?.openSettings(tab: "translate") }
        controller.onClose = { [weak self] closed in
            self?.translateWindows.removeAll { $0 === closed }
        }
        translateWindows.append(controller)
        controller.show()
    }

    private func openLines(_ file: URL?) {
        guard let file, WheelAction.isFolder(file) else {
            ActionRunner.notify(title: "Lines failed", body: "Drop a folder")
            return
        }
        let controller = LinesWindowController(folder: file)
        controller.onClose = { [weak self] closed in
            self?.linesWindows.removeAll { $0 === closed }
        }
        linesWindows.append(controller)
        controller.show()
    }

    private func openPixelPerfect(_ files: [URL]) {
        guard files.count == 2, let controller = PixelPerfectWindowController(files: files) else {
            ActionRunner.notify(title: "Pixel Perfect failed", body: "Need two readable images")
            return
        }
        controller.onClose = { [weak self] closed in
            self?.pixelPerfectWindows.removeAll { $0 === closed }
        }
        pixelPerfectWindows.append(controller)
        controller.show()
    }

    private func runTool(_ tool: BuiltinTool?, _ files: [URL]) {
        guard let tool, let file = files.first else {
            ActionRunner.notify(title: "Tool failed", body: "Unknown tool or missing file")
            return
        }
        let job = JobCenter.shared.begin(title: tool.title, file: file.lastPathComponent)
        Task {
            do {
                let outcome = try await Task.detached { try tool.run(on: files) }.value
                if let text = outcome.clipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                JobCenter.shared.finish(job, state: .succeeded, output: outcome.output)
                ActionRunner.notify(title: tool.title, body: outcome.message, file: outcome.output)
            } catch {
                JobCenter.shared.finish(job, state: .failed, detail: error.localizedDescription)
                ActionRunner.notify(title: "\(tool.title) failed", body: error.localizedDescription)
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        if let path = response.notification.request.content.userInfo["path"] as? String {
            DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }

    func openPacksFolder() {
        try? FileManager.default.createDirectory(at: ActionRegistry.userPacksURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(ActionRegistry.userPacksURL)
    }

    private func openVideo(_ file: URL?, mode: VideoMode?) {
        Task {
            guard let file, let mode, let controller = await VideoWindowController.make(file: file, mode: mode) else {
                ActionRunner.notify(title: "Video preview failed", body: "Cannot open the video (mp4, mov and m4v only)")
                return
            }
            controller.onClose = { [weak self] closed in
                self?.videoWindows.removeAll { $0 === closed }
            }
            videoWindows.append(controller)
            controller.show()
        }
    }

    func reloadActions() {
        let problems = registry.load()
        if !problems.isEmpty {
            ActionRunner.notify(title: "Skipped \(problems.count) invalid action(s)", body: problems.joined(separator: "\n"))
        }
    }

    func openSettings(tab: String? = nil) {
        if settingsWindow == nil || tab != nil {
            settingsWindow?.close()
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(
                registry: registry, tab: tab,
                tools: SettingsTools(openActions: { [weak self] in self?.openActions() },
                                     reload: { [weak self] in self?.reloadActions() },
                                     openPacksFolder: { [weak self] in self?.openPacksFolder() }))))
            window.title = "FlickWheel Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
            window.showCentered()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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

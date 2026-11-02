import AppKit
import SwiftUI

@main
struct FlickWheelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var jobs = JobCenter.shared

    var body: some Scene {
        MenuBarExtra {
            if !jobs.running.isEmpty {
                ForEach(jobs.running) { job in
                    Button("Cancel \(job.title): \(job.fileName)\(job.status.map { " (\($0))" } ?? "")") { jobs.cancel(job.id) }
                        .disabled(!job.cancellable)
                }
                Divider()
            }
            Menu("Recent") {
                if jobs.recent.isEmpty {
                    Text("Nothing yet")
                } else {
                    ForEach(jobs.recent) { job in
                        Button("\(mark(job.state)) \(job.title): \(job.fileName)") { reveal(job) }
                            .disabled(job.output == nil)
                            .help(job.detail ?? "")
                    }
                    Divider()
                    Button("Clear") { jobs.clearRecent() }
                }
            }
            Divider()
            Button("Settings…") { delegate.openSettings() }
                .keyboardShortcut(",")
            Button("Reload actions") { delegate.reloadActions() }
            Button("Open actions.json") { delegate.openActions() }
            Button("Accessibility status: \(delegate.accessibilityTrusted ? "granted" : "not granted")") {
                delegate.checkAccessibility()
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            // a job that reports progress shows its percentage beside the icon
            if let progress = jobs.running.compactMap(\.progress).first {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("\(Int(progress * 100))%").monospacedDigit()
                }
            } else {
                Image(systemName: jobs.running.isEmpty ? "circle.grid.cross" : "arrow.triangle.2.circlepath")
            }
        }
    }

    private func mark(_ state: JobCenter.State) -> String {
        switch state {
        case .succeeded: return "✓"
        case .failed: return "✕"
        case .cancelled: return "–"
        case .running: return "…"
        }
    }

    private func reveal(_ job: JobCenter.Job) {
        if let output = job.output { NSWorkspace.shared.activateFileViewerSelecting([output]) }
    }
}

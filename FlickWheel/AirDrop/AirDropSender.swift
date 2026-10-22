import AppKit

@MainActor
final class AirDropSender: NSObject, NSSharingServiceDelegate {
    private var pending: [URL] = []
    private var debounce: Task<Void, Never>?
    private var service: NSSharingService?

    // the runner fires one command per dropped file; gather them so a single AirDrop sheet opens
    func send(_ file: URL) {
        pending.append(file)
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    private func flush() {
        let files = pending
        pending = []
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: files) else {
            ActionRunner.notify(title: "AirDrop failed", body: "AirDrop is not available")
            return
        }
        service.delegate = self
        self.service = service
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: files)
    }

    nonisolated func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            ActionRunner.notify(title: "AirDrop failed", body: message)
            self.service = nil
        }
    }

    nonisolated func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        Task { @MainActor in
            self.service = nil
        }
    }
}

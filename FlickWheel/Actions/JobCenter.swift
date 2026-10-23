import Combine
import Foundation

// what is running now and what finished lately; feeds the menu bar (cancel, reveal the result)
@MainActor
final class JobCenter: ObservableObject {
    static let shared = JobCenter()
    static let maxHistory = 10

    enum State: Equatable { case running, succeeded, failed, cancelled }

    struct Job: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let fileName: String
        var state: State = .running
        var output: URL?
        var detail: String?
        let cancellable: Bool
    }

    // newest first
    @Published private(set) var jobs: [Job] = []
    private var handles: [UUID: RunHandle] = [:]

    var running: [Job] { jobs.filter { $0.state == .running } }
    var recent: [Job] { jobs.filter { $0.state != .running } }

    @discardableResult
    func begin(title: String, file: String, handle: RunHandle? = nil) -> UUID {
        let job = Job(title: title, fileName: file, cancellable: handle != nil)
        jobs.insert(job, at: 0)
        if let handle { handles[job.id] = handle }
        return job.id
    }

    func finish(_ id: UUID, state: State, output: URL? = nil, detail: String? = nil) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].state = state
        jobs[i].output = output
        jobs[i].detail = detail
        handles[id] = nil
        trim()
    }

    func cancel(_ id: UUID) {
        handles[id]?.cancel()
    }

    func clearRecent() {
        jobs.removeAll { $0.state != .running }
    }

    // keep every running job, but only the newest maxHistory finished ones
    private func trim() {
        var finished = 0
        jobs = jobs.filter {
            guard $0.state != .running else { return true }
            finished += 1
            return finished <= Self.maxHistory
        }
    }
}

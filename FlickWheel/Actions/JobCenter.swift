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
        // 0...1 for work that reports it (translate, clone); status is the short text shown beside the title
        var progress: Double?
        var status: String?
        let cancellable: Bool
    }

    // newest first
    @Published private(set) var jobs: [Job] = []
    private var handles: [UUID: RunHandle] = [:]
    private var cancelActions: [UUID: () -> Void] = [:]

    var running: [Job] { jobs.filter { $0.state == .running } }
    var recent: [Job] { jobs.filter { $0.state != .running } }

    @discardableResult
    func begin(title: String, file: String, handle: RunHandle? = nil) -> UUID {
        let job = Job(title: title, fileName: file, cancellable: handle != nil)
        jobs.insert(job, at: 0)
        if let handle { handles[job.id] = handle }
        return job.id
    }

    // for in-app work (a window's task) rather than a shell command
    @discardableResult
    func begin(title: String, file: String, cancel: @escaping () -> Void) -> UUID {
        let job = Job(title: title, fileName: file, cancellable: true)
        jobs.insert(job, at: 0)
        cancelActions[job.id] = cancel
        return job.id
    }

    func update(_ id: UUID, progress: Double?, status: String?) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].progress = progress
        jobs[i].status = status
    }

    // the file a job produced after it finished (a translation saved later)
    func attach(output: URL, to id: UUID) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].output = output
    }

    func finish(_ id: UUID, state: State, output: URL? = nil, detail: String? = nil) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].state = state
        jobs[i].output = output
        jobs[i].detail = detail
        jobs[i].progress = nil
        jobs[i].status = nil
        handles[id] = nil
        cancelActions[id] = nil
        trim()
    }

    func cancel(_ id: UUID) {
        handles[id]?.cancel()
        cancelActions[id]?()
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

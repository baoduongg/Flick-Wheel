import XCTest

@MainActor
final class JobCenterTests: XCTestCase {
    func testRunningThenFinishedKeepsNewestFirst() {
        let center = JobCenter()
        let a = center.begin(title: "A", file: "a.png")
        let b = center.begin(title: "B", file: "b.png", handle: RunHandle())
        XCTAssertEqual(center.running.map(\.title), ["B", "A"])
        XCTAssertFalse(center.running[1].cancellable)
        XCTAssertTrue(center.running[0].cancellable)
        center.finish(a, state: .succeeded, output: URL(fileURLWithPath: "/tmp/a.jpg"))
        XCTAssertEqual(center.running.map(\.title), ["B"])
        XCTAssertEqual(center.recent.map(\.title), ["A"])
        XCTAssertEqual(center.recent[0].output?.lastPathComponent, "a.jpg")
        center.finish(b, state: .failed, detail: "boom")
        XCTAssertEqual(center.recent.map(\.state), [.failed, .succeeded])
    }

    func testHistoryIsCappedButRunningJobsStay() {
        let center = JobCenter()
        let keep = center.begin(title: "long", file: "x")
        for i in 0..<(JobCenter.maxHistory + 5) {
            center.finish(center.begin(title: "t\(i)", file: "f"), state: .succeeded)
        }
        XCTAssertEqual(center.recent.count, JobCenter.maxHistory)
        XCTAssertEqual(center.recent.first?.title, "t\(JobCenter.maxHistory + 4)")
        XCTAssertEqual(center.running.map(\.id), [keep])
        center.clearRecent()
        XCTAssertTrue(center.recent.isEmpty)
        XCTAssertEqual(center.running.count, 1)
    }

    func testCancelReachesTheHandle() {
        let center = JobCenter()
        let handle = RunHandle()
        let id = center.begin(title: "A", file: "a", handle: handle)
        center.cancel(id)
        XCTAssertTrue(handle.isCancelled)
    }
}

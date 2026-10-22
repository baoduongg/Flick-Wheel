import XCTest

final class ActionRunnerTests: XCTestCase {
    private func action(_ command: String) -> WheelAction {
        WheelAction(id: "t", label: "T", wheel: .shift, accepts: ["*"], command: command)
    }

    func testEnvironmentForPathWithSpacesAndSingleQuote() async {
        let file = URL(fileURLWithPath: "/tmp/flick wheel/it's a.photo.PNG")
        let result = await ActionRunner.run(
            action(#"printf 'INPUT=%s\nDIR=%s\nNAME=%s\n' "$INPUT" "$DIR" "$NAME" >&2"#), on: file)
        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(result.stderr.contains("INPUT=/tmp/flick wheel/it's a.photo.PNG\n"))
        XCTAssertTrue(result.stderr.contains("DIR=/tmp/flick wheel\n"))
        XCTAssertTrue(result.stderr.contains("NAME=it's a.photo\n"))
    }

    func testHomebrewIsOnPath() async {
        let result = await ActionRunner.run(
            action(#"case ":$PATH:" in *:/opt/homebrew/bin:*) ;; *) exit 1;; esac"#), on: URL(fileURLWithPath: "/tmp/a.png"))
        XCTAssertTrue(result.succeeded)
    }

    func testNonZeroExitIsFailureWithStderr() async {
        let result = await ActionRunner.run(action("echo boom >&2; exit 3"), on: URL(fileURLWithPath: "/tmp/a.png"))
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.exitCode, 3)
        XCTAssertTrue(result.stderr.contains("boom"))
    }

    func testTimeoutKillsProcess() async {
        let result = await ActionRunner.run(action("sleep 30"), on: URL(fileURLWithPath: "/tmp/a.png"), timeout: 1)
        XCTAssertTrue(result.timedOut)
        XCTAssertFalse(result.succeeded)
    }
}

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

    func testInputsHoldsEveryFileOnePerLine() async {
        let a = URL(fileURLWithPath: "/tmp/a b.png"), b = URL(fileURLWithPath: "/tmp/it's.png")
        let result = await ActionRunner.run(action(#"printf '%s' "$INPUTS" >&2"#), on: a, all: [a, b])
        XCTAssertEqual(result.stderr, "/tmp/a b.png\n/tmp/it's.png")
    }

    func testFwOutPicksANameThatIsFree() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("it's a.png")
        for name in ["it's a.gif", "it's a 2.gif"] { FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data()) }
        let result = await ActionRunner.run(action(#"fw_out "$DIR/$NAME.gif" >&2"#), on: file)
        XCTAssertEqual(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines), dir.path + "/it's a 3.gif")
        let free = await ActionRunner.run(action(#"fw_out "$DIR/$NAME.webp" >&2"#), on: file)
        XCTAssertEqual(free.stderr.trimmingCharacters(in: .whitespacesAndNewlines), dir.path + "/it's a.webp")
    }

    func testCancelStopsTheCommandAndItsChild() async throws {
        let handle = RunHandle()
        let started = Date()
        async let result = ActionRunner.run(action("sleep 30; echo late"), on: URL(fileURLWithPath: "/tmp/a.png"), handle: handle)
        try await Task.sleep(nanoseconds: 400_000_000)
        handle.cancel()
        let r = await result
        XCTAssertTrue(r.cancelled)
        XCTAssertFalse(r.succeeded)
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testOutputProbeFindsTheNewFileOnly() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("a.png")
        FileManager.default.createFile(atPath: input.path, contents: Data())
        FileManager.default.createFile(atPath: dir.appendingPathComponent("old.txt").path, contents: Data())
        let before = OutputProbe.snapshot(dir)
        XCTAssertNil(OutputProbe.newest(in: dir, since: before, excluding: input))
        FileManager.default.createFile(atPath: dir.appendingPathComponent("a.jpg").path, contents: Data())
        XCTAssertEqual(OutputProbe.newest(in: dir, since: before, excluding: input)?.lastPathComponent, "a.jpg")
    }

    private func scratch() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    func testExitZeroWithoutTheOutputFileIsAFailure() async throws {
        let dir = try scratch()
        let file = dir.appendingPathComponent("a.png")
        // what sips does when it cannot read the input: a warning on stdout, exit code 0
        let skipped = await ActionRunner.run(
            action(#"out="$(fw_out "$DIR/$NAME.jpg")"; echo "Warning: $INPUT not a valid file - skipping""#), on: file)
        XCTAssertEqual(skipped.exitCode, 0)
        XCTAssertFalse(skipped.succeeded)
        XCTAssertEqual(URL(fileURLWithPath: skipped.missingOutput ?? "").lastPathComponent, "a.jpg")
        let text = skipped.explanation(for: file)
        XCTAssertTrue(text.contains("Nothing was written to a.jpg"), text)
        XCTAssertTrue(text.contains("not a valid file"), text)
        XCTAssertTrue(text.contains("Files & Folders"), text)

        let wrote = await ActionRunner.run(action(#"echo data > "$(fw_out "$DIR/$NAME.jpg")""#), on: file)
        XCTAssertTrue(wrote.succeeded)
        XCTAssertNil(wrote.missingOutput)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("a.jpg").path))

        let clipboardLike = await ActionRunner.run(action("true"), on: file)
        XCTAssertTrue(clipboardLike.succeeded, "actions that never call fw_out are not checked")
    }

    func testLangDefaultsToUTF8ForChildren() {
        let file = URL(fileURLWithPath: "/tmp/Ảnh.png")
        XCTAssertEqual(ActionRunner.environment(for: file, inherited: [:])["LANG"], "en_US.UTF-8")
        XCTAssertEqual(ActionRunner.environment(for: file, inherited: ["LANG": "vi_VN.UTF-8"])["LANG"], "vi_VN.UTF-8")
        XCTAssertEqual(ActionRunner.environment(for: file, inherited: [:])["NAME"], "Ảnh")
    }

    func testFailedCommandLeavesNoHalfWrittenOutput() async throws {
        let dir = try scratch()
        let file = dir.appendingPathComponent("a.png")
        let result = await ActionRunner.run(
            action(#"echo partial > "$(fw_out "$DIR/$NAME.webp")"; echo "boom: Invalid data found" >&2; exit 69"#), on: file)
        XCTAssertFalse(result.succeeded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("a.webp").path))
        XCTAssertEqual(result.explanation(for: file), "boom: Invalid data found")
        let banner = ActionResult(exitCode: 1, stderr: "ffmpeg version 7\n  built with clang\n  configuration: x\nbroken.png: Invalid data found\n", timedOut: false)
        XCTAssertTrue(banner.explanation(for: file).hasSuffix("broken.png: Invalid data found"))
    }

    func testFwOutHandlesNamesWithoutExtensionAndDotsInFolders() async throws {
        let dir = try scratch().appendingPathComponent("v1.2 build")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("archive"), withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("archive.zip")
        let result = await ActionRunner.run(action(#"fw_out "$DIR/$NAME" >&2"#), on: file)
        XCTAssertEqual(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines), dir.path + "/archive 2")
    }

    func testAFolderOutputOnlyHasToExist() async throws {
        let dir = try scratch()
        let file = dir.appendingPathComponent("pack.zip")
        let made = await ActionRunner.run(action(#"mkdir "$(fw_out "$DIR/$NAME")""#), on: file)
        XCTAssertTrue(made.succeeded)
        let skipped = await ActionRunner.run(action(#"fw_out "$DIR/$NAME" >/dev/null"#), on: file)
        XCTAssertFalse(skipped.succeeded, "a folder that was never created is still a missing output")
    }
}

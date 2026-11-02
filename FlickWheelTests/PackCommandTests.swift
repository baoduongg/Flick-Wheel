import XCTest

// runs the shell commands of the bundled packs that touch only files (no clipboard, no dialogs)
final class PackCommandTests: XCTestCase {
    private func action(_ id: String) throws -> WheelAction {
        let packs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FlickWheel/Resources/Packs")
        for file in try FileManager.default.contentsOfDirectory(at: packs, includingPropertiesForKeys: nil) {
            let pack = ActionRegistry.parsePack(try Data(contentsOf: file), id: "t", bundled: true).pack
            if let found = pack?.actions.first(where: { $0.id == id }) { return found }
        }
        throw XCTSkip("no action \(id)")
    }

    private func scratch() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func shell(_ args: [String], in dir: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        p.currentDirectoryURL = dir
        p.environment = ["PATH": "/opt/homebrew/bin:/usr/bin:/bin"]
        try p.run()
        p.waitUntilExit()
    }

    func testEveryPackActionHasADescriptionAndMultiOnesAreMarked() throws {
        let packs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FlickWheel/Resources/Packs")
        var ids = Set<String>()
        for file in try FileManager.default.contentsOfDirectory(at: packs, includingPropertiesForKeys: nil) {
            let parsed = ActionRegistry.parsePack(try Data(contentsOf: file), id: file.lastPathComponent, bundled: true)
            XCTAssertTrue(parsed.problems.isEmpty, "\(file.lastPathComponent): \(parsed.problems)")
            for a in parsed.pack?.actions ?? [] {
                XCTAssertFalse(a.description?.isEmpty ?? true, a.id)
                XCTAssertTrue(ids.insert(a.id).inserted, "\(a.id) is in two packs")
                if a.command.contains("$INPUTS") { XCTAssertEqual(a.multi, true, "\(a.id) reads INPUTS but is not multi") }
            }
        }
        XCTAssertTrue(ids.isSuperset(of: ["img-diff", "vid-target", "vid-timecode", "file-report", "unzip", "img-qr", "copy-llm", "verify-sha"]))
    }

    func testPermalinkAndRepoPageDropCredentialsFromTheRemote() throws {
        for id in ["git-permalink", "repo-page"] {
            let command = try action(id).command
            let expression = try XCTUnwrap(command.range(of: #"sed -E '[^']*'"#, options: .regularExpression).map { String(command[$0]) }, id)
            let cases = [
                ("https://user:tok@github.com/a/b.git", "https://github.com/a/b"),
                ("git@github.com:a/b.git", "https://github.com/a/b"),
                ("ssh://git@host/a/b.git", "https://host/a/b"),
                ("https://github.com/a/b", "https://github.com/a/b"),
            ]
            for (remote, want) in cases {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = ["-c", "printf '%s' \"$REMOTE\" | " + expression]
                p.environment = ["REMOTE": remote]
                let out = Pipe()
                p.standardOutput = out
                try p.run()
                p.waitUntilExit()
                XCTAssertEqual(String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self), want, "\(id): \(remote)")
            }
        }
    }

    func testUnzipExtractsIntoAFreeFolder() async throws {
        let dir = try scratch()
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("src/inner"), withIntermediateDirectories: true)
        try Data("hi".utf8).write(to: dir.appendingPathComponent("src/inner/a.txt"))
        try shell(["zip", "-q", "-r", "pack.zip", "src"], in: dir)
        let zip = dir.appendingPathComponent("pack.zip")
        let first = await ActionRunner.run(try action("unzip"), on: zip)
        XCTAssertTrue(first.succeeded, first.stderr)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("pack/src/inner/a.txt").path))
        let second = await ActionRunner.run(try action("unzip"), on: zip)
        XCTAssertTrue(second.succeeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("pack 2/src/inner/a.txt").path), "never merges into an existing folder")
    }

    func testCSVToJSONNeverOverwritesAnExistingJSON() async throws {
        let dir = try scratch()
        let csv = dir.appendingPathComponent("data.csv")
        try Data("x,y\n1,\"a, b\"\n".utf8).write(to: csv)
        try Data("keep me".utf8).write(to: dir.appendingPathComponent("data.json"))
        let run = await ActionRunner.run(try action("csv-json"), on: csv)
        XCTAssertTrue(run.succeeded, run.stderr)
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("data.json")), "keep me")
        XCTAssertTrue(try String(contentsOf: dir.appendingPathComponent("data 2.json")).contains("\"y\": \"a, b\""))
    }

    func testJSONFormatMinifyAndNoLeftoverOnInvalidInput() async throws {
        let dir = try scratch()
        let file = dir.appendingPathComponent("data.json")
        try Data(#"{"b": 2, "a": [1, {"c": null}], "é": "x"}"#.utf8).write(to: file)
        let pretty = await ActionRunner.run(try action("json-format"), on: file)
        XCTAssertTrue(pretty.succeeded, pretty.stderr)
        XCTAssertTrue(try String(contentsOf: dir.appendingPathComponent("data.pretty.json")).contains("\n  \"b\": 2"))
        let mini = await ActionRunner.run(try action("json-minify"), on: file)
        XCTAssertTrue(mini.succeeded, mini.stderr)
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("data.min.json")).trimmingCharacters(in: .newlines),
                       #"{"b":2,"a":[1,{"c":null}],"é":"x"}"#)

        let bad = dir.appendingPathComponent("broken.json")
        try Data("{nope".utf8).write(to: bad)
        let failed = await ActionRunner.run(try action("json-format"), on: bad)
        XCTAssertFalse(failed.succeeded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("broken.pretty.json").path))
    }

    func testTimecodeAndTargetSizeEncodeWithFFmpeg() async throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/ffmpeg"))
        let dir = try scratch()
        // noise does not compress, so the clip is well over the 2 MB target below
        try shell(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "nullsrc=size=320x180:rate=30:duration=2,geq=random(1)*255:128:128",
                   "-c:v", "mpeg4", "-q:v", "2", "-pix_fmt", "yuv420p", "clip.mp4"], in: dir)
        try shell(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=321x181:rate=30:duration=2",
                   "-c:v", "mpeg4", "-pix_fmt", "yuv420p", "tiny.mp4"], in: dir)
        let clip = dir.appendingPathComponent("clip.mp4")
        let stamped = await ActionRunner.run(try action("vid-timecode"), on: clip)
        XCTAssertTrue(stamped.succeeded, stamped.explanation(for: clip))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("clip-timecode.mp4").path))

        // vid-target asks for the size in a dialog; run its encoding part with the answer filled in
        let command = try action("vid-target").command
        let encoding = try XCTUnwrap(command.components(separatedBy: "r=${r// /}; ").last)
        var probe = WheelAction(id: "t", label: "t", wheel: .shift, accepts: ["*"], command: "r=2; " + encoding)
        probe.timeout = 120
        let small = await ActionRunner.run(probe, on: clip)
        XCTAssertTrue(small.succeeded, small.explanation(for: clip))
        let size = try dir.appendingPathComponent("clip-2mb.mp4").resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        XCTAssertGreaterThan(size, 0)
        XCTAssertLessThan(size, 2_500_000, "noise makes x264 overshoot its bitrate a little; the 4 MB source must still shrink to about the target")

        // a clip already under the target is left alone instead of being re-encoded bigger
        let tiny = await ActionRunner.run(probe, on: dir.appendingPathComponent("tiny.mp4"))
        XCTAssertFalse(tiny.succeeded)
        XCTAssertTrue(tiny.stderr.contains("Already under 2 MB"), tiny.stderr)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("tiny-2mb.mp4").path))
    }

    func testFreshInstallStopsBeforeDeletingWhenThereIsNoLockfile() async throws {
        let dir = try scratch()
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: dir.appendingPathComponent("package.json"))
        let run = await ActionRunner.run(try action("fresh-install"), on: dir)
        XCTAssertFalse(run.succeeded)
        XCTAssertTrue(run.stderr.contains("no lockfile"), run.stderr)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("node_modules").path))
    }
}

import XCTest

final class CloneModelTests: XCTestCase {
    func testRepoNameFromHttpsAndSshURLs() {
        XCTAssertEqual(CloneModel.repoName(from: "https://github.com/octocat/Hello-World.git"), "Hello-World")
        XCTAssertEqual(CloneModel.repoName(from: "git@github.com:octocat/Hello-World.git"), "Hello-World")
        XCTAssertEqual(CloneModel.repoName(from: "ssh://git@host.io/team/app/"), "app")
        XCTAssertEqual(CloneModel.repoName(from: "  https://x.io/a/b  "), "b")
    }

    func testOnlyWebAndSshURLsPass() {
        for ok in ["https://github.com/a/b.git", "http://h/a/b", "ssh://git@h/a/b.git", "git@github.com:a/b.git"] {
            XCTAssertNil(CloneModel.urlProblem(ok), ok)
        }
        for bad in ["", "ext::sh -c id", "file:///tmp/x", "/tmp/x", "--upload-pack=x", "https://github.com", "git@github.com"] {
            XCTAssertNotNil(CloneModel.urlProblem(bad), bad)
        }
    }

    func testLogRewritesProgressLinesAndKeepsFinishedOnes() {
        var log = CloneLog()
        log.feed("Cloning into 'x'...\nReceiving objects:  10%\rReceiving objects:  50%\r")
        XCTAssertEqual(log.text, "Cloning into 'x'...\nReceiving objects:  50%")
        log.feed("Receiving objects: 100%, done.\r\nResolving")
        XCTAssertEqual(log.text, "Cloning into 'x'...\nReceiving objects: 100%, done.\nResolving")
    }

    @MainActor
    func testFormRefusesAnExistingFolderAndBadNames() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("repo"), withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let model = CloneModel(parent: dir)
        model.url = "https://h.io/o/repo.git"
        XCTAssertNotNil(model.problem, "repo already exists")
        XCTAssertFalse(model.canStart)
        model.customName = "fresh"
        XCTAssertNil(model.problem)
        XCTAssertTrue(model.canStart)
        model.customName = "../x"
        XCTAssertNotNil(model.problem)
    }

    func testDirTokenMatchesPlainFoldersOnly() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let package = dir.appendingPathComponent("Thing.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        func action(_ accepts: [String]) -> WheelAction {
            WheelAction(id: "a", label: "A", wheel: .command, accepts: accepts, command: "x")
        }
        XCTAssertTrue(action(["dir"]).accepts(file: dir))
        XCTAssertFalse(action(["dir"]).accepts(file: dir.appendingPathComponent("f.txt")))
        XCTAssertTrue(action(["*"]).accepts(file: dir), "* still matches folders")
        XCTAssertFalse(action(["*", "!dir"]).accepts(file: dir))
        XCTAssertFalse(action(["dir"]).accepts(file: package), ".app is a package, not a folder")
    }
}

final class LinesCounterTests: XCTestCase {
    func testCountsNewlinesPerLanguageAndSkipsGeneratedFolders() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        for sub in ["src", "node_modules/x"] {
            try FileManager.default.createDirectory(at: dir.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        try Data("a\nb\nc\n".utf8).write(to: dir.appendingPathComponent("src/a.swift"))
        try Data("a\nb\n".utf8).write(to: dir.appendingPathComponent("src/b.swift"))
        try Data("x\n".utf8).write(to: dir.appendingPathComponent("src/c.ts"))
        try Data("1\n2\n3\n".utf8).write(to: dir.appendingPathComponent("node_modules/x/z.js"))
        try Data("1\n".utf8).write(to: dir.appendingPathComponent("src/app.min.js"))
        try Data("{}\n".utf8).write(to: dir.appendingPathComponent("package-lock.json"))
        let stats = LinesCounter.count(in: dir)
        XCTAssertEqual(stats, [LanguageStat(name: "Swift", lines: 5, files: 2), LanguageStat(name: "TypeScript", lines: 1, files: 1)])
        XCTAssertTrue(LinesCounter.text(stats).hasSuffix("6 lines      3 files"))
    }
}

final class TranslateSupportTests: XCTestCase {
    func testChunksRejoinToTheOriginalAndKeepFencesWhole() {
        let fence = "```swift\n" + String(repeating: "let a = 1\n\nlet b = 2\n", count: 5) + "```\n"
        let text = "# Title\n\n" + String(repeating: "A paragraph of words.\n\n", count: 80) + fence + "tail"
        for limit in [50, 300, 6000] {
            let chunks = TranslateChunker.split(text, limit: limit)
            XCTAssertEqual(chunks.joined(), text, "limit \(limit)")
        }
        let chunks = TranslateChunker.split(text, limit: 300)
        let fenceChunk = chunks.first { $0.contains("```swift") }!
        XCTAssertEqual(fenceChunk.components(separatedBy: "```").count - 1, 2, "a short fence stays in one chunk with its closing line")
        XCTAssertEqual(TranslateChunker.split(""), [])
    }

    func testEdgesAndOutputNeverOverwrite() throws {
        XCTAssertEqual(TranslateChunker.restoreEdges(of: "\n\nHello\n", in: "Xin chào"), "\n\nXin chào\n")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("notes.md")
        XCTAssertEqual(TranslateChunker.outputURL(for: source, code: "vi").lastPathComponent, "notes.vi.md")
        try Data("x".utf8).write(to: dir.appendingPathComponent("notes.vi.md"))
        XCTAssertEqual(TranslateChunker.outputURL(for: source, code: "vi").lastPathComponent, "notes.vi 2.md")
        XCTAssertEqual(TranslateLanguage.typed(" Tagalog ")?.code, "tagalog")
        XCTAssertNil(TranslateLanguage.typed("  "))
    }

    func testGeminiRequestAndResponseHandling() throws {
        let client = GeminiClient(apiKey: "K", model: "models/gemini-x.1")
        let request = try XCTUnwrap(client.translateRequest(system: "s", text: "t"))
        XCTAssertEqual(request.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/models/gemini-x.1:generateContent")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "K")
        XCTAssertFalse(request.url!.absoluteString.contains("K"), "the key never goes in the URL")
        XCTAssertNil(GeminiClient(apiKey: "K", model: "a/b?x=1").translateRequest(system: "s", text: "t"))

        func json(_ text: String) -> Data { Data(text.utf8) }
        XCTAssertEqual(try GeminiClient.parse(json(#"{"candidates":[{"content":{"parts":[{"text":"Xin "},{"text":"chào"}]},"finishReason":"STOP"}]}"#)), "Xin chào")
        XCTAssertThrowsError(try GeminiClient.parse(json(#"{"candidates":[{"content":{"parts":[{"text":"cut"}]},"finishReason":"MAX_TOKENS"}]}"#)))
        XCTAssertThrowsError(try GeminiClient.parse(json(#"{"promptFeedback":{"blockReason":"SAFETY"}}"#)))
        XCTAssertThrowsError(try GeminiClient.parse(json(#"{"candidates":[]}"#)))
        XCTAssertEqual(GeminiClient.errorMessage(in: json(#"{"error":{"code":429,"message":"Quota exceeded"}}"#)), "Quota exceeded")
    }

    func testModelListParsingAndPickingTheDefault() {
        let page = Data(#"""
        {"models":[
          {"name":"models/gemini-2.5-flash","supportedGenerationMethods":["generateContent"]},
          {"name":"models/gemini-3-flash-preview","supportedGenerationMethods":["generateContent"]},
          {"name":"models/gemini-3.5-flash","supportedGenerationMethods":["generateContent"]},
          {"name":"models/gemini-3.5-flash-lite","supportedGenerationMethods":["generateContent"]},
          {"name":"models/gemini-3.5-flash-image","supportedGenerationMethods":["generateContent"]},
          {"name":"models/text-embedding-004","supportedGenerationMethods":["embedContent"]}],
         "nextPageToken":"abc"}
        """#.utf8)
        let parsed = GeminiClient.parseModels(page)
        XCTAssertEqual(parsed.next, "abc")
        XCTAssertFalse(parsed.names.contains("text-embedding-004"))
        XCTAssertEqual(GeminiClient.pickDefault(parsed.names), "gemini-3.5-flash")
        XCTAssertEqual(GeminiClient.pickDefault(parsed.names + ["gemini-flash-latest"]), "gemini-flash-latest")
        XCTAssertEqual(GeminiClient.textModels(parsed.names).first, "gemini-3.5-flash")
        XCTAssertFalse(GeminiClient.textModels(parsed.names).contains("gemini-3.5-flash-image"))
        XCTAssertNil(GeminiClient.pickDefault(["gemini-embedding-001", "other"]))
    }
}

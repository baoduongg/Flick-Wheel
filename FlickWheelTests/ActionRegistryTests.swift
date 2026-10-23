import XCTest

@MainActor
final class ActionRegistryTests: XCTestCase {
    private func makeRegistry(json: String? = nil, packDirs: [URL] = []) throws -> ActionRegistry {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("actions.json")
        if let json { try Data(json.utf8).write(to: url) }
        let suite = "flickwheel.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return ActionRegistry(url: url, defaults: defaults, packDirs: packDirs)
    }

    func testWheelCapsAtEightActions() throws {
        let entries = (1...10).map {
            #"{"id":"a\#($0)","label":"A","wheel":"shift","accepts":["*"],"command":"x"}"#
        }.joined(separator: ",")
        let registry = try makeRegistry(json: "[\(entries)]")
        registry.load()
        XCTAssertEqual(registry.actions(for: .shift, files: [URL(fileURLWithPath: "/tmp/a.png")]).map(\.id),
                       (1...8).map { "a\($0)" })
    }

    func testHidingAnActionBringsTheNextOneOntoTheWheel() throws {
        let entries = (1...10).map {
            #"{"id":"a\#($0)","label":"A","wheel":"shift","accepts":["*"],"command":"x"}"#
        }.joined(separator: ",")
        let registry = try makeRegistry(json: "[\(entries)]")
        registry.load()
        let png = [URL(fileURLWithPath: "/tmp/a.png")]
        XCTAssertEqual(registry.usableActions(for: .shift, files: png).count, 10)
        registry.setHidden("a1", true)
        XCTAssertEqual(registry.actions(for: .shift, files: png).map(\.id), (2...9).map { "a\($0)" })
        // turning actions back on is never refused, even past eight: the wheel just shows the first eight
        for id in ["a1"] { registry.setHidden(id, false) }
        XCTAssertFalse(registry.hidden.contains("a1"))
        XCTAssertEqual(registry.actions(for: .shift, files: png).count, 8)
        XCTAssertEqual(registry.usableActions(for: .shift, files: png).count, 10)
    }

    func testOriginTellsBuiltInCustomAndPackActionsApart() throws {
        let dir = try packDir(["dev.json": #"{"title":"Developer","actions":[{"id":"p1","label":"P","wheel":"shift","accepts":["png"],"command":"x"}]}"#])
        let registry = try makeRegistry(json: """
        [{"id":"img-jpg","label":"JPG","wheel":"shift","accepts":["png"],"command":"x"},
         {"id":"mine","label":"M","wheel":"shift","accepts":["png"],"command":"x"}]
        """, packDirs: [dir])
        registry.load()
        registry.setPack("dev", enabled: true)
        let origins = Dictionary(uniqueKeysWithValues: registry.actions.map { ($0.id, registry.origin(of: $0)) })
        XCTAssertEqual(origins["img-jpg"], .builtIn)
        XCTAssertEqual(origins["mine"], .custom)
        XCTAssertEqual(origins["p1"], .pack("Developer"))
    }

    func testHiddenActionsAreFilteredAndPersisted() throws {
        let registry = try makeRegistry()
        registry.load()
        let png = URL(fileURLWithPath: "/tmp/a.png")
        registry.setHidden("airdrop", true)
        XCTAssertFalse(registry.actions(for: .control, files: [png]).map(\.id).contains("airdrop"))
        registry.load()
        XCTAssertFalse(registry.actions(for: .control, files: [png]).map(\.id).contains("airdrop"))
        registry.setHidden("airdrop", false)
        XCTAssertTrue(registry.actions(for: .control, files: [png]).map(\.id).contains("airdrop"))
    }

    func testExtensionFilteringWildcardAndCaseInsensitivity() throws {
        let registry = try makeRegistry(json: """
        [
          {"id":"a","label":"A","wheel":"shift","accepts":["png"],"command":"x"},
          {"id":"b","label":"B","wheel":"shift","accepts":["JPG"],"command":"x"},
          {"id":"c","label":"C","wheel":"shift","accepts":["*"],"command":"x"}
        ]
        """)
        XCTAssertTrue(registry.load().isEmpty)
        let png = URL(fileURLWithPath: "/tmp/PHOTO.PNG")
        let jpg = URL(fileURLWithPath: "/tmp/photo.jpg")
        let txt = URL(fileURLWithPath: "/tmp/notes.txt")
        XCTAssertEqual(registry.actions(for: .shift, files: [png]).map(\.id), ["a", "c"])
        XCTAssertEqual(registry.actions(for: .shift, files: [jpg]).map(\.id), ["b", "c"])
        XCTAssertEqual(registry.actions(for: .shift, files: [txt]).map(\.id), ["c"])
        XCTAssertEqual(registry.actions(for: .shift, files: [png, jpg]).map(\.id), ["c"])
    }

    func testWheelFiltering() throws {
        let registry = try makeRegistry()
        registry.load()
        let png = URL(fileURLWithPath: "/tmp/a.png")
        let mp4 = URL(fileURLWithPath: "/tmp/a.mp4")
        XCTAssertEqual(registry.actions(for: .shift, files: [png]).map(\.id), ["img-jpg", "img-webp", "img-heic", "img-pdf"])
        XCTAssertEqual(registry.actions(for: .control, files: [png]).map(\.id),
                       ["airdrop", "reveal", "copy-file", "copy-image", "copy-path", "open-terminal", "zip", "checksum"])
        XCTAssertEqual(registry.actions(for: .command, files: [png]).map(\.id),
                       ["img-annotate", "crop", "img-addbg", "img-redact", "edit", "resize"])
        XCTAssertEqual(registry.actions(for: .command, files: [mp4]).map(\.id), ["crop", "edit", "compress"])
    }

    func testDefaultManifestFitsTheWheel() throws {
        let registry = try makeRegistry()
        registry.load()
        for kind in [WheelKind.shift, .command, .control] {
            XCTAssertLessThanOrEqual(registry.enabledCount(kind), ActionRegistry.maxPerWheel)
        }
    }

    func testInvalidEntriesAreSkippedAndReported() throws {
        let registry = try makeRegistry(json: """
        [
          {"id":"ok","label":"OK","wheel":"shift","accepts":["png"],"command":"x"},
          {"id":"bad-wheel","label":"B","wheel":"option","accepts":["png"],"command":"x"},
          {"id":"no-command","label":"B","wheel":"shift","accepts":["png"]},
          {"id":"blank","label":"B","wheel":"shift","accepts":["png"],"command":"  "},
          {"id":"ok","label":"Dup","wheel":"shift","accepts":["png"],"command":"x"},
          {"id":"no-ext","label":"B","wheel":"shift","accepts":[],"command":"x"},
          42
        ]
        """)
        let problems = registry.load()
        XCTAssertEqual(registry.actions.map(\.id), ["ok"])
        XCTAssertEqual(problems.count, 6)
    }

    func testMalformedJSONYieldsNoActions() throws {
        let registry = try makeRegistry(json: "{not json")
        XCTAssertEqual(registry.load().count, 1)
        XCTAssertTrue(registry.actions.isEmpty)
    }

    func testMissingManifestIsWrittenOnceAndNeverOverwritten() throws {
        let registry = try makeRegistry()
        XCTAssertTrue(registry.load().isEmpty)
        XCTAssertEqual(registry.actions.count, 24)
        XCTAssertEqual(try String(contentsOf: registry.url), ActionRegistry.defaultManifest)

        try Data("[]".utf8).write(to: registry.url)
        registry.load()
        XCTAssertTrue(registry.actions.isEmpty)
        XCTAssertEqual(try String(contentsOf: registry.url), "[]")
    }

    func testMultiActionsNeedExactlyTwoFilesAndLeadTheWheel() throws {
        let registry = try makeRegistry(json: """
        [
          {"id":"one","label":"One","wheel":"command","accepts":["png"],"command":"x"},
          {"id":"pair","label":"Pair","wheel":"command","accepts":["png"],"command":"x","multi":true}
        ]
        """)
        registry.load()
        let a = URL(fileURLWithPath: "/tmp/a.png"), b = URL(fileURLWithPath: "/tmp/b.png")
        XCTAssertEqual(registry.actions(for: .command, files: [a]).map(\.id), ["one"])
        XCTAssertEqual(registry.actions(for: .command, files: [a, b]).map(\.id), ["pair", "one"])
        XCTAssertEqual(registry.actions(for: .command, files: [a, b, a]).map(\.id), ["one"])
    }

    private func packDir(_ files: [String: String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        for (name, text) in files { try Data(text.utf8).write(to: dir.appendingPathComponent(name)) }
        return dir
    }

    func testPacksStayOffUntilEnabledAndActionsJsonWins() throws {
        let dir = try packDir(["dev.json": """
        {"title":"Developer","description":"d","actions":[
          {"id":"p1","label":"P1","wheel":"shift","accepts":["png"],"command":"x","description":"does p1"},
          {"id":"mine","label":"FromPack","wheel":"shift","accepts":["png"],"command":"x"}]}
        """])
        let registry = try makeRegistry(json: #"[{"id":"mine","label":"Mine","wheel":"shift","accepts":["png"],"command":"x"}]"#, packDirs: [dir])
        XCTAssertTrue(registry.load().isEmpty)
        XCTAssertEqual(registry.packs.map(\.id), ["dev"])
        XCTAssertEqual(registry.packs[0].title, "Developer")
        XCTAssertEqual(registry.actions.map(\.id), ["mine"])

        registry.setPack("dev", enabled: true)
        XCTAssertEqual(registry.actions.map(\.id), ["mine", "p1"])
        XCTAssertEqual(registry.actions.first { $0.id == "mine" }?.label, "Mine")
        XCTAssertEqual(registry.actions.last?.description, "does p1")

        registry.load()
        XCTAssertEqual(registry.actions.map(\.id), ["mine", "p1"], "enabled packs survive a reload")
        registry.setPack("dev", enabled: false)
        XCTAssertEqual(registry.actions.map(\.id), ["mine"])
    }

    func testPackFormatsUserPackOverridesAndProblems() throws {
        let bundled = try packDir(["tools.json": #"[{"id":"a","label":"A","wheel":"shift","accepts":["png"],"command":"x"}]"#])
        let user = try packDir([
            "tools.json": #"[{"id":"b","label":"B","wheel":"shift","accepts":["png"],"command":"x"}]"#,
            "broken.json": "{nope",
            "partial.json": #"{"actions":[{"id":"ok","label":"O","wheel":"shift","accepts":["png"],"command":"x"},{"id":"bad"}]}"#,
            "notes.txt": "ignored",
        ])
        let registry = try makeRegistry(packDirs: [bundled, user])
        let problems = registry.load()
        XCTAssertEqual(registry.packs.map(\.id), ["tools", "partial"])
        XCTAssertEqual(registry.packs[0].actions.map(\.id), ["b"], "the user pack replaces the bundled one")
        XCTAssertEqual(registry.packs[1].title, "partial")
        XCTAssertEqual(problems.count, 2)
        XCTAssertTrue(problems.contains { $0.hasPrefix("pack broken:") })
        XCTAssertTrue(problems.contains { $0.hasPrefix("pack partial:") })
    }

    func testBundledPacksParseAndFitTheirWheels() throws {
        let packs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FlickWheel/Resources/Packs")
        let registry = try makeRegistry(packDirs: [packs])
        XCTAssertTrue(registry.load().isEmpty)
        XCTAssertEqual(Set(registry.packs.map(\.id)), ["everyone", "dev", "qc", "video"])
        for pack in registry.packs {
            XCTAssertTrue(pack.actions.allSatisfy { $0.description?.isEmpty == false }, "\(pack.id) needs descriptions")
            XCTAssertTrue(pack.actions.allSatisfy { !$0.command.contains("npx -y @svgr/cli ") }, "pin npx versions")
        }
    }
}

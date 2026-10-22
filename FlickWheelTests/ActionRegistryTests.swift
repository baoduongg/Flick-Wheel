import XCTest

@MainActor
final class ActionRegistryTests: XCTestCase {
    private func makeRegistry(json: String? = nil) throws -> ActionRegistry {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("actions.json")
        if let json { try Data(json.utf8).write(to: url) }
        return ActionRegistry(url: url)
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
        XCTAssertEqual(registry.actions(for: .shift, files: [png]).map(\.id), ["img-webp", "img-jpg"])
        XCTAssertEqual(registry.actions(for: .control, files: [png]).map(\.id), ["airdrop", "copy-path", "copy-file", "open-terminal", "reveal"])
        XCTAssertEqual(registry.actions(for: .command, files: [png]).map(\.id),
                       ["img-edit", "img-annotate", "img-addbg", "img-crop", "img-redact"])
        XCTAssertEqual(registry.actions(for: .command, files: [URL(fileURLWithPath: "/tmp/a.mp4")]).map(\.id),
                       ["vid-compress", "vid-edit", "vid-crop"])
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
        XCTAssertEqual(registry.actions.count, 19)
        XCTAssertEqual(try String(contentsOf: registry.url), ActionRegistry.defaultManifest)

        try Data("[]".utf8).write(to: registry.url)
        registry.load()
        XCTAssertTrue(registry.actions.isEmpty)
        XCTAssertEqual(try String(contentsOf: registry.url), "[]")
    }
}

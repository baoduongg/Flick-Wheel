import XCTest

final class FileKindTests: XCTestCase {
    func testKindsFromAcceptedExtensions() {
        XCTAssertEqual(FileKind.kinds(for: ["PNG", "jpg", "heic"]), [.image])
        XCTAssertEqual(FileKind.kinds(for: ["mp4", "mov"]), [.video])
        XCTAssertEqual(FileKind.kinds(for: ["wav", "mp4", "mkv", "mp3"]), [.video, .audio])
        XCTAssertEqual(FileKind.kinds(for: ["png", "mp4"]), [.image, .video])
        XCTAssertEqual(FileKind.kinds(for: ["pdf"]), [.document])
        XCTAssertEqual(FileKind.kinds(for: ["app"]), [.code])
        XCTAssertEqual(FileKind.kinds(for: ["txt", "json", "ts"]), [.document, .code])
        XCTAssertEqual(FileKind.kinds(for: ["*", "png"]), [.any])
        // stray extensions do not add a kind: this is the MP4 converter, which also takes gif and ts
        XCTAssertEqual(FileKind.kinds(for: ["mov", "mkv", "avi", "webm", "m4v", "flv", "wmv", "ts", "gif"]), [.video])
    }

    func testEveryDefaultActionHasAKind() {
        for action in ActionRegistry.parse(Data(ActionRegistry.defaultManifest.utf8)).actions {
            XCTAssertFalse(FileKind.kinds(for: action.accepts).isEmpty, action.id)
        }
    }
}

import Foundation

enum WheelKind: String, Codable, Sendable {
    case shift
    case command
    case control
}

struct WheelAction: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let wheel: WheelKind
    // lowercase extensions or "*"; "!ext" rules a type out, e.g. ["*", "!png"] is everything except PNG;
    // "dir" is a plain folder (not an .app or other package), so "*" alone still matches folders too
    let accepts: [String]
    let command: String
    // optional SF Symbol name; ActionIcon falls back to a per-id default
    var icon: String? = nil
    // runs once for all dropped files (INPUT = first, INPUTS = all, newline-separated) and only offered for exactly two
    var multi: Bool? = nil
    // seconds before the command is killed; nil = ActionRunner's default (too short for video encodes)
    var timeout: Double? = nil
    // one line shown in Settings and under the wheel while the segment is hovered
    var description: String? = nil

    func accepts(file: URL) -> Bool {
        let ext = file.pathExtension.lowercased()
        let rules = accepts.map { $0.lowercased() }
        let folder = Self.isFolder(file)
        return !rules.contains("!" + ext) && !(folder && rules.contains("!dir"))
            && rules.contains { $0 == "*" || $0 == ext || ($0 == "dir" && folder) }
    }

    static func isFolder(_ file: URL) -> Bool {
        if file.hasDirectoryPath { return true }
        let values = try? file.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }
}

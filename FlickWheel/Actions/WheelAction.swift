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
        return accepts.contains { $0 == "*" || $0.lowercased() == ext }
    }
}

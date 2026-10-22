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

    func accepts(file: URL) -> Bool {
        let ext = file.pathExtension.lowercased()
        return accepts.contains { $0 == "*" || $0.lowercased() == ext }
    }
}

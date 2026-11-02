import Foundation

// the kinds of file an action works on, for the chips and filters in Settings
enum FileKind: String, CaseIterable, Identifiable, Sendable {
    case image, video, audio, document, code, folder, any

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .audio: return "Audio"
        case .document: return "Document"
        case .code: return "Code & apps"
        case .folder: return "Folder"
        case .any: return "Any file"
        }
    }

    // for crowded chips
    var shortTitle: String {
        switch self {
        case .document: return "Docs"
        case .code: return "Code"
        case .any: return "Any"
        default: return title
        }
    }

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .document: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .folder: return "folder"
        case .any: return "asterisk"
        }
    }

    static let extensions: [FileKind: Set<String>] = [
        .image: ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif", "webp", "svg"],
        .video: ["mp4", "mov", "m4v", "mkv", "webm", "avi", "flv", "wmv"],
        .audio: ["mp3", "wav", "m4a", "flac", "ogg", "aiff"],
        .folder: ["dir"],
        .code: ["json", "js", "ts", "tsx", "jsx", "html", "css", "xml", "yml", "yaml", "app", "apk", "ipa"],
    ]

    // "*" means any file. A kind counts when it covers at least a quarter of the accepted extensions, so one stray
    // "gif" in a list of video formats does not make a video converter an image action; an extension in none of
    // the lists counts as a document
    static func kinds(for accepts: [String]) -> [FileKind] {
        if accepts.contains("*") { return [.any] }
        let lowered = Set(accepts.map { $0.lowercased() })
        guard !lowered.isEmpty else { return [] }
        var counts: [FileKind: Int] = [:]
        for ext in lowered {
            counts[extensions.first { $0.value.contains(ext) }?.key ?? .document, default: 0] += 1
        }
        let big = allCases.filter { Double(counts[$0] ?? 0) / Double(lowered.count) >= 0.25 }
        return big.isEmpty ? allCases.filter { counts[$0] != nil } : big
    }
}

enum ActionOrigin: Equatable {
    case builtIn
    case custom
    case pack(String)

    var label: String {
        switch self {
        case .builtIn: return "Built in"
        case .custom: return "Custom"
        case .pack(let title): return title
        }
    }
}

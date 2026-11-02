import Foundation

struct TranslateLanguage: Identifiable, Hashable {
    let name: String
    // suffix of the output file: notes.md -> notes.vi.md
    let code: String
    var id: String { code }

    static let custom = TranslateLanguage(name: "Other…", code: "")

    static let common: [TranslateLanguage] = [
        ("Vietnamese", "vi"), ("English", "en"), ("Japanese", "ja"), ("Korean", "ko"), ("Chinese (Simplified)", "zh-CN"),
        ("Chinese (Traditional)", "zh-TW"), ("French", "fr"), ("German", "de"), ("Spanish", "es"), ("Portuguese", "pt"),
        ("Russian", "ru"), ("Thai", "th"), ("Indonesian", "id"),
    ].map { TranslateLanguage(name: $0.0, code: $0.1) }

    // a language typed by hand: the file suffix is the name reduced to letters, digits and "-"
    static func typed(_ name: String) -> TranslateLanguage? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = String(trimmed.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(12))
        return code.isEmpty ? nil : TranslateLanguage(name: trimmed, code: code)
    }
}

enum TranslateChunker {
    // pieces that join back to exactly `text`; cuts fall on a blank line outside a code fence, so a paragraph or a
    // fenced block is never split unless it alone is longer than the limit
    static func split(_ text: String, limit: Int = 6000) -> [String] {
        var chunks: [String] = []
        var current = ""
        var size = 0
        var inFence = false
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            let piece = index < lines.count - 1 ? line + "\n" : String(line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFence.toggle() }
            current += piece
            size += piece.count
            if (!inFence && (size >= limit || (trimmed.isEmpty && size >= limit / 2))) || size >= limit * 2 {
                chunks.append(current)
                current = ""
                size = 0
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    // the model tends to trim a chunk; put back the whitespace the original had at both ends
    static func restoreEdges(of original: String, in translated: String) -> String {
        let lead = String(original.prefix { $0.isWhitespace })
        let trail = String(original.reversed().prefix { $0.isWhitespace }.reversed())
        return lead + translated.trimmingCharacters(in: .whitespacesAndNewlines) + trail
    }

    // notes.md -> notes.vi.md, then "notes.vi 2.md"; never an existing file
    static func outputURL(for source: URL, code: String) -> URL {
        let directory = source.deletingLastPathComponent()
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension.isEmpty ? "" : "." + source.pathExtension
        var candidate = directory.appendingPathComponent("\(base).\(code)\(ext)")
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base).\(code) \(number)\(ext)")
            number += 1
        }
        return candidate
    }
}

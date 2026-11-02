import Combine
import Foundation

struct LanguageStat: Identifiable, Equatable {
    let name: String
    var lines: Int
    var files: Int
    var id: String { name }
}

// lines of code per language; like `wc -l`, a line is a newline byte
enum LinesCounter {
    static let languages: [String: String] = {
        let groups: [(String, [String])] = [
            ("Swift", ["swift"]), ("Obj-C", ["m", "mm"]), ("C", ["c", "h"]), ("C++", ["cc", "cpp", "cxx", "hpp"]),
            ("Rust", ["rs"]), ("Go", ["go"]), ("Java", ["java"]), ("Kotlin", ["kt", "kts"]),
            ("JavaScript", ["js", "jsx", "mjs", "cjs"]), ("TypeScript", ["ts", "tsx"]), ("Vue", ["vue"]),
            ("Svelte", ["svelte"]), ("Python", ["py"]), ("Ruby", ["rb"]), ("PHP", ["php"]), ("C#", ["cs"]),
            ("Dart", ["dart"]), ("Lua", ["lua"]), ("Shell", ["sh", "zsh", "bash"]), ("SQL", ["sql"]),
            ("HTML", ["html", "htm"]), ("CSS", ["css", "scss", "sass", "less"]),
        ]
        return Dictionary(groups.flatMap { name, exts in exts.map { ($0, name) } }, uniquingKeysWith: { first, _ in first })
    }()

    // generated or vendored folders; a git repo's .gitignore covers these already
    static let skippedFolders: Set<String> = [
        ".git", "node_modules", "Pods", ".build", "DerivedData", ".next", "dist", "build", "__pycache__", ".venv", "target", "vendor",
    ]

    static func language(of file: URL) -> String? {
        let name = file.lastPathComponent.lowercased()
        if name.hasSuffix(".lock") || name.hasSuffix(".map") || name.contains("lock.") || name.contains(".min.") { return nil }
        return languages[file.pathExtension.lowercased()]
    }

    static func count(in folder: URL) -> [LanguageStat] {
        var stats: [String: LanguageStat] = [:]
        for file in files(in: folder) {
            guard let language = language(of: file), let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { continue }
            let lines = data.withUnsafeBytes { $0.reduce(0) { $1 == 10 ? $0 + 1 : $0 } }
            stats[language, default: LanguageStat(name: language, lines: 0, files: 0)].lines += lines
            stats[language]?.files += 1
        }
        return stats.values.sorted { ($0.lines, $1.name) > ($1.lines, $0.name) }
    }

    // a git repo lists its own files (respecting .gitignore); anything else is walked
    static func files(in folder: URL) -> [URL] {
        if let listed = gitFiles(in: folder) { return listed }
        var found: [URL] = []
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: [.skipsPackageDescendants])
        while let url = walker?.nextObject() as? URL {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDirectory {
                if skippedFolders.contains(url.lastPathComponent) { walker?.skipDescendants() }
            } else {
                found.append(url)
            }
        }
        return found
    }

    private static func gitFiles(in folder: URL) -> [URL]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", folder.path, "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        // read before waiting: a big listing fills the pipe and would block git
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return data.split(separator: 0).compactMap { String(data: $0, encoding: .utf8) }
            .map { folder.appendingPathComponent($0) }
    }

    static func text(_ stats: [LanguageStat]) -> String {
        func row(_ name: String, _ lines: Int, _ files: Int) -> String {
            let pad = String(repeating: " ", count: max(0, 12 - name.count))
            return "\(name)\(pad) \(String(format: "%9d", lines)) lines \(String(format: "%6d", files)) files"
        }
        let rows = stats.map { row($0.name, $0.lines, $0.files) }
        return (rows + [row("Total", stats.reduce(0) { $0 + $1.lines }, stats.reduce(0) { $0 + $1.files })]).joined(separator: "\n")
    }
}

@MainActor
final class LinesModel: ObservableObject {
    let folder: URL
    @Published private(set) var stats: [LanguageStat] = []
    @Published private(set) var scanning = true

    init(folder: URL) {
        self.folder = folder
    }

    var totalLines: Int { stats.reduce(0) { $0 + $1.lines } }
    var totalFiles: Int { stats.reduce(0) { $0 + $1.files } }
    var text: String { LinesCounter.text(stats) }

    func scan() {
        scanning = true
        let folder = folder
        Task {
            let result = await Task.detached { LinesCounter.count(in: folder) }.value
            stats = result
            scanning = false
        }
    }
}

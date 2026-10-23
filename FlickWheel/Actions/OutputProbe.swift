import Foundation

// finds the file an action produced: whatever is new or touched in the input's folder after the run
enum OutputProbe {
    static func snapshot(_ dir: URL) -> [String: Date] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        var result: [String: Date] = [:]
        for url in urls {
            result[url.lastPathComponent] = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        }
        return result
    }

    static func newest(in dir: URL, since before: [String: Date], excluding input: URL) -> URL? {
        snapshot(dir)
            .filter { name, date in
                name != input.lastPathComponent && (before[name].map { date > $0 } ?? true)
            }
            .max { $0.value < $1.value }
            .map { dir.appendingPathComponent($0.key) }
    }
}

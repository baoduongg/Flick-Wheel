import Foundation

@MainActor
final class ActionRegistry {
    nonisolated static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/flickwheel/actions.json")

    static let defaultManifest = #"""
    [
      { "id": "img-webp", "label": "WebP 80%", "wheel": "shift", "accepts": ["png", "jpg", "jpeg", "heic"], "command": "ffmpeg -y -i \"$INPUT\" -c:v libwebp -quality 80 \"$DIR/$NAME.webp\"" },
      { "id": "img-png", "label": "PNG", "wheel": "shift", "accepts": ["jpg", "jpeg", "heic", "webp", "tiff"], "command": "sips -s format png \"$INPUT\" --out \"$DIR/$NAME.png\"" },
      { "id": "img-jpg", "label": "JPG", "wheel": "shift", "accepts": ["png", "heic", "webp", "tiff", "bmp"], "command": "sips -s format jpeg \"$INPUT\" --out \"$DIR/$NAME.jpg\"" },
      { "id": "vid-gif", "label": "GIF", "wheel": "shift", "accepts": ["mp4", "mov", "mkv", "webm"], "command": "ffmpeg -y -i \"$INPUT\" -vf \"fps=12,scale=480:-1:flags=lanczos\" \"$DIR/$NAME.gif\"" },
      { "id": "to-mp3", "label": "MP3", "wheel": "shift", "accepts": ["mp4", "mov", "mkv", "webm", "wav", "m4a", "flac", "ogg", "aiff"], "command": "ffmpeg -y -i \"$INPUT\" -vn -q:a 2 \"$DIR/$NAME.mp3\"" },
      { "id": "img-compress-jpg", "label": "Compress", "wheel": "command", "accepts": ["jpg", "jpeg"], "command": "sips -s format jpeg -s formatOptions 60 \"$INPUT\" --out \"$DIR/$NAME-small.${INPUT##*.}\"" },
      { "id": "vid-compress", "label": "Compress", "wheel": "command", "accepts": ["mp4", "mov", "mkv"], "command": "ffmpeg -y -i \"$INPUT\" -c:v libx264 -crf 26 -preset medium -c:a aac -b:a 128k -movflags +faststart \"$DIR/$NAME-small.mp4\"" },
      { "id": "img-edit", "label": "Edit", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif", "webp", "pdf"], "command": "open -a Preview \"$INPUT\"" },
      { "id": "vid-edit", "label": "Edit", "wheel": "command", "accepts": ["mp4", "mov", "m4v"], "command": "open -a \"QuickTime Player\" \"$INPUT\"" },
      { "id": "img-annotate", "label": "Annotate", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "command": "open \"flickwheel://annotate?path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=\"\"))' \"$INPUT\")\"" },
      { "id": "img-addbg", "label": "Add BG", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "command": "open \"flickwheel://background?path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=\"\"))' \"$INPUT\")\"" },
      { "id": "img-crop", "label": "Crop", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "command": "open \"flickwheel://crop?path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=\"\"))' \"$INPUT\")\"" },
      { "id": "vid-crop", "label": "Crop", "wheel": "command", "accepts": ["mp4", "mov", "mkv", "webm"], "command": "s=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 \"$INPUT\"); w=${s%%x*}; h=${s##*x}; r=$(SIZE=\"$s\" osascript -e 'text returned of (display dialog \"Crop size (W x H)\" default answer (system attribute \"SIZE\") buttons {\"Cancel\",\"Crop\"} default button \"Crop\" with title \"FlickWheel\")') || { echo Cancelled >&2; exit 1; }; r=${r:l}; r=${r// /}; cw=${r%%x*}; ch=${r##*x}; [[ $cw =~ ^[0-9]+$ && $ch =~ ^[0-9]+$ ]] || { echo 'Use WxH, e.g. 1080x1080' >&2; exit 1; }; cw=$((cw<w?cw:w)); ch=$((ch<h?ch:h)); cw=$((cw/2*2)); ch=$((ch/2*2)); ffmpeg -y -i \"$INPUT\" -vf \"crop=$cw:$ch\" -c:a copy \"$DIR/$NAME-crop.mp4\"" },
      { "id": "img-redact", "label": "Redact", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "command": "open \"flickwheel://annotate?tool=redact&path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=\"\"))' \"$INPUT\")\"" },
      { "id": "airdrop", "label": "AirDrop", "wheel": "control", "accepts": ["*"], "command": "open \"flickwheel://airdrop?path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=\"\"))' \"$INPUT\")\"" },
      { "id": "copy-path", "label": "Copy path", "wheel": "control", "accepts": ["*"], "command": "printf '%s' \"$INPUT\" | pbcopy" },
      { "id": "copy-file", "label": "Copy file", "wheel": "control", "accepts": ["*"], "command": "osascript -e 'set the clipboard to (POSIX file (system attribute \"INPUT\"))'" },
      { "id": "open-terminal", "label": "Terminal", "wheel": "control", "accepts": ["*"], "command": "if [ -d \"$INPUT\" ]; then open -a Terminal \"$INPUT\"; else open -a Terminal \"$DIR\"; fi" },
      { "id": "reveal", "label": "Reveal", "wheel": "control", "accepts": ["*"], "command": "open -R \"$INPUT\"" }
    ]
    """#

    let url: URL
    private(set) var actions: [WheelAction] = []

    init(url: URL = ActionRegistry.defaultURL) {
        self.url = url
    }

    @discardableResult
    func load() -> [String] {
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(Self.defaultManifest.utf8).write(to: url, options: .withoutOverwriting)
            }
            let parsed = Self.parse(try Data(contentsOf: url))
            actions = parsed.actions
            return parsed.problems
        } catch {
            actions = []
            return ["Cannot read \(url.path): \(error.localizedDescription)"]
        }
    }

    func actions(for wheel: WheelKind, files: [URL]) -> [WheelAction] {
        actions.filter { $0.wheel == wheel && files.allSatisfy($0.accepts(file:)) }
    }

    nonisolated static func parse(_ data: Data) -> (actions: [WheelAction], problems: [String]) {
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return ([], ["actions.json is not a valid JSON array"])
        }
        var valid: [WheelAction] = []
        var problems: [String] = []
        var seen = Set<String>()
        for (index, entry) in entries.enumerated() {
            let position = "entry \(index + 1)"
            guard let action = entry.action else {
                problems.append("\(position): missing field or unknown wheel")
                continue
            }
            if [action.id, action.label, action.command].contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
                || action.accepts.isEmpty {
                problems.append("\(position) (\(action.id)): empty id, label, command or accepts")
            } else if !seen.insert(action.id).inserted {
                problems.append("\(position) (\(action.id)): duplicate id")
            } else {
                valid.append(action)
            }
        }
        return (valid, problems)
    }

    private struct Entry: Decodable {
        let action: WheelAction?

        init(from decoder: Decoder) throws {
            action = try? WheelAction(from: decoder)
        }
    }
}

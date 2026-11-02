import Combine
import Foundation

@MainActor
final class ActionRegistry: ObservableObject {
    nonisolated static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/flickwheel/actions.json")
    // packs the app ships, then the user's own; a user pack with the same id replaces the bundled one
    nonisolated static let userPacksURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/flickwheel/packs")
    nonisolated static var defaultPackDirs: [URL] {
        [Bundle.main.resourceURL?.appendingPathComponent("Packs"), userPacksURL].compactMap { $0 }
    }

    nonisolated static let defaultManifest = #"""
    [
      {"id": "img-jpg", "label": "JPG", "wheel": "shift", "accepts": ["png", "heic", "webp", "tiff", "bmp"], "description": "Convert to JPG", "command": "sips -s format jpeg \"$INPUT\" --out \"$(fw_out \"$DIR/$NAME.jpg\")\""},
      {"id": "img-png", "label": "PNG", "wheel": "shift", "accepts": ["jpg", "jpeg", "heic", "webp", "tiff"], "description": "Convert to PNG", "command": "sips -s format png \"$INPUT\" --out \"$(fw_out \"$DIR/$NAME.png\")\""},
      {"id": "img-webp", "label": "WebP 80%", "wheel": "shift", "accepts": ["png", "jpg", "jpeg", "heic"], "description": "Convert to WebP (quality 80)", "command": "ffmpeg -hide_banner -loglevel error -y -i \"$INPUT\" -c:v libwebp -quality 80 \"$(fw_out \"$DIR/$NAME.webp\")\""},
      {"id": "img-heic", "label": "HEIC", "wheel": "shift", "accepts": ["png", "jpg", "jpeg", "tiff", "bmp"], "description": "Convert to HEIC", "command": "sips -s format heic \"$INPUT\" --out \"$(fw_out \"$DIR/$NAME.heic\")\""},
      {"id": "img-pdf", "label": "PDF", "wheel": "shift", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "description": "Wrap the image in a PDF", "command": "sips -s format pdf \"$INPUT\" --out \"$(fw_out \"$DIR/$NAME.pdf\")\""},
      {"id": "vid-gif", "label": "GIF", "wheel": "shift", "accepts": ["mp4", "mov", "m4v", "mkv", "webm", "avi"], "timeout": 1800, "description": "Make a GIF (15 fps, up to 720 px wide)", "command": "ffmpeg -hide_banner -loglevel error -y -i \"$INPUT\" -vf \"fps=15,scale='min(720,iw)':-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle\" \"$(fw_out \"$DIR/$NAME.gif\")\""},
      {"id": "to-mp3", "label": "MP3", "wheel": "shift", "accepts": ["mp4", "mov", "m4v", "mkv", "webm", "avi", "wav", "m4a", "flac", "ogg", "aiff"], "timeout": 1800, "description": "Extract or convert audio to MP3", "command": "ffmpeg -hide_banner -loglevel error -y -i \"$INPUT\" -vn -map_metadata 0 -c:a libmp3lame -q:a 2 \"$(fw_out \"$DIR/$NAME.mp3\")\""},
      {"id": "to-m4a", "label": "M4A", "wheel": "shift", "accepts": ["mp4", "mov", "m4v", "wav", "aiff", "mp3"], "description": "Extract or convert audio to M4A", "command": "case \"${INPUT:e:l}\" in mp4|mov|m4v) avconvert --preset PresetAppleM4A --source \"$INPUT\" --output \"$(fw_out \"$DIR/$NAME.m4a\")\" --replace;; *) afconvert -f m4af -d aac \"$INPUT\" \"$(fw_out \"$DIR/$NAME.m4a\")\";; esac"},
      {"id": "img-annotate", "label": "Annotate", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "description": "Draw arrows, text and marks on the image", "command": "open \"flickwheel://annotate?path=$(perl -e 'print join q(), map { /[A-Za-z0-9_.~-]/ ? $_ : sprintf(q(%%%02X), ord) } split //, shift' \"$INPUT\")\""},
      {"id": "crop", "label": "Crop", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "mp4", "mov", "m4v", "mkv", "webm"], "timeout": 7200, "description": "Crop an image or video", "command": "case \"${INPUT:e:l}\" in mp4|mov|m4v) open \"flickwheel://video?mode=crop&path=$(perl -e 'print join q(), map { /[A-Za-z0-9_.~-]/ ? $_ : sprintf(q(%%%02X), ord) } split //, shift' \"$INPUT\")\";; mkv|webm) s=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 \"$INPUT\"); w=${s%%x*}; h=${s##*x}; r=$(SIZE=\"$s\" osascript -e 'text returned of (display dialog \"Crop size (W x H)\" default answer (system attribute \"SIZE\") buttons {\"Cancel\",\"Crop\"} default button \"Crop\" with title \"FlickWheel\")') || { echo Cancelled >&2; exit 1; }; r=${r:l}; r=${r// /}; cw=${r%%x*}; ch=${r##*x}; [[ $cw =~ ^[0-9]+$ && $ch =~ ^[0-9]+$ ]] || { echo 'Use WxH, e.g. 1080x1080' >&2; exit 1; }; cw=$((cw<w?cw:w)); ch=$((ch<h?ch:h)); cw=$((cw/2*2)); ch=$((ch/2*2)); ffmpeg -hide_banner -loglevel error -y -i \"$INPUT\" -vf \"crop=$cw:$ch\" -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart \"$(fw_out \"$DIR/$NAME-crop.mp4\")\";; *) open \"flickwheel://crop?path=$(perl -e 'print join q(), map { /[A-Za-z0-9_.~-]/ ? $_ : sprintf(q(%%%02X), ord) } split //, shift' \"$INPUT\")\";; esac"},
      {"id": "img-addbg", "label": "Add BG", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "description": "Put the image on a gradient or solid backdrop", "command": "open \"flickwheel://background?path=$(perl -e 'print join q(), map { /[A-Za-z0-9_.~-]/ ? $_ : sprintf(q(%%%02X), ord) } split //, shift' \"$INPUT\")\""},
      {"id": "img-pixelperfect", "label": "Pixel Perfect", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "multi": true, "description": "Overlay two images to compare them", "command": "open \"flickwheel://pixelperfect?$(printf '%s\\n' \"$INPUTS\" | perl -ne 'chomp; $p = join q(), map { /[A-Za-z0-9_.~-]/ ? $_ : sprintf(q(%%%02X), ord) } split //; print q(path=), $p, q(&)')\""},
      {"id": "img-redact", "label": "Redact", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "description": "Hide parts of the image with solid blocks", "command": "open \"flickwheel://annotate?tool=redact&path=$(perl -e 'print join q(), map { /[A-Za-z0-9_.~-]/ ? $_ : sprintf(q(%%%02X), ord) } split //, shift' \"$INPUT\")\""},
      {"id": "edit", "label": "Edit", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif", "webp", "pdf", "mp4", "mov", "m4v"], "description": "Open in Preview or QuickTime Player", "command": "case \"${INPUT:e:l}\" in mp4|mov|m4v) open -a \"QuickTime Player\" \"$INPUT\";; *) open -a Preview \"$INPUT\";; esac"},
      {"id": "compress", "label": "Compress", "wheel": "command", "accepts": ["jpg", "jpeg", "mp4", "mov", "m4v"], "description": "Make the file smaller (video or JPG)", "command": "case \"${INPUT:e:l}\" in mp4|mov|m4v) avconvert --preset PresetMediumQuality --source \"$INPUT\" --output \"$(fw_out \"$DIR/$NAME-small.mp4\")\" --replace;; *) sips -s format jpeg -s formatOptions 60 \"$INPUT\" --out \"$(fw_out \"$DIR/$NAME-small.${INPUT##*.}\")\";; esac"},
      {"id": "resize", "label": "50%", "wheel": "command", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp"], "description": "Halve the width", "command": "w=$(sips -g pixelWidth \"$INPUT\" | awk '/pixelWidth/{print $2}'); sips --resampleWidth $((w/2)) \"$INPUT\" --out \"$(fw_out \"$DIR/$NAME-50.${INPUT##*.}\")\""},
      {"id": "airdrop", "label": "AirDrop", "wheel": "control", "accepts": ["*"], "description": "Send with AirDrop", "command": "open \"flickwheel://airdrop?path=$(perl -e 'print join q(), map { /[A-Za-z0-9_.~-]/ ? $_ : sprintf(q(%%%02X), ord) } split //, shift' \"$INPUT\")\""},
      {"id": "reveal", "label": "Reveal", "wheel": "control", "accepts": ["*"], "description": "Show in Finder", "command": "open -R \"$INPUT\""},
      {"id": "copy-file", "label": "Copy file", "wheel": "control", "accepts": ["*"], "description": "Copy the file to the clipboard", "command": "osascript -e 'set the clipboard to (POSIX file (system attribute \"INPUT\"))'"},
      {"id": "copy-image", "label": "Copy image", "wheel": "control", "accepts": ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "gif", "webp"], "description": "Copy the image to the clipboard", "command": "t=$(mktemp -t flickwheel); sips -s format png \"$INPUT\" --out \"$t\" >/dev/null && T=\"$t\" osascript -e 'set the clipboard to (read (POSIX file (system attribute \"T\")) as «class PNGf»)'; rc=$?; rm -f \"$t\"; exit $rc"},
      {"id": "copy-path", "label": "Copy path", "wheel": "control", "accepts": ["*"], "description": "Copy the full path", "command": "printf '%s' \"$INPUT\" | pbcopy"},
      {"id": "open-terminal", "label": "Terminal", "wheel": "control", "accepts": ["*"], "description": "Open Terminal here", "command": "if [ -d \"$INPUT\" ]; then open -a Terminal \"$INPUT\"; else open -a Terminal \"$DIR\"; fi"},
      {"id": "zip", "label": "Zip", "wheel": "control", "accepts": ["*"], "description": "Make a zip next to the file", "command": "ditto -c -k --keepParent \"$INPUT\" \"$(fw_out \"$DIR/$NAME.zip\")\""},
      {"id": "checksum", "label": "SHA-256", "wheel": "control", "accepts": ["*"], "description": "Copy the SHA-256 hash", "command": "shasum -a 256 \"$INPUT\" | cut -d' ' -f1 | tr -d '\\n' | pbcopy"}
    ]
    """#

    // 8 segments is where the ring is squarest; more only makes the wheel bigger
    nonisolated static let maxPerWheel = 8
    private static let hiddenKey = "hiddenActionIDs"
    private static let orderKey = "actionOrder"
    private static let packsKey = "enabledPackIDs"

    let url: URL
    let packDirs: [URL]
    // actions.json first, then the enabled packs; actions.json wins when an id repeats
    @Published private(set) var actions: [WheelAction] = []
    @Published private(set) var packs: [ActionPack] = []
    @Published private(set) var enabledPacks: Set<String>
    private var baseActions: [WheelAction] = []
    // visibility lives in UserDefaults, never in actions.json (that file is user-owned)
    @Published private(set) var hidden: Set<String>
    // user's drag order, also in UserDefaults; ids not listed (new actions) keep their manifest order after the listed ones
    private var order: [String]
    private let defaults: UserDefaults

    init(url: URL = ActionRegistry.defaultURL, defaults: UserDefaults = .standard,
         packDirs: [URL] = ActionRegistry.defaultPackDirs) {
        self.url = url
        self.defaults = defaults
        self.packDirs = packDirs
        hidden = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
        enabledPacks = Set(defaults.stringArray(forKey: Self.packsKey) ?? [])
        order = defaults.stringArray(forKey: Self.orderKey) ?? []
    }

    func setPack(_ id: String, enabled: Bool) {
        if enabled { enabledPacks.insert(id) } else { enabledPacks.remove(id) }
        defaults.set(enabledPacks.sorted(), forKey: Self.packsKey)
        rebuild()
    }

    private func rebuild() {
        var seen = Set(baseActions.map(\.id))
        var merged = baseActions
        for pack in packs where enabledPacks.contains(pack.id) {
            for action in pack.actions where seen.insert(action.id).inserted { merged.append(action) }
        }
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        actions = merged.enumerated()
            .sorted { (rank[$0.element.id] ?? .max, $0.offset) < (rank[$1.element.id] ?? .max, $1.offset) }
            .map(\.element)
    }

    // `to` is the SwiftUI onMove offset: the row goes in front of the item now at that index
    func moveAction(on wheel: WheelKind, from: Int, to: Int) {
        var ids = actions.filter { $0.wheel == wheel }.map(\.id)
        guard ids.indices.contains(from) else { return }
        let id = ids.remove(at: from)
        ids.insert(id, at: min(max(to > from ? to - 1 : to, 0), ids.count))
        saveOrder(actions.filter { $0.wheel != wheel }.map(\.id) + ids)
    }

    func hasCustomOrder(_ wheel: WheelKind) -> Bool {
        let ids = Set(actions.filter { $0.wheel == wheel }.map(\.id))
        return order.contains(where: ids.contains)
    }

    func resetOrder(_ wheel: WheelKind) {
        let ids = Set(actions.filter { $0.wheel == wheel }.map(\.id))
        saveOrder(order.filter { !ids.contains($0) })
    }

    private func saveOrder(_ ids: [String]) {
        order = ids
        defaults.set(ids, forKey: Self.orderKey)
        rebuild()
    }

    func enabledCount(_ wheel: WheelKind) -> Int {
        actions.filter { $0.wheel == wheel && !hidden.contains($0.id) }.count
    }

    func setHidden(_ id: String, _ isHidden: Bool) {
        if isHidden { hidden.insert(id) } else { hidden.remove(id) }
        defaults.set(hidden.sorted(), forKey: Self.hiddenKey)
    }

    // ids of the actions the app writes into a fresh actions.json
    nonisolated static let defaultActionIDs: Set<String> = Set(parse(Data(defaultManifest.utf8)).actions.map(\.id))

    func origin(of action: WheelAction) -> ActionOrigin {
        if baseActions.contains(where: { $0.id == action.id }) {
            return Self.defaultActionIDs.contains(action.id) ? .builtIn : .custom
        }
        if let pack = packs.first(where: { enabledPacks.contains($0.id) && $0.actions.contains { $0.id == action.id } }) {
            return .pack(pack.title)
        }
        return .custom
    }

    @discardableResult
    func load() -> [String] {
        // reload also picks up visibility changed outside the app
        hidden = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
        enabledPacks = Set(defaults.stringArray(forKey: Self.packsKey) ?? [])
        order = defaults.stringArray(forKey: Self.orderKey) ?? []
        var problems: [String] = []
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(Self.defaultManifest.utf8).write(to: url, options: .withoutOverwriting)
            }
            let parsed = Self.parse(try Data(contentsOf: url))
            baseActions = parsed.actions
            problems = parsed.problems
        } catch {
            baseActions = []
            problems = ["Cannot read \(url.path): \(error.localizedDescription)"]
        }
        let loaded = loadPacks()
        packs = loaded.packs
        rebuild()
        return problems + loaded.problems
    }

    private func loadPacks() -> (packs: [ActionPack], problems: [String]) {
        var byID: [String: ActionPack] = [:]
        var order: [String] = []
        var problems: [String] = []
        for dir in packDirs {
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for file in files.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let id = file.deletingPathExtension().lastPathComponent
                guard let data = try? Data(contentsOf: file) else {
                    problems.append("pack \(id): cannot read \(file.lastPathComponent)")
                    continue
                }
                let parsed = Self.parsePack(data, id: id, bundled: dir.standardizedFileURL != Self.userPacksURL.standardizedFileURL)
                problems += parsed.problems.map { "pack \(id): \($0)" }
                guard let pack = parsed.pack else { continue }
                if byID[id] == nil { order.append(id) }
                byID[id] = pack
            }
        }
        return (order.compactMap { byID[$0] }, problems)
    }

    // a pack file is either a plain array of actions or { "title", "description", "actions": [...] }
    nonisolated static func parsePack(_ data: Data, id: String, bundled: Bool) -> (pack: ActionPack?, problems: [String]) {
        struct Wrapped: Decodable {
            var title: String?
            var description: String?
            var actions: [Entry]
        }
        if let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            let parsed = validate(entries)
            return (ActionPack(id: id, title: id, description: nil, actions: parsed.actions, bundled: bundled), parsed.problems)
        }
        if let wrapped = try? JSONDecoder().decode(Wrapped.self, from: data) {
            let parsed = validate(wrapped.actions)
            return (ActionPack(id: id, title: wrapped.title ?? id, description: wrapped.description,
                               actions: parsed.actions, bundled: bundled), parsed.problems)
        }
        return (nil, ["not a valid JSON array or pack object"])
    }

    // everything that applies to these files, in wheel order; the wheel itself shows only the first maxPerWheel
    func usableActions(for wheel: WheelKind, files: [URL]) -> [WheelAction] {
        let usable = actions.filter {
            $0.wheel == wheel && !hidden.contains($0.id) && files.allSatisfy($0.accepts(file:))
                && ($0.multi != true || files.count == 2)
        }
        // pair actions exist only for two files, so they lead and never fall off the wheel cap
        return usable.filter { $0.multi == true } + usable.filter { $0.multi != true }
    }

    func actions(for wheel: WheelKind, files: [URL]) -> [WheelAction] {
        Array(usableActions(for: wheel, files: files).prefix(Self.maxPerWheel))
    }

    nonisolated static func parse(_ data: Data) -> (actions: [WheelAction], problems: [String]) {
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return ([], ["actions.json is not a valid JSON array"])
        }
        return validate(entries)
    }

    nonisolated private static func validate(_ entries: [Entry]) -> (actions: [WheelAction], problems: [String]) {
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

    fileprivate struct Entry: Decodable {
        let action: WheelAction?

        init(from decoder: Decoder) throws {
            action = try? WheelAction(from: decoder)
        }
    }
}

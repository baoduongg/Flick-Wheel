import AppKit

enum ActionIcon {
    // keyed by manifest id; the first symbol that exists on this macOS wins
    private static let byID: [String: [String]] = [
        // convert
        "img-jpg": ["photo"], "img-png": ["photo"], "img-webp": ["photo"], "img-heic": ["photo"],
        "img-pdf": ["doc.richtext"], "pdf-png": ["photo"], "app-icon": ["app.dashed", "app"],
        "vid-gif": ["play.square.stack", "film.stack"], "vid-mp4": ["film"], "vid-webm": ["globe"],
        "vid-hevc": ["h.square", "film.stack"], "vid-frame": ["camera.viewfinder", "photo"], "vid-info": ["info.circle"],
        "to-mp3": ["music.note"], "to-m4a": ["music.note"], "aud-ogg": ["music.note.list", "music.note"],
        "svg-tsx": ["chevron.left.forwardslash.chevron.right"], "csv-json": ["tablecells"], "json-ts": ["curlybraces"],
        // edit
        "img-annotate": ["pencil.and.scribble", "scribble.variable"], "crop": ["crop"],
        "img-addbg": ["photo.on.rectangle.angled", "photo.on.rectangle"], "img-redact": ["eye.slash"],
        "img-pixelperfect": ["square.on.square.dashed", "square.on.square"],
        "edit": ["slider.horizontal.3"], "compress": ["arrow.down.right.and.arrow.up.left"],
        "vid-trim": ["scissors"], "img-ocr": ["text.viewfinder", "doc.text.viewfinder"], "img-send": ["paperplane", "square.and.arrow.up"],
        "unzip": ["archivebox"], "img-qr": ["qrcode"], "img-diff": ["square.on.square.intersection.dashed"], "vid-target": ["scalemass"],
        "vid-timecode": ["timer"], "file-report": ["list.bullet.clipboard"], "log-errors": ["exclamationmark.magnifyingglass"],
        "copy-llm": ["text.append"], "json-format": ["curlybraces"], "json-minify": ["arrow.right.to.line.compact"],
        "git-permalink": ["link.badge.plus"], "diff-files": ["arrow.left.arrow.right"], "verify-sha": ["checkmark.seal"],
        "img-strip": ["location.slash", "eye.slash"], "ios-install": ["iphone.gen3", "iphone"], "android-install": ["arrow.down.app", "shippingbox"], "vid-split": ["square.split.2x1", "scissors"], "vid-redact": ["square.dashed.inset.filled", "eye.slash"], "vid-mute": ["speaker.slash"], "vid-speed": ["speedometer", "gauge"],
        "vid-720p": ["aspectratio", "tv"],
        "resize": ["arrow.up.left.and.arrow.down.right"], "rotate": ["rotate.right"],
        // share, open, copy
        "airdrop": ["dot.radiowaves.left.and.right"], "reveal": ["folder"], "zip": ["doc.zipper", "archivebox"],
        "open-terminal": ["terminal"], "open-vscode": ["chevron.left.forwardslash.chevron.right"],
        "claude-here": ["sparkles"],
        "copy-file": ["doc.on.doc"], "copy-image": ["doc.on.clipboard"], "copy-path": ["link"],
        "copy-name": ["textformat"], "copy-md": ["text.quote"], "copy-content": ["text.alignleft"],
        "copy-data-uri": ["curlybraces.square"], "copy-sha256": ["checkmark.shield"], "checksum": ["checkmark.shield"],
    ]

    static func symbol(for action: WheelAction) -> String {
        let fallback: String
        switch action.wheel {
        case .shift: fallback = "arrow.triangle.2.circlepath"
        case .command: fallback = "wand.and.stars"
        case .control: fallback = "square.and.arrow.up"
        }
        return ([action.icon].compactMap { $0 } + (byID[action.id] ?? []))
            .first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? fallback
    }
}

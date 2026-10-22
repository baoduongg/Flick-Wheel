# FlickWheel

macOS menu-bar utility. Drag a file in Finder, tap a modifier key, and a radial wheel appears at the cursor. Drop the file on a segment to run a shell command on it.

## Setup
Requires macOS 13+, Apple silicon, full Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
xcodegen generate
xcodebuild -scheme FlickWheel -configuration Debug build
xcodebuild test -scheme FlickWheel
```

The default actions use `ffmpeg` (`brew install ffmpeg`); `sips` and `pbcopy` ship with macOS.

## Permissions
- **Accessibility**: required for the global event monitors. The system prompt appears on first launch; the menu shows the current status and opens System Settings when clicked while not granted. If you grant it after launch, click the status item once to restart the monitors.
- **Notifications**: allow them to see success and failure results.
- **Signing**: `project.yml` uses ad-hoc signing (`CODE_SIGN_IDENTITY: "-"`) because no valid Apple Development certificate was available. The Accessibility grant therefore resets on every rebuild and must be re-granted. To keep it, set `CODE_SIGN_IDENTITY` and `DEVELOPMENT_TEAM` from a valid cert (`security find-identity -v -p codesigning`).

## Usage
1. Start dragging a file in Finder.
2. Hold Shift, Command or Control (without Option or other modifiers) to pick the wheel. Releasing the key hides it.
3. Drop on a segment. Releasing anywhere else hides the wheel and runs nothing.

Only actions whose `wheel` matches the key and whose `accepts` covers every dragged file are shown. The command runs once per file.

## Default actions
| Key | Actions |
|---|---|
| Shift (convert) | WebP, PNG, JPG, GIF, MP3 |
| Command (tools) | Compress (JPG, video), Edit, Annotate, Add BG, Crop, Redact |
| Control (file) | AirDrop, Copy path, Copy file, Terminal, Reveal |

**Crop** on images opens a crop window (drag handles or the box, aspect presets, W/H fields, Apply writes `name-crop.ext` beside the original). The action runs `open "flickwheel://crop?path=<percent-encoded path>"`, which the app handles. On video, Crop asks for a `WxH` size in a dialog.

**Annotate** on images opens an annotation window (arrow, highlighter, text, rectangle, ellipse, pen, numbered marker, color, undo, delete). Drag an existing mark to move it. Zoom with the −/+ buttons, ⌘= / ⌘−, ⌘0 (fit) or trackpad pinch, and scroll to pan; the window is resizable. **Save Annotated Copy** writes `name-annotated.ext` beside the original. **Redact** opens the same window with a solid-block tool selected (black by default, follows the color picker) (saves `name-redacted.ext`). **Add BG** opens a window with gradient/solid/image backgrounds, padding, corner, shadow and ratio controls (saves `name-bg.ext`).

An existing `actions.json` is never overwritten, so new defaults only appear for a fresh file. To pick them up, move your file aside (`mv ~/.config/flickwheel/actions.json ~/.config/flickwheel/actions.old.json`), relaunch, then copy your own entries back.

## Manifest
`~/.config/flickwheel/actions.json` is created with defaults on first launch and never overwritten. Use menu **Reload actions** after editing.

```json
[{ "id": "copy-path", "label": "Copy path", "wheel": "control", "accepts": ["*"], "command": "printf '%s' \"$INPUT\" | pbcopy" }]
```

| Field | Meaning |
|---|---|
| `id` | unique string |
| `label` | segment text |
| `wheel` | `shift`, `command` or `control` |
| `accepts` | lowercase extensions, or `"*"` (matching ignores case) |
| `command` | run with `/bin/zsh -lc`, killed after 120 s |

Paths are passed only as environment variables, never in the command string: `INPUT` (full path), `DIR` (parent folder), `NAME` (filename without extension). Always quote them: `"$INPUT"`.

Invalid entries are skipped and reported in one notification.

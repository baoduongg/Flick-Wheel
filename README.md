# FlickWheel

macOS menu-bar utility. Drag a file in Finder, tap a modifier key, and a radial wheel appears at the cursor. Drop the file on a segment to run a shell command on it.

## Setup
Requires macOS 13+, Apple silicon, full Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
xcodegen generate
xcodebuild -scheme FlickWheel -configuration Debug build
xcodebuild test -scheme FlickWheel
```

The video actions and some defaults use `ffmpeg` (`brew install ffmpeg`); `sips` and `pbcopy` ship with macOS.

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
| Shift (convert) | JPG, PNG, WebP 80%, HEIC, PDF, GIF, MP3, M4A |
| Command (tools) | Annotate, Crop, Add BG, Pixel Perfect, Redact, Edit, Compress, 50% |
| Control (file) | AirDrop, Reveal, Copy file, Copy image, Copy path, Terminal, Zip, SHA-256 |

A wheel shows at most 8 segments for any one file. Click the menu bar item, then **Settings…** (⌘,):

- The sidebar has the three wheels (blue ⇧ Shift, purple ⌘ Command, orange ⌃ Control; the same colours mark every action), **Packs** and **Translate** (Gemini API key and model).
- Each action is a row with its icon, a one-line description, a **Built in / Custom / pack-name** badge, chips for the file kinds it accepts (Image, Video, Audio, Docs, Code, Any) and an on/off switch. Rows are in wheel order and can be dragged to reorder (stored in `actionOrder`). Search and the kind chips filter the list.
- The sidebar counts **on / total** per wheel. The right pane previews the real wheel for a sample file (png, mp4, mp3, pdf, txt, json) and reconciles the numbers: `7 on = 4 on the wheel + 3 for other file types` (plus any cut by the 8-slot limit, named so you can switch one off to bring the next in). A kind chip appears when it covers at least a quarter of an action's accepted extensions, so a stray `gif` does not make a video converter an image action.
- The window has a fixed width and opens centred in the usable screen area, like every other FlickWheel window.
- Settings only toggles visibility, pack on/off and order (stored in `UserDefaults`); it never edits `actions.json`.

**Crop** on images opens a crop window (drag handles or the box, aspect presets, W/H fields, Apply writes `name-crop.ext` beside the original). The action runs `open "flickwheel://crop?path=<percent-encoded path>"`, which the app handles. On mp4, mov and m4v, Crop opens the video crop window (see [Video tools](#video-tools)); on mkv and webm it asks for a `WxH` size in a dialog.

**Pixel Perfect** takes two images (drop both at once; the first is the base) and opens a comparison window: Overlay (opacity slider), Difference (black pixels match, anything lit differs) or Swipe. Drag the overlay or use the arrow keys (⇧ for 10 px) to align it, Swap exchanges the two, and Annotate lets you mark the base. The overlay is scaled to the base width, so a 3x phone screenshot lines up with a 1x design. **Save Comparison** writes `name-compare.ext` beside the base. It only shows when exactly two images are dropped.

**GIF** makes a 15 fps palette GIF at most 720 px wide, never upscaled. **MP3** accepts audio and video files and keeps metadata.

**Annotate** on images opens an annotation window (arrow, highlighter, text, rectangle, ellipse, pen, numbered marker, color, undo, delete). Drag an existing mark to move it. Zoom with the −/+ buttons, ⌘= / ⌘−, ⌘0 (fit) or trackpad pinch, and scroll to pan; the window is resizable. **Save Annotated Copy** writes `name-annotated.ext` beside the original. **Redact** opens the same window with a solid-block tool selected (black by default, follows the color picker) (saves `name-redacted.ext`). **Add BG** opens a window with gradient/solid/image backgrounds, padding, corner, shadow and ratio controls (saves `name-bg.ext`).

## Packs
A pack is a JSON file of extra actions that you switch on in **Settings → Packs**. They keep `actions.json` yours: a pack never edits it, and when both define the same `id`, `actions.json` wins. Packs are off until you enable them (the choice is stored in `UserDefaults`, key `enabledPackIDs`).

| Pack | Adds |
|---|---|
| Everyone | **Text** (read the text in an image and copy it, Apple Vision), **QR** (read a QR code or barcode and copy it), **Send-ready** (shrink to 1600 px, JPEG, drop EXIF and GPS), **Clean** (same format, no EXIF, GPS or camera data), **Unzip** (into a folder that never merges with an existing one), **Translate** (txt or md through Google Gemini; see below) |
| Developer | **iOS Sim** (install a `.app` on the booted simulator and launch it), **Android** (`adb install -r` an `.apk`), **For LLM** (copy a file, or a folder tree, as a fenced block with its path), **Format** / **Minify** JSON, **Permalink** (GitHub link to the file at the current commit; push first), **Diff files** (two non-image files, VS Code or FileMerge; images use Image diff), **Verify** (file against a SHA-256 on the clipboard; fails with both hashes when they differ), SVG to TSX, JSON to TS types, CSV to JSON, App icon. Drop a folder for clone, clean, fresh install, pull, repo page, zip, sizes and lines of code (git `.gitignore` respected) |
| QC | **Image diff** (two images: changed pixels in red, saved as `name-diff.png`, with the % that differ and a note when the sizes differ), **To MB** (re-encode a recording to fit a size limit, asks for MB; the result is at most that size), **Timecode** (burn a running timecode into a video), **Report** (copy name, size, type, dimensions or duration and SHA-256), **Errors** (the last 200 lines that mention error, fatal, exception, fail or panic) |
| Video | The video actions below |

Built-in packs live in the app bundle (`Resources/Packs`). Add your own as `~/.config/flickwheel/packs/<name>.json` (**Open packs folder** in Settings); a user pack with the same name replaces the built-in one. A pack file is either an array of actions, or `{ "title", "description", "actions": [...] }`.

**Translate** opens a window (target language, progress per part) for a txt or md file and writes `name.<code>.ext` beside it, never over an existing file. It needs a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey), pasted in **Settings → Translate** and kept in the macOS Keychain; it is sent only to Google's API.

Text, Send-ready and Clean run inside the app through `flickwheel://tool?name=ocr|send|strip|qr|diff&path=<percent-encoded path>` (repeat `path=` for the two images of `diff`). SVG to TSX and JSON to TS use `npx` with pinned versions (`@svgr/cli@8.1.0`, `quicktype@26.0.0`), so the first run needs network.

## Results and cancelling
The menu bar icon spins while a command runs. The menu lists running jobs (**Cancel** stops the command and the ffmpeg or npx it started) and a **Recent** submenu with the last 10 results: click one to reveal its output in Finder. Clicking a success notification also reveals the output. The app finds the output as the newest file that appeared or changed beside the input.

Commands never overwrite an existing file when they write through `fw_out`, a zsh function the runner defines before every command: `"$(fw_out "$DIR/$NAME.gif")"` gives `name.gif`, then `name 2.gif`, `name 3.gif`. All built-in actions use it. The runner also checks every name `fw_out` handed out: if the command exits 0 but nothing was written there (`sips` does this after `Warning: ... not a valid file - skipping`, for example when the app is not allowed to read that folder), the job is reported as failed with that message, and the half-written output of a failed command is removed. Commands run with `LANG=en_US.UTF-8` when the app has none, so `pbcopy` keeps non-ASCII file names intact.

## Video tools
The **Video** pack has these actions. If you already copied them into `actions.json`, yours win.

| Action | Wheel | Result | What it does |
|---|---|---|---|
| MP4 | Shift | `name.mp4` | H.264 + AAC from mov, mkv, avi, webm, m4v, flv, wmv, ts or gif; even dimensions, `yuv420p`, fast start |
| WebM | Shift | `name.webm` | VP9 + Opus from mp4, mov, m4v, mkv, avi |
| H.265 | Shift | `name-hevc.mp4` | HEVC (`hvc1`, plays in QuickTime) |
| Frames | Shift | `name-frame-1.60s.png` | **Video Snapshots** window: scrub, add several frames, save them all |
| 720p | Shift | `name-720p.mp4` | Scales down to at most 720 px tall |
| Trim | Command | `name-trim.mp4` | **Trim Video** window: filmstrip, drag both ends, looped preview |
| Mute | Command | `name-mute.ext` | Drops the audio track without re-encoding |
| Speed | Command | `name-2x.mp4` | **Change Speed** window: 0.5x to 8x with a live preview |
| Split | Command | `name-part1.mp4`, … | **Split Video** window: add split points at the playhead or set N equal clips |
| Redact | Command | `name-redacted.mp4` | **Redact Video** window: draw boxes on the video, each with its own time range; Solid (any color) or Blur |
| Info | Control | clipboard | Codec, size, duration, frame rate and bitrate |

The windows open from `flickwheel://video?mode=trim|frame|crop|speed|split|redact&path=<percent-encoded path>` and need an mp4, mov or m4v file (AVPlayer cannot play mkv, webm or avi). For Trim, Frames, Speed and Crop the actions fall back to a plain dialog on other formats; Split and Redact report an error. Applying a window closes it and exports in the background with ffmpeg, with a notification when it starts and when it finishes.

The video actions set `timeout` (seconds) so long encodes are not killed after the default 120 s. The ffmpeg commands pass `-hide_banner -loglevel error`, otherwise the startup banner would fill the failure notification.

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
| `accepts` | lowercase extensions, or `"*"` (matching ignores case); `"!ext"` rules a type out (`["*", "!png"]`); `"dir"` means a plain folder, not an `.app` package |
| `command` | run with `/bin/zsh -lc` |
| `icon` | optional SF Symbol name; otherwise a per-`id` default, or a generic wheel icon |
| `timeout` | optional seconds before the command is killed (default 120) |
| `description` | optional one-liner shown in Settings and under the wheel while the segment is hovered |
| `multi` | optional; run once for two dropped files (`INPUTS` holds both) |

Paths are passed only as environment variables, never in the command string: `INPUT` (full path), `DIR` (parent folder), `NAME` (filename without extension). Always quote them: `"$INPUT"`. The runner also defines `fw_out` (see above) before your command.

Invalid entries are skipped and reported in one notification.

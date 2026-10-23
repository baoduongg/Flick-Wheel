# FlickWheel

Personal macOS menu-bar utility. Drag a file in Finder, tap Shift/Command/Control, drop it on a radial wheel segment to run a shell command from a JSON manifest.

## Locked decisions (do not revisit)
1. Drag detection: `NSEvent.addGlobalMonitorForEvents` for `.leftMouseDragged`, `.leftMouseUp`, `.flagsChanged`. File URLs come from `NSPasteboard(name: .drag)` via `readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`.
2. Wheel UI: non-activating borderless floating `NSPanel` at `NSEvent.mouseLocation` hosting a SwiftUI radial view. Panel content view (`WheelDropView`) registers for file-URL drags and hit-tests the drop point to pick the segment.
3. Actions: `~/.config/flickwheel/actions.json`, item = `{ id, label, wheel: shift|command|control, accepts: [lowercase ext or "*"], command, icon?, timeout?, multi? }` (`timeout` = seconds, default 120; video encodes set it much higher) (`icon` = optional SF Symbol name; `ActionIcon` maps manifest id to a list of candidate symbols, so renaming or adding an id needs an entry there or it gets the generic wheel icon).
4. Runner: `/bin/zsh -lc <command>`, with a fixed one-line `fw_out` function defined before the command (unique output name; it holds no paths). Every name it hands out is logged to `FW_OUTLOG`; exit 0 with a missing or empty logged file is a failure (sips exits 0 on unreadable input). The environment gets `LANG=en_US.UTF-8` when unset. Paths go ONLY through env vars `INPUT`, `DIR`, `NAME` (name without extension), merged into `ProcessInfo.processInfo.environment`. NEVER interpolate paths into the command string.
5. `LSUIElement = YES` menu-bar agent, no Dock icon, no App Sandbox.

## Hard rules
- Bundle id `com.baoduongg.flickwheel` is fixed: the Accessibility (TCC) grant is tied to it.
- Never overwrite an existing `actions.json`; it is written only when missing.
- No third-party Swift packages. No key rebinding, batching, AI actions in phase 1. Settings UI only toggles action visibility and pack on/off; it never edits `actions.json`.

## Build and test
```
xcodegen generate
xcodebuild -scheme FlickWheel -configuration Debug build
xcodebuild test -scheme FlickWheel
```
Tests are unhosted: `FlickWheelTests` compiles `FlickWheel/Actions` and the UI-free `Crop`/`Annotate`/`Background`/`Video`/`Tools` files directly, so they never touch UI or `UNUserNotificationCenter`.

## Layout
- `App/` `WindowPlacement` (`NSWindow.showCentered()`: fit to the hosted SwiftUI content, then centre; every window controller's `show()` uses it, because `center()` before the content is laid out lands off-centre), menu bar scene + `AppDelegate` (wiring, Accessibility prompt), `SettingsView` (opened from menu bar "Settings…" or `flickwheel://settings?tab=shift|command|control|packs`; sidebar of wheels + Packs, one row per action with origin badge, file-kind chips and a switch, search + kind filter, and a scaled-down real `RadialWheelView` preview per sample file type that names the actions cut by the 8-slot limit), `ActionIcon`
- `Drag/` `DragKeyMonitor`
- `Wheel/` `WheelPanelController`, `WheelDropView`, `RadialWheelView` (rounded-corner glass segments via SwiftUI materials with SF Symbol icon + label, accent-fill selection, hover scale + entrance spring, state in `WheelState`; `WheelDropView` blanks the Finder drag image and `DragPuck` draws a file icon at the cursor so long names don't cover segments)
- `Actions/` `WheelAction`, `ActionRegistry` (also holds hidden action ids in `UserDefaults` key `hiddenActionIDs`, not in `actions.json`; loads packs (everyone, dev, qc, video) from the bundle `Resources/Packs` and `~/.config/flickwheel/packs`, enabled ids in `enabledPackIDs`, actions.json wins on a repeated id), `ActionPack`, `ActionRunner` (`RunHandle` cancels the command and its children, success notifications reveal the output), `OutputProbe` (newest changed file beside the input), `JobCenter` (running + last 10 jobs for the menu bar)
- `Tools/` `ImageTools` + `ImageDiff`: in-app jobs behind `flickwheel://tool?name=ocr|send|strip|qr|diff&path=` (repeat `path=` for diff): Vision OCR and QR, shrink for sending, strip metadata, pixel diff of two images `flickwheel://settings?tab=packs` opens Settings
- `Annotate/` image annotation window (`AnnotateModel` + `Annotation` geometry, `AnnotatedImageView` draws preview and export, `AnnotateView`), opened by `flickwheel://annotate?path=`
- `Background/` Add BG window (`BackgroundModel`, `BackgroundRenderView` draws preview and export), opened by `flickwheel://background?path=`
- `Video/` preview windows for the video actions `vid-trim`/`vid-frame`/`vid-speed`/`vid-split`/`vid-redact`/`crop`, opened by `flickwheel://video?mode=trim|frame|crop|speed|split|redact&path=` (`VideoSession` = AVKit `PlayerController` + `Filmstrip` thumbnails; `VideoModel` holds marks, splits, snapshots, redact boxes; `VideoExporter` builds the ffmpeg args and runs them in the background; crop reuses `CropView` on a still frame). Only mp4/mov/m4v play in AVPlayer: trim/speed/frame/crop fall back to dialog commands for mkv/webm/avi, split/redact just report an error. These actions live in the user's `actions.json`, not the default manifest (wheel cap of 8 per file)
- `Crop/` image crop window (`CropModel` geometry, `CropView`, `ImageCropper`), opened by the `flickwheel://crop?path=` URL that the `img-crop` manifest command emits

## Signing
`project.yml` uses ad-hoc signing (no valid cert: the Apple Development cert in the keychain expired 2023-11), so the TCC grant resets on each rebuild. Switch `CODE_SIGN_IDENTITY` + `DEVELOPMENT_TEAM` once a valid cert exists.

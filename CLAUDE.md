# FlickWheel

Personal macOS menu-bar utility. Drag a file in Finder, tap Shift/Command/Control, drop it on a radial wheel segment to run a shell command from a JSON manifest.

## Locked decisions (do not revisit)
1. Drag detection: `NSEvent.addGlobalMonitorForEvents` for `.leftMouseDragged`, `.leftMouseUp`, `.flagsChanged`. File URLs come from `NSPasteboard(name: .drag)` via `readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`.
2. Wheel UI: non-activating borderless floating `NSPanel` at `NSEvent.mouseLocation` hosting a SwiftUI radial view. Panel content view (`WheelDropView`) registers for file-URL drags and hit-tests the drop point to pick the segment.
3. Actions: `~/.config/flickwheel/actions.json`, item = `{ id, label, wheel: shift|command|control, accepts: [lowercase ext or "*"], command }`.
4. Runner: `/bin/zsh -lc <command>`. Paths go ONLY through env vars `INPUT`, `DIR`, `NAME` (name without extension), merged into `ProcessInfo.processInfo.environment`. NEVER interpolate paths into the command string.
5. `LSUIElement = YES` menu-bar agent, no Dock icon, no App Sandbox.

## Hard rules
- Bundle id `com.baoduongg.flickwheel` is fixed: the Accessibility (TCC) grant is tied to it.
- Never overwrite an existing `actions.json`; it is written only when missing.
- No third-party Swift packages. No settings UI, key rebinding, batching, AI actions in phase 1.

## Build and test
```
xcodegen generate
xcodebuild -scheme FlickWheel -configuration Debug build
xcodebuild test -scheme FlickWheel
```
Tests are unhosted: `FlickWheelTests` compiles `FlickWheel/Actions` and the UI-free `Crop`/`Annotate`/`Background` files directly, so they never touch UI or `UNUserNotificationCenter`.

## Layout
- `App/` menu bar scene + `AppDelegate` (wiring, Accessibility prompt)
- `Drag/` `DragKeyMonitor`
- `Wheel/` `WheelPanelController`, `WheelDropView`, `RadialWheelView`
- `Actions/` `WheelAction`, `ActionRegistry`, `ActionRunner`
- `Annotate/` image annotation window (`AnnotateModel` + `Annotation` geometry, `AnnotatedImageView` draws preview and export, `AnnotateView`), opened by `flickwheel://annotate?path=`
- `Background/` Add BG window (`BackgroundModel`, `BackgroundRenderView` draws preview and export), opened by `flickwheel://background?path=`
- `Crop/` image crop window (`CropModel` geometry, `CropView`, `ImageCropper`), opened by the `flickwheel://crop?path=` URL that the `img-crop` manifest command emits

## Signing
`project.yml` uses ad-hoc signing (no valid cert: the Apple Development cert in the keychain expired 2023-11), so the TCC grant resets on each rebuild. Switch `CODE_SIGN_IDENTITY` + `DEVELOPMENT_TEAM` once a valid cert exists.

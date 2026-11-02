# FlickWheel: tài liệu tham khảo cho landing page

Nguồn: README.md, CLAUDE.md, project.yml, Resources/Info.plist, `ActionRegistry.defaultManifest`, SettingsView, AppDelegate, Resources/Packs/*.json (working tree, ngày 2026-11-02).
Mọi con số và tên action bên dưới lấy từ code. Đừng thêm tính năng không có ở đây.

---

## 1. Tổng quan

| Mục | Giá trị |
|---|---|
| Tên | FlickWheel |
| Loại | Tiện ích macOS chạy trên menu bar (agent, không icon Dock) |
| Một dòng | Kéo file trong Finder, chạm Shift/Command/Control, thả lên một ô của bánh xe tròn để chạy lệnh shell. |
| Bundle id | `com.baoduongg.flickwheel` |
| Phiên bản | 1.0 (build 1) |
| Yêu cầu | macOS 13+, Apple silicon (arm64), Xcode 15+ và XcodeGen để build |
| Ngôn ngữ / UI | Swift 5.9, SwiftUI + AppKit |
| Phụ thuộc | Không có package bên thứ ba. Không sandbox. |
| Cách cài | Build từ source (chưa có bản release, chưa notarize) |
| Tác giả / repo / license | **Chưa có trong repo.** Cần bạn điền: `[AUTHOR]`, `[REPO_URL]`, `[LICENSE]` |

Icon menu bar: SF Symbol `circle.grid.cross`.

## 2. Cách dùng (3 bước)

1. Bắt đầu kéo một file trong Finder.
2. Giữ Shift, Command hoặc Control (không kèm Option hay phím khác) để chọn bánh xe. Nhả phím thì bánh xe ẩn.
3. Thả file lên một ô. Thả ở chỗ khác thì bánh xe ẩn và không chạy gì.

Quy tắc hiển thị:
- Chỉ hiện action có `wheel` khớp phím VÀ `accepts` bao phủ mọi file đang kéo.
- Lệnh chạy một lần cho mỗi file.
- Kết quả thành công/thất bại báo qua Notification.

## 3. Ba bánh xe và action mặc định

Mỗi bánh xe tối đa 8 ô cho một file (`maxPerWheel = 8`, vì 8 ô cho vòng tròn cân nhất). Mặc định mỗi bánh xe đúng 8 action. Ngoài default có thêm bộ action video tùy chọn (xem mục 4).

### Shift: Convert (chuyển đổi)
| Label | Nhận | Công cụ |
|---|---|---|
| JPG | png, heic, webp, tiff, bmp | sips |
| PNG | jpg, jpeg, heic, webp, tiff | sips |
| WebP 80% | png, jpg, jpeg, heic | ffmpeg |
| HEIC | png, jpg, jpeg, tiff, bmp | sips |
| PDF | png, jpg, jpeg, heic, tiff, bmp | sips |
| GIF | mp4, mov, m4v, mkv, webm, avi | ffmpeg (15 fps, rộng tối đa 720px, không phóng to, palette bayer dither) |
| MP3 | mp4, mov, m4v, mkv, webm, avi, wav, m4a, flac, ogg, aiff | ffmpeg (giữ metadata) |
| M4A | mp4, mov, m4v, wav, aiff, mp3 | avconvert / afconvert |

### Command: Tools (công cụ)
| Label | Nhận | Làm gì |
|---|---|---|
| Annotate | ảnh | Mở cửa sổ chú thích (`flickwheel://annotate`) |
| Crop | ảnh + video | Ảnh: cửa sổ crop. Video mp4/mov/m4v: cửa sổ crop video (`flickwheel://video?mode=crop`). mkv/webm: hộp thoại nhập `WxH` rồi ffmpeg |
| Add BG | ảnh | Mở cửa sổ thêm nền (`flickwheel://background`) |
| Pixel Perfect | hai ảnh (thả cùng lúc) | Mở cửa sổ so sánh hai ảnh (`flickwheel://pixelperfect`). Chỉ hiện khi thả đúng hai ảnh |
| Redact | ảnh | Mở Annotate sẵn công cụ khối đặc |
| Edit | ảnh, gif, webp, pdf, mp4, mov, m4v | Mở Preview (ảnh/PDF) hoặc QuickTime Player (video) |
| Compress | jpg, jpeg, mp4, mov, m4v | Ảnh: JPEG chất lượng 60 → `name-small`. Video: avconvert PresetMediumQuality |
| 50% | ảnh | Giảm một nửa chiều rộng → `name-50` |

Ảnh = png, jpg, jpeg, heic, tiff, bmp.

### Control: File (tệp)
| Label | Nhận | Làm gì |
|---|---|---|
| AirDrop | mọi file | Gửi qua AirDrop (`flickwheel://airdrop`) |
| Reveal | mọi file | Hiện trong Finder |
| Copy file | mọi file | Copy file vào clipboard |
| Copy image | ảnh + gif, webp | Copy ảnh (chuyển PNG) vào clipboard |
| Copy path | mọi file | Copy đường dẫn đầy đủ |
| Terminal | mọi file | Mở Terminal tại thư mục |
| Zip | mọi file | Nén `name.zip` bằng ditto |
| SHA-256 | mọi file | Copy mã SHA-256 vào clipboard |

Công cụ ngoài macOS: chỉ `ffmpeg` (`brew install ffmpeg`). `sips`, `pbcopy`, `avconvert`, `afconvert`, `ditto`, `shasum` có sẵn.

## 4. Trình chỉnh sửa tích hợp

### Annotate (chú thích ảnh)
- Công cụ: arrow, highlighter, text, rectangle, ellipse, pen, numbered marker, chọn màu, undo, delete.
- Kéo mark có sẵn để di chuyển.
- Zoom: nút −/+, ⌘=, ⌘−, ⌘0 (vừa khung), pinch trackpad. Cuộn để pan. Cửa sổ resize được.
- **Save Annotated Copy** ghi `name-annotated.ext` cạnh file gốc.
- **Redact**: cùng cửa sổ, chọn sẵn khối đặc (mặc định đen, theo color picker). Lưu `name-redacted.ext`.

### Crop (cắt ảnh)
- Kéo tay cầm hoặc kéo khung, preset tỉ lệ, ô W/H.
- Apply ghi `name-crop.ext` cạnh file gốc.
- Video mp4/mov/m4v: cùng cửa sổ crop trên một frame tĩnh, có thanh trượt "Frame" để chọn frame hiển thị. Ghi `name-crop.mp4` (H.264 + AAC, kích thước chẵn).
- Video mkv/webm: hộp thoại `WxH`, ghi `name-crop.mp4`.

### Pixel Perfect (so sánh hai ảnh)
- Thả hai ảnh cùng lúc (ảnh đầu là base). Overlay co về chiều rộng base, nên ảnh chụp 3x khớp thiết kế 1x. Ba chế độ: **Overlay** (opacity), **Difference** (pixel đen = khớp), **Swipe**.
- Căn bằng kéo hoặc phím mũi tên (⇧ = 10 px); **Swap**, **Annotate** trên base. **Save Comparison** ghi `name-compare.ext` cạnh base.

### Translate (dịch txt/md, nằm trong Everyone pack)
- Dịch bằng Google Gemini; cần API key dán ở **Settings → Translate** (lưu trong Keychain, chỉ gửi tới API của Google). Kết quả `name.<mã ngôn ngữ>.ext` cạnh file gốc, không ghi đè file có sẵn.

### Video tools (tùy chọn, không nằm trong default)
Mỗi bánh xe tối đa 8 ô nên các action này nằm trong **Video pack** (bật ở Settings → Packs, xem mục Packs bên dưới). Cửa sổ mở bằng `flickwheel://video?mode=trim|frame|crop|speed|split|redact&path=`, chỉ nhận mp4, mov, m4v (AVPlayer không phát được mkv/webm/avi). Bấm nút xong cửa sổ đóng, ffmpeg chạy nền, có notification lúc bắt đầu và lúc xong.

| Action | Bánh xe | Cửa sổ / kết quả |
|---|---|---|
| Trim | Command | **Trim Video**: filmstrip, kéo hai đầu, xem lặp trong đoạn chọn → `name-trim.mp4` |
| Frames | Shift | **Video Snapshots**: scrub, Add Frame nhiều frame, thumbnail có nút ✕ → `name-frame-1.60s.png` |
| Speed | Command | **Change Speed**: 0.5x đến 8x, xem trước đúng tốc độ → `name-2x.mp4` |
| Split | Command | **Split Video**: Add Split tại playhead hoặc "Equal clips" N phần → `name-part1.mp4`, … |
| Redact | Command | **Redact Video**: vẽ box lên video, mỗi box một khoảng thời gian (kéo trên track), Solid (chọn màu) hoặc Blur → `name-redacted.mp4`. Blur chỉ thấy trong file xuất, cửa sổ xem trước chỉ tô mờ |
| Mute | Command | Bỏ audio, không encode lại → `name-mute.ext` |
| MP4, WebM, H.265, 720p | Shift | Chuyển đổi bằng ffmpeg → `name.mp4`, `name.webm`, `name-hevc.mp4`, `name-720p.mp4` |
| Info | Control | Copy codec, kích thước, thời lượng, fps, bitrate |

Trim, Frames, Speed và Crop có lệnh dự phòng (hộp thoại nhập số) cho mkv/webm/avi. Split và Redact báo lỗi "cần mp4, mov hoặc m4v".

### Packs (bật trong Settings → Packs)
Pack là một file JSON chứa thêm action; không đụng tới `actions.json` (trùng `id` thì `actions.json` thắng). Mặc định tắt hết. Pack tích hợp nằm trong app (`Resources/Packs`), pack của bạn đặt ở `~/.config/flickwheel/packs/<tên>.json` (nút **Open packs folder**).

| Pack | Có gì |
|---|---|
| Everyone | **Translate** (dịch txt/md bằng Gemini, xem trên), **Text** (đọc chữ trong ảnh, chép vào clipboard, Apple Vision), **QR** (đọc mã QR/barcode, chép nội dung), **Send-ready** (thu về 1600px, JPEG, bỏ EXIF/GPS), **Clean** (giữ định dạng, bỏ EXIF/GPS/thông tin máy), **Unzip** (giải nén vào thư mục mới, không gộp vào thư mục có sẵn) |
| Developer | **iOS Sim**, **Android**, **For LLM** (chép file hoặc cây thư mục dạng khối code kèm đường dẫn), **Format**/**Minify** JSON, **Permalink** (link GitHub tới file ở commit hiện tại, cần push trước), **Diff files** (VS Code hoặc FileMerge; ảnh dùng Image diff), **Verify** (so file với SHA-256 trong clipboard), SVG→TSX, JSON→TS types, CSV→JSON, App icon. Thả **thư mục**: Clone, Clean, Fresh install, Pull, Repo, Zip src, Sizes, Lines (đếm dòng code theo ngôn ngữ, tôn trọng `.gitignore`) |
| QC | **Image diff** (hai ảnh: pixel khác tô đỏ, lưu `name-diff.png`, kèm % khác và cảnh báo khi kích thước lệch), **To MB** (nén bản ghi màn hình để vừa giới hạn dung lượng, hỏi số MB; kết quả không vượt quá), **Timecode** (ghi timecode chạy lên video), **Report** (chép tên, dung lượng, loại, kích thước hoặc thời lượng, SHA-256), **Errors** (200 dòng cuối chứa error/fatal/exception/fail/panic) |
| Video | Các action video ở mục trên |

Text/Send-ready/Clean chạy trong app qua `flickwheel://tool?name=ocr|send|strip|qr|diff&path=` (diff lặp `path=` cho hai ảnh). SVG→TSX và JSON→TS dùng `npx` với phiên bản ghim (`@svgr/cli@8.1.0`, `quicktype@23.2.6`), lần đầu cần mạng.

### Kết quả và hủy việc
- Icon menu bar xoay khi có lệnh đang chạy. Menu liệt kê việc đang chạy (**Cancel** dừng lệnh và cả ffmpeg/npx nó đã mở) và mục **Recent** (10 kết quả gần nhất, bấm để hiện file trong Finder). Bấm notification thành công cũng hiện file.
- Action dựng sẵn không bao giờ ghi đè file có sẵn: dùng hàm `fw_out` mà runner định nghĩa trước mỗi lệnh (`name.gif`, `name 2.gif`, `name 3.gif`…).
- Trường `description` (một dòng) hiện trên thẻ Settings và dưới bánh xe khi rê vào ô.

### Add BG (thêm nền)
- Nền: gradient / solid / ảnh.
- Điều chỉnh: padding, bo góc, đổ bóng, tỉ lệ khung.
- Lưu `name-bg.ext`.

## 5. Tùy biến

**Manifest**: `~/.config/flickwheel/actions.json`, tạo khi chạy lần đầu, **không bao giờ bị ghi đè**. Sau khi sửa dùng menu **Reload actions**.

```json
[{ "id": "copy-path", "label": "Copy path", "wheel": "control", "accepts": ["*"], "command": "printf '%s' \"$INPUT\" | pbcopy" }]
```

| Trường | Ý nghĩa |
|---|---|
| `id` | chuỗi duy nhất |
| `label` | chữ trên ô |
| `wheel` | `shift`, `command` hoặc `control` |
| `accepts` | đuôi file viết thường, hoặc `"*"` (không phân biệt hoa thường); `"!ext"` loại một đuôi (`["*", "!png"]`); `"dir"` = thư mục thường, không phải gói `.app` |
| `command` | chạy bằng `/bin/zsh -lc` |
| `icon` | tùy chọn, tên SF Symbol |
| `timeout` | tùy chọn, số giây trước khi bị kill (mặc định 120). Action video đặt 1800 đến 7200 |
| `description` | tùy chọn, mô tả một dòng |
| `multi` | tùy chọn, chạy một lần cho hai file thả cùng lúc (`INPUTS` chứa cả hai) |

**An toàn (điểm bán hàng)**: đường dẫn CHỈ truyền qua biến môi trường `INPUT` (đường dẫn đầy đủ), `DIR` (thư mục cha), `NAME` (tên không đuôi). Không bao giờ nối vào chuỗi lệnh, nên tên file lạ không phá được lệnh. Luôn bọc nháy: `"$INPUT"`.

Entry không hợp lệ bị bỏ qua và báo trong một notification.

**Settings** (menu bar → Settings…, ⌘,): cửa sổ resize được, 3 vùng.
- Sidebar: ba bánh xe, mỗi cái một màu cố định (Shift xanh dương ⇧, Command tím ⌘, Control cam ⌃), thêm mục **Packs** và **Translate** (API key + model Gemini). Màu này dùng lại cho icon, chip pack và preview.
- Danh sách action (đúng thứ tự trên bánh xe, kéo để đổi thứ tự, lưu ở `actionOrder`): mỗi dòng có icon, mô tả một dòng, nhãn nguồn (**Built in** / **Custom** / tên pack), chip loại file nhận (Image, Video, Audio, Docs, Code, Any) và công tắc bật/tắt. Có ô tìm kiếm và lọc theo loại file.
- Sidebar đếm **bật / tổng** cho mỗi bánh xe. Khung **Wheel preview** bên phải: chọn file mẫu (png, mp4, mp3, pdf, txt, json) để xem đúng bánh xe thật thu nhỏ, hiện "N of 8 slots used" và đối chiếu số liệu (`7 on = 4 on the wheel + 3 for other file types`), kèm cảnh báo liệt kê các action bị cắt do giới hạn 8 ô. Chip loại file chỉ hiện khi loại đó chiếm ít nhất 1/4 số đuôi file action nhận (một đuôi `gif` lẻ không biến bộ chuyển video thành action ảnh).
- Cửa sổ Settings có chiều rộng cố định và mở giữa vùng hiển thị của màn hình.
- Không còn khóa "đủ 8 thì không bật thêm được": luôn bật được, bánh xe chỉ hiện 8 action đầu phù hợp với file.
- Chỉ bật/tắt hiển thị, bật/tắt pack và đổi thứ tự, **không sửa actions.json**. Trạng thái lưu trong UserDefaults (`hiddenActionIDs`, `enabledPackIDs`, `actionOrder`). Trang Packs kết thúc bằng số "Adds to your wheels" cho mỗi bánh xe.

**Menu bar**: Settings… (⌘,) · Reload actions · Open actions.json · Accessibility status (granted / not granted) · Quit (⌘Q).

## 6. Giao diện bánh xe (để mô phỏng demo)

- Panel không kích hoạt, không viền, nổi, xuất hiện tại vị trí con trỏ.
- Các ô bo góc kiểu kính (SwiftUI materials), mỗi ô có icon SF Symbol + nhãn.
- Ô đang chọn tô màu accent. Hover phóng to nhẹ. Lúc xuất hiện có hiệu ứng spring.
- Ảnh kéo mặc định của Finder bị làm trống; thay bằng icon file nhỏ tại con trỏ, để tên file dài không che các ô.
- Nút Shift/Command/Control hiển thị theo `WheelKind`.

## 7. Quyền và cài đặt

- **Accessibility**: bắt buộc (global event monitor). Hộp thoại hệ thống hiện lần đầu. Menu hiển thị trạng thái, bấm khi chưa cấp sẽ mở System Settings. Cấp sau khi mở app thì bấm status item một lần để khởi động lại monitor.
- **Notifications**: nên cho phép để thấy kết quả.
- **Ký số**: ký ad-hoc (`CODE_SIGN_IDENTITY: "-"`) vì chưa có cert hợp lệ. Hệ quả: quyền Accessibility **bị reset mỗi lần build lại**. Muốn giữ thì đặt `CODE_SIGN_IDENTITY` + `DEVELOPMENT_TEAM` từ cert hợp lệ.
- Không sandbox. Hardened runtime bật (cờ `--options=runtime` đặt trong `project.yml`, vì Xcode bỏ qua khi ký ad-hoc).

Build:
```
xcodegen generate
xcodebuild -scheme FlickWheel -configuration Debug build
xcodebuild test -scheme FlickWheel
```

## 8. Quyết định kỹ thuật (nội dung cho mục "Under the hood")

- Phát hiện kéo: `NSEvent.addGlobalMonitorForEvents` cho `.leftMouseDragged`, `.leftMouseUp`, `.flagsChanged`. File lấy từ `NSPasteboard(name: .drag)`.
- Bánh xe: `NSPanel` không kích hoạt chứa view SwiftUI, đăng ký nhận file-URL drag, hit-test điểm thả để chọn ô.
- Chạy lệnh: `/bin/zsh -lc`, timeout mặc định 120 giây (`timeout` trong manifest ghi đè được).
- Có unit test cho phần Actions, Crop, Annotate, Background, PixelPerfect, Tools, Dev (Clone), Video (không chạm UI; test Video chạy ffmpeg thật nếu có).

## 9. Thông điệp có thể dùng (copy bank, tiếng Anh)

Headline gợi ý:
- "Drag. Flick. Done."
- "Your files, one flick away."

Value prop:
- "Drag a file in Finder, tap a modifier key, and drop it on a radial wheel to convert, annotate, compress or share it."

Điểm khác biệt (đều có thật):
- Chạy ngay tại chỗ đang kéo, không mở app khác, không menu chuột phải.
- Ba phím = ba bánh xe: convert, tools, file.
- Thấy đúng action hợp với loại file đang kéo.
- Tự viết action bằng một dòng shell, không bị ghi đè khi cập nhật.
- Đường dẫn chỉ qua biến môi trường, an toàn với tên file lạ.
- Không package bên thứ ba, không telemetry. Chỗ duy nhất app tự gọi mạng là Translate (Gemini), chỉ khi bạn dùng và đã dán key; ngoài ra chỉ các lệnh bạn tự định nghĩa (và `npx`, `git clone`) chạm mạng.

## 10. Không được nói trên landing page

- Đã notarize / có trên Mac App Store / có file .dmg: **sai**.
- Hỗ trợ Intel: **sai** (`ARCHS: arm64`).
- Đổi phím tắt, xử lý hàng loạt: **không có** (ngoài phạm vi phase 1). AI action duy nhất là Translate (Gemini, txt/md); đừng gợi ý AI cho thứ khác.
- Settings sửa được action: **sai**, chỉ bật/tắt hiển thị.
- Có bản tải sẵn: **chưa**. Chỉ build từ source.

## 11. Lưu ý trước khi dùng nguồn này

1. Khi README, CLAUDE.md và tài liệu này xung đột với code, code thắng.
2. Settings, ActionIcon, giới hạn 8 ô, `Video/`, `Dev/`, `Translate/`, `PixelPerfect/`, các pack và action mới đang là **thay đổi chưa commit** (git status: M/??). Commit trước khi công bố.
3. `sample-action.json` ở gốc repo là bộ ví dụ khác (WebP/AVIF, React TSX, srcset…), dùng để tham khảo "Make it yours", không phải mặc định.
4. Đã có ảnh wheel thật (xem mục 12). Chưa có ảnh các cửa sổ editor (Annotate, Crop, Add BG, các cửa sổ Video), nên landing chỉ liệt kê tính năng bằng chữ.
5. `~/.config/flickwheel/actions.json` trên máy bạn khác default (có thêm nhiều action riêng và bản sao các action của pack). Landing và tài liệu này chỉ theo **default trong code**, không theo file cá nhân.

## 12. Landing page đã tạo (`/landing/`)

HTML + CSS + JS thuần, không build, mở thẳng `landing/index.html` hoặc deploy GitHub Pages. Tổng khoảng 70 KB.

| File | Vai trò |
|---|---|
| `index.html` | Hero, How it works, Packs (bản sao tương tác của cửa sổ Settings), 3 wheels, Editors (gồm thẻ Video tools), Customize, Install |
| `style.css` | Dark-first, tự đổi sang light theo hệ thống, `prefers-reduced-motion` |
| `wheel.js` | Tab wheel ở hero, demo kéo-thả, nút Copy |
| `actions-data.js` | **Sinh tự động** từ `ActionRegistry.defaultManifest` (`accepts`, đuôi file đầu ra). Đổi default thì sinh lại, đừng sửa tay |
| `packs-data.js` | **Sinh tự động** từ `Resources/Packs/*.json` cho bản sao cửa sổ Settings |
| `gen-data.py` | Sinh lại `actions-data.js`, `packs-data.js` và `assets/sf/*.png` (icon SF Symbol, cần `swift`): `python3 landing/gen-data.py`. Đổi action, pack hoặc `ActionIcon` thì chạy lại |
| `assets/icons`, `assets/sf` | Icon file và SF Symbol dựng sẵn cho demo |
| `assets/wheel-{shift,command,control}.webp` | Ảnh wheel thật, 640x560, khoảng 12 KB mỗi ảnh |

Hành vi demo (đã test bằng Chrome headless):
- Chọn file `photo.png` / `clip.mp4` / `notes.txt`: chỉ hiện action có `accepts` khớp, giống app.
- Kéo chip file vào ô, hoặc Tab tới ô rồi Enter: hiện kết quả, ví dụ `WebP 80%: photo.png → photo.webp`. Action mở cửa sổ (Crop, Annotate...) chỉ hiện tên file.
- Phím S / C / K đổi sang Shift / Command / Control.
- Kiểm tra layout: 1440px và 375px, không overflow ngang.

Ảnh wheel thật:
- Dùng đúng `RadialWheelView` + `WheelAction` + `ActionIcon` của app, hiện trong `NSPanel` trong suốt trên nền gradient tự vẽ rồi chụp bằng `screencapture`. Vật liệu kính và icon SF Symbol là của app thật.
- Nền gradient là giả (để tránh lộ cửa sổ khác và nhẹ file). Icon file ở giữa là icon PNG của hệ thống.
- Độ phân giải 1x (màn hình 1920x1080), nên hơi mềm trên màn Retina. Muốn nét hơn thì chụp lại trên màn Retina.
- Harness chụp nằm ở thư mục tạm, **chưa lưu vào repo**.

Còn phải điền trong landing: `[REPO_URL]` (hero + footer), `[LICENSE]`, `[AUTHOR]`.

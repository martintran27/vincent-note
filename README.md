# Vincent Note

Công cụ ôn trắc nghiệm trên macOS, chạy AI local, không cần mạng. Rê chuột lên chấm xám ở góc trên bên phải màn hình, app chụp vùng màn hình cố định, đọc chữ bằng OCR của macOS, hỏi model qua Ollama, rồi hiện đáp án A/B/C/D bằng một chữ xám nhỏ ngay tại chỗ chấm. Không cần bàn phím.

## Cần có

- Máy Mac chip Apple Silicon, macOS 15.2 trở lên, RAM 32GB
- [Ollama](https://ollama.com) và model:

```bash
ollama pull qwen3:30b-a3b-thinking-2507-q4_K_M
```

## Build

```bash
./build.sh setup-signing   # chạy một lần: tạo chứng chỉ ký riêng trong .signing/
./build.sh                 # tạo Vincent Note.app
./build.sh test            # chạy bài kiểm tra
```

`setup-signing` tạo chứng chỉ tự ký nằm trong keychain riêng của dự án, không động tới login keychain. Nhờ đó app giữ nguyên danh tính qua các lần build, nên quyền Ghi màn hình đã cấp không bị mất. Nếu bỏ qua bước này, app được ký ad-hoc và mỗi lần build lại phải cấp quyền lại.

## Dùng

- **Hỏi:** rê chuột lên chấm xám mờ ở góc trên phải (hoặc lên chữ đáp án đang hiện) và giữ yên khoảng 0,5 giây. Mỗi lần hỏi, app chỉ chụp màn hình một lần. Nếu trong vùng không thấy ít nhất 2 đáp án dạng `A.` / `B)` thì app trả `?` ngay, không chạy model.
- **Chọn lại vùng:** rê chuột vào **góc trên cùng bên trái** màn hình và giữ yên 2 giây.
- **Bấm vào chấm xám** để mở menu *Chọn lại vùng / Thoát*.
- **Bấm đúp icon app** khi app đang chạy cũng mở màn hình chọn lại vùng.
- Phím tắt, nếu bàn phím dùng được:

| Phím | Việc |
|---|---|
| ⌃⌥A | Hỏi ngay cho vùng đã chọn |
| ⌃⌥R | Chọn lại vùng chụp |
| ⌃⌥Q | Thoát (tắt luôn Ollama nếu app đã bật nó) |

Ký hiệu: `…` là đang nghĩ, `?` là model không chắc hoặc không thấy câu hỏi, `!` là có lỗi hoặc app chưa có quyền Ghi màn hình.

Lần đầu chạy, vào System Settings → Privacy & Security → **Screen & System Audio Recording**, bật quyền cho app rồi mở lại app. Ảnh và chữ OCR của lần chụp gần nhất được lưu ở `~/Library/Caches/local.onthi/` để tiện kiểm tra lỗi.

File `cau-hoi-thu.html` có sẵn vài câu hỏi mẫu để thử.

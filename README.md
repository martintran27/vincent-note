# Vincent Note

Công cụ ôn trắc nghiệm trên macOS, chạy AI local, không cần mạng. Bấm phím tắt, app chụp vùng màn hình đã chọn, đọc chữ bằng OCR của macOS, hỏi model qua Ollama, rồi hiện đáp án A/B/C/D bằng một chữ xám nhỏ ở góc trên bên phải.

## Cần có

- Máy Mac chip Apple Silicon, macOS 15.2 trở lên, RAM 32GB
- [Ollama](https://ollama.com) và model:

```bash
ollama pull qwen3:30b-a3b-thinking-2507-q4_K_M
```

## Build

```bash
./build.sh        # tạo Vincent Note.app
./build.sh test   # chạy bài kiểm tra phần đọc đáp án
```

## Dùng

| Phím | Việc |
|---|---|
| ⌃⌥A | Hỏi đáp án cho vùng đã chọn |
| ⌃⌥R | Chọn lại vùng chụp |
| ⌃⌥Q | Thoát (tắt luôn Ollama nếu app đã bật nó) |

Ký hiệu hiện trên màn hình: `…` là đang nghĩ, `?` là không đọc được câu hỏi hoặc model không chắc, `!` là có lỗi.

Lần đầu chạy, cần cấp quyền **Screen & System Audio Recording** cho app trong System Settings, rồi mở lại app. App được ký ad-hoc, nên **mỗi lần build lại phải cấp lại quyền**. Khi bị ra `?`, xem ảnh và chữ OCR của lần chụp gần nhất ở `~/Library/Caches/local.onthi/`.

File `cau-hoi-thu.html` có sẵn vài câu hỏi mẫu để thử.

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

- **Hỏi:** rê chuột lên chấm xám mờ ở góc trên phải và giữ yên khoảng 0,5 giây. Chấm luôn đứng yên ở góc. Mỗi lần hỏi, app chỉ chụp màn hình một lần. Nếu trong vùng không thấy ít nhất 2 đáp án dạng `A.` / `B)` mà cũng không có đề tự luận thì app trả `?` ngay.
- **Đáp án hiện riêng, tách khỏi chấm**, mặc định nằm ngay bên trái chấm. **Kéo chữ đáp án** đi chỗ nào cũng được, app nhớ vị trí. Đáp án nằm yên tới khi anh hỏi câu mới. Chữ rất mờ, khoảng 20%, và tự chọn xám đậm hoặc xám nhạt theo màu nền bên dưới.
- **Tự luận (Accounting Principles, US GAAP, giáo trình Wild):** nếu trong vùng không có đáp án A/B/C/D, app giải theo dạng tự luận, mất khoảng 1–3 phút. Lời giải hiện **từng dòng một**, mỗi dòng là một bút toán hoặc một phép tính, ví dụ `Dec 10  Dr A/R 28,000 · Cr Sale revenue 28,000   2/5`. **Lướt trên dòng chữ** để chuyển dòng, mỗi lần lướt đi một dòng. Lời giải chỉ để tham khảo khi ôn: model chạy trên máy vẫn có thể sai.
- **Chọn lại vùng:** rê chuột vào **góc trên cùng bên trái** màn hình và giữ yên vài giây. Khi chấm xám ở góc phải đổi thành `+` thì kéo khung quanh câu hỏi. Màn hình không thay đổi gì và cửa sổ đang dùng vẫn giữ tiêu điểm. Bấm một cái mà không kéo để huỷ.
- **Thoát:** dùng Activity Monitor (tìm *VincentNote* → ✕), hoặc ⌃⌥Q. App không có menu, để không thao tác nào có thể lấy tiêu điểm.
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

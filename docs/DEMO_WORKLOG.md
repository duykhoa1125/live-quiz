# Nhật ký thực hiện & Hướng dẫn tự chạy Demo (ALB & ElastiCache)

File này lưu toàn bộ lịch sử thực hiện công việc, thao tác chi tiết, kết quả thực tế và hướng dẫn từng bước để bất kỳ thành viên nào (hoặc agent ở phiên làm việc mới) đều có thể **truy xuất lại** khi cần giải trình và **tự thực hiện lại demo** từ đầu.

> **Lưu ý bảo mật:** Tuyệt đối không ghi mật khẩu Valkey, AWS keys, token hay dữ liệu nhạy cảm vào file này. Luôn dùng placeholder như `<VALKEY_PASSWORD>`, `<ALB_DNS>`, `<EC2_A_ID>`.

---

## Hướng dẫn tự thực hiện demo nhanh (Runbook tổng hợp)

> **Trạng thái hiện tại:** Mới hoàn tất chuyển đổi tài liệu sang Markdown và thiết lập quy tắc ghi chép. **Chưa triển khai** hạ tầng AWS và mã nguồn lab. Phần lệnh thực thi cụ thể sẽ được cập nhật đầy đủ tại đây ngay khi dựng xong hạ tầng và ứng dụng.

### Tài liệu tham chiếu chính
- Đặc tả & tiêu chí bàn giao: [ALB_ElastiCache_Demo_Handover.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Demo_Handover.md)
- Kịch bản 20 phút & timeline từng demo (3 phút/demo): [ALB_ElastiCache_Noi_dung_chi_tiet.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Noi_dung_chi_tiet.md)
- Kiến thức nền tảng & Q&A: [ALB_ElastiCache_Kien_thuc_theo_slide.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Kien_thuc_theo_slide.md)

### Thông tin cấu hình môi trường thực tế (cập nhật khi triển khai)
| Thành phần | Giá trị / Placeholder | Ghi chú |
|---|---|---|
| AWS Region | `ap-southeast-1` (dự kiến) | Cập nhật region thực tế khi tạo |
| ALB DNS | `<ALB_DNS>` | HTTP port 80, dùng DNS AWS cấp |
| EC2 A (`BACKEND_ID=A`) | `<EC2_A_ID>` | Public subnet AZ1, truy cập qua SSM |
| EC2 B (`BACKEND_ID=B`) | `<EC2_B_ID>` | Public subnet AZ2, truy cập qua SSM |
| ElastiCache Valkey | `<VALKEY_ENDPOINT>:6379` | Node-based, 1 primary, 0 replica, TLS + RBAC (`quizlab:*`) |
| Thư mục code lab | `seminar-lab/alb-elasticache/` *(chưa tạo)* | Node.js 24 + Docker, container `quizlab` |

### Tóm tắt trình tự tự chạy 2 demo (sau khi đã dựng xong lab)
1. **Chuẩn bị trước khi trình diễn:**
   - Mở sẵn 2 phiên SSM tới EC2 A và EC2 B.
   - Mở sẵn AWS Console ở tab **Target Groups (`tg-main`) -> Targets** và tab **ElastiCache cluster**.
   - Kiểm tra `/health`, `/api/cache-status` trả `connected`, và reset phòng `demo` ở cả `memory` lẫn `elasticache`.
2. **Demo 1 — ALB (tối đa 3 phút):**
   - `0:00–0:40`: Mở `http://<ALB_DNS>/`, ở tab **ALB** gửi 20 request `/api/whoami` → xác nhận có cả `A` và `B`, `requestId` thay đổi.
   - `0:40–1:10`: Cho xem `tg-main` đang `healthy` cả 2 → qua SSM trên EC2 A chạy `docker stop quizlab` → tiếp tục gửi request.
   - `1:10–1:50`: Quan sát trên Console đến khi A chuyển `unhealthy` (ghi nhận thời gian thực tế) → gửi tiếp 20 request mặc định → các request thành công đều do `B` phục vụ.
   - `1:50–3:00`: Trên EC2 A chạy `docker start quizlab` → chờ `tg-main` đưa A về `healthy` → gửi lại request thấy cả `A` và `B`, chốt phạm vi.
3. **Demo 2 — ElastiCache (tối đa 3 phút):**
   - Đảm bảo A đã `healthy` và dữ liệu phòng `demo` đã reset sạch.
   - `0:00–0:40`: Chọn `store=memory`, ghi Alice 100 qua A (`/lab/a/...`), đọc qua B (`/lab/b/...`) → A có Alice, B rỗng (khẳng định `backendId`).
   - `0:40–1:30`: Chọn `store=elasticache`, bấm seed Alice 100 / Bob 150 / Chi 120 qua A → đọc qua B thấy đúng thứ tự Bob 150, Chi 120, Alice 100.
   - `1:30–2:00`: Update Alice 170 qua A → đọc qua B thấy Alice lên đầu; bấm lại PUT Alice 170 để chứng minh điểm giữ nguyên 170 (không cộng dồn).
   - `2:00–2:40`: Trên EC2 A chạy `docker stop quizlab` (hoặc restart) → đọc cache qua `/lab/b/...` thấy B vẫn đọc được bảng điểm bình thường.
   - `2:40–3:00`: Khởi động lại A, đọc lại qua A (nếu `tg-a` kịp `healthy`) và mở màn hình ElastiCache trên AWS Console xác nhận dịch vụ chạy thật.

---

## Bảng theo dõi trạng thái nghiệm thu (theo Mục 12 Handover)

| # | Tiêu chí | Trạng thái | Entry liên quan | Bằng chứng / Ghi chú |
|---|---|---|---|---|
| 1 | DNS ALB và tài nguyên AWS thật | Chưa chạy | — | — |
| 2 | Request qua `tg-main` thấy cả A/B | Chưa chạy | — | — |
| 3 | Stop A và `tg-main` tiếp tục qua B | Chưa chạy | — | — |
| 4 | Start A và quay lại `healthy` | Chưa chạy | — | — |
| 5 | Memory A/B độc lập | Chưa chạy | — | — |
| 6 | ElastiCache ghi A đọc B | Chưa chạy | — | — |
| 7 | Alice cập nhật 170 lên đầu | Chưa chạy | — | — |
| 8 | Restart A không xóa dữ liệu remote | Chưa chạy | — | — |
| 9 | 2 video dưới 3 phút cho từng demo | Chưa chạy | — | — |
| 10 | Cleanup và chi phí theo cấu hình | Chưa chạy | — | — |

---

## Nhật ký chi tiết các lần thực hiện

## Entry #1 — 2026-11-25 15:31 — Chuyển đổi 2 tài liệu DOCX sang Markdown và tạo quy tắc ghi chép (AGENTS.md)

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Tài liệu & Quy trình làm việc.
- **Mục tiêu:** Chuyển 2 file `.docx` sang `.md` để dễ đọc/truy xuất trực tiếp trong repo, đồng thời thiết lập quy tắc bắt buộc ghi nhật ký mỗi lần làm việc.
- **File tạo mới:**
  - `docs/ALB_ElastiCache_Noi_dung_chi_tiet.md` (chuyển từ `docs/ALB_ElastiCache_Noi_dung_chi_tiet.docx`)
  - `docs/ALB_ElastiCache_Kien_thuc_theo_slide.md` (chuyển từ `docs/ALB_ElastiCache_Kien_thuc_theo_slide.docx`)
  - `AGENTS.md` (quy tắc tự động áp dụng cho agent trong toàn repo)
  - `docs/DEMO_WORKLOG.md` (file nhật ký và runbook này)

### 2. Các thao tác đã thực hiện
1. Kiểm tra cấu trúc thư mục `docs/` và các công cụ có sẵn (`python3`, không có `pandoc`).
2. Kiểm tra XML bên trong 2 file `.docx` (`word/document.xml`, `word/_rels/document.xml.rels`, `word/styles.xml`) để xác định các style (`Title`, `Subtitle`, `Heading1`, `Heading2`), định dạng đậm (`<w:b/>`), ngắt dòng (`<w:br/>`), 46 hyperlink trên mỗi file và các bảng (17 bảng ở file nội dung chi tiết, 11 bảng ở file kiến thức theo slide).
3. Chạy script Python đọc trực tiếp XML trong file `.docx` để xuất ra 2 file `.md` tương ứng, giữ nguyên phân cấp heading, bảng Markdown, in đậm và toàn bộ link tài liệu AWS chính thức.
4. Tham khảo tài liệu `agy-customizations` (`rules.md`) để tạo `AGENTS.md` đặt ở gốc workspace (không dùng frontmatter để luôn kích hoạt theo phạm vi thư mục).
5. Tạo `docs/DEMO_WORKLOG.md` kèm phần Runbook tổng hợp, bảng nghiệm thu và Entry #1.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS`
- **Kết quả chi tiết:**
  - `docs/ALB_ElastiCache_Noi_dung_chi_tiet.md` và `docs/ALB_ElastiCache_Kien_thuc_theo_slide.md` đã được tạo hoàn chỉnh trong `docs/`, vẫn giữ nguyên 2 file `.docx` gốc.
  - `AGENTS.md` và `docs/DEMO_WORKLOG.md` đã có mặt tại gốc workspace và `docs/`.
- **Lỗi gặp phải:** Không có.

### 4. Cách tự thực hiện lại / Kiểm tra
- Khi cần đọc nội dung seminar hoặc kiến thức slide mà không cần mở Word, đọc trực tiếp `docs/ALB_ElastiCache_Noi_dung_chi_tiet.md` và `docs/ALB_ElastiCache_Kien_thuc_theo_slide.md`.
- Nếu `.docx` gốc được cập nhật sau này, có thể chuyển đổi lại bằng Python `zipfile` + `xml.etree.ElementTree` (giữ mapping `Title -> #`, `Heading1 -> ##`, `Heading2 -> ###`, `<w:br/> -> khoảng trắng`, hyperlink từ `word/_rels/document.xml.rels`, và `<w:tbl>` thành bảng Markdown).

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Nội dung 2 file `.md` được chuyển giữ nguyên nghĩa và cấu trúc từ `.docx` gốc tại thời điểm `2026-11-25`, chưa sửa đổi nội dung gốc.
- Chưa dựng hạ tầng AWS hay code lab trong bước này.

### 6. Đối chiếu tiêu chí nghiệm thu
- Bước chuẩn bị quy trình & tài liệu nền; chưa tác động trực tiếp đến 10 tiêu chí chạy thật trong bảng nghiệm thu.

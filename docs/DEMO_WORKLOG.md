# Nhật ký thực hiện & Hướng dẫn tự chạy Demo (ALB & ElastiCache)

File này lưu toàn bộ lịch sử thực hiện công việc, thao tác chi tiết, kết quả thực tế và hướng dẫn từng bước để bất kỳ thành viên nào (hoặc agent ở phiên làm việc mới) đều có thể **truy xuất lại** khi cần giải trình và **tự thực hiện lại demo** từ đầu.

> **Lưu ý bảo mật:** Tuyệt đối không ghi mật khẩu Valkey, AWS keys, token hay dữ liệu nhạy cảm vào file này. Luôn dùng placeholder như `<VALKEY_PASSWORD>`, `<ALB_DNS>`, `<EC2_A_ID>`.

---

## Hướng dẫn tự thực hiện demo nhanh (Runbook tổng hợp)

> **Trạng thái hiện tại:** Mới hoàn tất chuyển đổi tài liệu sang Markdown và thiết lập quy tắc ghi chép. **Chưa triển khai** hạ tầng AWS và mã nguồn lab. Phần lệnh thực thi cụ thể sẽ được cập nhật đầy đủ tại đây ngay khi dựng xong hạ tầng và ứng dụng.

### Tài liệu tham chiếu chính
- Đặc tả & tiêu chí bàn giao: [ALB_ElastiCache_Demo_Handover.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Demo_Handover.md)
- Checklist công việc trọn phần demo: [DEMO_TASKS.md](file:///home/khoa/projects/live-quiz/docs/DEMO_TASKS.md)
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

## Entry #2 — 2026-11-25 15:34 — Tạo danh sách công việc cho người phụ trách trọn phần Demo (`docs/DEMO_TASKS.md`)

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Tài liệu & Kế hoạch triển khai.
- **Mục tiêu:** Tổng hợp danh sách công việc chi tiết dạng checklist cho người phụ trách trọn phần demo (không làm slide), bám sát hoàn toàn 3 tài liệu gốc trong `docs/` và không thêm yêu cầu ngoài phạm vi.
- **File tạo/chỉnh sửa:**
  - Tạo mới: `docs/DEMO_TASKS.md`
  - Cập nhật: `docs/DEMO_WORKLOG.md` (bổ sung link tham chiếu tới `docs/DEMO_TASKS.md` và ghi Entry #2)

### 2. Các thao tác đã thực hiện
1. Đối chiếu trực tiếp các mục 1–12 của `docs/ALB_ElastiCache_Demo_Handover.md` cùng phần chuẩn bị demo ở Slide 5, Slide 9 và Slide 12 trong `docs/ALB_ElastiCache_Noi_dung_chi_tiet.md`.
2. Tách rõ ranh giới giữa phần việc của người làm demo (hạ tầng AWS, ứng dụng lab, kiểm thử, video dự phòng, tài liệu cấu hình/README/biên bản/chi phí, cleanup) và phần người làm slide (14 slide lý thuyết, bài nói 20 phút, Q&A).
3. Viết `docs/DEMO_TASKS.md` gồm: Ranh giới nhiệm vụ, Lộ trình 2 ngày, Checklist chi tiết Phần A–D (Hạ tầng AWS, Ứng dụng & Docker, Chạy thử & Video, Tài liệu & Cleanup), Phần mở rộng có điều kiện (chỉ làm khi lõi đã đạt) và Danh sách việc không làm.
4. Cập nhật mục tham chiếu và thêm Entry #2 vào `docs/DEMO_WORKLOG.md` theo đúng quy tắc trong `AGENTS.md`.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS`
- **Kết quả:** Đã tạo `docs/DEMO_TASKS.md` bám sát 100% tài liệu giao việc và kịch bản demo, không bổ sung công cụ hay yêu cầu thừa ngoài docs.

### 4. Cách tự thực hiện lại / Sử dụng
- Mở `docs/DEMO_TASKS.md` và đánh dấu lần lượt từng checkbox từ Ngày 1 đến Ngày 2 (ưu tiên làm xong Phần A + Phần B cho Demo ALB trước, sau đó đến ElastiCache, kiểm thử 3 lần, quay video, nghiệm thu và cleanup).
- Sau mỗi đầu việc hoàn thành, ghi bổ sung Entry mới vào `docs/DEMO_WORKLOG.md`.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Tài liệu `docs/DEMO_TASKS.md` chỉ là checklist công việc; mọi thông số chi tiết khi làm xong phải được cập nhật bằng giá trị quan sát thật (resource IDs, thời gian phát hiện `unhealthy`, chi phí thực tế theo bảng giá AWS hiện hành).
- Phần mở rộng ở Mục 3 trong `docs/DEMO_TASKS.md` là tùy chọn theo Mục 9 của Handover, không phải điều kiện nghiệm thu bắt buộc.

### 6. Đối chiếu tiêu chí nghiệm thu
- Phục vụ quản lý và kiểm tra đầy đủ 10 tiêu chí ở Mục 12 của `docs/ALB_ElastiCache_Demo_Handover.md`; hiện tại cả 10 tiêu chí vẫn ở trạng thái `Chưa chạy`.

## Entry #3 — 2026-11-25 15:47 — Cài AWS CLI v2 và xây dựng mã nguồn ứng dụng Lab (`seminar-lab/alb-elasticache/`)

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Hạ tầng (công cụ CLI) & Ứng dụng & Cache.
- **Mục tiêu:** Cài AWS CLI v2 lên máy làm việc và tạo trọn bộ mã nguồn ứng dụng lab (Node.js 24 + Docker + UI 2 tab) bám sát hợp đồng Mục 5 trong `docs/ALB_ElastiCache_Demo_Handover.md`.
- **Công cụ & File đã tạo/chỉnh sửa:**
  - Cài đặt công cụ: `/home/khoa/.local/bin/aws` (`aws-cli/2.42.3`, cài tại `/home/khoa/.local/aws-cli`).
  - Mã nguồn mới trong `seminar-lab/alb-elasticache/`:
    - `seminar-lab/alb-elasticache/package.json`
    - `seminar-lab/alb-elasticache/Dockerfile`
    - `seminar-lab/alb-elasticache/.dockerignore`
    - `seminar-lab/alb-elasticache/.env.example`
    - `seminar-lab/alb-elasticache/src/server.js`
    - `seminar-lab/alb-elasticache/public/index.html`
    - `seminar-lab/alb-elasticache/README.md`

### 2. Các thao tác đã thực hiện
1. Kiểm tra công cụ sẵn có trên máy (`aws`, `node`, `npm`, `docker`, `terraform`, `~/.aws`) — xác nhận đều chưa có và chưa cấu hình credentials AWS.
2. Tải gói cài đặt chính thức `https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip` về `/tmp/awscliv2.zip`.
3. Giải nén bằng Python (giữ nguyên Unix permission và symlink) sang `/tmp/awscli-extract`, cài đặt vào `/home/khoa/.local/aws-cli` và tạo symlink thực thi tại `/home/khoa/.local/bin/aws`. Xóa các file tạm ở `/tmp/`.
4. Xây dựng `seminar-lab/alb-elasticache/src/server.js` bằng Node.js `http` + `ioredis` với các hành vi:
   - Tự strip prefix `/lab/a` và `/lab/b` trước khi khớp route.
   - Mọi API trả JSON và `Cache-Control: no-store`.
   - `/health` độc lập hoàn toàn với ElastiCache; `/api/cache-status` kiểm tra `PING` qua TLS/RBAC và ẩn thông tin nhạy cảm.
   - `store=memory` dùng `Map` trong tiến trình; `store=elasticache` dùng 1 client `ioredis` tái sử dụng (`enableReadyCheck: false`, `enableOfflineQueue: false`, `ZADD`, `EXPIRE 3600`, `ZRANGE ... REV WITHSCORES`, `DEL`), trả HTTP `503` khi lỗi và không fallback ngầm về RAM.
   - Xử lý `SIGTERM`/`SIGINT` đóng server nhanh để `docker stop quizlab` dừng tức thì khi demo.
5. Xây dựng `public/index.html` với 2 tab `ALB` (gửi 20 request `/api/whoami`, đếm A/B/lỗi) và `Shared leaderboard` (chọn `roomId`, `store`, ghi qua `/lab/a`, đọc `/lab/a` & `/lab/b`, seed 3 người chơi, update Alice 170, reset phòng, kiểm tra `cache-status`, hiển thị lỗi thật).
6. Tạo `Dockerfile` (`node:24-alpine`), `.dockerignore`, `.env.example` và `README.md`.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PARTIAL` (Đã cài AWS CLI và tạo xong mã nguồn lab; chưa có AWS credentials để thao tác lên AWS thật, chưa có `node`/`docker` tại máy local để chạy thử container tại chỗ).
- **Output thực tế:** `/home/khoa/.local/bin/aws --version` trả về `aws-cli/2.42.3 Python/3.14.10 Linux/6.6.87.2-microsoft-standard-WSL2 exe/x86_64.ubuntu.24`.
- **Lỗi/Vướng mắc hiện tại:**
  - Chưa có credentials AWS trong `~/.aws` hoặc biến môi trường `AWS_*`, nên chưa thể chạy `aws sts get-caller-identity` và chưa thể tạo tài nguyên AWS.

### 4. Cách tự thực hiện lại / Bước tiếp theo
- Để chạy `aws` trực tiếp không cần gõ đường dẫn đầy đủ, đảm bảo `~/.local/bin` nằm trong `PATH` (`export PATH="$HOME/.local/bin:$PATH"`).
- Cấu hình tài khoản AWS (`aws configure` hoặc `aws configure sso`) bằng credentials được cấp, sau đó kiểm tra quyền bằng `aws sts get-caller-identity` trước khi tạo hạ tầng trong `ap-southeast-1`.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Code đã viết đúng đặc tả Mục 5 Handover nhưng **chưa chạy thử trực tiếp trên Node 24/Docker local** do máy hiện chưa cài `node` và `docker`; cần test ngay sau khi cài/build trên EC2 (hoặc máy có Docker/Node).
- Chưa dựng bất kỳ tài nguyên AWS nào ở bước này nên chưa phát sinh chi phí AWS.

### 6. Đối chiếu tiêu chí nghiệm thu
- Chuẩn bị mã nguồn phục vụ các tiêu chí 2–8 của Mục 12 Handover; toàn bộ 10 tiêu chí vẫn ở trạng thái `Chưa chạy`.

## Entry #4 — 2026-11-25 15:50 — Khôi phục và kiểm tra lại `public/index.html`

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Ứng dụng & Cache.
- **Mục tiêu:** Kiểm tra nguyên nhân và khôi phục file `seminar-lab/alb-elasticache/public/index.html` sau khi file bị rỗng (`0` byte lúc `15:49:01`), đồng thời kiểm tra khớp ID phần tử HTML/JS và cấu trúc với `src/server.js`.
- **File chỉnh sửa:** `seminar-lab/alb-elasticache/public/index.html`

### 2. Các thao tác đã thực hiện
1. Kiểm tra kích thước và timestamp file bằng `ls -la --full-time`, phát hiện `public/index.html` có kích thước `0` byte tại mốc `2026-11-25 15:49:01` (trong khi trước đó ở `15:47` là `22,866` byte — khả năng do lưu đè từ trình soạn thảo khi file đang mở lúc sửa).
2. Kiểm tra lại toàn bộ `src/server.js` (534 dòng) để đối chiếu route, method, query parameter và format JSON trả về.
3. Ghi khôi phục đầy đủ nội dung `seminar-lab/alb-elasticache/public/index.html`, bổ sung dọn lỗi nhỏ khi ô `Score` để trống (`rawScore === '' ? Number.NaN : Number(rawScore)`) và đưa `escapeHtml` lên đầu IIFE.
4. Chạy script Python kiểm tra cân bằng thẻ HTML, đối chiếu toàn bộ `getElementById` trong `<script>` với các `id` khai báo trong HTML, và kiểm tra JSON của `package.json`.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS` (Kiểm tra cấu trúc tĩnh đạt; vẫn chưa chạy runtime do máy chưa cài `node`/`docker`).
- **Kết quả kiểm tra:**
  - `public/index.html`: đã khôi phục đầy đủ (không còn 0 byte), thẻ HTML đóng mở cân bằng (`HTML stack remaining: []`, `HTML errors: []`), không thiếu element ID (`Missing element IDs: []`).
  - `src/server.js`: còn nguyên vẹn 534 dòng (`14,461` byte).

### 4. Cách tự thực hiện lại / Kiểm tra
- Khi build/chạy bằng Docker hoặc Node.js 24, mở `http://localhost:3000/` (hoặc `http://<ALB_DNS>/`) để kiểm tra 2 tab `ALB` và `Shared leaderboard`.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Nếu trình soạn thảo đang mở sẵn file khi công cụ sửa file, cần reload file (hoặc không bấm `Ctrl+S` trên tab cũ chưa đồng bộ) để tránh ghi đè mất nội dung.

### 6. Đối chiếu tiêu chí nghiệm thu
- Khôi phục giao diện UI phục vụ các tiêu chí 2–8 của Mục 12 Handover; 10 tiêu chí vẫn ở trạng thái `Chưa chạy`.

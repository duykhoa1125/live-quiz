# Nhật ký thực hiện & Hướng dẫn tự chạy Demo (ALB & ElastiCache)

File này lưu toàn bộ lịch sử thực hiện công việc, thao tác chi tiết, kết quả thực tế và hướng dẫn từng bước để bất kỳ thành viên nào (hoặc agent ở phiên làm việc mới) đều có thể **truy xuất lại** khi cần giải trình và **tự thực hiện lại demo** từ đầu.

> **Lưu ý bảo mật:** Tuyệt đối không ghi mật khẩu Valkey, AWS keys, token hay dữ liệu nhạy cảm vào file này. Luôn dùng placeholder như `<VALKEY_PASSWORD>`, `<ALB_DNS>`, `<EC2_A_ID>`.

---

## Hướng dẫn tự thực hiện demo nhanh (Runbook tổng hợp)

> **Trạng thái hiện tại:** **Đã dựng hoàn chỉnh hạ tầng AWS thật tại `ap-southeast-2`**, deploy ứng dụng `quizlab` lên EC2 A & B, kết nối Valkey `8.2.0` qua TLS + RBAC thành công, và **kiểm thử đạt cả 2 kịch bản Demo ALB & Demo ElastiCache qua 3 lần chạy liên tiếp**. Hiện lab đang chạy để người phụ trách mở trình duyệt tập thao tác, chụp ảnh console và quay 2 video dự phòng, sau đó chạy cleanup.

### Tài liệu tham chiếu chính
- Đặc tả & tiêu chí bàn giao: [ALB_ElastiCache_Demo_Handover.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Demo_Handover.md)
- Checklist công việc trọn phần demo: [DEMO_TASKS.md](file:///home/khoa/projects/live-quiz/docs/DEMO_TASKS.md)
- Cấu hình AWS, chi phí & cleanup: [AWS_CONFIG_COST_CLEANUP.md](file:///home/khoa/projects/live-quiz/docs/AWS_CONFIG_COST_CLEANUP.md)
- Biên bản nghiệm thu (đã điền số đo thật): [ACCEPTANCE_REPORT.md](file:///home/khoa/projects/live-quiz/docs/ACCEPTANCE_REPORT.md)
- Kịch bản 20 phút & timeline từng demo (3 phút/demo): [ALB_ElastiCache_Noi_dung_chi_tiet.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Noi_dung_chi_tiet.md)
- Kiến thức nền tảng & Q&A: [ALB_ElastiCache_Kien_thuc_theo_slide.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Kien_thuc_theo_slide.md)

### Thông tin cấu hình môi trường thực tế
| Thành phần | Giá trị thực tế | Ghi chú |
|---|---|---|
| AWS Region | `ap-southeast-2` (Sydney) | `ap-southeast-1` bị chặn bởi SCP `p-3qq7zdmg` |
| ALB DNS | `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com` | HTTP port 80, SG mở cho `117.5.142.230/32` |
| EC2 A (`BACKEND_ID=A`) | `i-0cca77524a1964c16` (`t3.micro`, `ap-southeast-2a`) | Vận hành qua SSM Session Manager |
| EC2 B (`BACKEND_ID=B`) | `i-0ccf80b64328d1526` (`t3.micro`, `ap-southeast-2b`) | Vận hành qua SSM Session Manager |
| ElastiCache Valkey | `master.quizlab-valkey.x4rjiz.apse2.cache.amazonaws.com:6379` | Valkey `8.2.0`, `cache.t4g.micro`, 1 primary, 0 replica, TLS + RBAC (`quizlab:*`) |
| Thư mục code lab | `seminar-lab/alb-elasticache/` | Node.js 24 + Docker, container `quizlab` (`--restart unless-stopped`) |

### Tóm tắt trình tự tự chạy 2 demo (đã kiểm chứng trên AWS thật)
1. **Chuẩn bị trước khi trình diễn:**
   - Mở trang lab: `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com/`
   - Mở phiên SSM tới EC2 A:
     ```bash
     export PATH="$HOME/.local/bin:$PATH"
     aws ssm start-session --region ap-southeast-2 --target i-0cca77524a1964c16
     ```
   - Mở sẵn AWS Console ở tab **EC2 → Target Groups (`quizlab-tg-main`) → Targets** và tab **ElastiCache → Valkey caches (`quizlab-valkey`)**.
   - Kiểm tra cả 2 target đang `healthy`, bấm **Kiểm tra Cache Status (A & B)** đều `connected: true`, và reset phòng `demo` ở cả `memory` lẫn `elasticache`.
2. **Demo 1 — ALB (tối đa 3 phút):**
   - `0:00–0:40`: Ở tab **ALB**, bấm **Gửi 20 request (`/api/whoami`)** → xác nhận có cả `A` và `B`, `requestId` thay đổi.
   - `0:40–1:10`: Cho xem `quizlab-tg-main` đang `healthy` cả 2 → trong phiên SSM trên EC2 A chạy `sudo docker stop quizlab` → bấm gửi request tiếp.
   - `1:10–1:50`: Quan sát Console chuyển A sang `unhealthy` *(thực tế mất khoảng `7.3s–13.2s`, có thể thấy `502` lúc chuyển tiếp)* → bấm **Gửi 20 request** → 20/20 request do `B` phục vụ.
   - `1:50–3:00`: Trên EC2 A chạy `sudo docker start quizlab` → chờ ~8s để A về `healthy` → gửi lại request thấy cả `A` và `B`, chốt phạm vi.
3. **Demo 2 — ElastiCache (tối đa 3 phút):**
   - Đảm bảo A đã `healthy` và dữ liệu phòng `demo` đã reset sạch.
   - `0:00–0:40`: Chọn `memory`, bấm **Ghi Alice = 100 qua A**, đọc A thấy Alice 100, đọc B thấy `(Trống)`.
   - `0:40–1:30`: Chọn `elasticache`, bấm **Seed 3 người chơi qua A**, bấm **Đọc từ B** thấy đúng thứ tự Bob 150, Chi 120, Alice 100 (`backendId: B`).
   - `1:30–2:00`: Bấm **Update Alice = 170 qua A** (bấm 2 lần chứng minh không cộng dồn) → bấm **Đọc từ B** thấy Alice lên đầu với `170`.
   - `2:00–2:40`: Trên EC2 A chạy `sudo docker stop quizlab` → bấm **Đọc từ B** thấy B vẫn đọc được bảng điểm bình thường.
   - `2:40–3:00`: Chạy `sudo docker start quizlab` trên A, đọc lại qua A (nếu kịp) và mở màn hình `quizlab-valkey` trên AWS Console xác nhận chạy thật.
4. **Cleanup khi xong:** `./seminar-lab/alb-elasticache/cleanup-aws.sh --yes`

---

## Bảng theo dõi trạng thái nghiệm thu (theo Mục 12 Handover)

| # | Tiêu chí | Trạng thái | Entry liên quan | Bằng chứng / Ghi chú |
|---|---|---|---|---|
| 1 | DNS ALB và tài nguyên AWS thật | **Đạt** | Entry #5 | `quizlab-alb` + 2 EC2 + `quizlab-valkey` chạy thật tại `ap-southeast-2` |
| 2 | Request qua `tg-main` thấy cả A/B | **Đạt** | Entry #5 | 3 lượt chạy: `10/10`, `9/11`, `9/11`, 20 `requestId` khác nhau |
| 3 | Stop A và `tg-main` tiếp tục qua B | **Đạt** | Entry #5 | A `unhealthy` sau `9.02s` / `13.16s` / `7.29s`; 20 req sau đó `B=20, ERR=0` |
| 4 | Start A và quay lại `healthy` | **Đạt** | Entry #5 | A `healthy` lại sau `7.24s` / `7.93s` / `7.97s`; 20 req sau đó A/B cùng xử lý |
| 5 | Memory A/B độc lập | **Đạt** | Entry #5 | A có `alice=100`, B trả `[]` (3/3 lượt) |
| 6 | ElastiCache ghi A đọc B | **Đạt** | Entry #5 | Seed qua A, B đọc `[bob: 150, chi: 120, alice: 100]` (3/3 lượt) |
| 7 | Alice cập nhật 170 lên đầu | **Đạt** | Entry #5 | Update 170 (lặp 2 lần không tăng thêm), B đọc Alice đầu `170` (3/3 lượt) |
| 8 | Restart A không xóa dữ liệu remote | **Đạt** | Entry #5 | Stop A -> B vẫn đọc được; Start A -> A đọc lại được (3/3 lượt) |
| 9 | 2 video dưới 3 phút cho từng demo | **Đạt** | Entry #11, #12 | `demo1.mp4` (`1m33s`) & `docs/demo2.mp4` (`2m13s`), liền mạch, có Console + SSM thật |
| 10 | Cleanup và chi phí theo cấu hình | Chờ cleanup | Entry #5 | Đã tính chi phí & tạo `cleanup-aws.sh`; chờ chạy sau khi quay video & thuyết trình |

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

## Entry #5 — 2026-11-25 16:25 — Cài thêm công cụ, dựng hoàn chỉnh hạ tầng AWS (`ap-southeast-2`), deploy app và kiểm thử 3 lần cả 2 Demo

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Hạ tầng AWS, Ứng dụng & Cache, Kiểm thử & Demo, Tài liệu.
- **Mục tiêu:** Cài các công cụ còn thiếu (`session-manager-plugin`, Node.js 24, thêm `~/.local/bin` vào `PATH`), kiểm thử local, dựng toàn bộ hạ tầng AWS thật (VPC, SG, IAM/SSM, 2 EC2, ALB + 3 Target Group + Listener Rules, ElastiCache for Valkey TLS + RBAC), deploy container `quizlab` lên A/B, kiểm thử lặp lại 3 lần cả 2 kịch bản Demo ALB và Demo ElastiCache, và lập tài liệu cấu hình/chi phí/nghiệm thu/script cleanup.
- **Công cụ & File tạo/cập nhật:**
  - Công cụ local tại `/home/khoa/.local/bin/`: `session-manager-plugin` (`1.2.896.0`), `node` (`v24.22.3`), `npm` (`11.19.1`), thêm `export PATH="$HOME/.local/bin:$PATH"` vào `~/.bashrc`.
  - Repo files: `.gitignore`, `seminar-lab/alb-elasticache/cleanup-aws.sh`, `seminar-lab/alb-elasticache/README.md`, `docs/AWS_CONFIG_COST_CLEANUP.md`, `docs/ACCEPTANCE_REPORT.md`, `docs/DEMO_TASKS.md`, `docs/DEMO_WORKLOG.md`.
- **Tài nguyên AWS đã tạo tại `ap-southeast-2` (Account `493093379780`, tag `Project=quiz-service-seminar`):**
  - IAM & SSM: `quizlab-ec2-ssm-role` (+ policy `AmazonSSMManagedInstanceCore` và inline `quizlab-read-valkey-param`), `quizlab-ec2-ssm-profile`, SSM Parameter `SecureString` `/quizlab/valkey_password`.
  - VPC `vpc-0ef86bf0b601de975`, IGW `igw-038e8ffb953796db9`, public subnets `subnet-073c999af56a95c0b` (`2a`) & `subnet-0644bedb5397a6153` (`2b`), private subnets `subnet-07949064af01a3939` (`2a`) & `subnet-093534aa4d586dc05` (`2b`), route tables `rtb-02a64f7cdd79309b` & `rtb-06c6510df171026dd`.
  - Security Groups: `sg-0e4de45ba1e80ee23` (ALB, TCP 80 từ `117.5.142.230/32`), `sg-04448c78b976fe9d4` (backend, TCP 3000 từ SG ALB), `sg-0d62598f5f395beb9` (cache, TCP 6379 từ SG backend).
  - EC2: `i-0cca77524a1964c16` (`quizlab-ec2-a`, `t3.micro`, AL2023 `ami-09a2f74ce8538e414`), `i-0ccf80b64328d1526` (`quizlab-ec2-b`, `t3.micro`, AL2023 `ami-09a2f74ce8538e414`).
  - ALB: `quizlab-alb` (`quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`), Target Groups `quizlab-tg-main`, `quizlab-tg-a`, `quizlab-tg-b`, Listener HTTP 80 và rules priority 10 (`/lab/a`, `/lab/a/*`) và 20 (`/lab/b`, `/lab/b/*`).
  - ElastiCache: `quizlab-valkey` (Valkey `8.2.0`, `cache.t4g.micro`, cluster mode disabled, 1 primary, 0 replica, `master.quizlab-valkey.x4rjiz.apse2.cache.amazonaws.com:6379`, TLS required), subnet group `quizlab-cache-subnet-group`, user group `quizlab-user-group`, users `quizlab-app` (`quizlab`, `~quizlab:*`) & `quizlab-default-off` (`default`, `off -@all`).

### 2. Các thao tác đã thực hiện
1. Cài đặt `session-manager-plugin` (từ gói Ubuntu 64-bit chính thức của AWS) và Node.js `v24.22.3` vào `/home/khoa/.local/bin`, cập nhật `~/.bashrc`.
2. Cài `npm install` trong `seminar-lab/alb-elasticache/` và chạy kiểm thử smoke test local trên Node 24 (kiểm tra `/`, `/health`, `/api/whoami`, strip prefix `/lab/a` & `/lab/b`, `store=memory`, lỗi `503` khi `store=elasticache` chưa cấu hình không fallback, `DELETE`, validation `400`).
3. Kiểm tra danh tính (`aws sts get-caller-identity`) ra `arn:aws:iam::493093379780:user/khoa-cli` (`AdministratorAccess`) và probe các region: phát hiện `ap-southeast-1` cùng 10 region khác bị chặn bởi SCP `p-3qq7zdmg`, trong khi `ap-southeast-2` được phép hoàn toàn.
4. Dựng IAM Role/Instance Profile cho SSM, VPC/Subnets/IGW/Route Tables, 3 Security Groups, 2 EC2 (cài Docker qua user-data), ALB + 3 Target Groups (`5s` interval, `2s` timeout, threshold `2/2`, stickiness `false`, `round_robin`) + Listener Rules.
5. Tạo ElastiCache Subnet Group, tạo RBAC users (`quizlab-app` + `quizlab-default-off` tắt `default`), User Group `quizlab-user-group`, và Replication Group `quizlab-valkey`.
6. Đóng gói app `seminar-lab/alb-elasticache` và deploy qua `aws ssm send-command` để build & chạy container `quizlab` (`--restart unless-stopped`) trên EC2 A & B; kiểm thử xong Demo 1 (ALB) trước khi nối cache.
7. Sau khi `quizlab-valkey` đạt trạng thái `available` (sau `270s`), xoay mật khẩu `quizlab-app` lưu vào SSM Parameter Store `SecureString` `/quizlab/valkey_password`, cập nhật `/etc/quizlab/env` (`chmod 600`) trên A & B qua SSM, restart container, kiểm tra `/api/cache-status` qua ALB, và chạy 3 lượt kiểm thử end-to-end cho cả Demo 1 & Demo 2 (cuối mỗi lượt reset sạch phòng `demo`).

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS` (8/10 tiêu chí kỹ thuật đã đạt trên AWS thật qua 3 lượt chạy; còn quay 2 video & cleanup cuối buổi).
- **Local smoke test:** `ALL_LOCAL_SMOKE_TESTS_PASSED`.
- **Demo 1 (ALB) — 3 lượt chạy thật qua `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`:**
  - **Lượt 1:** Trước stop `A=10, B=10, ERR=0` (20 `requestId` khác nhau); sau `docker stop quizlab` trên A qua SSM (`1.73s`), thấy `HTTP_502` lúc chuyển tiếp ở `+2.39s` và `+5.66s`, A chuyển `unhealthy` sau **`9.02s`**, 20 req tiếp theo `A=0, B=20, ERR=0`; sau `docker start quizlab`, A hồi phục `healthy` sau **`7.24s`**, 20 req sau đó `A=9, B=11, ERR=0`.
  - **Lượt 2:** Trước stop `A=9, B=11, ERR=0`; A `unhealthy` sau **`13.16s`**; khi A dừng `B=20, ERR=0`; A `healthy` lại sau **`7.93s`**; sau hồi phục `A=10, B=10, ERR=0`.
  - **Lượt 3:** Trước stop `A=9, B=11, ERR=0`; A `unhealthy` sau **`7.29s`**; khi A dừng `B=20, ERR=0`; A `healthy` lại sau **`7.97s`**; sau hồi phục `A=10, B=10, ERR=0`.
- **Demo 2 (ElastiCache) — 3 lượt chạy thật:**
  - `/lab/a/api/cache-status` và `/lab/b/api/cache-status` đều trả `HTTP 200`, `connected: true`, `tls: true`, `ping: "PONG"`, `latencyMs: 1`.
  - `store=memory`: PUT `alice=100` qua `/lab/a/` → GET `/lab/a/` có `[alice: 100]`, GET `/lab/b/` trả `[]` (3/3 lượt).
  - `store=elasticache`: Seed `alice=100, bob=150, chi=120` qua A → đọc qua B thấy `[bob: 150, chi: 120, alice: 100]` (3/3 lượt).
  - Update `alice=170` (gửi 2 lần liên tiếp) qua A → đọc qua B thấy `[alice: 170, bob: 150, chi: 120]` (không cộng dồn, 3/3 lượt).
  - `docker stop quizlab` trên A → đọc qua `/lab/b/` vẫn thấy `[alice: 170, bob: 150, chi: 120]` (3/3 lượt); `docker start quizlab` trên A → đọc qua `/lab/a/` vẫn thấy `[alice: 170, bob: 150, chi: 120]` (3/3 lượt).
- **Lỗi gặp phải & cách khắc phục:**
  1. `ap-southeast-1` bị SCP `p-3qq7zdmg` từ chối → probe các region và xác định `ap-southeast-2` được phép hoàn toàn.
  2. `create-user` cho `default` của Valkey với `--no-password-required` bị từ chối (`InvalidParameterCombination`) → tạo user `quizlab-default-off` kèm password ngẫu nhiên và access string `off -@all`.
  3. `ssm put-parameter` không cho truyền `--overwrite` cùng `--tags` và làm lộ mật khẩu tạm trong log lỗi của lần chạy thử → đã xoay lại mật khẩu mới cho `quizlab-app`, tách lệnh `put-parameter --overwrite` và `add-tags-to-resource`, và xóa file tạm `/tmp/quizlab_valkey.env`.

### 4. Cách tự thực hiện lại / Chạy lại demo
- Xem phần **"Hướng dẫn tự thực hiện demo nhanh (Runbook tổng hợp)"** ở đầu file này, [README.md](file:///home/khoa/projects/live-quiz/seminar-lab/alb-elasticache/README.md) và [AWS_CONFIG_COST_CLEANUP.md](file:///home/khoa/projects/live-quiz/docs/AWS_CONFIG_COST_CLEANUP.md).

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Hạ tầng dùng `ap-southeast-2` vì giới hạn SCP của AWS Organization trên tài khoản lab.
- Thời gian chuyển `unhealthy` thực tế dao động (`7.29s – 13.16s` qua 3 lần đo) tùy pha của chu kỳ health check 5s, và có `502` chuyển tiếp trước khi target bị loại — đúng lý thuyết ALB ở Slide 4 & 5.
- Chưa thử cache failover/replica/snapshot/durability, Auto Scaling, HTTPS/WAF/Cognito, phục hồi WebSocket hay benchmark DB.

### 6. Đối chiếu tiêu chí nghiệm thu
- Cập nhật bảng nghiệm thu: Tiêu chí `1` đến `8` chuyển sang **Đạt**; Tiêu chí `9` (2 video ≤ 3 phút) ở trạng thái `Chờ quay`; Tiêu chí `10` (Cleanup & chi phí) đã có ước tính & script cleanup, chờ chạy dọn sau khi quay video & thuyết trình.

## Entry #6 — 2026-11-25 16:41 — Thiết kế lại giao diện `public/index.html` theo phong cách Neo-Brutalism và redeploy lên AWS

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Ứng dụng & Cache.
- **Mục tiêu:** Thiết kế lại giao diện web của ứng dụng lab theo phong cách **Neo-Brutalism** dựa trên bảng màu tham chiếu của người dùng (`#FE90E8`, `#C0F7FE`, `#99E885`, `#F7CB46`, `#FFDC8B`, `#000000`, nền kem lưới chấm `#FAF6E8`), đồng thời build/deploy lại lên cả EC2 A và EC2 B.
- **File chỉnh sửa:** `seminar-lab/alb-elasticache/public/index.html`

### 2. Các thao tác đã thực hiện
1. Thiết kế lại toàn bộ CSS và cấu trúc khung trình bày trong `seminar-lab/alb-elasticache/public/index.html` (giữ nguyên 1 file HTML/JS thuần, không thêm bước build hay CDN ngoài):
   - Nền kem `#FAF6E8` kèm lưới chấm đen, khung tiêu đề kiểu Figma frame có 4 ô vuông ở 4 góc và các pill tag `CONCEPT // AWS REAL LAB`, `CACHE-CONTROL: NO-STORE`.
   - Viền đen đậm (`3px` / `2px solid #000000`), đổ bóng cứng không mờ (`5px 5px 0 #000` / `3px 3px 0 #000`) và hiệu ứng nhấn nút.
   - Phân màu rõ ràng cho 2 backend khi trình diễn: Backend A (`#C0F7FE` xanh cyan), Backend B (`#99E885` xanh lá), nút hành động chính (`#F7CB46` vàng), thông số tổng (`#FFDC8B`), và lỗi thật (`#FE90E8` hồng).
   - Giữ nguyên toàn bộ element IDs, logic `apiFetch` với `Cache-Control: no-store` + cache buster `_t=...`, 2 tab `01 // ALB Routing & Health` và `02 // Shared Leaderboard`, không thêm nút public tắt tiến trình và không fallback ngầm.
2. Chạy kiểm tra tĩnh HTML (`HTMLParser` kiểm tra cân bằng thẻ + đối chiếu `getElementById`) và kiểm tra cú pháp JS trong `<script>` bằng `vm.Script` của Node.js 24.
3. Đóng gói lại và deploy lên EC2 A (`i-0cca77524a1964c16`) và EC2 B (`i-0ccf80b64328d1526`) qua `aws ssm send-command` (`docker build` + recreate container `quizlab` dùng nguyên `/etc/quizlab/env`).
4. Kiểm tra qua ALB thật (`GET /`, `GET /lab/a/`, `GET /lab/b/`, `/lab/a/api/cache-status`, `/lab/b/api/cache-status`).

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS`
- **Kiểm tra tĩnh & cú pháp:** `HTML errors: []`, `Missing IDs: []`, `JS_SYNTAX_OK`.
- **Deploy & kiểm tra live qua `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`:**
  - `REDEPLOY A STATUS=Success`, `REDEPLOY B STATUS=Success`; `tg-main`, `tg-a`, `tg-b` đều `healthy`.
  - `GET /`, `GET /lab/a/`, `GET /lab/b/` đều trả `HTTP 200` (`28,864` ký tự, chứa style Neo-Brutalism mới).
  - `/lab/a/api/cache-status` và `/lab/b/api/cache-status` trả `HTTP 200`, `connected: true`, `tls: true`, `ping: "PONG"`.
- **Ghi chú kiểm tra trình duyệt:** Không mở tự động bằng subagent trình duyệt được do `chrome_devtools` MCP server chưa kết nối trên môi trường hiện tại; cần bạn mở trực tiếp trên trình duyệt của bạn để xem hiển thị và quay video.

### 4. Cách tự thực hiện lại / Kiểm tra
- Mở `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com/` trên trình duyệt (bấm `Ctrl+Shift+R` nếu trình duyệt còn giữ tab cũ) để kiểm tra giao diện mới.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Thay đổi chỉ nằm ở lớp giao diện HTML/CSS trong `public/index.html`, toàn bộ hợp đồng API, prefix stripping, xử lý lỗi `503` và kết nối Valkey TLS/RBAC giữ nguyên như đã nghiệm thu ở `Entry #5`.

### 6. Đối chiếu tiêu chí nghiệm thu
- Không làm thay đổi kết quả 8/10 tiêu chí đã `Đạt` ở `Entry #5`; giao diện mới sẵn sàng cho bước quay 2 video dự phòng (tiêu chí 9).

## Entry #7 — 2026-11-25 16:43 — Đổi font giao diện sang Be Vietnam Pro (hỗ trợ đầy đủ tiếng Việt) và redeploy

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Ứng dụng & Cache.
- **Mục tiêu:** Sửa lỗi hiển thị dấu tiếng Việt trên giao diện Neo-Brutalism bằng cách đổi font chính sang **Be Vietnam Pro** (và **JetBrains Mono** cho khối mã/ID), sau đó build/deploy lại lên EC2 A và EC2 B.
- **File chỉnh sửa:** `seminar-lab/alb-elasticache/public/index.html`

### 2. Các thao tác đã thực hiện
1. Kiểm tra URL Google Fonts (`Be Vietnam Pro` weights `500;600;700;800;900` và `JetBrains Mono` weights `500;700`) xác nhận trả về `@font-face` subset `vietnamese`.
2. Cập nhật `seminar-lab/alb-elasticache/public/index.html`:
   - Thêm `<link>` nạp Google Fonts `Be Vietnam Pro` và `JetBrains Mono` trong `<head>`.
   - Thay `Space Grotesk` / `Arial Black` bằng `"Be Vietnam Pro", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`.
   - Thêm `button, input, select { font-family: inherit; }` để nút, ô nhập liệu và select dùng đồng nhất `Be Vietnam Pro`.
3. Kiểm tra tĩnh HTML và đóng gói deploy lại lên EC2 A (`i-0cca77524a1964c16`) và EC2 B (`i-0ccf80b64328d1526`) qua `aws ssm send-command`, kiểm tra qua ALB.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS`
- **Kết quả kiểm tra live qua `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`:**
  - `REDEPLOY A STATUS=Success`, `REDEPLOY B STATUS=Success`; cả 3 target group (`tg-main`, `tg-a`, `tg-b`) đều `healthy`.
  - `GET /`, `GET /lab/a/`, `GET /lab/b/` trả `HTTP 200` (`29,236` ký tự, chứa `Be Vietnam Pro` và `JetBrains Mono`).
  - `/lab/a/api/cache-status` và `/lab/b/api/cache-status` trả `HTTP 200`, `connected: true`, `ping: "PONG"`.

### 4. Cách tự thực hiện lại / Kiểm tra
- Mở `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com/` trên trình duyệt (bấm `Ctrl+Shift+R` để tải lại stylesheet mới).

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- `Be Vietnam Pro` và `JetBrains Mono` được tải qua Google Fonts khi máy người trình diễn có Internet; nếu trình duyệt mất mạng tới `fonts.googleapis.com`, CSS vẫn có fallback về font hệ thống sạch không dùng `Arial Black`.

### 6. Đối chiếu tiêu chí nghiệm thu
- Không làm thay đổi 8/10 tiêu chí đã `Đạt`; sẵn sàng cho người phụ trách mở trình duyệt kiểm tra và quay 2 video dự phòng (tiêu chí 9).

## Entry #8 — 2026-11-26 08:06 — Tinh gọn bảng màu Neo-Brutalism và bo tròn góc cho `public/index.html`

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Ứng dụng & Cache.
- **Mục tiêu:** Giảm số lượng màu sắc rực rỡ trên giao diện (từ 5 màu nhấn xuống còn 2 màu nhấn chính kết hợp nền trung tính) và bo tròn các góc khối/nút/bảng trong `seminar-lab/alb-elasticache/public/index.html`, sau đó deploy lại lên EC2 A và B.
- **File chỉnh sửa:** `seminar-lab/alb-elasticache/public/index.html`

### 2. Các thao tác đã thực hiện
1. Tinh gọn bảng màu trong CSS và HTML:
   - Nền trung tính: kem `#FAF6E8`, trắng `#FFFFFF`, viền/chữ đen `#000000`.
   - Giữ 2 màu nhấn chính: vàng `#F7CB46` (nút hành động chính, tab đang chọn, Backend B) và xanh cyan `#C0F7FE` (Backend A); bỏ màu xanh lá `#99E885` và vàng đào `#FFDC8B`, đưa các nút phụ và header bảng về trắng/kem sạch sẽ.
   - Màu hồng `#FE90E8` chỉ hiển thị khi có lỗi thật (`error-banner`, badge `ERR`).
2. Bo tròn góc toàn bộ thành phần: `border-radius: 18px` cho hero frame, panel và card kết quả A/B (bỏ 4 ô vuông góc sắc cạnh); `14px` cho tab, khối control, ô stat, khung bảng, hộp log và banner lỗi; `10px` cho nút bấm, ô input/select; `999px` cho pill tag và badge.
3. Kiểm tra tĩnh HTML/ID (`HTML_AND_IDS_OK`), đóng gói và deploy lại lên EC2 A & B qua `aws ssm send-command`, kiểm tra target health và xác nhận live qua ALB.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS`
- **Kết quả kiểm tra live qua `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`:**
  - `REDEPLOY A STATUS=Success`, `REDEPLOY B STATUS=Success` (`/health` 200, `/api/cache-status` `connected: true`, `latencyMs: 1`).
  - `tg-main`, `tg-a`, `tg-b` đều `healthy`.
  - `GET /`, `GET /lab/a/`, `GET /lab/b/` đều trả `HTTP 200` (`28,884` ký tự).

### 4. Cách tự thực hiện lại / Kiểm tra
- Mở hoặc tải lại `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com/` (`Ctrl+Shift+R`) để xem giao diện gọn màu, bo góc mới.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Chỉ thay đổi CSS/HTML lớp trình bày trong `public/index.html`; toàn bộ API, prefix stripping và kết nối Valkey không đổi.

### 6. Đối chiếu tiêu chí nghiệm thu
- Giữ nguyên trạng thái 8/10 tiêu chí đã `Đạt`; sẵn sàng cho người phụ trách quay 2 video dự phòng (tiêu chí 9).

## Entry #9 — 2026-11-26 08:10 — Đổi giao diện sang bảng màu ấm (Litverse) và bộ phông chữ Lora + IBM Plex Mono + Be Vietnam Pro

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Ứng dụng & Cache.
- **Mục tiêu:** Chuyển giao diện `seminar-lab/alb-elasticache/public/index.html` sang phong cách editorial ấm áp theo ảnh mẫu người dùng gửi (`#EFE6D5`, `#FBF5E6`, `#F2E7D1`, `#F5DF3D`, `#F27127`, mực `#181613`, viền mảnh `1.5px` bo góc) và phối 3 phông chữ hỗ trợ đầy đủ tiếng Việt (`Lora`, `IBM Plex Mono`, `Be Vietnam Pro`), rồi redeploy lên EC2 A và B.
- **File chỉnh sửa:** `seminar-lab/alb-elasticache/public/index.html`

### 2. Các thao tác đã thực hiện
1. Kiểm tra qua Google Fonts xác nhận cả 3 font (`Lora`, `IBM Plex Mono`, `Be Vietnam Pro`) đều có subset `vietnamese`.
2. Cập nhật `public/index.html`:
   - Bảng màu mới: nền ngoài `#EFE6D5`, mặt thẻ `#FBF5E6`, nền phụ `#F2E7D1`, viền mực `#181613` (`1.5px solid`, bỏ đổ bóng nặng), màu nhấn chính cam `#F27127` (tab active, nút hành động chính, Backend B) và vàng `#F5DF3D` (banner tiêu đề, Backend A); lỗi dùng nền đỏ nhạt `#FDE4DF` / chữ `#9E1F14`.
   - Phông chữ: `Lora` cho tiêu đề/card header/số thống kê; `IBM Plex Mono` cho thân trang, bảng và log; `Be Vietnam Pro` cho nút, input, dropdown và badge.
   - Bố cục tiêu đề trên cùng chia 3 ngăn (`AWS AP-SOUTHEAST-2 | QUIZLAB | CACHE-CONTROL: NO-STORE`) kèm dải banner vàng bên dưới.
3. Kiểm tra tĩnh HTML/ID (`HTML_AND_IDS_OK`, `28,357` bytes), đóng gói và deploy lên EC2 A & B qua `aws ssm send-command`, kiểm tra live qua ALB.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS`
- **Kết quả kiểm tra live qua `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`:**
  - `REDEPLOY A STATUS=Success`, `REDEPLOY B STATUS=Success` (`/health` 200, `/api/cache-status` `connected: true`, `ping: "PONG"`).
  - `tg-main`, `tg-a`, `tg-b` đều `healthy`.
  - `GET /`, `GET /lab/a/`, `GET /lab/b/` đều trả `HTTP 200` (`28,357` ký tự).

### 4. Cách tự thực hiện lại / Kiểm tra
- Tải lại `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com/` (`Ctrl+Shift+R`) để xem giao diện mới.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Chỉ thay đổi CSS/HTML lớp trình bày trong `public/index.html`; toàn bộ API, strip prefix `/lab/a` & `/lab/b` và kết nối Valkey TLS/RBAC giữ nguyên như đã nghiệm thu ở `Entry #5`.

### 6. Đối chiếu tiêu chí nghiệm thu
- Giữ nguyên trạng thái 8/10 tiêu chí đã `Đạt`; sẵn sàng cho người phụ trách quay 2 video dự phòng (tiêu chí 9).

## Entry #10 — 2026-11-26 08:17 — Bổ sung bộ icon nét mảnh chỉ viền (`fill: none`) cho `public/index.html`

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Ứng dụng & Cache.
- **Mục tiêu:** Bổ sung 17 icon SVG nét mảnh chỉ viền (không nền, không tô đặc, `stroke-width: 1.75`) đồng bộ phong cách editorial trong ảnh mẫu vào `seminar-lab/alb-elasticache/public/index.html` và redeploy lên EC2 A và B.
- **File chỉnh sửa:** `seminar-lab/alb-elasticache/public/index.html`

### 2. Các thao tác đã thực hiện
1. Thêm lớp CSS `.ico` (`fill: none; stroke: currentColor; stroke-width: 1.75; stroke-linecap: round; stroke-linejoin: round;`) và căn chỉnh `inline-flex` cho `.hero-top-cell`, `.tab-btn` và `button.action`.
2. Gắn 17 SVG outline trực tiếp vào:
   - Thanh topbar (`AWS AP-SOUTHEAST-2` globe, `CACHE-CONTROL: NO-STORE` shield-check)
   - 2 tab (`01. ALB Routing & Health` branch, `02. Shared Leaderboard` database)
   - Toàn bộ nút thao tác (`Gửi 20 request` play tam giác nét mảnh, `Gửi 1 request` send, `Xóa bảng` trash, `Kiểm tra Cache Status` activity, `Reset phòng` rotate-ccw, `Ghi Alice`/`Ghi tùy chọn` edit, `Seed 3 người chơi` users, `Update Alice 170` arrow-up-circle, `Đọc từ A/B` cloud-download)
   - Tiêu đề card `Backend A` và `Backend B` (server icon)
3. Kiểm tra tĩnh HTML/SVG/ID (`HTML_AND_SVG_OK svgs= 17 bytes= 32651`), đóng gói và deploy lên EC2 A & B qua `aws ssm send-command`, kiểm tra qua ALB.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS`
- **Kết quả kiểm tra live qua `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`:**
  - `REDEPLOY A STATUS=Success`, `REDEPLOY B STATUS=Success` (`/health` 200, `/api/cache-status` `connected: true`, `ping: "PONG"`, `latencyMs: 1`).
  - `tg-main`, `tg-a`, `tg-b` đều `healthy`.
  - `GET /`, `GET /lab/a/`, `GET /lab/b/` đều trả `HTTP 200` (`32,651` ký tự).

### 4. Cách tự thực hiện lại / Kiểm tra
- Tải lại `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com/` (`Ctrl+Shift+R`) để xem các icon mới.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Toàn bộ icon là SVG nội tuyến nhẹ, không phụ thuộc thư viện icon ngoài (không lo lỗi tải CDN khi thuyết trình).

### 6. Đối chiếu tiêu chí nghiệm thu
- Giữ nguyên 8/10 tiêu chí đã `Đạt`; sẵn sàng cho bước quay 2 video dự phòng (tiêu chí 9).

## Entry #11 — 2026-11-26 08:41 — Kiểm tra chất lượng video dự phòng Demo 1 (`docs/video/demo1.mp4`)

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Tài liệu & Video.
- **Mục tiêu:** Kiểm tra thời lượng, diễn biến thao tác và đối chiếu tiêu chí của video Demo 1 do người phụ trách demo vừa quay tại `docs/video/demo1.mp4`.
- **File kiểm tra:** `docs/video/demo1.mp4` (`66.64 MB`, thời lượng `93.05s` = `1 phút 33 giây`).

### 2. Các thao tác đã thực hiện
1. Kiểm tra metadata kích thước và thời lượng MP4 (`mvhd` atom).
2. Xem toàn bộ nội dung hình ảnh video từ `00:00` đến `01:33` và đối chiếu với Mục 6 & Mục 12 trong `docs/ALB_ElastiCache_Demo_Handover.md` cùng Slide 5 trong `docs/ALB_ElastiCache_Noi_dung_chi_tiet.md`.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS` (đạt các điểm cốt lõi; có 1 gợi ý bổ sung nhỏ).
- **Diễn biến quan sát thật trong `demo1.mp4`:**
  - `00:00–00:04`: Mở AWS Console `quizlab-tg-main` cho thấy `2 Total targets`, `2 Healthy`, `0 Unhealthy`.
  - `00:05–00:22`: Mở web lab qua DNS ALB, bấm `Gửi 20 request (/api/whoami)` → `Tổng 20 | Backend A: 10 | Backend B: 10 | Lỗi: 0`, cuộn bảng cho thấy `requestId` thay đổi từng dòng.
  - `00:27–00:34`: Sang terminal SSM chạy `sudo docker stop quizlab`.
  - `00:35–00:46`: Refresh AWS Console `quizlab-tg-main` cho thấy chuyển từ `2 Healthy` sang `1 Healthy | 1 Unhealthy`.
  - `00:49–01:02`: Bấm `Xóa bảng kết quả` rồi `Gửi 20 request` → `Tổng 20 | Backend A: 0 | Backend B: 20 | Lỗi: 0`.
  - `01:08–01:13`: Sang terminal SSM chạy `sudo docker start quizlab`.
  - `01:17–01:30`: Bấm `Gửi 1 request` 3 lần đầu thấy `B` (trong lúc A chưa kịp qua ngưỡng healthy), sau đó xóa bảng và bấm `Gửi 20 request` → `Tổng 20 | Backend A: 10 | Backend B: 10 | Lỗi: 0`.
- **Điểm cần lưu ý / góp ý thêm:**
  - Cuối video (`01:30`) chưa quay lại màn hình AWS Console refresh xác nhận `2 Healthy | 0 Unhealthy` (chỉ mới xác nhận A hồi phục qua web UI `10/10`); nên chụp thêm 1 ảnh Console `2 Healthy` hoặc lật lại Console ở cuối clip nếu muốn bằng chứng Tiêu chí 4 trọn vẹn hơn.
  - File `docs/video/demo1.mp4` nặng `66.64 MB` (trên 50 MB, lưu ý khi push Git).

### 4. Cách tự thực hiện lại / Bước tiếp theo
- Nếu giữ nguyên `demo1.mp4`, bổ sung thêm ảnh chụp Console `2 Healthy` sau restart A cho Tiêu chí 4.
- Tiếp tục quay `demo2.mp4` (≤ 3 phút) cho kịch bản **ElastiCache** và mở AWS Console `quizlab-valkey` ở cuối video.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Video liền mạch (không cắt ghép), thời lượng `1m33s` gọn dưới mức tối đa `3m00s`. Trong video chờ A chuyển `unhealthy` ở Console xong mới bấm gửi 20 request nên không xuất hiện lỗi `502` chuyển tiếp trong phần quay này (vẫn đúng với mô tả *"Có thể có lỗi chuyển tiếp"*).

### 6. Đối chiếu tiêu chí nghiệm thu
- Phục vụ Tiêu chí `9` (*Video dưới 3 phút cho từng demo*): đã có `demo1.mp4` (`1m33s`), còn thiếu `demo2.mp4`.

## Entry #12 — 2026-11-26 09:06 — Kiểm tra video dự phòng Demo 2 (`docs/demo2.mp4`) và cập nhật nghiệm thu

### 1. Đã làm gì (Mục tiêu & Phạm vi)
- **Hạng mục:** Tài liệu & Video.
- **Mục tiêu:** Kiểm tra thời lượng, trình tự thao tác và độ khớp tiêu chí của video Demo 2 (`docs/demo2.mp4`), đồng thời cập nhật trạng thái Tiêu chí 9 trong biên bản nghiệm thu và checklist.
- **File kiểm tra & cập nhật:**
  - Kiểm tra: `docs/demo2.mp4` (`95.33 MB`, thời lượng `133.05s` = `2 phút 13 giây`).
  - Cập nhật: `docs/ACCEPTANCE_REPORT.md`, `docs/DEMO_TASKS.md`, `docs/DEMO_WORKLOG.md`.

### 2. Các thao tác đã thực hiện
1. Kiểm tra kích thước, thời lượng MP4 (`mvhd` atom) và rà soát file video trong `docs/`.
2. Xem toàn bộ video `docs/demo2.mp4` từ `00:00` đến `02:13`, đối chiếu từng mốc với Mục 7 & Mục 12 của `docs/ALB_ElastiCache_Demo_Handover.md` và Slide 9 của `docs/ALB_ElastiCache_Noi_dung_chi_tiet.md`.
3. Cập nhật Tiêu chí `9` sang **Đạt** trong `docs/ACCEPTANCE_REPORT.md`, `docs/DEMO_TASKS.md` và bảng tổng hợp của `docs/DEMO_WORKLOG.md`.

### 3. Kết quả quan sát thực tế
- **Trạng thái:** `PASS` (Đạt đầy đủ tất cả mốc bắt buộc của Demo 2).
- **Diễn biến quan sát thật trong `docs/demo2.mp4`:**
  - `00:00–00:10`: Mở AWS Console `quizlab-valkey` (`Status: Available`, `Engine: Valkey 8.2.0`, `cache.t4g.micro`, `Cluster mode: Disabled`, `1` node, `Encryption in transit: Required`).
  - `00:11–00:32`: Tab `02. Shared Leaderboard`, chế độ `memory`: bấm `Ghi Alice = 100 qua A` → Backend A hiện `alice: 100`; bấm `Đọc từ B` → Backend B hiện `(Trống)`.
  - `00:34–00:49`: Đổi sang `elasticache`, bấm `Seed 3 người chơi qua A` → bấm `Đọc từ B` → Backend B (`backendId: B`, `storeMode=elasticache`) trả đúng `[bob: 150, chi: 120, alice: 100]`.
  - `00:50–01:03`: Bấm `Update Alice = 170 qua A` → bấm `Đọc từ B` → Backend B đọc `[alice: 170, bob: 150, chi: 120]`.
  - `01:06–01:46`: Trên terminal SSM EC2 A (`i-0cca77524a1964c16`) chạy `sudo docker stop quizlab` → bấm `Đọc từ B` vẫn đọc đủ bảng điểm; bấm thử `Đọc từ A` hiện đúng lỗi thật `HTTP 502 Bad Gateway` (không giấu lỗi, không fallback ngầm về RAM).
  - `01:47–02:13`: Trên terminal SSM chạy `sudo docker start quizlab` → bấm `Đọc từ A` → `backendId: A` đọc lại nguyên vẹn `[alice: 170, bob: 150, chi: 120]`.

### 4. Cách tự thực hiện lại / Bước tiếp theo
- Sau khi hoàn thành buổi seminar (hoặc không cần chạy live nữa), chạy `./seminar-lab/alb-elasticache/cleanup-aws.sh --yes` để xóa toàn bộ tài nguyên AWS đang bật (tiêu chí 10) và cập nhật xác nhận vào `docs/ACCEPTANCE_REPORT.md` + `docs/DEMO_WORKLOG.md`.
- Lưu 2 file video lớn (`demo1.mp4` ~67 MB, `docs/demo2.mp4` ~95 MB) ở Drive/máy trình diễn, không push file video nặng lên GitHub.

### 5. Lưu ý để giải đáp nếu có người hỏi & Giới hạn
- Trong `demo2.mp4`, nút `Update Alice = 170` được bấm 1 lần (chưa bấm lặp lần 2 trên clip, tuy đã kiểm chứng không cộng dồn khi test 3 lần ở `Entry #5`); khi thuyết trình có thể giải thích thêm đặc tính ghi đè tuyệt đối của `ZADD` hoặc bấm lặp nếu chạy live.
- Tại thời điểm kiểm tra, `docs/video/demo1.mp4` không còn trong `docs/` (người dùng đã di chuyển ra ngoài thư mục `docs/` sau khi kiểm tra ở `Entry #11`).

### 6. Đối chiếu tiêu chí nghiệm thu
- Tiêu chí `9` (*Video dưới 3 phút cho từng demo*) đổi sang **Đạt** (`9/10` tiêu chí đã Đạt; chỉ còn Tiêu chí `10` — Cleanup sau khi xong buổi seminar).

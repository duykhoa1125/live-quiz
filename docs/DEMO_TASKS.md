# Danh sách công việc cho người phụ trách trọn phần Demo (ALB & ElastiCache)

Tài liệu này tổng hợp đúng và đủ toàn bộ đầu việc để hoàn thành phần demo trên AWS thật theo:
- [ALB_ElastiCache_Demo_Handover.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Demo_Handover.md)
- [ALB_ElastiCache_Noi_dung_chi_tiet.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Noi_dung_chi_tiet.md)
- [ALB_ElastiCache_Kien_thuc_theo_slide.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Kien_thuc_theo_slide.md)

---

## 0. Ranh giới nhiệm vụ: Bạn (Demo) vs Người làm Slide

- **Bạn phụ trách trọn phần Demo:** Dựng hạ tầng AWS cho lab, code ứng dụng lab (A/B + UI + Docker), chạy kiểm thử & tập kịch bản 2 demo (≤ 3 phút/demo), quay 2 video dự phòng, chụp ảnh AWS Console, đo số liệu thực tế, viết tài liệu cấu hình/README/biên bản nghiệm thu/chi phí, và cleanup tài nguyên sau seminar.
- **Người làm Slide phụ trách:** Tổng hợp 14 slide lý thuyết, nội dung nói 20 phút và chuẩn bị câu trả lời Q&A.
- **Đầu ra bạn bàn giao cho người làm Slide / trình bày:**
  - Đường dẫn DNS ALB (trang lab) để mở khi trình diễn, lệnh stop/start sẵn sàng (nếu cùng vận hành lúc live), và cửa sổ AWS Console (Target Group `tg-main` + ElastiCache).
  - 2 video dự phòng (≤ 3 phút/video) + ảnh chụp AWS Console (đã che thông tin nhạy cảm).
  - Thông số cấu hình thực tế đã chạy (region, số backend, engine & version, node type, số replica, TLS...), **thời gian phát hiện backend A lỗi đo được thực tế**, và bảng các giới hạn / phần chưa thử.

---

## 1. Lộ trình thực hiện trong 2 ngày (theo Mục 8 Handover)

### Ngày 1 — Quyền, Hạ tầng & Bản lõi cả 2 demo
- [ ] **Giờ đầu:** Kiểm tra quyền tạo VPC, EC2, ALB, ElastiCache và dùng instance profile cho SSM (nếu có SCP hoặc thiếu quyền thì xử lý với người quản lý tài khoản ngay, không đợi code xong mới kiểm tra).
- [ ] Chốt region (`ap-southeast-1` nếu tài khoản cho phép), quy ước tag (`Project=quiz-service-seminar` + tag owner/expiry nội bộ), cách quản lý credential ngoài Git/image, và chốt hợp đồng API theo Mục 5 Handover.
- [ ] Dựng VPC/SG, 2 EC2, ALB, 3 Target Groups, Listener Rules; chạy app A/B và hoàn thành **Demo ALB** trước (vì `/health` và `/api/whoami` không cần cache).
- [ ] Tạo **ElastiCache for Valkey** + RBAC user/user group; kiểm tra kết nối TLS/RBAC từ EC2 tới Valkey.
- [ ] Hoàn thành 2 adapter (`memory` và `elasticache`), route pin `/lab/a/*`, `/lab/b/*` (tự strip prefix trong app) và giao diện HTML/JS. Cuối ngày chạy được bản lõi cả 2 demo.

### Ngày 2 — Sửa lỗi, Lặp lại, Quay video, Nghiệm thu & Cleanup
- [ ] Sửa các lỗi mạng / TLS / health check / routing (nếu có); đối chiếu response, `backendId`, `storeMode` và thứ tự điểm.
- [ ] Chạy lại toàn bộ kịch bản ít nhất **3 lần** để kiểm tra tính lặp lại; chốt thứ tự reset dữ liệu và khôi phục backend A giữa 2 demo.
- [ ] Quay **2 video dự phòng** từ lab thật; chụp ảnh Console; lập biên bản nghiệm thu ngắn; tập thao tác mỗi demo tối đa **3 phút**.
- [ ] Phối hợp tổng duyệt toàn buổi seminar **20 phút** cùng người làm slide/thuyết trình.
- [ ] Hoàn thành **cleanup** toàn bộ tài nguyên lab trên AWS và ghi danh sách đã xóa/còn giữ.

---

## 2. Chi tiết các công việc cần làm

### Phần A — Hạ tầng AWS (trên AWS thật)
> Region ưu tiên: `ap-southeast-1` (nếu tài khoản cho phép). Mọi tài nguyên tạo mới đều gắn tag `Project=quiz-service-seminar` (+ tag owner/expiry nội bộ).

- [ ] **Kiểm tra quyền AWS:** Xác nhận tạo được VPC, EC2, ALB, ElastiCache và gán instance profile cho SSM.
- [ ] **VPC & Mạng:**
  - [ ] Dùng 1 VPC bật DNS support.
  - [ ] Tạo/dùng **2 public subnet ở 2 AZ** (cho ALB và 2 EC2 có public IPv4 phục vụ outbound bootstrap và SSM; không cần NAT Gateway).
  - [ ] Tạo/dùng **Internet Gateway** cho VPC.
  - [ ] Tạo/dùng **private subnet** cùng VPC cho subnet group của ElastiCache.
- [ ] **Security Groups (3 nhóm):**
  - [ ] `SG ALB`: Inbound TCP `80` từ IP người trình diễn hoặc dải IP nhóm đã chọn.
  - [ ] `SG backend`: Inbound TCP `3000` **chỉ từ `SG ALB`** (không mở port 3000 ra Internet).
  - [ ] `SG cache`: Inbound TCP `6379` **chỉ từ `SG backend`**.
- [ ] **2 EC2 (`A` và `B`) & Kênh vận hành SSM:**
  - [ ] Tạo 2 EC2 nhỏ kiến trúc `x86_64` (ví dụ `t3.micro` nếu khả dụng), mỗi máy ở 1 AZ, có public IPv4, cài Docker.
  - [ ] Gán instance role/profile, đảm bảo SSM agent và outbound HTTPS hoạt động để chạy `docker stop` / `docker start` qua **Systems Manager Session Manager**.
  - [ ] Chạy cùng image/app trên 2 máy, khác biến môi trường `BACKEND_ID` (`A` và `B`).
  - [ ] Lưu username/password Valkey ở cấu hình môi trường riêng được bảo vệ trên mỗi EC2 (không đưa vào Git, không bake vào Docker image).
- [ ] **ALB, Target Groups & Listener Rules:**
  - [ ] Tạo ALB Internet-facing, listener **HTTP port 80** (dùng DNS AWS cấp; không bắt buộc mua domain hay cấu hình ACM).
  - [ ] Tạo 3 Target Groups (`target type: instance`, HTTP port `3000`):
    - [ ] `tg-main`: đăng ký A và B; thuật toán **round robin**, **tắt cookie stickiness**.
    - [ ] `tg-a`: chỉ đăng ký A.
    - [ ] `tg-b`: chỉ đăng ký B.
  - [ ] Cấu hình Health Check cho cả 3 Target Groups: `GET /health`, success code `200`, interval `5` giây, timeout `2` giây, healthy threshold `2`, unhealthy threshold `2`.
  - [ ] Tạo Listener Rules:
    - [ ] Priority `10`: Path `/lab/a/*` → `tg-a`
    - [ ] Priority `20`: Path `/lab/b/*` → `tg-b`
    - [ ] Default: các request còn lại → `tg-main`
- [ ] **ElastiCache for Valkey:**
  - [ ] Tạo **ElastiCache for Valkey**, **node-based**, **cluster mode disabled**, **1 primary và 0 replica** (node nhỏ như `cache.t4g.micro` nếu region hỗ trợ).
  - [ ] Đặt trong VPC, port `6379`, bật **TLS required**.
  - [ ] Cấu hình **RBAC**: tạo user + user group gắn vào cluster, có password riêng cho lab, giới hạn key prefix `quizlab:*`, cấp đủ quyền kết nối/handshake cho client, Sorted Set, `GET`/`SET`, `TTL`/`EXPIRE`, `DEL` trên key lab.

---

### Phần B — Ứng dụng Lab & Đóng gói Docker
> Xây dựng **1 codebase độc lập** (gợi ý đặt tại `seminar-lab/alb-elasticache/` hoặc nhánh lab riêng), không kéo toàn bộ Live Quiz vào làm điều kiện hoàn thành.

- [ ] **Nền tảng & Container:**
  - [ ] Dùng Node.js 24 và Docker, app listen `0.0.0.0:3000`, đọc `BACKEND_ID` từ env.
  - [ ] Đặt tên container thống nhất (ví dụ `quizlab`) và dùng restart policy `unless-stopped` để `docker stop quizlab` không tự khởi động lại ngay.
- [ ] **Định tuyến & Header:**
  - [ ] Backend **tự bỏ prefix `/lab/a` hoặc `/lab/b`** trước khi xử lý route (không dùng URL rewrite của ALB).
  - [ ] `GET /` trả giao diện HTML/JS đơn giản (không build thêm frontend framework).
  - [ ] Tất cả API trả JSON và header `Cache-Control: no-store`.
- [ ] **8 Endpoint theo hợp đồng (Mục 5 Handover):**
  - [ ] `GET /health`: kiểm tra tiến trình HTTP còn đáp ứng (`200`), **không phụ thuộc Redis/Valkey**.
  - [ ] `GET /api/whoami`: trả `{backendId, requestId, timestamp}` với `requestId` mới mỗi lần.
  - [ ] `GET /api/cache-status`: kiểm tra TLS/auth/`PING` từ server tới cache (không lộ password hay thông tin nhạy cảm).
  - [ ] `PUT /api/rooms/:roomId/scores/:playerId?store=memory` (body `{"score": 100}`): gán điểm vào `Map` riêng của tiến trình.
  - [ ] `PUT /api/rooms/:roomId/scores/:playerId?store=elasticache` (body `{"score": 100}`): gán điểm tuyệt đối bằng `ZADD` (không dùng `ZINCRBY`) vào key `quizlab:room:<roomId>:leaderboard`, đặt/làm mới TTL `3600` giây.
  - [ ] `GET /api/rooms/:roomId/leaderboard?store=memory`: đọc `Map` hiện tại và sắp xếp top 10 giảm dần.
  - [ ] `GET /api/rooms/:roomId/leaderboard?store=elasticache`: đọc top 10 theo score giảm dần (`ZRANGE ... REV WITHSCORES` hoặc tương đương).
  - [ ] `DELETE /api/lab/rooms/:roomId?store=...`: reset đúng dữ liệu phòng lab (`memory` gọi riêng A/B; `elasticache` gọi 1 lần).
- [ ] **Quy tắc kỹ thuật bắt buộc trong app:**
  - [ ] Response các API phòng/điểm phải có `backendId`, `storeMode`, `roomId`, trạng thái và dữ liệu trả về.
  - [ ] Tái sử dụng connection Valkey trong tiến trình (`rediss` hoặc TLS options của client), không tạo connection mới mỗi request.
  - [ ] Nếu `store=elasticache` lỗi kết nối thì trả lỗi rõ ràng (như HTTP `503`), **tuyệt đối không fallback ngầm sang RAM**.
  - [ ] Kiểm tra `roomId`, `playerId`, `score` hợp lệ; dùng dữ liệu giả; trình duyệt chỉ gọi backend (không có Redis client/credential ở trình duyệt).
- [ ] **Giao diện HTML/JS tối thiểu:**
  - [ ] Gửi request kèm `Cache-Control: no-store` / cache buster để tránh browser đọc response cache.
  - [ ] **Tab ALB:** nút gửi 20 request qua `/api/whoami`, bảng `backendId`/`requestId`, đếm lượt A/B và số lỗi.
  - [ ] **Tab Shared leaderboard:** chọn `roomId` và `store`; nút ghi qua A (`/lab/a/...`), đọc từ A (`/lab/a/...`), đọc từ B (`/lab/b/...`); hiển thị `backendId` thật của response.
  - [ ] Nút **seed 3 người chơi** (Alice 100, Bob 150, Chi 120), nút **update Alice 170**, nút **reset** phòng lab.
  - [ ] Hiển thị lỗi thật (không thay response lỗi bằng dữ liệu hardcode); **không tạo nút public** để tắt tiến trình trên web UI.

---

### Phần C — Chạy thử, Tập kịch bản 3 phút & Quay Video dự phòng
- [ ] **Chuẩn bị trước khi chạy / trình diễn:**
  - [ ] Mở sẵn trang lab (DNS ALB), 2 session SSM tới A và B, và AWS Console ở đúng vị trí Target Group `tg-main` + ElastiCache.
  - [ ] Trước Demo 2: bảo đảm A đã `healthy`, `/api/cache-status` connected, và đã reset phòng `demo` ở cả `memory` lẫn `elasticache`.
- [ ] **Chạy lặp lại tối thiểu 3 lần cả 2 kịch bản (≤ 3 phút/demo):**
  - [ ] **Demo 1 — ALB (≤ 3 phút):**
    1. Mở DNS ALB, gửi 20 request mặc định → quan sát có cả `A` và `B`, `requestId` thay đổi.
    2. Cho xem `tg-main` đang khỏe cả 2 → qua SSM chạy `docker stop quizlab` trên A → tiếp tục gửi request (không giấu lỗi chuyển tiếp nếu có trước khi health đổi).
    3. Quan sát AWS Console chuyển A sang `unhealthy`, B vẫn `healthy` → gửi 20 request mặc định → các request thành công do B xử lý. (**Ghi lại thời gian phát hiện thực tế**, không lấy `5s * 2` làm số đo).
    4. Chạy `docker start quizlab` trên A → chờ health check đưa A về `healthy` → gửi lại request thấy cả A và B; chốt phạm vi.
  - [ ] **Demo 2 — ElastiCache (≤ 3 phút):**
    1. Chế độ `memory`: ghi Alice 100 qua `/lab/a/...`, đọc cùng phòng qua `/lab/b/...` → A có Alice, B rỗng (kiểm tra `backendId`).
    2. Chế độ `elasticache`: seed Alice 100, Bob 150, Chi 120 qua A → đọc qua B thấy thứ tự Bob 150, Chi 120, Alice 100.
    3. Ghi Alice 170 qua A → đọc lại qua B thấy Alice lên đầu (score 170); lặp lại PUT 170 vẫn giữ nguyên 170.
    4. Dừng/restart app A (`docker stop quizlab` / restart) → đọc cache qua `/lab/b/...` → B vẫn đọc được bảng điểm.
    5. Khởi động lại A, đọc lại qua A *(có thể lược bước đọc lại A khi live nếu đã có bằng chứng ở video và B đã đọc xong để không lố 3 phút)* + mở trạng thái ElastiCache trên AWS Console xác nhận chạy thật.
- [ ] **Quay 2 video dự phòng & chụp bằng chứng:**
  - [ ] Quay 2 video (mỗi video **tối đa 3 phút**) từ **chính lần chạy của lab thật**, có quay kèm màn hình AWS Console đối chiếu (Target Health và ElastiCache), không cắt ghép giấu khoảng lỗi chuyển tiếp.
  - [ ] Chụp ảnh AWS Console (che thông tin nhạy cảm không cần thiết) và lưu output thực tế cho biên bản & slide.

---

### Phần D — Tài liệu bàn giao, Nghiệm thu, Chi phí & Cleanup
- [ ] **Tài liệu cấu hình AWS:** ghi sơ đồ, region, resource IDs, port, SG, endpoint ALB, hướng dẫn dựng lại bằng Console/CLI hoặc IaC tách riêng (**không đưa Terraform state/credential vào repo**).
- [ ] **README chạy và demo:** hướng dẫn cài đặt, cấu hình mẫu, seed/reset dữ liệu, stop/start app qua SSM và cleanup (**không chứa mật khẩu**).
- [ ] **Biên bản nghiệm thu (theo mẫu Mục 12 Handover):** ghi ngày giờ, cấu hình thực tế (region, số backend, engine & version, node type, số replica, TLS...), **thời gian phát hiện backend A lỗi đo được**, kết quả & bằng chứng cho cả **10 tiêu chí**:
  1. DNS ALB và tài nguyên AWS thật
  2. Request qua `tg-main` thấy cả A/B
  3. Stop A và `tg-main` tiếp tục qua B
  4. Start A và quay lại `healthy`
  5. Memory A/B độc lập
  6. ElastiCache ghi A đọc B
  7. Alice cập nhật 170 lên đầu
  8. Restart A không xóa dữ liệu remote
  9. Video dưới 3 phút cho từng demo
  10. Cleanup và chi phí theo cấu hình (kèm các chức năng chưa thử/giới hạn).
- [ ] **Ước tính chi phí thực tế:** tra giá hiện hành theo region từ AWS Pricing Calculator hoặc bảng giá chính thức của AWS theo các khoản `ALB + LCU + 2 EC2 + cache node + EBS + public IPv4 + data transfer` và thời gian bật lab (không dùng số tiền cũ trong repo, không giả định Free Tier/credit = 0).
- [ ] **Cleanup toàn bộ tài nguyên lab theo đúng thứ tự:**
  1. Lưu xong code, video và biên bản → xóa ALB, listener và các target group thuộc lab.
  2. Xóa ElastiCache lab + subnet group / user group / RBAC users tạo riêng cho lab (không xóa đối tượng dùng chung của người khác).
  3. Terminate 2 EC2 → kiểm tra xóa EBS, snapshot hoặc địa chỉ IP tĩnh do lab tạo còn sót.
  4. Xóa SG, subnet, route/Internet Gateway và VPC riêng sau khi ENI được giải phóng (không ép xóa VPC dùng chung).
  5. Ghi danh sách resource IDs đã xóa và tài nguyên chủ ý giữ (cập nhật vào biên bản + [DEMO_WORKLOG.md](file:///home/khoa/projects/live-quiz/docs/DEMO_WORKLOG.md)).

---

## 3. Phần mở rộng có điều kiện (Mục 9 Handover — KHÔNG bắt buộc)
> **Chỉ làm sau khi toàn bộ phần lõi ở trên đã đạt.**

- [ ] WebSocket echo qua ALB (chỉ kiểm tra transport qua ALB, hiển thị `backendId` khi mở socket và echo 1 message; không broadcast A/B, không đại diện phục hồi Socket.IO/room).
- [ ] TTL 15 giây trên một key phụ khác (không dùng trên key leaderboard chính, không kéo dài thời lượng live chỉ để chờ TTL).
- [ ] Mở metric CloudWatch có sẵn để quan sát (không dựng pipeline monitoring riêng).

---

## 4. Những việc KHÔNG làm (tránh làm dư ngoài tài liệu)
- **Không** làm 14 slide thuyết trình hay bài nói (phần người khác làm).
- **Không** triển khai hệ thống Live Quiz hoàn chỉnh (luồng host/player, Socket.IO room, EKS, Kafka, PostgreSQL/RDS).
- **Không** mua domain, cấu hình HTTPS/ACM, bật WAF, làm đăng nhập Cognito/OIDC/JWT, làm Auto Scaling EC2, bật replica/Multi-AZ failover/durability transactional log cho ElastiCache, hay làm benchmark so sánh tốc độ với DB.
- **Không** bật URL rewrite trên ALB, không bật cookie stickiness trên `tg-main`, không tạo nút public tắt tiến trình trên web UI, không fallback ngầm về RAM khi ElastiCache lỗi.

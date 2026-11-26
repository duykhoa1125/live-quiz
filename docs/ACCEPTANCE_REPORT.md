# Biên bản nghiệm thu Demo AWS (ALB & ElastiCache)

- **Ngày giờ kiểm thử:** `2026-11-25 16:08–16:24 UTC`
- **Người thực hiện cấu hình & kiểm thử:** `khoa-cli` (cùng trợ lý tự động hóa)
- **Tài liệu đối chiếu:** [ALB_ElastiCache_Demo_Handover.md](file:///home/khoa/projects/live-quiz/docs/ALB_ElastiCache_Demo_Handover.md) (Mục 12)

---

## 1. Thông tin cấu hình thực tế

| Thông số | Giá trị thực tế |
|---|---|
| AWS Account ID | `493093379780` |
| Region | `ap-southeast-2` *(chú thích: `ap-southeast-1` bị chặn bởi SCP `p-3qq7zdmg`)* |
| Tag quản lý | `Project=quiz-service-seminar`, `Owner=khoa-cli` |
| ALB DNS | `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com` (HTTP `80`, internet-facing) |
| Backend A | `i-0cca77524a1964c16` (`t3.micro`, AL2023, `ap-southeast-2a`, `BACKEND_ID=A`, port `3000`) |
| Backend B | `i-0ccf80b64328d1526` (`t3.micro`, AL2023, `ap-southeast-2b`, `BACKEND_ID=B`, port `3000`) |
| Target Groups | `quizlab-tg-main` (A+B, round robin, stickiness off), `quizlab-tg-a` (A), `quizlab-tg-b` (B) |
| Health Check | `GET /health`, HTTP `200`, interval `5s`, timeout `2s`, healthy `2`, unhealthy `2` |
| ElastiCache | `quizlab-valkey` — Valkey `8.2.0`, node-based, `cache.t4g.micro`, cluster mode disabled, `1` primary, `0` replica (`ap-southeast-2a`) |
| Bảo mật Cache | VPC endpoint port `6379`, TLS (`TransitEncryptionEnabled: true`), RBAC user `quizlab` (`~quizlab:*`) |

---

## 2. Kết quả từng tiêu chí nghiệm thu

| # | Tiêu chí | Kết quả thực tế | Bằng chứng / Số đo quan sát |
|---|---|---|---|
| 1 | DNS ALB và tài nguyên AWS thật | **Đạt** | ALB `quizlab-alb`, 2 EC2 (`t3.micro`), Valkey `quizlab-valkey` (`cache.t4g.micro`) chạy thật tại `ap-southeast-2` (`Entry #5`) |
| 2 | Request qua `tg-main` thấy cả A/B | **Đạt** | Lần 1: `A=10, B=10, ERR=0` (20 `requestId` khác nhau); Lần 2: `A=9, B=11`; Lần 3: `A=9, B=11` |
| 3 | Stop A và `tg-main` tiếp tục qua B | **Đạt** | Lần 1: phát hiện A `unhealthy` sau **`9.02s`** (có `HTTP_502` chuyển tiếp ở `+2.39s` và `+5.66s`), sau đó `B=20, ERR=0`; Lần 2: `unhealthy` sau **`13.16s`**, `B=20`; Lần 3: `unhealthy` sau **`7.29s`**, `B=20` |
| 4 | Start A và quay lại `healthy` | **Đạt** | Lần 1: hồi phục `healthy` sau **`7.24s`**, 20 req sau đó `A=9, B=11`; Lần 2: **`7.93s`**, `A=10, B=10`; Lần 3: **`7.97s`**, `A=10, B=10` |
| 5 | Memory A/B độc lập | **Đạt** | Ghi `alice=100` qua `/lab/a/...?store=memory` → A trả `[alice: 100]`, B trả `[]` (cả 3 lần chạy) |
| 6 | ElastiCache ghi A đọc B | **Đạt** | Seed `alice=100, bob=150, chi=120` qua `/lab/a/...?store=elasticache` → `/lab/b/...` đọc `[bob: 150, chi: 120, alice: 100]` |
| 7 | Alice cập nhật 170 lên đầu | **Đạt** | Ghi `alice=170` 2 lần liên tiếp qua A → B đọc `[alice: 170, bob: 150, chi: 120]` (không cộng dồn) |
| 8 | Restart A không xóa dữ liệu remote | **Đạt** | `docker stop quizlab` trên A → B vẫn đọc được bảng điểm; `docker start quizlab` trên A → A đọc lại `[alice: 170, bob: 150, chi: 120]` |
| 9 | Video dưới 3 phút cho từng demo | **Đạt** | Đã kiểm tra `demo1.mp4` (`1m33s`, Entry #11) và `docs/demo2.mp4` (`2m13s`, Entry #12) đều liền mạch, có AWS Console + SSM thật |
| 10 | Cleanup và chi phí theo cấu hình | **Đạt** | Đã ước tính chi phí `ap-southeast-2` (~`$0.08–$0.09/giờ`) và chạy dọn sạch 100% tài nguyên lab qua [cleanup-aws.sh](file:///home/khoa/projects/live-quiz/seminar-lab/alb-elasticache/cleanup-aws.sh) + dọn nốt `rtb-02a64f7cdd79309b9` & `vpc-0ef86bf0b601de975` (`Entry #13`); chỉ còn default VPC `vpc-03c23ad16d65cbeb4` |

---

## 3. Các chức năng chưa thử và giới hạn kết luận

- **Chưa thử (nằm ngoài phạm vi lab):**
  - ElastiCache Multi-AZ, read replica, automatic failover, snapshot restore, và durability transactional log (lab chỉ dùng 1 primary, 0 replica).
  - EC2 Auto Scaling, HTTPS/ACM domain riêng, AWS WAF, xác thực Cognito/OIDC/JWT tại ALB.
  - Phục hồi kết nối WebSocket / Socket.IO room đang chơi khi backend A dừng, hoặc benchmark tốc độ/tải so với PostgreSQL của hệ Live Quiz chính.
- **Lưu ý trình bày:** Thời gian phát hiện backend A `unhealthy` quan sát được qua 3 lần là **`7.29s – 13.16s`** (tùy vị trí dừng tiến trình trong chu kỳ health check 5 giây), không cố định là `10s`, và có xuất hiện lỗi `502` ngắn trong lúc chuyển tiếp trước khi ALB kịp đánh dấu A `unhealthy`.

# Seminar Lab: AWS ALB & ElastiCache for Valkey

Ứng dụng lab độc lập phục vụ hai demo 3 phút trên AWS thật theo đặc tả trong [ALB_ElastiCache_Demo_Handover.md](../../docs/ALB_ElastiCache_Demo_Handover.md).

> **Lưu ý bảo mật:** Không lưu mật khẩu Valkey, token hay AWS credentials trong file này hoặc trong Docker image. Luôn dùng file môi trường được bảo vệ riêng trên từng máy chủ EC2.

---

## 1. Cấu trúc mã nguồn

- `src/server.js`: HTTP server (Node.js 24, port `3000`, bind `0.0.0.0`), tự bỏ prefix `/lab/a` và `/lab/b`, xử lý 2 adapter `memory` và `elasticache` (`ioredis` TLS + RBAC).
- `public/index.html`: Giao diện 2 tab (`ALB` và `Shared leaderboard`), gửi request kèm `Cache-Control: no-store` và cache buster, hiển thị lỗi thật.
- `Dockerfile`: Đóng gói trên `node:24-alpine`.
- `.env.example`: Biến môi trường mẫu.

---

## 2. Cấu hình biến môi trường

Tạo file môi trường riêng ngoài Git trên từng máy EC2 (ví dụ `/etc/quizlab/env`, quyền `chmod 600`):

```dotenv
PORT=3000
BACKEND_ID=A
VALKEY_HOST=<VALKEY_ENDPOINT>
VALKEY_PORT=6379
VALKEY_TLS=true
VALKEY_USERNAME=<VALKEY_RBAC_USERNAME>
VALKEY_PASSWORD=<VALKEY_RBAC_PASSWORD>
VALKEY_TLS_REJECT_UNAUTHORIZED=true
```

> Trên EC2 B đổi `BACKEND_ID=B`. Không đưa file chứa mật khẩu thật vào Git hay Docker image.

---

## 3. Build và chạy bằng Docker trên EC2 A / B

```bash
# Build image từ thư mục seminar-lab/alb-elasticache
docker build -t quizlab:latest .

# Chạy container trên EC2 A (dùng --restart unless-stopped để docker stop không tự bật lại)
docker run -d \
  --name quizlab \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file /etc/quizlab/env \
  quizlab:latest
```

Kiểm tra nhanh trên máy hoặc qua ALB:

```bash
curl -s http://localhost:3000/health
curl -s http://localhost:3000/api/whoami
curl -s http://localhost:3000/api/cache-status
```

---

## 4. Thao tác vận hành khi chạy Demo

### Dừng và khởi động lại Backend A qua AWS SSM Session Manager
```bash
# Kiểm tra container đang chạy
docker ps

# Dừng ứng dụng A (Demo ALB & bước restart của Demo ElastiCache)
docker stop quizlab

# Khởi động lại ứng dụng A
docker start quizlab
```

### Reset dữ liệu phòng `demo` trước khi demo ElastiCache
```bash
# Reset RAM riêng của cả A và B
curl -X DELETE "http://<ALB_DNS>/lab/a/api/lab/rooms/demo?store=memory"
curl -X DELETE "http://<ALB_DNS>/lab/b/api/lab/rooms/demo?store=memory"

# Reset Sorted Set dùng chung trên ElastiCache
curl -X DELETE "http://<ALB_DNS>/lab/a/api/lab/rooms/demo?store=elasticache"
```

### Các endpoint chính (đã tự bỏ prefix `/lab/a` và `/lab/b`)
- `GET /health`: Kiểm tra HTTP process (`200`), không phụ thuộc ElastiCache.
- `GET /api/whoami`: Trả `{backendId, requestId, timestamp}`.
- `GET /api/cache-status`: Kiểm tra kết nối TLS/RBAC/`PING` tới ElastiCache (trả `503` nếu lỗi).
- `PUT /api/rooms/:roomId/scores/:playerId?store=memory|elasticache` (`{"score": 100}`).
- `GET /api/rooms/:roomId/leaderboard?store=memory|elasticache` (Top 10 giảm dần).
- `DELETE /api/lab/rooms/:roomId?store=memory|elasticache`.

---

## 5. Dọn tài nguyên (Cleanup)

Sau khi hoàn thành buổi seminar và lưu xong mã nguồn, video và biên bản nghiệm thu, xóa tài nguyên lab gắn tag `Project=quiz-service-seminar` theo thứ tự:
1. Xóa ALB, listener và các target group (`tg-main`, `tg-a`, `tg-b`).
2. Xóa ElastiCache cluster, subnet group, user group và RBAC user tạo riêng cho lab.
3. Terminate 2 EC2 A/B; kiểm tra xóa EBS volume, snapshot hoặc IP tĩnh còn sót.
4. Xóa Security Groups, subnet, route/Internet Gateway và VPC riêng của lab (không xóa tài nguyên dùng chung).

- **Người phụ trách dọn:** `<OWNER_NAME>`
- **Thời điểm dự kiến dọn:** `<CLEANUP_DATE>`
- **Chi tiết nhật ký & resource IDs:** Theo dõi tại [DEMO_WORKLOG.md](../../docs/DEMO_WORKLOG.md).

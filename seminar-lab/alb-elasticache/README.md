# Seminar Lab: AWS ALB & ElastiCache for Valkey

Ứng dụng lab độc lập phục vụ hai demo 3 phút trên AWS thật theo đặc tả trong [ALB_ElastiCache_Demo_Handover.md](../../docs/ALB_ElastiCache_Demo_Handover.md).

> **Lưu ý bảo mật:** Không lưu mật khẩu Valkey, token hay AWS credentials trong file này hoặc trong Docker image. Mật khẩu được lưu an toàn trong SSM Parameter Store (`SecureString`) và file `/etc/quizlab/env` (`chmod 600`) trên từng máy chủ EC2.

---

## 1. Thông tin môi trường AWS đang chạy (`ap-southeast-2`)

- **Region:** `ap-southeast-2` *(do SCP `p-3qq7zdmg` chặn `ap-southeast-1`)*
- **Trang Lab (ALB DNS):** `http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com`
- **EC2 Backend A (`BACKEND_ID=A`):** `i-0cca77524a1964c16` (`ap-southeast-2a`)
- **EC2 Backend B (`BACKEND_ID=B`):** `i-0ccf80b64328d1526` (`ap-southeast-2b`)
- **ElastiCache Valkey (`8.2.0`, `cache.t4g.micro`):** `master.quizlab-valkey.x4rjiz.apse2.cache.amazonaws.com:6379` (TLS + RBAC `quizlab:*`)
- **Chi tiết toàn bộ Resource IDs & Chi phí:** Xem [AWS_CONFIG_COST_CLEANUP.md](../../docs/AWS_CONFIG_COST_CLEANUP.md)

---

## 2. Cấu trúc mã nguồn

- `src/server.js`: HTTP server (Node.js 24, port `3000`, bind `0.0.0.0`), tự bỏ prefix `/lab/a` và `/lab/b`, xử lý 2 adapter `memory` và `elasticache` (`ioredis` TLS + RBAC).
- `public/index.html`: Giao diện 2 tab (`ALB` và `Shared leaderboard`), gửi request kèm `Cache-Control: no-store` và cache buster, hiển thị lỗi thật.
- `Dockerfile`: Đóng gói trên `node:24-alpine`.
- `.env.example`: Biến môi trường mẫu.
- `cleanup-aws.sh`: Script xóa toàn bộ tài nguyên AWS gắn tag `Project=quiz-service-seminar` đúng thứ tự.

---

## 3. Thao tác vận hành khi chạy Demo

### Mở phiên SSM vào EC2 A (chuẩn bị sẵn trước demo)
```bash
export PATH="$HOME/.local/bin:$PATH"
aws ssm start-session --region ap-southeast-2 --target i-0cca77524a1964c16
```

Bên trong phiên SSM của EC2 A:
```bash
# Kiểm tra container
sudo docker ps

# Dừng ứng dụng A (Demo ALB & bước restart của Demo ElastiCache)
sudo docker stop quizlab

# Khởi động lại ứng dụng A
sudo docker start quizlab
```

### Hoặc Stop/Start nhanh bằng `aws ssm send-command`
```bash
aws ssm send-command --region ap-southeast-2 \
  --instance-ids i-0cca77524a1964c16 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["docker stop quizlab"]'

aws ssm send-command --region ap-southeast-2 \
  --instance-ids i-0cca77524a1964c16 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["docker start quizlab"]'
```

### Reset dữ liệu phòng `demo` trước khi demo ElastiCache
```bash
ALB="http://quizlab-alb-1079474885.ap-southeast-2.elb.amazonaws.com"
curl -s -X DELETE "$ALB/lab/a/api/lab/rooms/demo?store=memory"
curl -s -X DELETE "$ALB/lab/b/api/lab/rooms/demo?store=memory"
curl -s -X DELETE "$ALB/lab/a/api/lab/rooms/demo?store=elasticache"
```

### Các endpoint chính (đã tự bỏ prefix `/lab/a` và `/lab/b`)
- `GET /health`: Kiểm tra HTTP process (`200`), không phụ thuộc ElastiCache.
- `GET /api/whoami`: Trả `{backendId, requestId, timestamp}`.
- `GET /api/cache-status`: Kiểm tra kết nối TLS/RBAC/`PING` tới ElastiCache (trả `503` nếu lỗi).
- `PUT /api/rooms/:roomId/scores/:playerId?store=memory|elasticache` (`{"score": 100}`).
- `GET /api/rooms/:roomId/leaderboard?store=memory|elasticache` (Top 10 giảm dần).
- `DELETE /api/lab/rooms/:roomId?store=memory|elasticache`.

---

## 4. Chạy local / Build Docker (tham khảo dựng lại)

```bash
# Chạy local với Node.js 24 (chế độ memory; store=elasticache sẽ trả 503 nếu chưa trỏ Valkey)
PORT=3000 BACKEND_ID=A npm start

# Build & chạy Docker trên EC2
docker build -t quizlab:latest .
docker run -d \
  --name quizlab \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file /etc/quizlab/env \
  quizlab:latest
```

---

## 5. Dọn tài nguyên (Cleanup)

Sau khi quay xong 2 video dự phòng và hoàn thành buổi seminar, **bắt buộc** chạy cleanup để dừng toàn bộ chi phí AWS:

```bash
./cleanup-aws.sh --yes
```

- **Người phụ trách dọn:** `khoa-cli` / người phụ trách demo
- **Thời điểm dự kiến dọn:** Ngay sau khi hoàn tất quay video & buổi seminar
- **Chi tiết nhật ký & resource IDs:** Theo dõi tại [DEMO_WORKLOG.md](../../docs/DEMO_WORKLOG.md) và [AWS_CONFIG_COST_CLEANUP.md](../../docs/AWS_CONFIG_COST_CLEANUP.md).

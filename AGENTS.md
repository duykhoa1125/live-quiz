# Quy tắc làm việc cho dự án Demo ALB & ElastiCache

## 1. Bối cảnh và tài liệu tham chiếu
Dự án này chuẩn bị hai demo chạy trên AWS thật (Application Load Balancer và Amazon ElastiCache for Valkey) phục vụ buổi seminar 20 phút với ngữ cảnh ứng dụng Live Quiz.

Các tài liệu chuẩn trong thư mục `docs/`:
- `docs/ALB_ElastiCache_Demo_Handover.md`: Đặc tả kiến trúc, cấu hình AWS, hợp đồng API/UI, kịch bản demo 3 phút, lịch triển khai, hướng dẫn cleanup và mẫu biên bản nghiệm thu.
- `docs/ALB_ElastiCache_Noi_dung_chi_tiet.md`: Nội dung chi tiết 14 slide, phân bổ thời gian và kịch bản nói khi demo.
- `docs/ALB_ElastiCache_Kien_thuc_theo_slide.md`: Cơ sở kỹ thuật theo từng slide, các điểm dễ hiểu nhầm và phần Q&A cần nắm.
- `docs/DEMO_WORKLOG.md`: File nhật ký triển khai và runbook bắt buộc phải cập nhật sau mỗi lần thực hiện công việc.

## 2. Quy tắc bắt buộc: Ghi chép nhật ký vào `docs/DEMO_WORKLOG.md`
Mỗi khi thực hiện bất kỳ công việc nào liên quan đến dự án demo (tạo/sửa mã nguồn, dựng/chỉnh sửa hạ tầng AWS, chạy lệnh deploy, kiểm tra kết nối, thử nghiệm kịch bản demo, sửa lỗi, quay video dự phòng, nghiệm thu hoặc dọn tài nguyên), **bắt buộc** phải ghi bổ sung một mục mới vào cuối file `docs/DEMO_WORKLOG.md` trước khi kết thúc lượt làm việc.

Mỗi mục ghi chép phải đánh số thứ tự tăng dần (`## Entry #N — YYYY-MM-DD HH:MM — <Tiêu đề ngắn>`) và có đầy đủ các phần sau:

1. **Đã làm gì (Mục tiêu & Phạm vi):**
   - Nêu rõ hạng mục công việc (`Hạ tầng AWS`, `Ứng dụng & Cache`, `Kiểm thử & Demo`, `Tài liệu & Video`, hoặc `Cleanup`).
   - Liệt kê các file đã tạo/chỉnh sửa hoặc tài nguyên AWS liên quan (kèm region, tên/ID không chứa secret).
2. **Các thao tác đã thực hiện (Từng bước tái lập được):**
   - Ghi lại chính xác các lệnh CLI/Docker/SSM, request API, thao tác trên AWS Console hoặc thay đổi cấu hình theo đúng thứ tự thực hiện.
   - Đủ chi tiết để người khác (hoặc một phiên agent sau) đọc là có thể **tự làm lại được từ đầu**.
3. **Kết quả quan sát thực tế:**
   - Ghi rõ trạng thái (`PASS`, `FAIL`, `PARTIAL`, hoặc `INFO`), output/response thực tế, và số đo quan sát thật (ví dụ: thời gian thực tế ALB chuyển target sang `unhealthy`, danh sách `backendId` trả về, kết quả đọc/ghi cache).
   - Nếu có lỗi xảy ra, ghi rõ thông báo lỗi, nguyên nhân tìm ra và cách đã khắc phục.
   - Không tự suy diễn số đo từ cấu hình (ví dụ: không lấy `interval * threshold` làm thời gian phát hiện lỗi thực tế).
4. **Cách tự thực hiện lại / Chạy lại demo (Runbook):**
   - Nêu điều kiện tiên quyết, biến môi trường mẫu và các lệnh chạy/kiểm tra/reset/stop-start/cleanup tương ứng.
   - Khi có thay đổi về quy trình dựng lab hoặc quy trình chạy demo 3 phút, cập nhật luôn phần **"Hướng dẫn tự thực hiện demo nhanh (Runbook tổng hợp)"** ở đầu `docs/DEMO_WORKLOG.md`.
5. **Lưu ý để giải đáp nếu có người hỏi & Giới hạn:**
   - Ghi rõ phần nào đã được kiểm chứng trên hạ tầng thật, phần nào chưa thử hoặc nằm ngoài phạm vi (ví dụ: failover cache, autoscaling, benchmark DB, phục hồi WebSocket) để tránh kết luận quá phạm vi khi thuyết trình/hỏi đáp.
6. **Đối chiếu tiêu chí nghiệm thu:**
   - Ghi rõ mục này phục vụ tiêu chí nào trong Mục 12 của `docs/ALB_ElastiCache_Demo_Handover.md` và cập nhật bảng tổng hợp trạng thái nếu tiêu chí đó đổi trạng thái.

## 3. Quy tắc kỹ thuật & trung thực khi demo
- **Tách biệt phạm vi:** Chỉ triển khai ứng dụng lab độc lập (gợi ý trong `seminar-lab/alb-elasticache/`), không kéo toàn bộ Live Quiz, EKS, Kafka, PostgreSQL/RDS hay các tính năng ngoài phạm vi vào làm điều kiện hoàn thành.
- **Định tuyến ALB & Prefix:** Backend phải tự bỏ prefix `/lab/a` và `/lab/b` trước khi xử lý route; không dựa vào URL rewrite của ALB. Mọi API trả `Cache-Control: no-store`.
- **Không giả lập kết quả:**
  - `/health` độc lập với ElastiCache để demo ALB chạy tách bạch.
  - Nếu `store=elasticache` lỗi kết nối thì phải trả lỗi thật (ví dụ HTTP `503`), **tuyệt đối không fallback ngầm sang RAM**.
  - Khi demo dừng backend A, phải dùng kênh vận hành (`docker stop` qua SSM/CLI), không tạo nút public tắt tiến trình trên web UI và không che giấu lỗi chuyển tiếp trước khi ALB đánh dấu `unhealthy`.

## 4. Quy tắc bảo mật và kiểm soát chi phí AWS
- **Tuyệt đối không ghi bí mật vào file:** Không lưu mật khẩu Valkey, token, AWS Access Key/Secret Key, file `.env` thật hay Terraform state chứa credential vào `docs/DEMO_WORKLOG.md`, `README.md`, code hay Git. Luôn dùng placeholder (như `<VALKEY_PASSWORD>`, `<AWS_ACCOUNT_ID>`, `<ALB_DNS>`).
- **Theo dõi tài nguyên & cleanup:** Mọi tài nguyên AWS được tạo mới cho lab đều phải dùng tag `Project=quiz-service-seminar`, được ghi resource ID/loại node vào `docs/DEMO_WORKLOG.md` khi tạo và cập nhật ngay sau khi xóa (cleanup) để không bỏ sót tài nguyên tính phí.

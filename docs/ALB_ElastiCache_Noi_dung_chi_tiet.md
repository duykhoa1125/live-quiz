# Nội dung seminar AWS Application Load Balancer và ElastiCache

*Tài liệu đọc để tự tổng hợp thành 14 slide*

20 phút gồm hai demo trên AWS thật và thời gian trao đổi

### Mục tiêu và cách sử dụng

Tài liệu dành cho nhóm đã biết các khái niệm cơ bản về cloud, load balancing và cache. Nội dung đi vào các đối tượng, tùy chọn và cơ chế vận hành trên AWS; Live Quiz cung cấp bối cảnh để chọn phép thử và đánh giá khả năng áp dụng.

Mỗi slide có trọng tâm cho phần nói theo giờ, phần giải thích để chuẩn bị và kết quả người nghe cần nắm. Tài liệu đọc dài hơn bài thuyết trình. Trong 20 phút, chọn cơ chế tiêu biểu để giải thích, giới thiệu ngắn các nhóm tính năng còn lại và dành chi tiết mở rộng cho câu hỏi. Không đọc nguyên văn toàn bộ tài liệu.

### Phân bổ thời gian

| **Khối nội dung** | **Slide** | **Thời gian** |
| --- | --- | --- |
| Mở đầu và nhu cầu | 1 đến 2 | 1 phút 30 giây |
| ALB cùng demo | 3 đến 6 | 7 phút |
| ElastiCache cùng demo | 7 đến 10 | 7 phút |
| Phối hợp chi phí và kết luận | 11 đến 13 | 2 phút 30 giây |
| Trao đổi hoặc đệm | 14 | 2 phút |

### Hai demo giữ cùng phạm vi

Demo ALB kiểm tra phân phối request và health check của hai backend. Demo ElastiCache đối chiếu RAM riêng với Sorted Set dùng chung và restart một backend khi cache còn chạy. Các tính năng TLS của ALB, WAF, authentication, replica, Multi AZ failover và durability được giải thích nhưng không trở thành yêu cầu phải demo.

Bản ALB_ElastiCache_Demo_Handover.md tiếp tục là tài liệu giao việc cho teammate. Hai demo không yêu cầu triển khai toàn bộ Live Quiz, EKS, Kafka hoặc một hệ thống database mới. Tài liệu AWS được liên kết ngay cạnh phần sử dụng; ngày đối chiếu là 24 tháng 11 năm 2026.

## Slide 1  Giới thiệu ALB và ElastiCache qua Live Quiz

Thời lượng phần nói  0 phút 30 giây

**Trọng tâm khi trình bày:** Nêu hai dịch vụ sẽ khảo sát, câu hỏi mà mỗi dịch vụ giải quyết và hai demo AWS thật. Chỉ dùng Live Quiz để giúp người nghe hình dung tình huống áp dụng.

Seminar khảo sát Application Load Balancer cho việc nhận và phân phối truy cập, cùng Amazon ElastiCache cho việc xử lý dữ liệu dùng chung trong bộ nhớ. Với mỗi dịch vụ, nhóm giải thích các thành phần AWS, giới thiệu nhóm tính năng chính, chạy một phép thử nhỏ và đánh giá phần nào có thể áp dụng vào Live Quiz.

Câu hỏi xuyên suốt là dịch vụ hoạt động theo cơ chế nào, nhóm phải cấu hình gì và bằng chứng nào cho thấy chức năng đang khảo sát dùng được. Một chức năng được giới thiệu trong lý thuyết không đồng nghĩa với việc nhóm sẽ triển khai chức năng đó trong demo.

**Điều giảng viên cần nắm:** Giảng viên nhận ra ngay đối tượng của seminar là hai dịch vụ AWS và cơ chế của chúng.

## Slide 2  Hai nhu cầu dẫn tới hai dịch vụ

Thời lượng phần nói  1 phút 00 giây

**Trọng tâm khi trình bày:** Dùng một tình huống nhiều backend để dẫn vào ALB, rồi dùng dữ liệu nằm riêng ở A và B để dẫn vào ElastiCache. Không trình bày toàn bộ kiến trúc dự án.

### Từ yêu cầu ứng dụng tới câu hỏi về dịch vụ

Khi có hai backend cùng phục vụ một buổi quiz, người chơi cần một địa chỉ truy cập chung. Nhóm muốn kiểm tra request có tới được cả A và B hay không và chuyện gì xảy ra với request mới khi một backend dừng. Đây là đầu vào cho phần ALB.

Nếu điểm thử nghiệm chỉ nằm trong RAM của A, B không tự đọc được dữ liệu đó. Nhóm tiếp tục kiểm tra việc đưa dữ liệu ra một dịch vụ dùng chung: ghi điểm qua A, đọc qua B và cập nhật thứ hạng. Đây là đầu vào cho phần ElastiCache.

| **Dịch vụ** | **Câu hỏi của phép thử** | **Bằng chứng cần thu** |
| --- | --- | --- |
| ALB | Một địa chỉ có phân phối request và loại backend lỗi khỏi luồng bình thường không | Backend ID trong response và target health trên AWS |
| ElastiCache | Hai backend có cùng đọc và cập nhật một bảng điểm không | Cùng room key và kết quả đọc từ A và B |

Hai phép thử xác nhận chức năng ở phạm vi lab. Để kết luận phục vụ được bao nhiêu người chơi, nhóm còn cần workload, baseline và bài đo riêng. Trong seminar, kết luận tính khả thi gắn với đúng hành vi quan sát được.

**Điều giảng viên cần nắm:** Giảng viên hiểu vì sao chọn hai dịch vụ này và nhóm sẽ kiểm tra tính khả thi theo tiêu chí nào.

## Slide 3  ALB trong hệ sinh thái AWS

Thời lượng phần nói  1 phút 30 giây

**Trọng tâm khi trình bày:** Giải thích ALB xử lý HTTP ở tầng ứng dụng và mô tả luồng listener tới rule tới target group tới target. Nhắc AWS mở rộng năng lực ALB, còn mở rộng backend là công việc riêng.

### AWS quản lý phần nào

ALB thuộc Elastic Load Balancing, nhận HTTP hoặc HTTPS và phân phối tới các target. AWS vận hành hạ tầng cân bằng tải và điều chỉnh năng lực của dịch vụ theo lưu lượng. Nhóm vẫn phải cung cấp backend, đăng ký target, thiết kế health check và cấu hình mạng. Việc ALB có thể nhận thêm lưu lượng không làm số EC2 tự tăng; muốn vậy cần cơ chế như EC2 Auto Scaling hoặc scaling của nền tảng chạy container.

[AWS tổng quan Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)

### Các đối tượng trong một request

| **Đối tượng** | **Vai trò và cấu hình nhóm quyết định** |
| --- | --- |
| Load balancer | Điểm truy cập có DNS do AWS cấp và các subnet được chọn |
| Listener | Nhận kết nối theo protocol và port như HTTP 80 hoặc HTTPS 443 |
| Listener rule | Xét điều kiện theo priority và thực hiện action |
| Target group | Gom các đích có cùng cấu hình định tuyến và health check |
| Target | Backend cụ thể nhận request và chạy logic ứng dụng |

Ví dụ, request GET /api/whoami tới listener 80, khớp default rule, được forward tới tg-main rồi đến A hoặc B. Target group không phải một máy chủ mới; nó là đối tượng cấu hình cho tập các đích. Target của ALB có thể thuộc loại instance, IP hoặc Lambda. Với EC2 dùng instance target, nhóm đăng ký instance và port backend; với IP target, nhóm đăng ký địa chỉ IP phù hợp.

[AWS listener và WebSocket](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)  |  [AWS listener rules](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-rules.html)  |  [AWS target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

### Availability Zone và điểm truy cập

ALB thông thường trên các Availability Zone yêu cầu ít nhất hai subnet ở hai AZ khác nhau. Cross zone load balancing cho phép phân phối qua các AZ; ALB bật ở cấp load balancer và có thể tắt ở cấp target group. Đây là cơ chế phân phối lưu lượng; muốn ứng dụng chịu được một AZ lỗi vẫn phải có backend và dữ liệu phù hợp ở AZ còn lại.

[AWS ALB và Availability Zone](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)

### Liên hệ ở mức vừa đủ với Live Quiz

Trong lab, ALB tạo một lối vào cho hai backend A và B. Seminar chỉ dùng mô hình này để quan sát quyết định định tuyến. Việc mỗi phòng quiz thuộc backend nào và cách khôi phục một phòng đang chơi là câu hỏi của ứng dụng, được nhắc lại sau khi đã hiểu dịch vụ.

**Điều giảng viên cần nắm:** Giảng viên nắm được các đối tượng phải cấu hình trên AWS và vai trò của từng đối tượng.

## Slide 4  Cơ chế routing và health check của ALB

Thời lượng phần nói  1 phút 30 giây

**Trọng tâm khi trình bày:** Theo dõi một request qua các rule, phân biệt việc chọn target group với chọn target bên trong nhóm. Giải thích health check bằng trạng thái, chu kỳ kiểm tra và ngưỡng lỗi. Các tùy chọn còn lại dùng để chuẩn bị câu hỏi hoặc đọc thêm.

### Điều kiện và thứ tự của listener rules

ALB đánh giá rule theo priority tăng dần; default rule đứng cuối. Điều kiện có thể dựa trên host, path, HTTP method, HTTP header, query string hoặc source IP. Ví dụ /api/* có thể đi tới nhóm API, còn /assets/* tới nhóm phục vụ tài nguyên. Các điều kiện trong rule phải cùng đúng; nhiều giá trị của một điều kiện cho phép khớp một trong các giá trị. Cần kiểm tra thứ tự để rule rộng không che rule cụ thể.

[AWS listener rules](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-rules.html)  |  [AWS các loại điều kiện định tuyến](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-condition-types.html)

| **Action** | **Cơ chế và ví dụ** |
| --- | --- |
| Forward | Chuyển request tới một hoặc nhiều target group |
| Redirect | Trả phản hồi để client chuyển sang URL khác như HTTP sang HTTPS |
| Fixed response | ALB trả mã và nội dung đã cấu hình như thông báo bảo trì |
| Weighted forwarding | Chia lưu lượng giữa các target group theo trọng số phục vụ canary hoặc blue green |

Trọng số giữa target group và thuật toán chọn target trong một group là hai quyết định khác nhau. Đặc biệt, nếu một weighted target group không còn target khỏe, ALB không tự chuyển toàn bộ phần lưu lượng của nhóm đó sang group khỏe khác. Vì vậy cấu hình 90/10 giữa hai phiên bản chưa phải một chính sách failover hoàn chỉnh.

[AWS các action của listener rule](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-action-types.html)

### Routing theo path và rewrite là hai việc khác nhau

Rule khớp /lab/a/* không tự bỏ prefix. ALB hỗ trợ host header rewrite và URL rewrite khi có transform. Rewrite sửa request trước khi forward; redirect yêu cầu client gửi request mới. Lab vẫn để backend bỏ prefix như plan đã bàn giao; rewrite được giới thiệu trong phần lý thuyết.

[AWS host header rewrite và URL rewrite](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-transforms.html)

### Thuật toán bên trong target group

| **Thuật toán** | **Cách chọn target** |
| --- | --- |
| Round robin | Lần lượt qua các target khỏe và là mặc định |
| Least outstanding requests | Ưu tiên target có ít request đang xử lý hơn |
| Weighted random | Chọn ngẫu nhiên và hỗ trợ ATW anomaly mitigation |

Demo dùng round robin và tắt stickiness. Mẫu 20 request dùng để thấy cả hai backend tham gia; không lấy tỷ lệ chính xác trong mẫu nhỏ làm tiêu chí duy nhất.

[AWS thuộc tính target group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/edit-target-group-attributes.html)

### Health check tạo ra quyết định loại target như thế nào

Health check là request riêng tới đường dẫn và port đã cấu hình. ALB dùng timeout, success code, interval và ngưỡng thành công hoặc thất bại liên tiếp để cập nhật target health. Lab chọn GET /health, mã 200, interval 5 giây, timeout 2 giây và hai lần lỗi liên tiếp để target thành unhealthy. Vì phát hiện theo chu kỳ nên crash có thể gây request lỗi trước khi trạng thái kịp đổi.

[AWS các tham số cấu hình health check](https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_ModifyTargetGroup.html)

Khi còn target khỏe, request mới đi tới các đích khỏe theo cấu hình. Nếu mọi target đã đăng ký trong group đều unhealthy, ALB có thể fail open và vẫn gửi tới các target đó. Health check không hỗ trợ WebSocket; ứng dụng cần một endpoint HTTP phù hợp. Nội dung /health chỉ xác nhận điều mà chính endpoint kiểm tra, nên 200 không tự bảo đảm mọi thao tác nghiệp vụ đều chạy đúng.

[AWS health checks và fail open](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)

### Đọc thêm về cập nhật backend và lỗi một phần

Deregistration delay hỗ trợ các request đang xử lý khi chủ động rút target; slow start giúp target mới nhận tải tăng dần. Hai cơ chế này phục vụ triển khai có kiểm soát, còn demo dừng tiến trình là tình huống crash. Không nên dùng khả năng drain để hứa một kết nối đang chạy sẽ sống qua mọi sự cố.

[AWS thuộc tính target group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/edit-target-group-attributes.html)

ATW nhận diện trường hợp target vẫn qua health check nhưng phát sinh lỗi bất thường so với các target khác, thường gọi là gray failure. Anomaly mitigation dùng cùng weighted random để giảm phần lưu lượng vào target bất thường. Tính năng này cần được khảo sát riêng; lab không bật để tránh lẫn với phép thử health check chủ động.

[AWS Automatic Target Weights và gray failures](https://aws.amazon.com/blogs/networking-and-content-delivery/improving-availability-with-application-load-balancer-automatic-target-weights/)

**Điều giảng viên cần nắm:** Giảng viên thấy nhóm hiểu quyết định định tuyến và điều kiện khiến một backend ngừng nhận request mới.

## Slide 5  Demo ALB trên AWS thật

Thời lượng phần nói  3 phút 00 giây

**Trọng tâm khi trình bày:** Chỉ trình diễn hai điều: request qua cùng DNS tới A và B, sau đó dừng A và quan sát target health cùng các request tiếp theo. Không tạo tài nguyên trong giờ báo cáo.

### Cấu hình phục vụ phép thử

Hai EC2 chạy cùng ứng dụng lab nhưng khác BACKEND_ID. Một ALB có listener HTTP 80 và default rule forward tới tg-main chứa cả A và B ở port 3000. Endpoint /api/whoami trả backendId, requestId và thời điểm. /health chỉ kiểm tra tiến trình HTTP để phần demo ALB không phụ thuộc trạng thái của cache.

### Kịch bản trong ba phút

| **Mốc** | **Thao tác** | **Màn hình hoặc kết quả quan sát** |
| --- | --- | --- |
| 0 đến 40 giây | Mở DNS ALB và chạy một loạt request | Response có cả backend A và B; không đọc cache trình duyệt |
| 40 đến 65 giây | Cho xem tg-main rồi dừng app A qua SSM | Hai target ban đầu khỏe và thao tác dừng tiến trình thực |
| 65 đến 130 giây | Tiếp tục request và xem target health | A đổi sang unhealthy; B tiếp tục phục vụ request mới |
| 130 đến 180 giây | Khởi động lại A và chốt kết quả | A hồi phục nếu kịp; nêu đúng thời gian đã quan sát |

Từ lúc dừng A tới lúc health đổi có thể xuất hiện lỗi. Nhóm ghi lại diễn biến thật thay vì cắt đoạn lỗi rồi kết luận chuyển đích tức thì. Trong phép thử này, B phải vẫn khỏe. Các path chẩn đoán /lab/a/* được ghim vào A phục vụ demo cache, nên không dùng chúng để đánh giá khả năng phân phối của tg-main.

### Phạm vi kết luận

Kết quả đạt khi cùng một DNS đã tới cả A và B, sau lỗi của A còn nhận được response thành công từ B qua đường mặc định và AWS hiển thị trạng thái phù hợp. Phép thử xác nhận routing và health detection. Nhóm chưa đo sức chứa, chưa kích hoạt autoscaling và chưa kiểm tra khôi phục phòng quiz hay kết nối WebSocket đang tồn tại.

Teammate chuẩn bị sẵn trang lab, lệnh stop và start, một cửa sổ target health và video dự phòng từ chính lab. Cấu hình chi tiết, API và cleanup vẫn theo ALB_ElastiCache_Demo_Handover.md; nội dung lý thuyết mở rộng không bổ sung điều kiện nghiệm thu demo.

**Điều giảng viên cần nắm:** Giảng viên xem được bằng chứng AWS đang phân phối request và phản ứng với lỗi tiến trình backend.

## Slide 6  Các tính năng ALB cần biết trước khi áp dụng

Thời lượng phần nói  1 phút 00 giây

**Trọng tâm khi trình bày:** Nêu ba nhóm tính năng mở rộng là giao thức và kết nối, bảo mật và quan sát. Dành câu cuối giải thích WebSocket gắn với một target trong suốt kết nối. Chi tiết bên dưới dành cho chuẩn bị và trao đổi.

### HTTPS và quản lý certificate

Với HTTPS listener, ALB kết thúc TLS từ client bằng certificate được cấu hình trên listener. AWS Certificate Manager hỗ trợ quản lý certificate; SNI giúp chọn certificate phù hợp khi một listener phục vụ nhiều tên miền. Chặng ALB tới target có cấu hình protocol riêng, vì vậy bật HTTPS ở phía client chưa tự mã hóa chặng backend. Lab dùng HTTP trên DNS AWS cấp để giảm việc chuẩn bị domain; phần TLS được giải thích bằng cơ chế và cấu hình.

[AWS certificate ACM và SNI](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html)  |  [AWS target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

### Security group và WAF

Security group của ALB cho phép client vào listener và ALB đi tới port ứng dụng cùng health check. Security group của backend nên nhận port ứng dụng từ security group ALB. Nếu mở backend trực tiếp cho mọi IP, người dùng có thể đi vòng qua quy tắc ở ALB.

[AWS security groups của ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)

ALB tích hợp AWS WAF để áp dụng web ACL, chẳng hạn rule chặn mẫu request hoặc rate based rule trên HTTP. WAF là dịch vụ và cấu hình bổ sung; tạo ALB chưa có nghĩa các rule bảo vệ ứng dụng đã được bật. Quyền host mở câu hỏi hay người chơi gửi đáp án vẫn phải được ứng dụng kiểm soát.

[AWS tích hợp ALB với WAF và các dịch vụ liên quan](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-integrations.html)

### Xác thực ở ALB

HTTPS listener có thể dùng Cognito hoặc OIDC để thực hiện xác thực người dùng trước khi forward request. ALB xử lý phần trao đổi với nhà cung cấp danh tính, còn backend vẫn cần phân quyền theo hành động và tài nguyên, ví dụ người dùng này có được quản lý phòng này hay không.

[AWS xác thực người dùng bằng OIDC và Cognito](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html)

Một khả năng đọc thêm hiện có là xác minh JWT cho giao tiếp dịch vụ hoặc máy với máy: ALB lấy khóa từ JWKS, kiểm tra chữ ký và các claim được hỗ trợ rồi mới forward. Đây là một lựa chọn có điều kiện về listener, thuật toán và cấu hình issuer, cần đối chiếu tài liệu khi dùng; lab không thêm luồng đăng nhập hoặc cấp token.

[AWS xác minh JWT tại ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-verify-jwt.html)

### WebSocket và các protocol version

ALB hỗ trợ HTTP Upgrade để tạo WebSocket; sau khi upgrade, các message đi qua kết nối tới target đã chọn. Một WebSocket không được chia từng message cho A và B. Nếu target mất, kết nối có thể đứt và client cần kết nối lại; việc phục hồi người chơi và trạng thái phòng thuộc giao thức ứng dụng. HTTP/2 và gRPC cũng được hỗ trợ theo cấu hình listener và target group thích hợp, nhưng không được suy ra từ demo HTTP hiện tại.

[AWS listener và WebSocket](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)  |  [AWS target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

Cookie stickiness giúp các HTTP request của một client tiếp tục về cùng target, với loại cookie do ALB hoặc ứng dụng hỗ trợ. Nó không nhân bản RAM của target. Với WebSocket đã upgrade, chính kết nối giữ target; cookie stickiness không phải cơ chế chuyển tiếp từng message.

[AWS các nhóm tính năng chính của ALB](https://aws.amazon.com/elasticloadbalancing/application-load-balancer/)

### Metrics và access logs

| **Dữ liệu quan sát** | **Câu hỏi có thể trả lời** |
| --- | --- |
| RequestCount | Lưu lượng HTTP đang đi qua ALB thay đổi thế nào |
| HealthyHostCount và UnHealthyHostCount | Còn bao nhiêu target khỏe theo health check |
| TargetResponseTime | Từ lúc request rời ALB đến lúc target bắt đầu trả response headers mất bao lâu |
| HTTPCode_ELB_5XX_Count | ALB đang tạo bao nhiêu response 5xx |
| HTTPCode_Target_5XX_Count | Backend đang tạo bao nhiêu response 5xx |

Nên xem percentile phù hợp cho thời gian đáp ứng. TargetResponseTime không đo trọn vòng từ browser và không phải độ trễ phát message tới mọi người chơi. ActiveConnectionCount còn gồm kết nối phía client và phía target, nên không quy đổi trực tiếp thành số người chơi.

[AWS CloudWatch metrics của ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)

Access logs có thể bật để ghi vào S3, giúp đối chiếu request, đích và mã phản hồi. Với WebSocket, access log mô tả kết nối và không ghi riêng từng message; muốn đo phát câu hỏi tới người chơi vẫn cần log hoặc metric trong ứng dụng.

[AWS access logs của ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)

### Đánh giá khả năng dùng cho Live Quiz

ALB là ứng viên phù hợp cho cổng HTTP và WebSocket của hệ thống nhiều backend. Để triển khai thật, nhóm cần health endpoint có ý nghĩa, cấu hình timeout phù hợp và cách reconnect hoặc rejoin phòng. Demo HTTP chứng minh phần đường vào; nó chỉ tạo cơ sở để thử tiếp luồng realtime.

**Điều giảng viên cần nắm:** Giảng viên thấy nhóm biết những gì ALB cung cấp ngoài demo và giới hạn của việc áp dụng cho realtime.

## Slide 7  Amazon ElastiCache và các lựa chọn triển khai

Thời lượng phần nói  1 phút 30 giây

**Trọng tâm khi trình bày:** Giới thiệu dịch vụ managed, so sánh Serverless với node based và giải thích primary replica shard. Nêu rõ lab chọn Valkey một node để thấy cơ chế dữ liệu dùng chung.

### Engine cung cấp lệnh còn AWS cung cấp dịch vụ quản lý

ElastiCache là dịch vụ AWS quản lý cho Valkey, Redis OSS và Memcached. Các cấu trúc như Sorted Set đến từ engine; AWS đảm nhận các công việc hạ tầng như cấp phát, thay thế node, giám sát và patching theo mô hình triển khai. Ứng dụng vẫn cần client tương thích, cách tổ chức key, TTL, quyền truy cập và xử lý khi dịch vụ chậm hoặc mất kết nối.

[AWS các mô hình triển khai ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html)

| **Engine** | **Đặc điểm cần phân biệt** | **Liên hệ seminar** |
| --- | --- | --- |
| Valkey | Cấu trúc dữ liệu phong phú và Redis compatible APIs; tính năng phụ thuộc phiên bản | Dùng Sorted Set trong lab |
| Redis OSS | Các cấu trúc như Hash Set Sorted Set và các cơ chế replication hỗ trợ | Hiểu thuật ngữ và khả năng tương thích client |
| Memcached | Mô hình cache đối tượng đơn giản; không cung cấp Sorted Set | Không phù hợp cho đúng phép thử leaderboard đã chọn |

Không dùng tên Redis để thay thế mọi cấu hình ElastiCache. Những tính năng replication, backup và command phải được đối chiếu theo engine, version và deployment option. Chẳng hạn bảng so sánh node based không đủ để kết luận mọi biến thể Memcached đều có cùng khả năng backup.

[AWS so sánh engine và cluster mode](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SelectEngine.html)

### Serverless và node based

| **Mô hình** | **AWS xử lý** | **Nhóm vẫn quyết định** |
| --- | --- | --- |
| Serverless | Tự điều chỉnh capacity và quản lý cấu trúc hạ tầng; lưu dữ liệu dự phòng qua ba AZ | Engine và khả năng client; giới hạn sử dụng; key TTL bảo mật và cách dùng dữ liệu |
| Node based | Vận hành phần cứng thay node và patching trong dịch vụ managed | Node type số shard replica vị trí AZ và tham số được cho phép |

[AWS các mô hình triển khai ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html)

### Node shard primary và replica

Trong node based Valkey hoặc Redis OSS, một shard chứa một phần dữ liệu và có primary cùng các replica nếu được cấu hình. Cluster mode disabled có một shard; cluster mode enabled cho phép chia dữ liệu qua nhiều shard. Primary nhận ghi, replica phục vụ đọc theo cách client được cấu hình và có thể tham gia dự phòng. Thêm replica và thêm shard vì vậy phục vụ những mục tiêu khác nhau.

[AWS các thành phần ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.corecomponents.html)

### Kết nối đúng endpoint

| **Cấu hình node based** | **Endpoint và client** |
| --- | --- |
| Một node độc lập | Dùng endpoint node cho đọc và ghi |
| Cluster mode disabled có replica | Ghi qua primary endpoint; đọc replica có thể dùng reader endpoint |
| Reader endpoint | DNS phân giải luân phiên tới replica; phân tán kết nối chứ không proxy từng lệnh như ALB |
| Cluster mode enabled | Dùng configuration endpoint để client hỗ trợ cluster khám phá và định tuyến tới các shard |

Client dùng pool kết nối lâu có thể tạo phân bố đọc không đều. Đọc replica cũng cần chấp nhận khả năng dữ liệu trễ; nếu B phải thấy ngay điểm vừa ghi từ A thì lab đọc và ghi trên cùng node primary. Configuration endpoint không phải nơi che toàn bộ việc định tuyến shard cho một client bất kỳ.

[AWS connection endpoints](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Endpoints.html)  |  [AWS client connection pools](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/BestPractices.Clients.Redis.Connections.html)

### Cấu hình thực sự dùng trong lab

Lab chọn ElastiCache for Valkey node based, cluster mode disabled, một primary và không có replica. A và B ở cùng VPC truy cập endpoint cache bằng TLS và tài khoản RBAC. Cấu hình này phục vụ kiểm tra chia sẻ dữ liệu; không đại diện cho cấu hình có dự phòng và không bật durability transactional log.

**Điều giảng viên cần nắm:** Giảng viên phân biệt được engine với dịch vụ AWS và biết các quyết định triển khai mà nhóm phải đưa ra.

## Slide 8  Cấu trúc dữ liệu TTL và chiến lược sử dụng cache

Thời lượng phần nói  1 phút 30 giây

**Trọng tâm khi trình bày:** Dùng Sorted Set để giải thích cơ chế leaderboard, phân biệt TTL với eviction và nói rõ demo đang thử dữ liệu dùng chung. Cache aside và write through được giới thiệu bằng luồng ngắn, không triển khai thêm DB.

### Chọn cấu trúc dữ liệu theo thao tác cần thực hiện

String phù hợp với một giá trị hoặc kết quả đã serialize; Hash gom các field; Set quản lý thành viên duy nhất; Sorted Set gắn một member với score và hỗ trợ lấy theo thứ hạng. Pub/Sub phù hợp cho thông báo tới các bên đang subscribe nhưng không thay thế một luồng sự kiện cần lưu và phát lại. Việc chọn cấu trúc phải xuất phát từ thao tác, vòng đời và yêu cầu khôi phục dữ liệu.

[AWS use cases của ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/elasticache-use-cases.html)

### Sorted Set trong phép thử leaderboard

Lab dùng key quizlab:room:demo:leaderboard, member là playerId và score là điểm tuyệt đối. Các lệnh minh họa dưới đây được backend gửi qua TLS; trình duyệt chỉ gọi API của lab.

| **Lệnh minh họa** | **Ý nghĩa** |
| --- | --- |
| ZADD key 100 alice 150 bob 120 chi | Tạo ba member cùng điểm trong một Sorted Set |
| ZRANGE key 0 9 REV WITHSCORES | Đọc tối đa 10 member có score cao nhất |
| ZADD key 170 alice | Gán lại điểm Alice thành 170 và cập nhật vị trí |

ZADD cập nhật member đã tồn tại. Gọi lại thao tác gán 170 không tự cộng thêm 170. Điều này làm demo dễ lặp lại nhưng chưa giải quyết xung đột giữa nhiều bản cập nhật điểm khác nhau hoặc thứ tự của event. Nếu bằng điểm, engine có quy tắc thứ tự member; demo chọn điểm khác nhau và để luật phá hòa của Live Quiz cho giai đoạn tích hợp.

[Valkey cơ chế ZADD](https://valkey.io/commands/zadd/)  |  [Valkey cơ chế ZRANGE](https://valkey.io/commands/zrange/)

### TTL gắn với vòng đời của key

EXPIRE gán thời gian hết hạn cho key. Với Sorted Set này, TTL áp dụng cho cả key leaderboard, không phải TTL riêng cho từng player. Sau khi hết hạn, lần đọc thấy key không còn; gán EXPIRE lần nữa có thể làm mới hạn. Lab đặt 3600 giây và chỉ dùng một key khác có TTL ngắn nếu muốn minh họa hết hạn.

[Valkey cơ chế EXPIRE](https://valkey.io/commands/expire/)

### Eviction gắn với áp lực bộ nhớ

Một key còn TTL vẫn có thể bị loại sớm do eviction nếu policy cho phép. maxmemory-policy trong parameter group quyết định nhóm key nào được xét và chính sách như LRU hoặc LFU. Ví dụ allkeys-lru xét mọi key, volatile-lru xét các key có TTL, còn noeviction có thể làm lệnh ghi thất bại khi đầy bộ nhớ. TTL vì vậy không phải cam kết key chắc chắn tồn tại đến một thời điểm.

[AWS parameter groups và maxmemory policy](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/ParameterGroups.Engine.html)

### Hai chiến lược cache phổ biến cần giới thiệu

Cache aside hay lazy loading: ứng dụng đọc cache trước; khi không có key thì đọc DB, trả kết quả và đưa vào cache. Cách này tập trung cache vào dữ liệu được hỏi nhưng lần đọc đầu phải đi DB và dữ liệu có thể cũ. TTL giới hạn thời gian giữ bản sao; khi dữ liệu gốc đổi, ứng dụng còn phải quyết định invalidate hoặc cập nhật cache.

Write through cập nhật cache trên đường ghi dữ liệu để tăng cơ hội lần đọc sau có dữ liệu mới. Đổi lại đường ghi có thêm công việc. Một cache trống sau sự cố vẫn cần cách nạp lại, nên các chiến lược thường được phối hợp.

[AWS lazy loading write through và TTL](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Strategies.html)

Trong ứng dụng phân tán, ghi DB và cache là hai thao tác có thể lỗi riêng. Nhóm cần xử lý trường hợp chỉ một bên thành công hoặc cập nhật đến sai thứ tự; tên write through không tự tạo transaction xuyên hai dịch vụ. Đây là yêu cầu thiết kế khi tích hợp, không thuộc phép thử hai ngày.

### Phân biệt hai cách dùng trong seminar

Cache của kết quả truy vấn nhằm giảm việc đọc lại DB; dữ liệu chung trong RAM nhằm để nhiều backend truy cập cùng một trạng thái. Demo đang kiểm tra cách dùng thứ hai. Vì không có DB và baseline trong lab, nhóm không kết luận đã giảm tải DB hoặc tăng tốc truy vấn một hệ số cụ thể. PostgreSQL vẫn có thể là nơi giữ dữ liệu chính, còn leaderboard trong cache là bản nhìn có thể dựng lại.

**Điều giảng viên cần nắm:** Giảng viên hiểu lệnh làm gì và thấy sự khác nhau giữa cache kết quả truy vấn với lưu trạng thái tạm dùng chung.

## Slide 9  Demo ElastiCache chia sẻ leaderboard giữa A và B

Thời lượng phần nói  3 phút 00 giây

**Trọng tâm khi trình bày:** So sánh RAM riêng từng tiến trình với một Sorted Set chung, rồi cập nhật điểm và restart A. Kết quả quan sát phải hiện rõ backend nào ghi và backend nào đọc.

### Tại sao cần hai chế độ cùng giao diện

Ứng dụng lab có store=memory và store=elasticache với cùng chức năng gán điểm và đọc leaderboard. Các path /lab/a/* và /lab/b/* chọn đích A hoặc B để phép thử không phụ thuộc request ngẫu nhiên rơi vào đâu. Đây là các rule chẩn đoán của lab, không phải thiết kế phân phòng cho Live Quiz.

### Kịch bản trong ba phút

| **Mốc** | **Thao tác** | **Kết quả mong đợi cần xác nhận** |
| --- | --- | --- |
| 0 đến 40 giây | Ở memory ghi Alice qua A rồi đọc cùng phòng qua B | A có dữ liệu; RAM riêng của B chưa có |
| 40 đến 90 giây | Ở ElastiCache ghi Alice 100 Bob 150 Chi 120 qua A rồi đọc qua B | B đọc Bob rồi Chi rồi Alice từ cùng key |
| 90 đến 120 giây | Gán Alice thành 170 qua A và đọc B | Alice lên đầu và điểm vẫn là 170 khi lặp thao tác gán |
| 120 đến 165 giây | Restart A trong khi cache và B tiếp tục chạy | B vẫn đọc được; A đọc lại được sau khi khởi động |
| 165 đến 180 giây | Chỉ lại endpoint và cấu hình cache trên AWS | Chốt dữ liệu được chia sẻ bằng ElastiCache thật |

### Giải thích đúng kết quả

Điều được kiểm tra là A và B kết nối thành công tới dịch vụ cache, thao tác trên cùng dữ liệu và đọc được thứ hạng sau cập nhật. Restart A cho thấy vòng đời dữ liệu đã tách khỏi tiến trình A khi cache còn hoạt động. Nó không cho biết điều gì xảy ra khi node cache mất, không kiểm tra replica promotion và không chứng minh độ bền của điểm trong mọi sự cố.

Nếu kết nối cache lỗi, giao diện phải hiện lỗi để người xem biết. Không âm thầm fallback sang RAM rồi vẫn gọi kết quả là dữ liệu dùng chung. Lab ghi và đọc trên cùng primary để không biến độ trễ replica thành một biến số ngoài mục tiêu.

### Chuẩn bị để thao tác ổn định

Dùng dữ liệu giả, room ID riêng cho từng lần chạy, nút reset có phạm vi lab và response hiện backendId cùng storeMode. Trước buổi nói, kiểm tra DNS, TLS, RBAC và cả hai backend. Video dự phòng phải được quay từ chính cấu hình trên AWS. TTL ngắn là tùy chọn sau khi đã hoàn thành các bước chính.

[Valkey cơ chế ZADD](https://valkey.io/commands/zadd/)  |  [Valkey cơ chế ZRANGE](https://valkey.io/commands/zrange/)

**Điều giảng viên cần nắm:** Giảng viên thấy dữ liệu nằm ngoài backend, dùng được qua nhiều backend và hỗ trợ thao tác thứ hạng.

## Slide 10  Tính năng ElastiCache ngoài phạm vi demo

Thời lượng phần nói  1 phút 00 giây

**Trọng tâm khi trình bày:** Nhóm các tính năng mở rộng theo availability, scaling, security và monitoring. Chốt lab một node chưa thử dự phòng; khi dùng cho Live Quiz phải giữ rõ nơi lưu điểm chính và cách dựng lại dữ liệu.

### Replication Multi AZ và automatic failover

Với cấu hình Valkey hoặc Redis OSS có replica, primary sao chép dữ liệu sang replica; replication thông thường là bất đồng bộ nên replica có thể đọc trễ và một số ghi mới có rủi ro mất khi primary lỗi. Multi AZ đặt replica ở AZ khác và dùng automatic failover để promote replica thích hợp khi primary hỏng. Client phải reconnect đúng endpoint; không nên hứa kết nối đang dùng sẽ liên tục không gián đoạn.

Replica giúp dự phòng và có thể phục vụ đọc. Nó không chia đôi dữ liệu của shard và không làm năng lực ghi tăng tuyến tính. Lab không có replica nên chỉ giới thiệu cơ chế này.

[AWS Multi AZ và automatic failover](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/AutoFailover.html)  |  [AWS replication groups và replica lag](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Replication.html)

### Snapshot và durability giải quyết các tình huống khác

Snapshot lưu trạng thái dữ liệu để restore về một mốc được chụp. Nó hỗ trợ khôi phục nhưng không tự bao gồm mọi cập nhật sau mốc đó, và thời gian restore khác với promotion của replica. Backup cần được đặt theo mục tiêu khôi phục và kiểm tra quy trình restore.

[AWS snapshot và restore](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups.html)

Tài liệu hiện tại của AWS còn có durability cho node based Valkey từ 9.0 với cluster mode enabled và các điều kiện về node type, Multi AZ cùng replica. Cơ chế này ghi vào transactional log qua nhiều AZ. Chế độ synchronous đợi lưu log rồi mới xác nhận ghi; asynchronous xác nhận trước nên có cửa sổ rủi ro mất phần chưa được lưu. Không suy từ tên ElastiCache rằng mọi cấu hình đều chỉ có dữ liệu dễ mất, cũng không suy rằng mọi cluster đã bật durability.

[AWS durability với transactional log](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/durability.html)  |  [AWS điều kiện áp dụng durability](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Durability.Limitations.html)

| **Cơ chế** | **Mục tiêu** | **Trong demo** |
| --- | --- | --- |
| Dữ liệu ngoài tiến trình A và B | Tách dữ liệu khỏi RAM riêng của backend | Có |
| Replica và Multi AZ failover | Khôi phục vai trò primary khi node hoặc AZ có sự cố | Chưa |
| Snapshot và restore | Khôi phục từ một bản chụp dữ liệu | Chưa |
| Durability transactional log | Bảo vệ ghi theo chế độ và điều kiện cấu hình | Chưa |

### Scaling phải khớp với nút thắt

Tăng node type mở rộng tài nguyên của node; thêm read replica phục vụ nhu cầu đọc; thêm shard trong cluster mode enabled phân bố dữ liệu và tải qua các primary. Client phải hỗ trợ topology tương ứng. Một hot key lớn vẫn tập trung thao tác vào shard chứa nó, nên tăng số shard không mặc nhiên tăng tốc mọi thao tác trên đúng key đó. Serverless tự quản lý capacity nhưng ứng dụng vẫn cần kiểm soát cách dùng và giới hạn chi phí.

[AWS scaling node based](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Scaling-self-designed.html)  |  [AWS các thành phần ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.corecomponents.html)  |  [AWS các mô hình triển khai ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html)

### Bảo mật gồm mạng mã hóa xác thực và phân quyền

Với cấu hình node based của lab, backend kết nối qua mạng VPC và security group cache chỉ cho phép port 6379 từ security group backend. Người chơi không nhận endpoint cùng credential để truy cập trực tiếp vào cache. Encryption in transit bảo vệ dữ liệu trên đường truyền; encryption at rest bảo vệ dữ liệu lưu theo các cơ chế của dịch vụ. Hai cài đặt có mục tiêu khác nhau.

[AWS tổng quan bảo mật dữ liệu ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/encryption.html)  |  [AWS TLS của ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/in-transit-encryption.html)

RBAC tổ chức user và user group cùng quyền lệnh, key hoặc channel. Tài khoản của lab chỉ cần các lệnh sử dụng và prefix quizlab:*; không cần trao quyền quản trị cache cho ứng dụng. Quyền IAM tạo cluster trong AWS và quyền chạy lệnh trên dữ liệu là hai lớp khác nhau.

[AWS users user groups và RBAC](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Clusters.RBAC.html)

ElastiCache còn hỗ trợ IAM authentication với engine version phù hợp và TLS. Client dùng token ngắn hạn thay mật khẩu dài hạn, vì vậy phải có cơ chế làm mới credential hoặc xác thực lại theo yêu cầu của dịch vụ. Tính năng này được giới thiệu; demo giữ RBAC có password riêng để giới hạn công việc chuẩn bị.

[AWS IAM authentication cho kết nối cache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-iam.html)

### Giám sát bằng CloudWatch

| **Metric hoặc nhóm metric** | **Diễn giải cần nắm** |
| --- | --- |
| CacheHits CacheMisses CacheHitRate | Mức thành công của các lookup; đối chiếu với cache pattern và loại command |
| DatabaseMemoryUsagePercentage | Áp lực bộ nhớ dành cho dữ liệu |
| Evictions | Key bị loại do giới hạn bộ nhớ; khác với hết TTL theo vòng đời |
| EngineCPUUtilization và CPUUtilization | Theo dõi phần engine cùng tải của cả host |
| CurrConnections | Kết nối client; cần xem pool hoặc việc mở kết nối lặp lại |
| ReplicationLag | Độ trễ của replica khi cấu hình có replication |

Hit rate cao không tự chứng minh dữ liệu đúng hoặc leaderboard cập nhật kịp. Các command và pattern khác nhau ảnh hưởng ý nghĩa metric; lab thao tác Sorted Set không thay thế một bài đo cache aside. Để đánh giá người chơi thấy kết quả nhanh hay chậm còn cần thời gian API và số lỗi từ ứng dụng.

[AWS định nghĩa metrics cho Valkey và Redis OSS](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.Redis.html)

Khi memory cao kèm eviction, kiểm tra kích thước dữ liệu, TTL và khả năng mở rộng. Khi CPU hoặc connection tăng, kiểm tra command, pool kết nối và workload trước khi chọn tăng tài nguyên. Cảnh báo cần ngưỡng phù hợp với baseline của chính hệ thống, không lấy một ngưỡng chung cho mọi node.

[AWS lựa chọn metrics cần giám sát](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.WhichShouldIMonitor.html)

**Điều giảng viên cần nắm:** Giảng viên thấy nhóm hiểu các lựa chọn vận hành của dịch vụ và không đánh đồng chia sẻ RAM với hệ thống đã chịu lỗi.

## Slide 11  Hai dịch vụ phối hợp trong một mô hình nhỏ

Thời lượng phần nói  1 phút 00 giây

**Trọng tâm khi trình bày:** Theo dõi một lần ghi và một lần đọc: request được ALB chuyển tới backend; backend thực hiện lệnh trên cache chung. Giữ sơ đồ ở mức người dùng ALB A B và ElastiCache.

### Luồng cần diễn giải

Người dùng gọi API qua DNS ALB. ALB chọn backend theo rule và trạng thái target. Backend xử lý request rồi truy cập ElastiCache bằng kết nối của server. Nếu request sau tới backend khác, backend đó vẫn đọc được cùng key. ALB không kết nối thay backend tới cache, và ElastiCache không quyết định browser được chuyển tới A hay B.

| **Tình huống quan sát** | **Cơ chế liên quan** | **Việc ứng dụng vẫn phải làm** |
| --- | --- | --- |
| Request được A hoặc B trả lời | Listener rule target group và routing của ALB | Cung cấp backend tương thích và health endpoint |
| A ghi B đọc cùng leaderboard | Hai client server dùng cùng dữ liệu ElastiCache | Tổ chức key và thao tác cập nhật nhất quán |
| A dừng nhưng B còn trả lời | ALB phát hiện lỗi và còn target khỏe | Đảm bảo B có tài nguyên và quyền truy cập dữ liệu |
| Người chơi cần quay lại phòng sau mất kết nối | Cần thử thêm ngoài hai demo hiện tại | Reconnect rejoin và khôi phục trạng thái phòng |

### Kết luận về khả năng triển khai

Hai dịch vụ cung cấp các thành phần khả dụng cho hướng nhiều backend: một lối vào được quản lý và một nơi xử lý dữ liệu dùng chung. Quyết định tích hợp tiếp theo dựa trên kết quả lab cùng yêu cầu thực tế của Live Quiz. Nhóm chỉ cần nêu những công việc nối tiếp này, không biến phần kết luận thành bản thiết kế lại toàn hệ thống.

### Đối chiếu với dự án hiện tại

Ở revision đã đối chiếu, dự án giữ điểm chính trong PostgreSQL và có luồng xử lý điểm riêng. Sorted Set trong lab là thử nghiệm cho một leaderboard hoặc bản nhìn tạm có thể dựng lại, chưa phải cơ chế đã tích hợp của repo. Trước khi đưa vào dự án, nhóm phải xác định nguồn điểm chính, nơi cập nhật cache, luật phá hòa và cách xử lý event lặp hoặc đến trễ.

[Repo Live Quiz tại revision đã đối chiếu](https://github.com/khanh04032005/cloud/blob/569e1f380dc824eba508d77d9e72083fdd1eddf3/packages/socket/src/services/cloud-game.ts)

**Điều giảng viên cần nắm:** Giảng viên phân biệt được đường truyền request với đường truy cập dữ liệu và thấy hai dịch vụ bổ sung cho nhau.

## Slide 12  Chi phí và vận hành cần tính khi lựa chọn

Thời lượng phần nói  1 phút 00 giây

**Trọng tâm khi trình bày:** Giải thích các thành phần tính phí và những cấu hình làm chi phí thay đổi. Nêu cách giới hạn thời gian bật lab và danh sách cleanup; không đọc bảng giá dài trong seminar.

### ALB tính theo thời gian và mức sử dụng

Với ALB, phần chi phí chính là thời gian load balancer hoạt động và LCU sử dụng. LCU xem các chiều gồm new connections, active connections, processed bytes và rule evaluations; chiều chi phối quyết định LCU tính phí theo cách AWS quy định. Vì vậy số request không đủ để ước tính một ứng dụng giữ nhiều WebSocket lâu. Giá còn phụ thuộc region, loại target và các điều kiện hiện hành.

[AWS giá Elastic Load Balancing](https://aws.amazon.com/elasticloadbalancing/pricing/)

### ElastiCache tùy deployment option

Node based tính theo node, loại node và thời gian cùng các khoản liên quan theo cấu hình. Serverless tính theo dữ liệu lưu và mức xử lý ECPU, với mức tối thiểu và giới hạn tùy engine. Replica và shard tăng tài nguyên cần trả tiền; backup hoặc durability có thể có thành phần tính phí riêng. Phải kiểm tra đúng cấu hình thay vì chỉ so giá một node với tên Serverless.

[AWS giá Amazon ElastiCache](https://aws.amazon.com/elasticache/pricing/)

| **Quyết định cấu hình** | **Tác động cần cân nhắc** |
| --- | --- |
| Một cache node thay vì có replica | Lab ít tài nguyên hơn nhưng chưa có failover replica |
| Thêm replica hoặc shard | Phục vụ mục tiêu HA đọc hoặc phân mảnh và làm đổi tài nguyên |
| Giữ kết nối hoặc tăng payload | Đổi workload và phần sử dụng cần đo |
| Bật WAF access logs và backup | Thêm khả năng vận hành cùng phần chi phí tương ứng |

### Những việc cần có trong hai ngày triển khai

Ngày đầu kiểm tra quyền tài khoản và region, dựng ALB cùng hai backend, rồi xác nhận TLS và RBAC tới cache. Ngày hai hoàn tất giao diện so sánh, chạy hai kịch bản liên tiếp, ghi kết quả, quay video và tập nói theo giờ. Phần việc cụ thể theo bản Demo Handover đã có; không thêm WAF, đăng nhập, replica hay benchmark làm điều kiện hoàn thành.

Ước tính tổng lab còn phải cộng EC2, EBS, public IPv4 và truyền dữ liệu nếu có. Dọn cả ALB, target group, EC2 và volume, cache, snapshot giữ lại và tài nguyên mạng được tạo riêng khi không còn dùng. Không dùng việc tài khoản có credit để suy ra mọi cấu hình đều miễn phí. Ghi người phụ trách và thời điểm dọn trong README của lab.

### Thông tin nên báo cáo cùng kết quả

Ghi region, thời gian chạy, số backend, engine và version cache, node type, số replica, protocol TLS và chức năng thực sự được bật. Ghi thời gian phát hiện lỗi đã đo trong lần chạy; tránh biến giá trị cấu hình health check thành cam kết thời gian hồi phục cho mọi lần.

**Điều giảng viên cần nắm:** Giảng viên hiểu managed service tiết kiệm công vận hành nhưng vẫn có chi phí và trách nhiệm cấu hình.

## Slide 13  Kết luận theo những gì đã kiểm chứng

Thời lượng phần nói  0 phút 30 giây

**Trọng tâm khi trình bày:** Chốt cơ chế chính của mỗi dịch vụ, nhắc hai hành vi quan sát được và nêu bước tích hợp tiếp theo vào Live Quiz.

ALB cung cấp routing HTTP và HTTPS theo rule, phân phối trong target group và theo dõi target health. ElastiCache cung cấp các lựa chọn cache được AWS quản lý, cùng khả năng thao tác dữ liệu trong bộ nhớ theo engine. Nhóm đã chọn hai cơ chế tiêu biểu để thử: phân phối request và dữ liệu leaderboard dùng chung.

Sau khi chạy thành công, kết luận được phép rút ra là lab đã hoạt động qua ALB thật và hai backend đã đọc ghi cùng dữ liệu trên ElastiCache thật. Để khẳng định lợi ích với Live Quiz, bước tiếp theo là tích hợp có giới hạn, đo workload phù hợp và thử sự cố đúng với yêu cầu của phòng đang chơi.

**Điều giảng viên cần nắm:** Giảng viên nhớ được giá trị riêng của từng dịch vụ và độ tin cậy của kết luận.

## Slide 14  Trao đổi và câu hỏi cần chuẩn bị

Thời lượng phần nói  2 phút 00 giây

**Trọng tâm khi trình bày:** Dành hai phút cho trao đổi hoặc thời gian đệm. Các câu trả lời bên dưới dùng để chuẩn bị, không đọc lần lượt trong bài nói.

### ALB có tự tạo thêm EC2 khi nhiều người truy cập không

ALB mở rộng năng lực của dịch vụ cân bằng tải. Thêm backend cần một cơ chế scaling riêng và phải gắn target group đúng. Trong demo không có kịch bản autoscaling.

### Khi A chết WebSocket đang kết nối có chuyển sang B không

Không tự di chuyển kết nối đang tồn tại. Client cần reconnect; ứng dụng cần nhận diện phiên và rejoin phòng. HTTP mới tới B chưa chứng minh phục hồi được trận quiz.

### Tại sao không chỉ dùng sticky sessions để giữ điểm ở A

Stickiness hỗ trợ affinity của request nhưng không sao chép dữ liệu của A. Khi A mất, dữ liệu chỉ nằm trong RAM của A không tự có ở B. Cần thiết kế lưu hoặc dựng lại dữ liệu theo yêu cầu của ứng dụng.

### Tại sao dùng ElastiCache nếu Redis local cũng có Sorted Set

Sorted Set là chức năng engine. Lý do khảo sát AWS là các lựa chọn triển khai, vận hành, mạng, bảo mật và dự phòng mà dịch vụ managed cung cấp. Demo cho thấy kết nối và sử dụng được dịch vụ thật; lợi ích chi phí và hiệu năng cần đánh giá riêng.

### Restart backend có chứng minh điểm được lưu bền không

Nó chỉ chứng minh dữ liệu không nằm riêng trong tiến trình backend vừa restart khi cache còn chạy. Muốn nói về lỗi cache phải xác định replica, backup hoặc durability nào đã cấu hình và chạy phép thử tương ứng.

### TTL có giữ dữ liệu chắc chắn cho tới lúc hết giờ không

TTL là thời điểm hết hạn được đặt cho key. Eviction, lệnh xóa hoặc lỗi trong cấu hình không có độ bền phù hợp có thể làm dữ liệu mất sớm hơn. Vòng đời dữ liệu và chính sách bộ nhớ phải được thiết kế cùng nhau.

### Demo đã chứng minh nhanh hơn PostgreSQL bao nhiêu lần

Chưa có số đo để trả lời. Hai chế độ lab so sánh nơi lưu RAM riêng và cache chung, không phải DB với cache. Muốn đo cần cùng workload, baseline, quy mô dữ liệu và thống kê latency hoặc throughput.

### Reader endpoint có giống ALB đứng trước các replica không

Reader endpoint của mô hình node based đang nói đến là DNS tới replica, không phải proxy chọn đích cho từng lệnh. Pool kết nối và replica lag ảnh hưởng kết quả đọc. Lab dùng cùng primary cho yêu cầu thấy ngay điểm vừa ghi.

**Điều giảng viên cần nắm:** Giảng viên kiểm tra được nhóm phân biệt cơ chế AWS với những bảo đảm do ứng dụng phải xây.

## Bản đồ tính năng để chọn nội dung nói

Dùng bảng này khi rút tài liệu thành slide. Nhóm giới thiệu tên và mục đích của các nhóm tính năng mở rộng; cột cuối ghi rõ phần dự kiến xuất hiện trong demo. Các phần đọc sâu đã đặt trong slide tương ứng để người phụ trách có thể chuẩn bị trước.

| **Dịch vụ và nhóm tính năng** | **Slide đọc** | **Phần demo** |
| --- | --- | --- |
| ALB listener rules và target groups | 3 đến 4 | Có |
| ALB thuật toán và health checks | 4 đến 5 | Có |
| Weighted target groups rewrite slow start và ATW | 4 | Không |
| HTTPS certificate security groups và WAF | 6 | Security group của lab |
| OIDC Cognito và JWT verification | 6 | Không |
| WebSocket HTTP2 gRPC và stickiness | 6 | Không |
| ALB metrics và access logs | 6 | Target health là chính |
| ElastiCache engine và deployment options | 7 | Valkey node based |
| Primary replica shard và endpoints | 7 | Một primary |
| Sorted Set và dữ liệu chung A B | 8 đến 9 | Có |
| TTL và eviction | 8 | TTL ngắn tùy chọn |
| Cache aside write through và Pub Sub | 8 | Không |
| Replication Multi AZ backup và durability | 10 | Không |
| Scaling TLS RBAC IAM và metrics | 10 | TLS và RBAC của lab |
| Chi phí và vận hành | 12 | Ghi cấu hình và cleanup |

Khi chọn nội dung nói, ưu tiên giải thích rõ một luồng request ALB và một luồng thao tác dữ liệu ElastiCache. Những nhóm tính năng còn lại giúp người nghe biết dịch vụ cung cấp thêm gì và nhóm biết giới hạn ở đâu. Nếu cần trình bày sâu tất cả các nhóm, cần tăng thời gian hoặc tách thành hai seminar.

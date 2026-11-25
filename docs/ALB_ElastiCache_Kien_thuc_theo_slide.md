# Kiến thức về ALB và ElastiCache theo từng slide

*Cơ chế AWS và ứng dụng trong Live Quiz*

## Slide 1  Application Load Balancer và Amazon ElastiCache

### Hai lớp chức năng trong một ứng dụng nhiều backend

Application Load Balancer và Amazon ElastiCache phục vụ hai lớp chức năng khác nhau. ALB nằm trên đường truy cập của client, tiếp nhận HTTP hoặc HTTPS rồi chuyển request tới backend phù hợp. ElastiCache nằm trên đường truy cập dữ liệu của backend, cung cấp dịch vụ xử lý dữ liệu trong bộ nhớ theo engine được lựa chọn. Một dịch vụ quyết định nơi xử lý request; dịch vụ còn lại cung cấp nơi các tiến trình cùng đọc và cập nhật dữ liệu.

Khi một ứng dụng chỉ chạy một tiến trình, toàn bộ request và trạng thái tạm có thể tập trung tại cùng một nơi. Khi có nhiều backend, hai vấn đề xuất hiện độc lập: request phải được phân phối và dữ liệu cần thiết phải có thể truy cập từ các backend liên quan. Phân phối request không tự làm dữ liệu trong RAM của các tiến trình trở thành dữ liệu chung.

### Ý nghĩa của dịch vụ được AWS quản lý

Với ALB, AWS vận hành hạ tầng cân bằng tải. Với ElastiCache, AWS quản lý hạ tầng cache theo mô hình triển khai. Cấu hình định tuyến, tổ chức dữ liệu, quyền truy cập và logic ứng dụng vẫn do bên xây dựng hệ thống quyết định. Giá trị của managed service nằm ở việc sử dụng những cơ chế được cung cấp sẵn cùng khả năng tích hợp và vận hành trong môi trường AWS.

[AWS tổng quan Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  |  [AWS các mô hình triển khai ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html)

## Slide 2  Phân phối truy cập và chia sẻ dữ liệu

### Lưu lượng và trạng thái có vòng đời khác nhau

Live Quiz có các hoạt động như vào phòng, lấy thông tin câu hỏi, gửi đáp án và xem bảng điểm. Một số thao tác có thể được biểu diễn bằng HTTP request độc lập; cập nhật realtime thường cần một kết nối kéo dài như WebSocket. Khi nhiều người cùng phản hồi một câu hỏi, lưu lượng có thể dồn vào một khoảng thời gian ngắn. Các backend phải cùng xử lý đường vào, trong khi dữ liệu về phòng và người chơi vẫn cần được truy cập đúng.

### Một điểm truy cập cho nhiều backend

Giả sử backend A và B cung cấp cùng API. Nếu client phải biết trực tiếp địa chỉ của từng máy, việc thay backend hoặc xử lý lỗi sẽ gắn với địa chỉ đó. Một điểm truy cập qua ALB cho phép backend được chọn ở phía hạ tầng. Client gửi request tới một DNS chung, còn rule và trạng thái target quyết định request được chuyển đi đâu.

### Dữ liệu trong RAM không tự đồng bộ giữa các tiến trình

Nếu A lưu Alice có 100 điểm trong một Map của tiến trình, request đọc tới B sẽ không tự nhìn thấy Map đó. Việc A và B chạy cùng code chỉ làm chúng có cùng logic, không làm chúng có cùng vùng nhớ. Một dịch vụ dữ liệu dùng chung cho phép cả hai truy cập cùng key. Khi đó khả năng đọc dữ liệu phụ thuộc vào kết nối, quyền truy cập và cơ chế nhất quán của nơi lưu dữ liệu thay vì phụ thuộc vào request có quay lại đúng A hay không.

Trong tình huống này, ALB giải quyết đường vào và lựa chọn backend; ElastiCache được khảo sát cho bảng điểm đang hoạt động hoặc dữ liệu tạm dùng chung. Dữ liệu chính cần lưu bền vẫn có thể nằm trong database, còn dữ liệu trong cache có thể được xây dựng lại từ nguồn đó.

[AWS tổng quan Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  |  [AWS use cases của ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/elasticache-use-cases.html)

## Slide 3  Các thành phần và phạm vi quản lý của ALB

### ALB hoạt động ở tầng ứng dụng

ALB thuộc Elastic Load Balancing của AWS và xử lý lưu lượng ở tầng ứng dụng. Khả năng đọc thông tin HTTP cho phép dịch vụ định tuyến dựa trên nội dung request, chẳng hạn host hoặc path. Cùng một ALB có thể đưa /api/* tới nhóm xử lý API và một đường dẫn khác tới nhóm phục vụ nội dung, thay vì chỉ lựa chọn một máy theo địa chỉ mạng.

### Load balancer listener rule target group và target

| **Thành phần** | **Chức năng** |
| --- | --- |
| Load balancer | Cung cấp điểm truy cập và gắn với cấu hình mạng cùng các Availability Zone |
| Listener | Tiếp nhận kết nối theo protocol và port đã cấu hình |
| Listener rule | Xác định điều kiện request phải thỏa và action được thực hiện |
| Target group | Tập hợp các đích cùng cấu hình liên quan đến routing và health check |
| Target | Đích thực tế xử lý request như một EC2 instance hoặc địa chỉ IP |

Ví dụ GET /api/whoami tới listener HTTP 80. Listener đánh giá các rule; action forward chọn tg-main. Thuật toán của tg-main chọn A hoặc B trong các target đủ điều kiện nhận lưu lượng. Target group là một đối tượng cấu hình, không phải một tiến trình ứng dụng nằm giữa ALB và backend.

[AWS tổng quan Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  |  [AWS listener và WebSocket](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)  |  [AWS listener rules](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-rules.html)

### Các loại target

ALB hỗ trợ các target type như instance, IP và Lambda. Với instance target, đích được đăng ký bằng EC2 instance và port phục vụ. Với IP target, đích được đăng ký bằng địa chỉ IP phù hợp. Lambda cho phép một hàm xử lý request được gọi qua ALB. Cách chọn target type phụ thuộc nơi ứng dụng chạy; nó khác với việc chọn thuật toán phân phối bên trong target group.

[AWS target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

### Availability Zone và cross zone load balancing

ALB thông thường trên các Availability Zone sử dụng ít nhất hai subnet ở hai AZ khác nhau. Cross zone load balancing cho phép một node của load balancer phân phối tới target qua các AZ được hỗ trợ. ALB bật cơ chế này ở cấp load balancer và có thể tắt ở cấp target group. Việc triển khai qua nhiều AZ tạo điều kiện phân tán đường vào, nhưng tính sẵn sàng của ứng dụng còn phụ thuộc backend và tầng dữ liệu.

[AWS ALB và Availability Zone](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)

### Năng lực ALB và số lượng backend

AWS điều chỉnh năng lực của dịch vụ cân bằng tải theo lưu lượng. Số lượng EC2 hoặc container của ứng dụng là một quyết định riêng, thường được thực hiện bằng cơ chế scaling của nền tảng chạy backend. Một ALB có đủ năng lực tiếp nhận request vẫn có thể đưa request tới một nhóm backend đang thiếu CPU hoặc thiếu kết nối database. Cân bằng tải phân phối công việc giữa các đích hiện có; cấp thêm tài nguyên ứng dụng làm thay đổi tập đích và tổng năng lực xử lý.

[AWS tổng quan Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)

## Slide 4  Cơ chế định tuyến và kiểm tra sức khỏe của ALB

### Rule được đánh giá theo priority

Listener xét các rule theo giá trị priority tăng dần và dùng default rule ở cuối. Mỗi rule mô tả điều kiện cùng action. Các điều kiện trong một rule phải cùng thỏa; nhiều giá trị trong một điều kiện cho phép khớp một trong các giá trị. Một rule có phạm vi rộng được đánh giá trước có thể khiến request không bao giờ tới rule cụ thể phía sau.

| **Điều kiện** | **Ví dụ về cách sử dụng** |
| --- | --- |
| Host | Tách api.example.com và một tên miền giao diện |
| Path | Đưa /api/* tới nhóm API |
| HTTP method | Áp dụng rule riêng cho một method |
| HTTP header hoặc query string | Phân loại request theo giá trị được gửi kèm |
| Source IP | Áp dụng rule theo địa chỉ nguồn được hỗ trợ |

[AWS listener rules](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-rules.html)  |  [AWS các loại điều kiện định tuyến](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-condition-types.html)

### Action và hai cấp lựa chọn đích

Forward chuyển request tới target group. Redirect trả phản hồi để client truy cập URL khác, chẳng hạn chuyển HTTP sang HTTPS. Fixed response tạo phản hồi trực tiếp tại ALB mà không cần backend xử lý. Với weighted forwarding, một action phân bổ lưu lượng cho nhiều target group theo trọng số, phù hợp với việc chuyển dần lưu lượng giữa hai phiên bản ứng dụng.

Có hai cấp quyết định: action chọn target group, sau đó thuật toán của target group chọn target. Trọng số 90/10 giữa hai group không có nghĩa mỗi target bên trong nhận đúng tỷ lệ đó. Khi một weighted target group không còn đích khỏe, ALB không tự dồn phần lưu lượng của nó sang một group khỏe khác; đây là giới hạn quan trọng khi dùng trọng số cho triển khai phiên bản mới.

[AWS các action của listener rule](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-action-types.html)

### Path matching và request transform

Khớp path chỉ quyết định rule được áp dụng. Một request /lab/a/api/whoami vẫn mang đường dẫn đó tới backend nếu không có cơ chế sửa đường dẫn. ALB hỗ trợ host header rewrite và URL rewrite qua transform được cấu hình. Rewrite thay đổi request ở phía server trước khi forward; redirect khiến client nhận một phản hồi chuyển hướng và gửi request mới. Rule khớp path không tự tạo ra rewrite.

[AWS host header rewrite và URL rewrite](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-transforms.html)

### Thuật toán bên trong một target group

| **Thuật toán** | **Cơ chế chọn đích** |
| --- | --- |
| Round robin | Lần lượt phân phối qua các target khỏe và là lựa chọn mặc định |
| Least outstanding requests | Ưu tiên target có ít request đang xử lý hơn |
| Weighted random | Phân phối ngẫu nhiên và hỗ trợ Automatic Target Weights anomaly mitigation |

Round robin phù hợp để quan sát các backend cùng tham gia. Least outstanding requests xem số công việc còn đang xử lý thay vì suy rằng mọi request có cùng độ nặng. Cookie stickiness có thể khiến các request tiếp theo của một client quay về cùng target, nên phân bố quan sát được còn phụ thuộc cấu hình affinity.

[AWS thuộc tính target group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/edit-target-group-attributes.html)

### Health check và độ trễ phát hiện lỗi

ALB chủ động gửi health check tới mỗi target theo protocol, port, path và chu kỳ. Timeout xác định khoảng chờ phản hồi; success code xác định phản hồi được chấp nhận. Unhealthy threshold và healthy threshold dùng số lần thất bại hoặc thành công liên tiếp để thay đổi trạng thái. Cơ chế ngưỡng hạn chế việc đổi trạng thái vì một lần lỗi ngắn, đồng thời tạo một khoảng trễ khi phát hiện và hồi phục.

Ví dụ interval 5 giây, timeout 2 giây và unhealthy threshold 2 tạo một phép kiểm tra theo chu kỳ với hai lần lỗi liên tiếp. Thời điểm tiến trình dừng có thể nằm ở bất kỳ vị trí nào trong chu kỳ, vì vậy các con số này không phải cam kết rằng mọi sự cố đều được xử lý sau đúng một số giây cố định.

[AWS các tham số cấu hình health check](https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_ModifyTargetGroup.html)

Khi vẫn còn target khỏe, routing bình thường tránh target unhealthy. Nếu mọi target đã đăng ký trong group đều unhealthy, ALB có thể fail open và gửi tới các target đó. Health check của ALB không dùng WebSocket. Một endpoint HTTP trả 200 chỉ phản ánh các thành phần mà endpoint ấy kiểm tra; nó có thể xác nhận tiến trình còn sống nhưng chưa xác nhận việc tính điểm hoặc truy cập dữ liệu đang đúng.

[AWS health checks và fail open](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)

### Drain slow start và lỗi một phần

Deregistration delay dành thời gian cho request đang xử lý khi target được chủ động rút khỏi nhóm. Slow start tăng dần phần tải vào target mới để có thời gian khởi động các thành phần cần thiết. Cả hai phục vụ thay đổi có kiểm soát; một tiến trình crash không còn khả năng hoàn thành công việc chỉ nhờ cấu hình drain.

[AWS thuộc tính target group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/edit-target-group-attributes.html)

Automatic Target Weights bổ sung cách nhận diện gray failure: target vẫn vượt qua health check nhưng tỷ lệ lỗi khác thường so với các target cùng nhóm. Anomaly mitigation phối hợp với weighted random để giảm tải vào target bất thường. Nó xử lý một dạng tín hiệu khác với việc endpoint health check liên tiếp không phản hồi.

[AWS Automatic Target Weights và gray failures](https://aws.amazon.com/blogs/networking-and-content-delivery/improving-availability-with-application-load-balancer-automatic-target-weights/)

## Slide 5  Cơ sở kỹ thuật của thử nghiệm ALB

### Mô hình và biến quan sát

Mô hình thử nghiệm gồm một ALB, listener HTTP 80 và target group tg-main chứa hai EC2 A và B ở port 3000. Hai backend chạy cùng logic nhưng có BACKEND_ID khác nhau. API /api/whoami trả backendId cùng requestId để phân biệt đích xử lý và từng request. Endpoint /health phản ánh khả năng đáp ứng của tiến trình HTTP.

Request qua cùng DNS nhưng nhận backendId khác nhau là dấu hiệu có nhiều target tham gia xử lý. RequestId mới giúp phân biệt một phản hồi thực với nội dung cũ được trình duyệt lưu lại. Với round robin và không dùng stickiness, một chuỗi request đủ để quan sát cả A và B; một mẫu ngắn không đại diện cho độ cân bằng tải của mọi workload.

### Chuỗi nguyên nhân khi một backend dừng

Khi tiến trình A dừng, request và health check đến A có thể lỗi. ALB chưa có tín hiệu đủ để đổi trạng thái ngay tại thời điểm crash. Sau khi các kiểm tra đạt ngưỡng thất bại, A trở thành unhealthy; B còn khỏe tiếp tục là đích cho request mới qua tg-main. Khi A khởi động lại và vượt qua điều kiện hồi phục, A có thể được đưa trở lại luồng xử lý.

| **Hiện tượng** | **Cơ chế giải thích** |
| --- | --- |
| Cùng DNS trả response từ A và B | Target group có nhiều backend cùng nhận lưu lượng |
| Có thể có lỗi ngay sau lúc A dừng | Health detection diễn ra theo chu kỳ |
| Request mới được B phục vụ khi A unhealthy | ALB còn một target khỏe trong tg-main |
| A tham gia lại sau khi hồi phục | Target health được cập nhật qua các kiểm tra thành công |

[AWS health checks và fail open](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)

### Routing theo group và routing ghim một đích

Các đường /lab/a/* và /lab/b/* dùng target group chẩn đoán chỉ chứa A hoặc B. Chúng phục vụ việc xác định backend trong phép thử dữ liệu. Khi A dừng, /lab/a/* không có một backend B trong chính group đó để chuyển tới. Hành vi của đường ghim A vì vậy khác với đường mặc định đi qua tg-main có cả hai target.

### Phạm vi bằng chứng

Thử nghiệm kiểm tra đường đi của HTTP request, sự tham gia của nhiều target và phản ứng với lỗi tiến trình khi còn một backend khỏe. Thời gian phát hiện lỗi là đại lượng phải lấy từ lần chạy. Khả năng khôi phục một phòng quiz, di chuyển WebSocket hoặc chịu được tải lớn không được đo bằng API nhận diện backend này.

## Slide 6  Các nhóm tính năng chính của ALB

### TLS termination certificate và SNI

HTTPS listener kết thúc TLS giữa client và ALB bằng certificate được cấu hình trên listener. Backend nhận request qua một kết nối khác có protocol riêng. Bật HTTPS ở phía client và chọn HTTPS tới target là hai quyết định; chỉ quyết định thứ nhất chưa bảo đảm chặng tới backend đã được mã hóa.

AWS Certificate Manager hỗ trợ quản lý certificate. SNI cho phép ALB lựa chọn certificate theo tên miền mà client gửi trong TLS handshake, nhờ đó một listener có thể phục vụ nhiều tên miền HTTPS. Chức năng này tập trung quản lý certificate ở đường vào thay vì buộc mỗi backend công khai phải tự phục vụ cùng cấu hình cho client.

[AWS certificate ACM và SNI](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html)  |  [AWS target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

### Security group và Web Application Firewall

Security group của ALB kiểm soát kết nối tới listener và kết nối đi tới backend cùng health check. Security group của backend có thể chỉ cho phép port ứng dụng từ security group ALB. Cách bố trí này làm đường truy cập qua ALB trở thành đường vào được kiểm soát; mở backend trực tiếp ra Internet tạo thêm một đường truy cập ngoài các rule của ALB.

[AWS security groups của ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)

AWS WAF tích hợp với ALB qua web ACL. Các rule của WAF có thể kiểm tra mẫu request hoặc áp dụng rate based rule trên HTTP. WAF hoạt động ở lớp kiểm tra request, còn security group làm việc ở lớp cho phép kết nối mạng. Việc tạo ALB và việc gắn web ACL là hai cấu hình độc lập.

[AWS tích hợp ALB với WAF và các dịch vụ liên quan](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-integrations.html)

### Xác thực bằng Cognito OIDC và JWT

HTTPS listener có thể tích hợp Amazon Cognito hoặc một identity provider hỗ trợ OpenID Connect. ALB thực hiện luồng xác thực được cấu hình trước khi forward request. Xác định danh tính người dùng không tự quyết định người ấy có được mở câu hỏi của một phòng cụ thể; phân quyền theo tài nguyên và nghiệp vụ vẫn thuộc ứng dụng.

[AWS xác thực người dùng bằng OIDC và Cognito](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html)

ALB cũng có khả năng xác minh JWT cho giao tiếp dịch vụ hoặc máy với máy. Dịch vụ sử dụng khóa từ JWKS để kiểm tra chữ ký và các claim được hỗ trợ trước khi chuyển request. Đây là lựa chọn xác thực có điều kiện về HTTPS listener, thuật toán và cấu hình issuer; nó không đồng nghĩa ALB tự cung cấp toàn bộ hệ thống tài khoản hoặc cấp token.

[AWS xác minh JWT tại ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-verify-jwt.html)

### WebSocket HTTP2 và gRPC

WebSocket bắt đầu bằng một HTTP Upgrade. Khi kết nối được chấp nhận, message tiếp tục đi tới target đã chọn thông qua kết nối kéo dài. ALB không phân phối lại từng message giữa A và B. Khi target mất, kết nối có thể đứt; client phải tạo kết nối mới và ứng dụng quyết định cách khôi phục phiên hoặc phòng.

HTTP/2 và gRPC được hỗ trợ theo cấu hình listener và protocol version của target group. Cấu hình giao thức ở client và ở backend cần được phân biệt, giống như hai chặng TLS. Khả năng hỗ trợ giao thức mô tả cách dữ liệu được truyền; tính đúng của sự kiện và trạng thái phòng vẫn thuộc logic xử lý.

[AWS listener và WebSocket](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)  |  [AWS target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

### Cookie stickiness

Sticky sessions tạo affinity để các HTTP request của một client tiếp tục tới cùng target. ALB hỗ trợ cookie dựa trên thời hạn hoặc cookie gắn với ứng dụng. Affinity có ích khi ứng dụng phụ thuộc trạng thái cục bộ nhưng không sao chép RAM sang target khác. Với WebSocket đã upgrade, target được giữ bởi chính kết nối, thay vì cookie quyết định lại đích cho từng message.

[AWS các nhóm tính năng chính của ALB](https://aws.amazon.com/elasticloadbalancing/application-load-balancer/)

### Metrics của ALB

| **Metric** | **Ý nghĩa** |
| --- | --- |
| RequestCount | Request IPv4 hoặc IPv6 mà ALB đã chọn được target để xử lý |
| HealthyHostCount và UnHealthyHostCount | Số target được đánh giá khỏe hoặc không khỏe |
| TargetResponseTime | Từ lúc request rời ALB tới lúc target bắt đầu trả response headers |
| HTTPCode_ELB_5XX_Count | Response 5xx do ALB tạo ra |
| HTTPCode_Target_5XX_Count | Response 5xx do target tạo ra |

Tách lỗi do ALB với lỗi do target giúp khoanh vùng đường vào và ứng dụng. TargetResponseTime có thể được xem qua percentile nhưng không phải thời gian từ browser tới mọi người chơi. ActiveConnectionCount gồm kết nối phía client lẫn phía target nên không thể chuyển trực tiếp thành số người chơi đang online.

[AWS CloudWatch metrics của ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)

### Access logs

Access logs có thể được ghi vào S3 để tra cứu request, target và trạng thái phản hồi. Chúng hỗ trợ phân tích từng lượt truy cập bên cạnh metric tổng hợp. Với WebSocket, bản ghi mô tả kết nối và không ghi riêng từng message; độ trễ phát câu hỏi hoặc xác nhận nhận đáp án cần dữ liệu quan sát từ ứng dụng.

[AWS access logs của ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)

## Slide 7  Amazon ElastiCache và các mô hình triển khai

### Dịch vụ managed và engine dữ liệu

ElastiCache cung cấp môi trường được AWS quản lý cho Valkey, Redis OSS và Memcached. Engine quyết định cấu trúc dữ liệu và hệ lệnh; dịch vụ AWS cung cấp các lựa chọn triển khai, mạng, giám sát và vận hành. Vì vậy Sorted Set có thể tồn tại cả ở Valkey tự chạy lẫn ElastiCache, còn công việc quản lý hạ tầng và cách tích hợp vào AWS là phần khác nhau.

| **Engine** | **Khả năng liên quan** |
| --- | --- |
| Valkey | Hỗ trợ cấu trúc dữ liệu phong phú và Redis compatible APIs theo phiên bản |
| Redis OSS | Hỗ trợ các cấu trúc như String Hash Set Sorted Set cùng replication theo cấu hình |
| Memcached | Tập trung vào cache đối tượng đơn giản và không có Sorted Set |

Khả năng backup, bảo mật và scaling phụ thuộc đồng thời engine, version và deployment option. Một kết luận về Memcached node based không tự áp dụng nguyên vẹn cho Memcached Serverless. Tên ElastiCache cũng không xác định duy nhất một topology hoặc một bộ command.

[AWS so sánh engine và cluster mode](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SelectEngine.html)

### Serverless

Với ElastiCache Serverless, AWS quản lý capacity và cấu trúc hạ tầng bên dưới, tự điều chỉnh theo mức sử dụng và lưu dữ liệu dự phòng qua ba AZ. Bên sử dụng tập trung vào engine, kết nối client, giới hạn sử dụng, quyền truy cập và dữ liệu. Serverless làm giảm phần quyết định về node, nhưng vòng đời key và tính đúng của cache vẫn phụ thuộc cách ứng dụng sử dụng dịch vụ.

### Node based

Với node based, cấu hình xác định node type, số node, shard, replica và vị trí AZ. AWS quản lý phần cứng, thay thế node và patching trong phạm vi dịch vụ. Mô hình này cho phép chọn tài nguyên và topology rõ hơn; đổi lại capacity phải phù hợp workload và yêu cầu dự phòng.

[AWS các mô hình triển khai ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html)

### Node shard primary và replica

Một node là một thành phần chạy engine. Một shard chứa một phần dữ liệu, có primary nhận ghi và có thể có replica. Cluster mode disabled của Valkey hoặc Redis OSS có một shard; cluster mode enabled cho phép phân dữ liệu qua nhiều shard. Replica giữ bản sao của dữ liệu trong shard và có thể phục vụ đọc hoặc được dùng trong cơ chế dự phòng.

Thêm replica chủ yếu tác động đến bản sao, khả năng đọc và availability. Thêm shard thay đổi cách phân mảnh dữ liệu và phân bố công việc qua nhiều primary. Hai thao tác này không thay thế nhau: nhiều replica của một shard vẫn sao chép cùng phần dữ liệu đó.

[AWS các thành phần ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.corecomponents.html)

### Endpoint và trách nhiệm của client

| **Topology node based** | **Cách kết nối** |
| --- | --- |
| Một node độc lập | Endpoint node phục vụ đọc và ghi |
| Cluster mode disabled có replica | Primary endpoint cho ghi; reader endpoint có thể dùng cho đọc replica |
| Reader endpoint | DNS phân giải luân phiên tới replica và phân tán kết nối |
| Cluster mode enabled | Configuration endpoint giúp client hỗ trợ cluster khám phá các shard và định tuyến |

Reader endpoint không phải proxy lựa chọn replica cho từng command. Pool kết nối lâu có thể tiếp tục sử dụng các đích đã kết nối, nên số request giữa replica không nhất thiết bằng nhau. Configuration endpoint cũng không biến một client không hỗ trợ cluster thành client hiểu cách phân mảnh. Đọc replica còn gắn với khả năng dữ liệu cập nhật chậm hơn primary.

[AWS connection endpoints](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Endpoints.html)  |  [AWS client connection pools](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/BestPractices.Clients.Redis.Connections.html)

## Slide 8  Cấu trúc dữ liệu TTL eviction và chiến lược cache

### Cấu trúc dữ liệu xác định thao tác hiệu quả

String biểu diễn một giá trị hoặc một đối tượng đã serialize. Hash gom nhiều field dưới một key. Set lưu các member duy nhất. Sorted Set gắn mỗi member với score và hỗ trợ lấy theo thứ tự. Pub/Sub phân phối thông báo tới bên đang subscribe nhưng không thay thế luồng sự kiện cần lưu lại và phát lại. Mỗi cấu trúc phục vụ một loại thao tác và một vòng đời dữ liệu khác nhau.

[AWS use cases của ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/elasticache-use-cases.html)

### Sorted Set và leaderboard

Một leaderboard có thể dùng key quizlab:room:demo:leaderboard. Mỗi member là playerId; score là điểm của người chơi. Engine duy trì quan hệ giữa member và score để hỗ trợ truy vấn thứ hạng. Ứng dụng không cần đọc toàn bộ một danh sách JSON rồi tự sắp xếp lại cho mỗi lần lấy top nếu thao tác mong muốn đã được Sorted Set cung cấp.

| **Command minh họa** | **Tác động lên dữ liệu** |
| --- | --- |
| ZADD key 100 alice 150 bob 120 chi | Tạo hoặc cập nhật ba member với score tương ứng |
| ZRANGE key 0 9 REV WITHSCORES | Lấy tối đa mười member từ score cao xuống thấp |
| ZADD key 170 alice | Cập nhật score của cùng member alice thành 170 |

Sau dữ liệu ban đầu, thứ tự là Bob 150, Chi 120 và Alice 100. Khi Alice được gán 170, Alice đứng đầu. Gán lại cùng giá trị 170 không tự cộng thêm 170. Thuộc tính này phù hợp với phép thử điểm tuyệt đối; xung đột giữa nhiều bản cập nhật khác nhau hoặc event đến trễ vẫn cần quy tắc ở tầng ứng dụng. Các trường hợp bằng điểm cũng cần luật phá hòa phù hợp nghiệp vụ.

[Valkey cơ chế ZADD](https://valkey.io/commands/zadd/)  |  [Valkey cơ chế ZRANGE](https://valkey.io/commands/zrange/)

### TTL và hết hạn dữ liệu

EXPIRE gán thời gian sống còn lại cho key. Với một Sorted Set leaderboard, TTL áp dụng cho toàn bộ key, không phải một TTL độc lập cho từng player. Khi hết hạn, key không còn được truy xuất như dữ liệu đang tồn tại. Gọi EXPIRE lại có thể làm mới hạn, vì vậy thời điểm đặt hoặc gia hạn TTL ảnh hưởng vòng đời của dữ liệu.

Ví dụ TTL 3600 giây giới hạn thời gian giữ key kể từ lần đặt hạn tương ứng. Nếu mỗi lần ghi đều gia hạn, phòng có hoạt động liên tục có thể giữ dữ liệu lâu hơn một giờ kể từ lần tạo đầu. Đó là khác biệt giữa thời hạn tính từ lúc tạo và thời hạn tính từ hoạt động gần nhất.

[Valkey cơ chế EXPIRE](https://valkey.io/commands/expire/)

### Eviction và giới hạn bộ nhớ

Eviction là việc loại key do áp lực bộ nhớ theo maxmemory-policy trong parameter group. allkeys-lru cho phép xét mọi key theo LRU; volatile-lru giới hạn tập xét ở các key có TTL; noeviction có thể làm lệnh ghi thất bại khi đầy bộ nhớ. Chính sách theo LRU hoặc LFU phục vụ việc chọn dữ liệu ưu tiên giữ lại, còn TTL mô tả thời gian hết hạn.

Một key chưa hết TTL vẫn có thể bị eviction nếu chính sách cho phép. Ngược lại, một key hết TTL có thể biến mất dù cache vẫn còn bộ nhớ. Vì vậy dữ liệu quan trọng cần nguồn khôi phục hoặc cấu hình độ bền phù hợp thay vì dùng TTL làm cam kết tồn tại.

[AWS parameter groups và maxmemory policy](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/ParameterGroups.Engine.html)

### Cache aside và write through

Với cache aside, ứng dụng đọc cache trước. Nếu không tìm được key, ứng dụng đọc database rồi đưa kết quả vào cache. Cách này chỉ đưa vào cache dữ liệu được yêu cầu nhưng tạo thêm đường đọc DB ở lần miss. Dữ liệu trong cache có thể cũ nếu bản gốc thay đổi mà key chưa được cập nhật hoặc invalidated.

Write through cập nhật cache trên đường ghi dữ liệu. Lần đọc sau có nhiều khả năng thấy bản mới mà không cần nạp lại từ DB, đổi lại đường ghi có thêm công việc. Sau khi cache trống hoặc có sự cố, vẫn cần cơ chế nạp dữ liệu. TTL giúp quản lý thời hạn của bản sao nhưng không bảo đảm mọi cập nhật DB được phản ánh tức thời.

[AWS lazy loading write through và TTL](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Strategies.html)

Ghi database và cache là hai thao tác có thể thành công hoặc thất bại riêng. Tên write through không tự tạo transaction xuyên hai dịch vụ. Cache miss cũng khác lỗi kết nối cache: miss là một kết quả truy vấn hợp lệ không có key, còn lỗi kết nối chưa cho biết key có tồn tại hay không.

### Cache truy vấn và trạng thái dùng chung

Cache kết quả truy vấn nhằm tái sử dụng dữ liệu lấy từ nguồn chính để giảm công việc lặp lại. Trạng thái tạm dùng chung nhằm để nhiều backend truy cập cùng dữ liệu ngoài RAM riêng. Leaderboard trong phép thử A và B thuộc cách dùng thứ hai. Chứng minh khả năng chia sẻ dữ liệu chưa tạo ra một phép đo mức giảm tải database.

## Slide 9  Cơ sở kỹ thuật của thử nghiệm ElastiCache

### Hai chế độ lưu trữ và cùng logic ứng dụng

Thử nghiệm dùng hai backend A và B, cùng API gán điểm và đọc leaderboard. Ở store=memory, mỗi backend giữ Map riêng. Ở store=elasticache, mỗi backend tạo kết nối tới cùng node Valkey và dùng cùng key. Biến thay đổi là nơi lưu dữ liệu, trong khi ý nghĩa của thao tác gán điểm và kết quả leaderboard được giữ tương ứng.

### Vai trò của đường dẫn ghim A và B

Các path /lab/a/* và /lab/b/* cho phép xác định đích ghi và đích đọc. Nếu cả hai request đều đi qua phân phối thông thường, chúng có thể cùng rơi vào A và khiến dữ liệu RAM riêng trông giống dữ liệu đã chia sẻ. Việc tách đích giúp so sánh đúng hai không gian bộ nhớ độc lập với một dịch vụ dữ liệu chung.

### Vì sao A có dữ liệu còn B không có ở chế độ memory

Map thuộc tiến trình A chỉ được thao tác bởi logic chạy trong tiến trình đó. B không có cơ chế đọc vùng nhớ của A chỉ vì nhận cùng roomId. Vì vậy Alice 100 được ghi vào A không tự có trong kết quả của B. Đây là giới hạn của lưu trữ cục bộ khi một ứng dụng có nhiều tiến trình.

### Vì sao B đọc được dữ liệu ở chế độ ElastiCache

A gửi lệnh ZADD tới key chung. B gửi lệnh đọc tới cùng node và cùng key nên truy cập cùng tập dữ liệu. Với Alice 100, Bob 150, Chi 120, kết quả giảm dần là Bob rồi Chi rồi Alice. Sau lệnh gán Alice 170 thành công, lần đọc sau trên cùng primary trong điều kiện không có ghi khác hoặc sự cố phản ánh Alice đứng đầu.

[Valkey cơ chế ZADD](https://valkey.io/commands/zadd/)  |  [Valkey cơ chế ZRANGE](https://valkey.io/commands/zrange/)

### Ý nghĩa của việc restart backend

Khi A restart, Map của A được tạo lại cùng tiến trình và mất dữ liệu cục bộ trước đó. Dữ liệu ElastiCache không thuộc tiến trình A nên vẫn có thể được B truy cập khi cache còn hoạt động. A sau khởi động tạo lại kết nối và đọc được key chung. Hiện tượng này kiểm tra sự độc lập giữa vòng đời backend và nơi lưu dữ liệu.

### Điều kiện và giới hạn của phép thử

Cấu hình một primary không có replica giữ đơn giản đường đọc ghi và tránh biến độ trễ replica thành một yếu tố khác. Backend kết nối qua TLS và RBAC; trình duyệt chỉ gọi API. Kết quả dự kiến chỉ trở thành bằng chứng khi có lần chạy thực tế. Restart backend không kiểm tra cache failover, snapshot restore hoặc durability, và phép so sánh này không chứa baseline database để tính hệ số tăng tốc.

[AWS connection endpoints](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Endpoints.html)  |  [AWS TLS của ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/in-transit-encryption.html)  |  [AWS users user groups và RBAC](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Clusters.RBAC.html)

## Slide 10  Availability scaling bảo mật và giám sát của ElastiCache

### Replication và Multi AZ failover

Trong cấu hình replication thông thường của Valkey hoặc Redis OSS, primary cập nhật dữ liệu rồi sao chép sang replica theo cơ chế bất đồng bộ. Replica có thể chậm hơn primary. Nếu primary lỗi, phần cập nhật mới chưa được sao chép có thể bị mất khi chuyển sang replica. Replica cung cấp bản sao để đọc và dự phòng, không phải một phần dữ liệu mới được tách ra khỏi shard.

Multi AZ bố trí replica ở AZ khác để tăng khả năng tiếp tục hoạt động khi một AZ có sự cố. Automatic failover promote replica phù hợp thành primary. Vai trò ghi được khôi phục qua topology và endpoint của dịch vụ, trong khi client phải xử lý reconnect. Một kết nối TCP đang tồn tại không tự trở thành kết nối liên tục tới primary mới.

[AWS replication groups và replica lag](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Replication.html)  |  [AWS Multi AZ và automatic failover](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/AutoFailover.html)

### Snapshot và khôi phục dữ liệu

Snapshot ghi trạng thái dữ liệu tại một mốc để có thể restore. Bản chụp hỗ trợ phục hồi sau lỗi hoặc thao tác sai nhưng không tự chứa mọi cập nhật sau mốc đó. Promotion của replica và restore snapshot có mục đích, thời gian và mức mất dữ liệu khác nhau; có replica không đồng nghĩa đã có một bản backup độc lập với mọi thay đổi được sao chép.

[AWS snapshot và restore](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/backups.html)

### Durability theo cấu hình được hỗ trợ

Tài liệu nguồn mô tả durability của node based Valkey từ 9.0 bằng transactional log qua nhiều AZ. Synchronous writes chờ dữ liệu được lưu log trước khi xác nhận; asynchronous writes xác nhận trước nên có cửa sổ rủi ro mất phần chưa được lưu khi xảy ra lỗi. Việc bật tính năng phụ thuộc cluster mode enabled, node type, Multi AZ và replica cùng những giới hạn được AWS công bố.

Độ bền vì vậy gắn với chế độ ghi và cấu hình cụ thể. Một node cache cơ bản không có cùng bảo đảm với cluster bật durability. Thời gian tồn tại của dữ liệu sau backend restart cũng không đại diện cho độ bền của chính tầng cache khi mất node.

[AWS durability với transactional log](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/durability.html)  |  [AWS điều kiện áp dụng durability](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Durability.Limitations.html)

### Ba hướng mở rộng tài nguyên

| **Thay đổi** | **Tác động chính** |
| --- | --- |
| Tăng node type | Tăng tài nguyên của một node |
| Thêm read replica | Tăng khả năng phục vụ đọc và bổ sung bản sao |
| Thêm shard | Phân dữ liệu và công việc qua nhiều primary |

Client phải phù hợp topology sau mở rộng. Một hot key vẫn thuộc shard chứa key đó, nên việc thêm shard không mặc nhiên phân tán mọi thao tác trên một leaderboard duy nhất. Serverless tự quản lý capacity nhưng không thay thế thiết kế dữ liệu hoặc giới hạn sử dụng.

[AWS scaling node based](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Scaling-self-designed.html)  |  [AWS các thành phần ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.corecomponents.html)  |  [AWS các mô hình triển khai ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html)

### Mạng mã hóa xác thực và phân quyền

Trong mô hình node based của thử nghiệm, cache đặt trong mạng VPC và security group cho phép backend truy cập port 6379. Browser không cần nhận credential cache. Encryption in transit bảo vệ dữ liệu đang truyền; encryption at rest bảo vệ dữ liệu lưu theo cơ chế của dịch vụ. Hai cơ chế đáp ứng hai phạm vi bảo vệ khác nhau.

[AWS tổng quan bảo mật dữ liệu ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/encryption.html)  |  [AWS TLS của ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/in-transit-encryption.html)

RBAC tổ chức user và user group, giới hạn command, key hoặc channel. Quyền chỉ dùng prefix quizlab:* tách dữ liệu của lab khỏi phần khác. IAM quản trị tài nguyên AWS và quyền chạy command trên dữ liệu là hai lớp quyền khác nhau. IAM authentication cho kết nối cache, với engine version và TLS phù hợp, dùng token ngắn hạn thay mật khẩu dài hạn; client cần xử lý vòng đời credential.

[AWS users user groups và RBAC](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Clusters.RBAC.html)  |  [AWS IAM authentication cho kết nối cache](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/auth-iam.html)

### Các tín hiệu giám sát cần đọc cùng nhau

| **Metric** | **Điều được phản ánh** |
| --- | --- |
| CacheHits CacheMisses CacheHitRate | Kết quả lookup theo loại thao tác được metric tính |
| DatabaseMemoryUsagePercentage | Mức sử dụng bộ nhớ dữ liệu |
| Evictions | Số key bị loại do giới hạn bộ nhớ |
| EngineCPUUtilization và CPUUtilization | Tải engine và tải cả host |
| CurrConnections | Số kết nối client |
| ReplicationLag | Mức trễ của replica |

Memory cao đi cùng eviction có thể liên quan tập dữ liệu, TTL hoặc capacity. CPU tăng có thể cần xem command và workload; connection tăng cần xem pool hoặc việc tạo kết nối lặp lại. Hit rate không phản ánh trực tiếp tính đúng của điểm và cũng không thay thế thời gian API. Ngưỡng cảnh báo có ý nghĩa khi gắn với baseline và ảnh hưởng mà ứng dụng thực sự quan sát được.

[AWS định nghĩa metrics cho Valkey và Redis OSS](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.Redis.html)  |  [AWS lựa chọn metrics cần giám sát](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/CacheMetrics.WhichShouldIMonitor.html)

## Slide 11  Luồng phối hợp ALB backend và ElastiCache

### Đường đi của một lần ghi và đọc

Một request gán điểm đi từ client tới ALB. Listener rule chọn target group; thuật toán chọn backend A. A xử lý điểm theo logic ứng dụng rồi gửi lệnh dữ liệu tới ElastiCache. Một request đọc sau đó có thể được ALB đưa tới B. B truy vấn cùng key nên có thể trả cùng leaderboard mà không cần truy cập RAM của A.

### Các trách nhiệm được nối tiếp

| **Thành phần** | **Trách nhiệm trong luồng** |
| --- | --- |
| ALB | Lựa chọn đường đi của request tới backend |
| Backend | Xử lý nghiệp vụ quyền truy cập và lệnh dữ liệu |
| ElastiCache | Thực hiện thao tác trên dữ liệu theo engine và cấu hình |
| Database nếu có | Giữ dữ liệu chính theo thiết kế nguồn dữ liệu của ứng dụng |

ALB không đọc score để chọn backend, và ElastiCache không định tuyến browser tới A hay B. Việc dữ liệu đã được đưa ra ngoài tiến trình giảm sự phụ thuộc vào backend cụ thể, nhưng chỉ những trạng thái thực sự được đưa ra ngoài mới có tính chất đó. Socket, timer hoặc biến phòng còn nằm riêng trong một backend vẫn có vòng đời riêng.

### Một điểm truy cập chung không tạo ra một trạng thái phòng chung

Hai người chơi cùng roomId có thể kết nối vào hai backend khác nhau. Khả năng đọc một leaderboard chung giúp chia sẻ dữ liệu về điểm; việc phát cùng câu hỏi và điều phối trạng thái phòng vẫn cần cơ chế của ứng dụng. Tương tự, khi A mất kết nối, client có thể vào lại qua ALB nhưng quyền tiếp tục phòng, câu hỏi hiện hành và đáp án đã nhận phải được khôi phục từ thiết kế dữ liệu.

### Quan hệ với nguồn điểm chính trong repo

Tại revision được tài liệu nguồn đối chiếu, điểm chính của dự án nằm trong PostgreSQL và có luồng xử lý điểm riêng. Sorted Set được đề xuất như leaderboard hoặc bản nhìn tạm có thể dựng lại. Việc ứng dụng dùng cấu trúc này phụ thuộc nơi phát sinh cập nhật, luật phá hòa, xử lý event lặp và thứ tự cập nhật; sự hiện diện của cache không tự chuyển quyền quyết định điểm khỏi nguồn chính.

[Repo Live Quiz tại revision đã đối chiếu](https://github.com/khanh04032005/cloud/blob/569e1f380dc824eba508d77d9e72083fdd1eddf3/packages/socket/src/services/cloud-game.ts)

## Slide 12  Chi phí và trách nhiệm vận hành

### Các chiều tính phí của ALB

Chi phí ALB gồm thời gian load balancer hoạt động và mức LCU theo sử dụng. Các chiều LCU gồm new connections, active connections, processed bytes và rule evaluations. Sau khi quy đổi từng chiều sang LCU theo quy tắc AWS, mức lớn nhất quyết định lượng LCU sử dụng được tính phí. Hai ứng dụng có cùng số request vẫn có thể khác chi phí nếu số kết nối, thời gian giữ kết nối, lượng byte hoặc cách đánh giá rule khác nhau.

Với Live Quiz, request HTTP ngắn và WebSocket kéo dài tạo các đặc tính sử dụng khác nhau. Số người online không đủ để suy ra LCU nếu chưa biết tần suất kết nối lại, lưu lượng trên kết nối và payload. Giá còn phụ thuộc region, target và điều kiện hiện hành.

[AWS giá Elastic Load Balancing](https://aws.amazon.com/elasticloadbalancing/pricing/)

### Các chiều tính phí của ElastiCache

Node based gắn chi phí với loại node, số node và thời gian sử dụng cùng các khoản theo cấu hình. Serverless gắn chi phí với dữ liệu lưu và mức xử lý ECPU theo quy định của dịch vụ. Thêm replica, thêm shard, backup hoặc tính năng độ bền có thể làm thay đổi tài nguyên và thành phần tính phí.

So sánh hai mô hình cần gắn với cùng workload và yêu cầu availability. Một node đơn có giá thấp hơn một topology có dự phòng vì cung cấp tập khả năng khác. Mô hình Serverless giảm phần quản lý capacity nhưng không làm dữ liệu lưu và hoạt động xử lý trở thành miễn phí.

[AWS giá Amazon ElastiCache](https://aws.amazon.com/elasticache/pricing/)

### Chi phí của các thành phần đi kèm

Hai EC2, EBS, public IPv4 và truyền dữ liệu có thể tạo chi phí ngoài ALB và cache. WAF, logs vào S3 và snapshot còn có cấu phần sử dụng riêng. Vì các tài nguyên có vòng đời khác nhau, dừng tiến trình ứng dụng không đồng nghĩa đã dừng tính phí mọi thành phần của môi trường thử nghiệm.

### Managed service và trách nhiệm ứng dụng

AWS đảm nhận phần vận hành được dịch vụ quản lý, còn cấu hình mạng, quyền truy cập, cấu trúc key, health check, capacity đã chọn và xử lý lỗi vẫn tác động trực tiếp tới hệ thống. Một health check không phù hợp có thể đánh giá sai readiness; TTL không phù hợp có thể làm dữ liệu hết hạn giữa phiên; cấp quyền quá rộng làm tăng phạm vi truy cập dữ liệu.

Các thông tin cấu hình như region, engine version, số node và replica, protocol, workload cùng thời gian chạy xác định bối cảnh của một phép đo. Chúng cho phép giải thích vì sao hai lần chạy hoặc hai phương án có latency, chi phí và hành vi lỗi khác nhau. Con số từ một lab nhỏ chỉ mô tả cấu hình và lần chạy tương ứng.

## Slide 13  Giá trị ứng dụng và giới hạn của hai dịch vụ

### ALB tạo khả năng phân phối ở đường vào

ALB cung cấp một điểm truy cập được quản lý, routing theo thông tin request, target health và các khả năng bảo mật cùng quan sát tại đường vào. Khi nhiều backend tương thích cùng tồn tại, các request độc lập có thể được phân phối và tránh một target lỗi khi còn đích khỏe. Năng lực này tạo điều kiện cho triển khai nhiều backend và cập nhật backend có kiểm soát.

### ElastiCache cung cấp thao tác dữ liệu ngoài tiến trình

ElastiCache cho phép nhiều backend dùng chung dữ liệu và tận dụng cấu trúc engine như Sorted Set cho leaderboard. Các lựa chọn replica, shard và Serverless mở ra những hướng về đọc, availability hoặc capacity. Mức phù hợp phụ thuộc loại dữ liệu, yêu cầu nhất quán, vòng đời key và khả năng dựng lại dữ liệu khi có lỗi.

### Tính khả thi có nhiều mức bằng chứng

Bằng chứng kết nối cho biết ứng dụng sử dụng được endpoint và credential. Bằng chứng chức năng cho biết request được route hoặc điểm được đọc từ backend khác. Bằng chứng hiệu năng cần workload và số đo latency hoặc throughput. Bằng chứng chịu lỗi cần xác định loại lỗi và trạng thái nào phải được phục hồi. Một kết quả chức năng thành công tạo cơ sở tích hợp, còn các mức bằng chứng khác cần phép thử tương ứng.

Trong Live Quiz, sự phối hợp của hai dịch vụ đáp ứng một phần của hướng nhiều backend: đường vào chung và một số dữ liệu chung. Tính đúng của điểm, phát câu hỏi tới phòng và tiếp tục trận đấu sau mất kết nối còn gắn với logic ứng dụng. Sự phù hợp của dịch vụ được đánh giá theo chức năng cụ thể thay vì coi việc có thêm tài nguyên AWS là một bảo đảm cho toàn hệ thống.

## Slide 14  Phân biệt các khái niệm liên quan

### Cân bằng tải và tự động mở rộng

Cân bằng tải lựa chọn đích trong tập backend hiện có. Scaling thay đổi tài nguyên hoặc số lượng backend. AWS mở rộng năng lực của ALB không có nghĩa ứng dụng đã được cấu hình thêm EC2 hoặc container khi tải tăng.

### Sticky session và chia sẻ trạng thái

Affinity giữ các request liên quan về cùng target trong điều kiện phù hợp. Shared state làm dữ liệu có thể được nhiều target truy cập. Khi một target lỗi, affinity không tạo ra bản sao dữ liệu trong RAM của target đó; dữ liệu chung cũng chỉ bao gồm phần thực sự được lưu chung.

### Kết nối WebSocket và phục hồi phiên

Một WebSocket được gắn với target của kết nối sau upgrade. Reconnect tạo kết nối mới, còn resume hoặc rejoin cần nhận diện phiên cùng trạng thái ở tầng ứng dụng. Thành công của một HTTP request tới B không chứng minh một WebSocket trước đó trên A đã được chuyển nguyên trạng.

### Restart backend và durability của cache

Dữ liệu tồn tại qua restart backend cho thấy vòng đời dữ liệu không phụ thuộc riêng tiến trình đó khi cache còn chạy. Khả năng tồn tại qua lỗi cache phụ thuộc replication, snapshot hoặc durability được cấu hình. Đây là hai miền sự cố khác nhau.

### Replica shard và backup

Replica giữ bản sao trong shard và có thể phục vụ đọc hoặc dự phòng. Shard phân chia tập dữ liệu qua các primary. Backup lưu một bản chụp để khôi phục theo mốc. Thêm replica không tự làm tăng phân mảnh, còn có replication không thay thế mọi mục tiêu phục hồi từ backup.

### TTL và eviction

TTL quy định hạn sống của key. Eviction phản ứng với giới hạn bộ nhớ theo policy. Key có TTL còn lại vẫn có thể bị loại theo policy, nên khoảng thời gian TTL không phải cam kết dữ liệu chắc chắn tồn tại đến hết hạn.

### Reader endpoint và proxy cân bằng tải

Reader endpoint node based được mô tả ở đây dùng DNS tới các replica. Nó không lựa chọn lại đích cho từng command trên một kết nối đã có. Phân bố request còn phụ thuộc pool kết nối và cách client tái sử dụng các kết nối.

### Chia sẻ dữ liệu và đo lợi ích hiệu năng

A ghi và B đọc chứng minh khả năng dùng chung key. Để định lượng giảm tải database hoặc tăng tốc, cần so sánh cùng workload, quy mô dữ liệu và điều kiện đo với baseline. Cache hit rate cũng không thay thế một phép đo end to end hoặc kiểm tra tính đúng của kết quả.

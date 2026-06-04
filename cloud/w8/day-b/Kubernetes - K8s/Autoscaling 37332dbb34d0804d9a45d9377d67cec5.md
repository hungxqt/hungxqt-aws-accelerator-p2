# Autoscaling

**Autoscaling** là cơ chế tự động tăng hoặc giảm tài nguyên khi tải hệ thống thay đổi. Trong Kubernetes, autoscaling có thể tự động điều chỉnh workload theo hai hướng chính:

**Horizontal scaling**: tăng hoặc giảm số lượng Pod/replica.

Ví dụ: từ 2 Pod lên 10 Pod khi traffic tăng.

**Vertical scaling**: tăng hoặc giảm CPU/memory request/limit của Pod.

Ví dụ: mỗi Pod từ `256Mi RAM` lên `1Gi RAM`.

Kubernetes hỗ trợ autoscaling để cluster phản ứng linh hoạt hơn với nhu cầu tài nguyên, thay vì phải scale thủ công bằng tay.

## Có 3 lớp autoscaling quan trọng trong K8s

### A. Horizontal Pod Autoscaler — HPA

**HPA** là loại autoscaling phổ biến nhất. Nó tự động tăng/giảm số lượng Pod dựa trên metric như CPU, memory hoặc custom metrics. Kubernetes mô tả HPA là một API resource và controller, định kỳ điều chỉnh số replica của workload để phù hợp với mức sử dụng tài nguyên quan sát được.

Ví dụ dễ hiểu:

```
Traffic tăng
→ CPU trung bình của Pod vượt 70%
→ HPA tăng replica từ 2 lên 5
→ Load được chia đều cho nhiều Pod hơn
```

Ví dụ YAML:

```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

Ý nghĩa:

```
Nếu CPU trung bình của các Pod vượt khoảng 70%
→ Kubernetes có thể tăng số Pod
Nếu CPU giảm xuống thấp
→ Kubernetes có thể giảm số Pod
Nhưng không thấp hơn 2 và không cao hơn 10
```

Điều kiện quan trọng: Pod nên có `resources.requests`, đặc biệt là `cpu`, vì HPA cần biết mức CPU request để tính phần trăm utilization.

Ví dụ Deployment nên có:

```
resources:
  requests:
    cpu:"200m"
    memory:"256Mi"
  limits:
    cpu:"500m"
    memory:"512Mi"
```

Nếu không khai báo `requests.cpu`, HPA scale theo CPU utilization sẽ hoạt động không chính xác hoặc không tính được.

### B. Vertical Pod Autoscaler — VPA

**VPA** không tăng số Pod. Nó điều chỉnh **CPU/memory requests và limits** của Pod sao cho phù hợp với mức sử dụng thực tế. Kubernetes định nghĩa VPA là cơ chế tự động cập nhật resource requests/limits của workload như Deployment hoặc StatefulSet để match với usage thực tế.

Ví dụ:

```
Pod hiện tại request 128Mi RAM
Nhưng thực tế thường dùng 700Mi RAM
→ VPA khuyến nghị hoặc tự cập nhật request lên gần mức phù hợp hơn
```

Ví dụ YAML:

```
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  updatePolicy:
    updateMode:"Auto"
```

Tuy nhiên, cần lưu ý: **VPA không được cài sẵn mặc định trong Kubernetes core**, khác với HPA. Nó là add-on/CRD cần được cài thêm vào cluster.

Các mode thường gặp của VPA:

| Mode | Ý nghĩa |
| --- | --- |
| `Off` | Chỉ đưa ra recommendation, không tự thay đổi Pod |
| `Initial` | Chỉ set resource khi Pod mới được tạo |
| `Recreate` | Có thể evict/recreate Pod để áp dụng resource mới |
| `InPlaceOrRecreate` | Ưu tiên resize tại chỗ nếu có thể, nếu không thì recreate |

VPA phù hợp với workload khó đoán resource, ví dụ service lúc đầu chưa biết cần bao nhiêu CPU/RAM.

### C. Node Autoscaling / Cluster Autoscaler

HPA chỉ tăng số Pod. Nhưng nếu cluster không còn đủ Node để chạy Pod mới thì Pod sẽ bị `Pending`.

Ví dụ:

```
HPA muốn tăng từ 5 Pod lên 20 Pod
Nhưng các Node hiện tại đã hết CPU/RAM
→ Pod mới không schedule được
→ cần scale thêm Node
```

Lúc này cần **Node Autoscaling**. Kubernetes mô tả node autoscaling là cơ chế tự động provision hoặc consolidate Node để đáp ứng nhu cầu workload và tối ưu chi phí. Nếu có Pod không thể schedule trên Node hiện tại, autoscaler có thể thêm Node mới.

Trong thực tế cloud provider thường dùng:

| Môi trường | Công cụ phổ biến |
| --- | --- |
| AWS EKS | Cluster Autoscaler hoặc Karpenter |
| GKE | GKE Cluster Autoscaler |
| AKS | AKS Cluster Autoscaler |
| On-prem | Tùy giải pháp hạ tầng |

Luồng hoạt động:

```
Traffic tăng
→ HPA tăng Pod
→ Pod mới bị Pending vì thiếu tài nguyên
→ Cluster Autoscaler/Karpenter thêm Node
→ Pod được schedule lên Node mới
```

## Metrics Server có vai trò gì?

Autoscaling cần số liệu. Trong K8s, **Metrics Server** thường được dùng để lấy CPU/memory usage từ kubelet, sau đó expose qua Metrics API cho HPA/VPA sử dụng. Kubernetes nói HPA và VPA dùng dữ liệu từ Metrics API để điều chỉnh replica và resource của workload.

Luồng đơn giản:

```
Pod/Container chạy trên Node
→ kubelet/cAdvisor thu thập CPU, memory
→ Metrics Server lấy metric từ kubelet
→ Metrics API expose metric
→ HPA/VPA đọc metric
→ quyết định scale
```

Bạn có thể kiểm tra Metrics Server bằng:

```
kubectltop nodes
kubectltop pods
```

Nếu lệnh trên lỗi, HPA theo CPU/memory thường cũng chưa hoạt động đúng.

## HPA hoạt động như thế nào?

Giả sử bạn cấu hình:

```
averageUtilization: 70
minReplicas: 2
maxReplicas: 10
```

Kubernetes sẽ theo dõi CPU trung bình của các Pod.

Ví dụ:

```
Deployment có 2 Pod
CPU target là 70%
CPU thực tế trung bình là 140%
```

Khi CPU thực tế gấp đôi target, HPA có thể tăng số replica lên gần gấp đôi.

```
2 Pod × 140 / 70 = 4 Pod
```

Tức là HPA có thể scale từ 2 lên 4 Pod.

Nhưng HPA không scale lên/xuống liên tục từng giây. Nó có cơ chế ổn định, đặc biệt khi scale down. Kubernetes có tham số `--horizontal-pod-autoscaler-downscale-stabilization`, mặc định 5 phút, giúp scale down từ từ để tránh dao động liên tục.

## HPA, VPA và Node Autoscaler khác nhau thế nào?

| Loại | Scale cái gì? | Khi nào dùng? |
| --- | --- | --- |
| HPA | Số lượng Pod | App có traffic thay đổi, cần thêm replica |
| VPA | CPU/RAM của Pod | App cần right-size tài nguyên |
| Node Autoscaler | Số lượng Node | Cluster thiếu hoặc thừa tài nguyên |
| KEDA | Số lượng Pod theo event | Queue, Kafka, RabbitMQ, SQS, cron, external metrics |

KEDA là một autoscaler hướng event. Nó hoạt động cùng các thành phần chuẩn của Kubernetes như HPA và cho phép scale container dựa trên số lượng event cần xử lý, ví dụ message trong queue.

## Ví dụ hoàn chỉnh: Deployment + HPA

### Deployment

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: webapp
          image: nginx
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu:"200m"
              memory:"256Mi"
            limits:
              cpu:"500m"
              memory:"512Mi"
```

### HPA

```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

Apply:

```
kubectl apply-f deployment.yaml
kubectl apply-f hpa.yaml
```

Kiểm tra:

```
kubectlget hpa
kubectl describe hpa webapp-hpa
kubectltop pods
kubectlget pods
```

## Khi nào nên dùng loại nào?

Với web API thông thường:

```
Dùng HPA + Metrics Server
```

Với app cần tối ưu CPU/RAM:

```
Dùng VPA ở mode recommendation trước
Sau đó mới cân nhắc Auto/Recreate
```

Với cluster cloud production:

```
Dùng HPA + Node Autoscaler
```

Với workload xử lý queue/event:

```
Dùng KEDA
Ví dụ: scale theo Kafka lag, RabbitMQ queue length, AWS SQS message count
```

Với hệ thống production tốt hơn:

```
HPA để scale Pod
Node Autoscaler/Karpenter để scale Node
Requests/Limits chuẩn để scheduler và autoscaler quyết định đúng
Readiness/startup probe để tránh scale sai trong lúc app mới khởi động
```

## Lưu ý quan trọng khi dùng autoscaling

- Không nên chỉ bật HPA mà quên `resources.requests`. HPA cần request để tính utilization.
- Không nên đặt `maxReplicas` quá thấp, vì khi traffic tăng mạnh app vẫn nghẽn.
- Không nên đặt `maxReplicas` quá cao nếu backend, database hoặc external service không chịu nổi.
- Không nên dùng HPA và VPA cùng điều chỉnh CPU/memory cho cùng một workload mà chưa hiểu rõ, vì có thể gây xung đột hành vi scale.
- Nên cấu hình `readinessProbe` và `startupProbe`, vì HPA có xử lý đặc biệt với Pod đang khởi động; Kubernetes cũng khuyến nghị dùng startup/readiness probe để tránh lấy nhầm CPU spike lúc app warm up.

## Tóm gọn dễ nhớ

```
HPA  = thêm/bớt Pod
VPA  = tăng/giảm CPU/RAM của Pod
Node Autoscaler = thêm/bớt Node
KEDA = scale theo event/queue/external metric
Metrics Server = nguồn metric CPU/RAM cho autoscaling
```

Trong thực tế, mô hình phổ biến nhất là:

```
Metrics Server
+ HPA cho application
+ Cluster Autoscaler/Karpenter cho node
+ requests/limits hợp lý
+ probe đầy đủ
```

Đây là bộ nền tảng autoscaling quan trọng nhất trong Kubernetes.
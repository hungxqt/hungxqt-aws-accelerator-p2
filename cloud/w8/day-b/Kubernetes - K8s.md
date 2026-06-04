# Kubernetes - K8s

**Kubernetes**, thường viết tắt là **K8s**, là một nền tảng mã nguồn mở, có tính di động và có thể mở rộng, dùng để quản lý workload và service chạy bằng container. Kubernetes hỗ trợ cả cấu hình khai báo và tự động hóa, nghĩa là người dùng mô tả trạng thái mong muốn của hệ thống, còn Kubernetes cố gắng đưa trạng thái thực tế của cluster về đúng trạng thái đó.

Một cách dễ hiểu, Kubernetes giải quyết bài toán sau:

> “Tôi có nhiều container cần chạy ổn định trên nhiều máy chủ. Tôi muốn chúng tự phục hồi khi lỗi, có thể scale, có thể update không downtime, có service discovery, có cấu hình, secret, storage, network policy và quan sát được trạng thái hệ thống.”
> 

Kubernetes cung cấp nhiều khả năng cốt lõi như service discovery, load balancing, storage orchestration, rollout và rollback tự động, tự phục hồi container lỗi, quản lý Secret/ConfigMap, chạy batch workload, horizontal scaling, hỗ trợ IPv4/IPv6 dual-stack và khả năng mở rộng qua API.

Kubernetes **không phải** là một PaaS hoàn chỉnh theo nghĩa truyền thống. Nó không bắt buộc cách bạn build source code, không áp đặt CI/CD, không cung cấp sẵn database, middleware, logging hay monitoring như một bộ sản phẩm đóng gói. Thay vào đó, Kubernetes cung cấp nền tảng điều phối và API mở để bạn tích hợp các công cụ phù hợp.

#### Định nghĩa ngắn gọn

Kubernetes là hệ thống giúp bạn:

- Chạy nhiều container trên nhiều server
- Tự động restart container bị lỗi
- Tự động scale khi traffic tăng
- Cân bằng tải (load balancing)
- Deploy/update ứng dụng mà không downtime
- Quản lý networking, storage, secret, config...

## Kubernetes Object và Kubernetes API

Trong Kubernetes, mọi thứ quan trọng đều được biểu diễn dưới dạng **API object**. Ví dụ: Pod, Deployment, Service, ConfigMap, Secret, Namespace, PersistentVolumeClaim, NetworkPolicy đều là object.

Một manifest Kubernetes thường có cấu trúc cơ bản như sau:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: example/backend:v1
```

Ý nghĩa các phần chính:

| Trường | Ý nghĩa |
| --- | --- |
| `apiVersion` | Xác định version API dùng cho object. |
| `kind` | Xác định loại object, ví dụ `Pod`, `Deployment`, `Service`. |
| `metadata` | Chứa thông tin định danh như `name`, `namespace`, `labels`, `annotations`. |
| `spec` | Mô tả trạng thái mong muốn do người dùng khai báo. |
| `status` | Mô tả trạng thái thực tế do Kubernetes cập nhật. |

Kubernetes khuyến nghị với môi trường production nên quản lý object theo hướng khai báo, thường bằng file manifest và `kubectl apply`, thay vì chỉnh sửa thủ công từng lệnh rời rạc. `kubectl` là CLI chính để giao tiếp với Kubernetes API, quản lý resource, kiểm tra trạng thái và debug cluster.

## Namespace, Labels và Annotations

**Namespace** dùng để chia cluster thành các không gian logic. Tên object chỉ cần duy nhất trong cùng namespace, không nhất thiết duy nhất trên toàn cluster. Namespace phù hợp khi nhiều team, nhiều môi trường hoặc nhiều project dùng chung một cluster. Với production, Kubernetes khuyến nghị không nên dùng namespace `default` cho toàn bộ workload.

[Namespace](Kubernetes%20-%20K8s/Namespace%2037432dbb34d0807f9a2cef3604f380ea.md)

**Labels** là cặp key-value gắn vào object để phân loại và chọn object. Service, Deployment, ReplicaSet và nhiều controller dùng label selector để tìm nhóm Pod cần quản lý. 

**Annotations** cũng là metadata dạng key-value, nhưng dùng cho thông tin không nhằm mục đích chọn lọc object, ví dụ thông tin build, mô tả tool, checksum hoặc cấu hình phụ trợ.

Ví dụ:

```
metadata:
  labels:
    app: backend
    env: production
  annotations:
    description:"Backend API for production environment"
```

Bạn nên dùng labels cho những thông tin cần query, select hoặc group object. Bạn nên dùng annotations cho metadata mô tả, thông tin phụ trợ hoặc dữ liệu mà tool bên ngoài cần đọc.

## Workload Resources

Workload resource giúp Kubernetes quản lý vòng đời của Pod. Thay vì tự tạo từng Pod, bạn khai báo workload resource và để controller duy trì trạng thái mong muốn. Kubernetes cung cấp nhiều loại workload resource cho nhiều kiểu ứng dụng khác nhau.

| Workload | Khi nào dùng |
| --- | --- |
| **Deployment** | Dùng cho stateless application, ví dụ backend API, frontend, worker không cần danh tính ổn định. Deployment hỗ trợ rollout, rollback, scale, pause/resume và quản lý ReplicaSet. |
| **ReplicaSet** | Đảm bảo số lượng Pod replica mong muốn. Thường được Deployment quản lý gián tiếp. |
| **StatefulSet** | Dùng cho stateful application cần danh tính ổn định, thứ tự triển khai hoặc storage ổn định, ví dụ database hoặc distributed system. |
| **DaemonSet** | Đảm bảo mỗi node phù hợp chạy một Pod, thường dùng cho log agent, monitoring agent hoặc network agent. |
| **Job** | Chạy tác vụ đến khi hoàn thành, ví dụ migration, batch processing hoặc one-time task. |
| **CronJob** | Chạy Job theo lịch, tương tự cron trong Linux. |

Deployment là workload phổ biến nhất cho ứng dụng stateless. Khi bạn khai báo Deployment, Kubernetes tạo và quản lý ReplicaSet, sau đó ReplicaSet tạo Pod. Khi update image, Deployment controller điều phối rollout để thay đổi dần từ phiên bản cũ sang phiên bản mới.

[Workload resource](Kubernetes%20-%20K8s/Workload%20resource%2037232dbb34d08007a3bccf6ca773c40f.md)

## Scheduling, tài nguyên và phân bổ Pod

Scheduling là quá trình Kubernetes chọn node phù hợp để chạy Pod. Scheduler xem xét tài nguyên yêu cầu, ràng buộc node, affinity, anti-affinity, taints, tolerations và nhiều yếu tố khác. Sau khi Pod được gán vào node, kubelet trên node đó chịu trách nhiệm chạy Pod.

### Requests và Limits

`requests` mô tả lượng tài nguyên mà container cần để được schedule. `limits` mô tả mức tài nguyên tối đa mà container được phép dùng. Kubernetes hỗ trợ khai báo CPU, memory, ephemeral storage và huge pages. Scheduler dùng requests để chọn node, còn kubelet và container runtime dùng cơ chế của hệ điều hành như cgroups để áp dụng giới hạn.

Ví dụ:

```
resources:
  requests:
    cpu:"250m"
    memory:"256Mi"
  limits:
    cpu:"500m"
    memory:"512Mi"
```

Trong Kubernetes, `1000m` CPU tương đương 1 CPU core hoặc 1 vCPU tùy môi trường chạy. Vì vậy, `250m` nghĩa là 0.25 CPU.

### nodeSelector, affinity và taints/tolerations

`nodeSelector` là cách đơn giản để yêu cầu Pod chạy trên node có label nhất định. Affinity và anti-affinity linh hoạt hơn, vì chúng hỗ trợ điều kiện bắt buộc hoặc ưu tiên, đồng thời có thể biểu diễn quan hệ giữa Pod với node hoặc giữa Pod với Pod.

Taints và tolerations dùng để “đẩy” Pod ra khỏi những node không phù hợp. Một node có taint sẽ không nhận Pod trừ khi Pod có toleration tương ứng. Toleration cho phép Pod được schedule lên node đó, nhưng không đảm bảo chắc chắn Pod sẽ được đặt ở đó.

## Probes: kiểm tra sức khỏe ứng dụng

Kubernetes cho phép định nghĩa probe để kubelet kiểm tra sức khỏe container theo chu kỳ. Dựa trên kết quả probe, Kubernetes có thể restart container không khỏe hoặc ngừng gửi traffic đến container chưa sẵn sàng.

Ba loại probe quan trọng là:

| Probe | Ý nghĩa |
| --- | --- |
| **startupProbe** | Kiểm tra ứng dụng đã khởi động xong chưa. Khi có startupProbe, livenessProbe và readinessProbe chưa chạy cho đến khi startupProbe thành công. |
| **livenessProbe** | Kiểm tra container còn sống và còn tiến triển được không. Nếu livenessProbe fail quá ngưỡng, kubelet restart container. |
| **readinessProbe** | Kiểm tra container đã sẵn sàng nhận traffic chưa. Nếu readinessProbe fail, Pod bị đánh dấu chưa Ready và Service không nên gửi traffic đến Pod đó. |

Liveness probe rất hữu ích nhưng cần cấu hình cẩn thận. Nếu check sai, Kubernetes có thể restart container liên tục dù ứng dụng vẫn có thể phục hồi. Với ứng dụng khởi động chậm, nên dùng startupProbe để tránh livenessProbe giết container quá sớm.

Ví dụ:

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
```

## ConfigMap và Secret

**ConfigMap** dùng để lưu cấu hình không nhạy cảm dưới dạng key-value. Pod có thể dùng ConfigMap làm biến môi trường, command-line argument hoặc file được mount vào volume. ConfigMap giúp tách cấu hình môi trường ra khỏi container image.

**Secret** dùng cho dữ liệu nhạy cảm như password, token, key hoặc thông tin đăng nhập image registry. Secret giống ConfigMap ở cách sử dụng, nhưng được thiết kế cho dữ liệu bí mật. Tuy vậy, tài liệu Kubernetes cảnh báo rằng Secret mặc định được lưu không mã hóa trong etcd, vì vậy production cluster cần bật encryption at rest, dùng RBAC theo nguyên tắc least privilege và giới hạn Pod nào được quyền đọc Secret.

Ví dụ dùng ConfigMap:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  APP_ENV:"production"
  LOG_LEVEL:"info"
```

Ví dụ dùng Secret:

```
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:
  DB_PASSWORD:"change-me"
```

Trong thực tế, không nên commit Secret thật vào Git repository. Bạn nên dùng giải pháp quản lý secret phù hợp với môi trường, bật encryption at rest và hạn chế quyền truy cập.

## Networking trong Kubernetes

[Networking](Kubernetes%20-%20K8s/Networking%2037232dbb34d0801ba806d2f62aec8004.md)

## Storage trong Kubernetes

Container có filesystem tạm thời. Khi container restart hoặc Pod bị thay thế, dữ liệu bên trong container có thể mất. Vì vậy, Kubernetes cung cấp cơ chế volume để Pod truy cập hoặc chia sẻ dữ liệu. Volume có thể dùng cho dữ liệu tạm thời, config, secret, chia sẻ dữ liệu giữa container trong cùng Pod hoặc lưu trữ bền vững.

Các khái niệm storage quan trọng:

| Khái niệm | Ý nghĩa |
| --- | --- |
| **Volume** | Cơ chế gắn dữ liệu vào Pod. Volume có thể là tạm thời hoặc bền vững. |
| **PersistentVolume** | Đại diện cho tài nguyên storage trong cluster, được cấp sẵn hoặc cấp động. |
| **PersistentVolumeClaim** | Yêu cầu storage từ phía workload. Pod thường dùng PVC thay vì trực tiếp quản lý PV. |
| **StorageClass** | Mô tả “loại storage” và cách provision storage động. |
| **VolumeSnapshot** | Cung cấp khả năng tạo bản chụp point-in-time cho volume khi CSI driver hỗ trợ. |

PersistentVolume tách cách storage được cung cấp khỏi cách storage được sử dụng. StorageClass cho phép admin mô tả các lớp storage khác nhau, ví dụ SSD, HDD, replicated storage hoặc cloud block storage.

[Storage](Kubernetes%20-%20K8s/Storage%2037232dbb34d080a0b652c966de054292.md)

## Security trong Kubernetes

Security trong Kubernetes cần nhìn theo nhiều lớp: authentication, authorization, admission control, Pod security, Secret security, network policy và runtime hardening.

### RBAC

RBAC là cơ chế authorization phổ biến trong Kubernetes. Nó dùng các object như `Role`, `ClusterRole`, `RoleBinding` và `ClusterRoleBinding` để xác định ai được làm gì trên resource nào. `Role` áp dụng trong namespace, còn `ClusterRole` có thể áp dụng toàn cluster hoặc dùng lại trong namespace.

Nguyên tắc quan trọng là **least privilege**. Bạn nên cấp quyền nhỏ nhất cần thiết, ưu tiên RoleBinding theo namespace, tránh wildcard permission nếu không thật sự cần, và tránh dùng nhóm `system:masters` cho tác vụ thường ngày.

### ServiceAccount

ServiceAccount là danh tính không phải con người, thường dùng cho Pod, controller hoặc component chạy trong cluster. Mỗi namespace có một default ServiceAccount, và nếu Pod không chỉ định ServiceAccount, Pod sẽ dùng default ServiceAccount của namespace đó. Với production, bạn nên tạo ServiceAccount riêng cho từng ứng dụng và gắn RBAC tối thiểu cần thiết.

### Admission Control

Admission controller chặn hoặc chỉnh sửa request sau bước authentication và authorization, nhưng trước khi object được lưu vào etcd. Admission control có thể validate, mutate hoặc reject request. Kubernetes hỗ trợ nhiều admission controller tích hợp và cơ chế mở rộng như admission webhook hoặc ValidatingAdmissionPolicy.

### Pod Security

Pod Security Standards định nghĩa ba mức chính: **Privileged**, **Baseline** và **Restricted**. Pod Security Admission là admission controller tích hợp, ổn định từ Kubernetes v1.25, dùng để enforce các chuẩn này ở cấp namespace thông qua label.

Trong production, bạn nên hướng tới baseline hoặc restricted, hạn chế privileged container, hạn chế chạy root, giới hạn Linux capabilities và không mount hostPath nếu không cần thiết.

[Security](Kubernetes%20-%20K8s/Security%2037232dbb34d08070a0d1dde203842905.md)

## Quota, LimitRange và quản trị namespace

- ResourceQuota giới hạn tổng tài nguyên mà một namespace có thể sử dụng, ví dụ tổng CPU, memory, số Pod, số Service hoặc số PVC. Khi request tạo hoặc cập nhật object làm namespace vượt quota, API server sẽ từ chối request.
- LimitRange dùng để đặt giới hạn mặc định hoặc min/max cho tài nguyên của object trong namespace. Hai công cụ này rất hữu ích khi nhiều team dùng chung cluster, vì chúng giúp tránh trường hợp một workload tiêu thụ quá nhiều tài nguyên và ảnh hưởng đến workload khác.

## Autoscaling

- Kubernetes hỗ trợ autoscaling ở nhiều lớp. **Horizontal Pod Autoscaler** tự động điều chỉnh số replica của workload như Deployment hoặc StatefulSet dựa trên metric quan sát được, ví dụ CPU, memory hoặc custom metric. Horizontal scaling nghĩa là tăng hoặc giảm số Pod, thay vì tăng tài nguyên của một Pod đơn lẻ.
- Ngoài HPA, Kubernetes documentation cũng mô tả vertical scaling và cluster autoscaling. Vertical scaling điều chỉnh tài nguyên của Pod, còn cluster autoscaling điều chỉnh số node trong cluster. Một số khả năng như Vertical Pod Autoscaler là add-on, không phải core component mặc định của Kubernetes.

[Autoscaling](Kubernetes%20-%20K8s/Autoscaling%2037332dbb34d0804d9a45d9377d67cec5.md)

## Observability và troubleshooting

Observability trong Kubernetes thường xoay quanh ba nhóm dữ liệu: **metrics**, **logs** và **traces**. Metrics giúp theo dõi hiệu năng và cảnh báo, logs giúp phân tích hành vi ứng dụng và lỗi, còn traces giúp hiểu luồng request qua nhiều service. Kubernetes components có thể phát metrics theo định dạng Prometheus text format, rất phù hợp để xây dashboard và alert.

Một quy trình debug cơ bản nên đi theo thứ tự:

```
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- sh
kubectl get events
kubectl get svc,endpoints,endpointslices
kubectl get nodes
kubectl describe node <node-name>
```

Khi debug cluster, tài liệu Kubernetes khuyến nghị kiểm tra node trước bằng `kubectl get nodes` để đảm bảo node ở trạng thái Ready. Khi debug Pod, Service hoặc cluster, Kubernetes documentation cung cấp các luồng kiểm tra riêng cho Pod đang chạy, Service và cluster-level issue.

## Extensibility: CRD, Controller và Operator

Kubernetes mạnh vì nó có API mở rộng. **Custom Resource Definition**, gọi tắt là **CRD**, cho phép bạn thêm loại resource mới vào Kubernetes API. Khi kết hợp CRD với controller, bạn có thể tạo mô hình vận hành riêng cho ứng dụng hoặc hạ tầng.

**Operator pattern** là cách phổ biến để đóng gói tri thức vận hành một hệ thống phức tạp vào Kubernetes. Một Operator thường gồm CRD và controller. Người dùng khai báo custom resource, còn controller đọc custom resource đó và thực hiện hành động cần thiết để vận hành hệ thống.

Kubernetes cũng mở rộng ở nhiều lớp khác, ví dụ Device Plugin để quảng bá tài nguyên phần cứng đặc biệt như GPU, NIC, FPGA hoặc thiết bị lưu trữ; và CNI network plugin để triển khai mô hình networking của cluster.

## Best practices cốt lõi khi dùng Kubernetes

Trong môi trường thực tế, bạn nên ưu tiên cấu hình khai báo bằng manifest hoặc GitOps, thay vì thay đổi thủ công không lưu lại lịch sử. Mỗi workload nên có labels rõ ràng, namespace phù hợp, requests/limits hợp lý, readinessProbe và livenessProbe được thiết kế đúng, Secret được bảo vệ bằng RBAC và encryption at rest, đồng thời NetworkPolicy được dùng để giới hạn traffic không cần thiết.

Với production cluster, bạn nên có nhiều control-plane node, backup etcd, giám sát metrics/logs/traces, kiểm soát version skew của `kubectl`, node và control plane, không chạy workload production trong namespace `default`, hạn chế quyền ServiceAccount mặc định và tránh cấp quyền cluster-wide nếu chỉ cần quyền trong một namespace. Những nguyên tắc này bám sát mô hình vận hành, security và object management được mô tả trong tài liệu chính thức Kubernetes.

[Cluster architecture](Kubernetes%20-%20K8s/Cluster%20architecture%2036c32dbb34d0803e8f51fbde676c8a58.md)
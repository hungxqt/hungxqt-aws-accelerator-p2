# Cluster architecture

Kiến trúc cụm (Cluster Architecture) trong Kubernetes là cách toàn bộ hệ thống Kubernetes được tổ chức thành nhiều thành phần phối hợp với nhau để quản lý container trên nhiều máy chủ khác nhau.

Một Kubernetes Cluster không phải chỉ là “một server chạy container”. Nó là một hệ thống phân tán gồm nhiều node hoạt động cùng nhau để giải quyết các vấn đề như:

- Triển khai ứng dụng tự động.
- Tự phục hồi khi container hoặc máy chủ bị lỗi.
- Scale ứng dụng theo tải.
- Quản lý networking và storage tập trung.
- Đảm bảo trạng thái mong muốn của hệ thống luôn được duy trì.

Về bản chất, kiến trúc cluster của Kubernetes được chia thành 2 phần lớn:

1. Control Plane.
2. Worker Nodes.

# Tổng quan kiến trúc Kubernetes Cluster

Một cluster Kubernetes thường có dạng:

```
                     +----------------------+
                     |    Control Plane     |
                     |----------------------|
                     | API Server           |
                     | Scheduler            |
                     | Controller Manager   |
                     | etcd                 |
                     +----------+-----------+
                                |
         -----------------------------------------------
         |                      |                      |
+--------+----------+  +--------+----------+  +------+-------+
|   Worker Node     |  |   Worker Node     |  | Worker Node  |
|-------------------|  |-------------------|  |--------------|
| kubelet           |  | kubelet           |  | kubelet      |
| kube-proxy        |  | kube-proxy        |  | kube-proxy   |
| Container Runtime |  | Container Runtime |  | containerd   |
| Pods              |  | Pods              |  | Pods         |
+-------------------+  +-------------------+  +--------------+
```

# Control Plane

Control Plane là “bộ não” của cluster.

Nó chịu trách nhiệm:

- Quản lý trạng thái toàn hệ thống.
- Ra quyết định scheduling.
- Theo dõi node.
- Tự phục hồi workload.
- Xử lý API request.

Nếu Control Plane bị chết hoàn toàn thì cluster gần như không thể quản lý được nữa, mặc dù một số container đang chạy có thể vẫn còn hoạt động tạm thời.

Các thành phần chính của Control Plane gồm:

## API Server (kube-apiserver)

API Server là trung tâm giao tiếp của Kubernetes.

Mọi thao tác đều đi qua API Server:

- `kubectl apply`
- tạo Pod
- scale Deployment
- scheduler đọc trạng thái cluster
- kubelet gửi heartbeat

Cơ chế hoạt động:

```
kubectl ---> kube-apiserver ---> etcd
```

API Server đóng vai trò:

- REST API gateway.
- Authentication.
- Authorization.
- Admission control.
- Entry point duy nhất của cluster.

Nếu không có API Server:

- Không thể tạo resource mới.
- Không thể cập nhật cluster state.
- Các component khác gần như không thể phối hợp.

Ví dụ:

```
kubectlget pods
```

Lệnh này thực chất gọi API Server để lấy thông tin Pod.

## etcd là gì

`etcd` là distributed key-value database của Kubernetes.

Nó lưu toàn bộ trạng thái cluster:

- Pod
- Deployment
- Secret
- ConfigMap
- Node info
- Service
- Network config

Ví dụ:

```
desired replicas = 3
current replicas = 2
```

Thông tin này được lưu trong etcd.

Kubernetes hoạt động theo mô hình:

```
Desired State vs Current State
```

etcd chính là nơi lưu “desired state”.

Nếu etcd mất dữ liệu:

- Cluster gần như mất toàn bộ trạng thái.
- Kubernetes không biết cần chạy gì nữa.

Vì vậy:

- etcd cực kỳ quan trọng.
- Thường cần backup định kỳ.
- Production thường chạy HA etcd cluster.

## Scheduler (kube-scheduler)

Scheduler quyết định:

```
Pod nào sẽ chạy trên node nào
```

Khi có Pod mới:

1. Pod được tạo nhưng chưa có node.
2. Scheduler phân tích tài nguyên:
    - CPU
    - RAM
    - affinity
    - taints/tolerations
    - topology
3. Scheduler chọn node phù hợp nhất.

Ví dụ:

```
Node A: còn 8GB RAM
Node B: còn 1GB RAM
```

Scheduler sẽ ưu tiên Node A.

Nếu không có Scheduler:

- Pod sẽ ở trạng thái `Pending`.
- Không Pod nào được gán vào node.

## Controller Manager

Controller Manager chạy nhiều controller khác nhau.

Controller là các vòng lặp (control loop) liên tục kiểm tra:

```
Current State == Desired State ?
```

Nếu khác → Kubernetes tự sửa.

Ví dụ Deployment Controller:

Desired:

```
3 replicas
```

Current:

```
2 replicas
```

Controller sẽ tạo thêm 1 Pod mới.

Một số controller phổ biến:

- Deployment Controller
- ReplicaSet Controller
- Node Controller
- Job Controller
- Endpoint Controller

Ý nghĩa:

Kubernetes là hệ thống “self-healing”.

Nếu container chết:

```
Controller phát hiện -> tạo lại Pod
```

# Worker Node

Worker Node là nơi thực sự chạy ứng dụng container.

Một cluster có thể có:

- vài node
- hàng trăm node
- hàng nghìn node

Mỗi worker node gồm:

- kubelet
- kube-proxy
- container runtime
- Pods

## kubelet

kubelet là agent chạy trên từng node.

Nó giao tiếp với API Server để:

- nhận Pod spec
- chạy container
- monitor container
- gửi trạng thái node

Ví dụ:

```
API Server:
"hãy chạy nginx pod"
```

kubelet sẽ:

1. Pull image.
2. Tạo container.
3. Theo dõi health.
4. Báo trạng thái lại.

Nếu kubelet chết:

- Node sẽ bị đánh dấu `NotReady`.
- Kubernetes có thể reschedule workload sang node khác.

## Container Runtime

Container Runtime là phần thực sự chạy container.

Ngày nay phổ biến nhất là:

- containerd
- CRI-O

Trước đây Docker phổ biến nhưng Kubernetes hiện giao tiếp qua CRI (Container Runtime Interface).

Runtime chịu trách nhiệm:

- pull image
- start container
- stop container
- isolate process

## kube-proxy

kube-proxy quản lý networking cho Service.

Nó thiết lập:

- iptables
- IPVS rules

để traffic có thể:

```
Service -> Pod
```

Ví dụ:

```
Frontend Service -> nhiều backend Pods
```

kube-proxy giúp load balancing request giữa các Pod.

Nếu kube-proxy lỗi:

- Networking trong cluster có thể bị hỏng.
- Service không route được traffic.

## Pod trong kiến trúc cluster

**Pod** là đơn vị nhỏ nhất có thể deploy trong Kubernetes. Một Pod có thể chứa một hoặc nhiều container. Các container trong cùng Pod chia sẻ network namespace, có thể giao tiếp qua `localhost`, và có thể dùng chung volume. 

Trong thực tế, bạn thường **không tạo Pod trực tiếp** cho ứng dụng lâu dài. Thay vào đó, bạn dùng các workload resource như Deployment, StatefulSet, DaemonSet hoặc Job. Lý do là Pod có tính tạm thời; nếu Pod chết hoặc node lỗi, controller sẽ tạo Pod mới thay thế.

Một Pod thường cần quan tâm đến các phần sau:

| Thành phần | Ý nghĩa |
| --- | --- |
| Container image | Image dùng để chạy ứng dụng. |
| Ports | Cổng mà container expose trong Pod. |
| Env | Biến môi trường truyền vào container. |
| Volume mounts | Nơi mount dữ liệu hoặc config vào container. |
| Resource requests/limits | Tài nguyên CPU, memory mà container yêu cầu hoặc bị giới hạn. |
| Probes | Cơ chế kiểm tra container có sống, sẵn sàng nhận traffic hoặc khởi động xong chưa. |
| Security context | Thiết lập bảo mật như user, privilege, capability hoặc filesystem. |

# Luồng hoạt động của cluster

Ví dụ khi deploy ứng dụng:

```
kubectl apply -f app.yaml
```

Quá trình xảy ra:

### Bước 1

User gửi request đến API Server.

### Bước 2

API Server lưu desired state vào etcd.

### Bước 3

Controller phát hiện cần tạo Pod mới.

### Bước 4

Scheduler chọn Worker Node phù hợp.

### Bước 5

kubelet trên node nhận Pod spec.

### Bước 6

Container runtime pull image và chạy container.

### Bước 7

kube-proxy cấu hình networking.

Kết quả:

Ứng dụng bắt đầu hoạt động.

# High Availability (HA) trong Cluster Architecture

Production cluster thường dùng HA để tránh single point of failure.

Ví dụ:

```
3 API Servers
3 etcd nodes
multiple worker nodes
```

Lợi ích:

- Một node chết cluster vẫn hoạt động.
- Giảm downtime.
- Tăng reliability.

Đặc biệt:

etcd thường dùng quorum.

Ví dụ:

```
3 nodes -> cần 2 node sống
5 nodes -> cần 3 node sống
```
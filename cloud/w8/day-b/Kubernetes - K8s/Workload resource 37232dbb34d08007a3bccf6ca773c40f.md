# Workload resource

**Workload Resources** là các tài nguyên Kubernetes dùng để **khai báo, chạy, quản lý và duy trì ứng dụng** trong cluster. Về bản chất, ứng dụng của bạn cuối cùng vẫn chạy dưới dạng **container bên trong Pod**, nhưng thay vì tự tạo và quản lý từng Pod thủ công, Kubernetes khuyến nghị dùng các workload resource để quản lý Pod thay bạn. Nếu một Pod lỗi, controller có thể tạo Pod mới để đưa hệ thống về trạng thái mong muốn.

Nói đơn giản:

```
Bạn khai báo Workload Resource
        ↓
Kubernetes controller đọc khai báo đó
        ↓
Controller tạo / cập nhật / thay thế Pod
        ↓
Container của ứng dụng chạy bên trong Pod
```

Cần phân biệt rõ: **Workload Resources** không phải là CPU/RAM resource. CPU/RAM thường liên quan đến `requests` và `limits`, còn **Workload Resources** là các object như `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`.

## Pod — đơn vị chạy ứng dụng nhỏ nhất

**Pod** là đơn vị nhỏ nhất mà Kubernetes dùng để chạy workload. 

Một Pod có thể chứa một hoặc nhiều container cùng chia sẻ network namespace, storage volume và lifecycle. 

Tuy nhiên, trong thực tế, bạn **không nên thường xuyên tạo Pod trực tiếp** cho ứng dụng production, vì Pod đơn lẻ không tự đảm bảo rollout, rollback, scale hay self-healing tốt bằng controller. 

Kubernetes docs nhấn mạnh rằng workload controllers thường tạo Pod từ **Pod template** và quản lý các Pod đó thay bạn

Ví dụ Pod đơn giản:

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

Pod phù hợp để học, test nhanh, debug, nhưng với ứng dụng thật, ta thường dùng `Deployment`, `StatefulSet`, `DaemonSet`, `Job` hoặc `CronJob`.

## Deployment — dùng cho ứng dụng stateless

**Deployment** là workload resource phổ biến nhất trong Kubernetes. Nó dùng để chạy các ứng dụng **stateless**, ví dụ web server, API service, backend service, frontend service. Deployment tạo và quản lý `ReplicaSet`; sau đó `ReplicaSet` tạo các Pod ở phía sau. Khi bạn cập nhật image hoặc cấu hình Pod template, Deployment tạo ReplicaSet mới, tăng dần Pod mới và giảm dần Pod cũ để rollout có kiểm soát. Deployment cũng hỗ trợ rollback, scale, pause/resume rollout và theo dõi trạng thái rollout.

Ví dụ:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
        - name: backend
          image: my-backend:v1
          ports:
            - containerPort: 8080
```

Luồng hoạt động:

```
Deployment
   ↓
ReplicaSet
   ↓
Pod 1, Pod 2, Pod 3
   ↓
Container backend
```

Dùng `Deployment` khi:

- Ứng dụng có nhiều bản sao giống nhau.
- Pod nào chết cũng có thể thay bằng Pod mới.
- Không cần danh tính cố định cho từng Pod.
- Muốn rolling update và rollback dễ dàng.

Ví dụ thực tế: REST API, web app, frontend, stateless microservice.

## ReplicaSet — giữ số lượng Pod ổn định

**ReplicaSet** có nhiệm vụ duy trì một số lượng Pod replica ổn định tại mọi thời điểm. Nếu bạn khai báo 3 replicas mà 1 Pod chết, ReplicaSet sẽ tạo Pod mới để quay lại đủ 3 Pod. Tuy nhiên, Kubernetes docs khuyến nghị thông thường bạn nên khai báo **Deployment**, rồi để Deployment tự quản lý ReplicaSet, thay vì tạo ReplicaSet trực tiếp.

Ví dụ ý tưởng:

```
Mong muốn: 3 Pod
Thực tế:   2 Pod đang chạy
ReplicaSet: tạo thêm 1 Pod
Kết quả:  3 Pod
```

Dùng trực tiếp `ReplicaSet` khi bạn cần kiểm soát thấp hơn, nhưng trong phần lớn trường hợp production, hãy dùng `Deployment`.

## StatefulSet — dùng cho ứng dụng stateful

**StatefulSet** dùng để quản lý ứng dụng **stateful**, tức là ứng dụng cần trạng thái ổn định, storage ổn định hoặc danh tính mạng ổn định. StatefulSet duy trì **sticky identity** cho từng Pod, đảm bảo mỗi Pod có định danh riêng và thứ tự nhất định khi tạo, scale hoặc xóa. Kubernetes docs mô tả StatefulSet là workload API object để quản lý stateful applications, với đảm bảo về ordering và uniqueness của Pod.

Ví dụ tên Pod trong StatefulSet:

```
mysql-0
mysql-1
mysql-2
```

Khác với Deployment, các Pod trong StatefulSet không hoàn toàn “thay thế tùy ý”. Mỗi Pod có danh tính riêng.

Dùng `StatefulSet` khi:

- Ứng dụng cần persistent storage.
- Mỗi Pod cần tên cố định.
- Mỗi Pod có vai trò hoặc dữ liệu riêng.
- Cần scale theo thứ tự ổn định.

Ví dụ thực tế: database, Kafka, Zookeeper, Elasticsearch, Redis cluster, PostgreSQL cluster.

## DaemonSet — chạy một Pod trên mỗi Node

**DaemonSet** đảm bảo rằng tất cả hoặc một số Node trong cluster đều chạy một bản sao của Pod. Khi Node mới được thêm vào cluster, DaemonSet tự tạo Pod trên Node đó. Khi Node bị xóa khỏi cluster, các Pod tương ứng cũng được dọn dẹp. Kubernetes docs mô tả DaemonSet thường dùng cho các thành phần node-local, ví dụ networking helper, logging agent hoặc monitoring agent.

Ví dụ mô hình:

```
Node 1 → log-agent Pod
Node 2 → log-agent Pod
Node 3 → log-agent Pod
```

Dùng `DaemonSet` khi:

- Cần chạy agent trên mọi Node.
- Cần thu thập log, metric hoặc security event từ từng Node.
- Cần thành phần hỗ trợ networking hoặc storage ở cấp Node.

Ví dụ thực tế: Fluent Bit, Prometheus Node Exporter, Datadog Agent, CNI plugin, CSI node plugin.

## Job — chạy task một lần rồi kết thúc

**Job** dùng cho tác vụ chạy đến khi hoàn thành, không chạy liên tục như web server. Job tạo một hoặc nhiều Pod và tiếp tục retry cho đến khi đủ số lần hoàn thành thành công theo cấu hình. Khi Job hoàn tất, task được xem là complete.

Dùng `Job` khi:

- Chạy migration database.
- Xử lý batch data.
- Import/export dữ liệu.
- Chạy script một lần.
- Chạy tác vụ tính toán có điểm kết thúc rõ ràng.

Ví dụ:

```
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrate
          image: my-migration:v1
          command: ["python","migrate.py"]
```

Khác biệt quan trọng:

```
Deployment: chạy mãi
Job: chạy xong thì dừng
```

## CronJob — chạy Job theo lịch

**CronJob** tạo `Job` theo lịch lặp lại, tương tự cron trên Linux. Kubernetes docs mô tả CronJob phù hợp cho các tác vụ định kỳ như backup, tạo report hoặc các hành động được lên lịch. CronJob sử dụng định dạng cron để khai báo lịch chạy.

Ví dụ chạy mỗi ngày lúc 2 giờ sáng:

```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
spec:
  schedule:"0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: my-backup:v1
              command: ["sh","-c","backup.sh"]
```

Dùng `CronJob` khi:

- Backup database định kỳ.
- Gửi report hằng ngày.
- Cleanup log cũ.
- Đồng bộ dữ liệu theo lịch.
- Chạy health check hoặc maintenance job định kỳ.

## ReplicationController — loại cũ, ít dùng

**ReplicationController** là API cũ để đảm bảo một số lượng Pod replica luôn chạy. Tuy nhiên, Kubernetes docs ghi rõ đây là legacy API và đã được thay thế bởi `Deployment` và `ReplicaSet`. Cách được khuyến nghị hiện nay là dùng `Deployment` để cấu hình ReplicaSet.

Vì vậy, khi học Kubernetes hiện đại, bạn chỉ cần biết `ReplicationController` để đọc tài liệu cũ hoặc hệ thống cũ. Khi triển khai mới, ưu tiên `Deployment`.

## Bảng chọn nhanh Workload Resource

| Nhu cầu | Resource nên dùng |
| --- | --- |
| Chạy web app, API, frontend, backend stateless | `Deployment` |
| Duy trì số lượng Pod giống nhau | `ReplicaSet`, thường thông qua `Deployment` |
| Chạy database hoặc ứng dụng cần danh tính ổn định | `StatefulSet` |
| Chạy agent trên mỗi Node | `DaemonSet` |
| Chạy task một lần rồi kết thúc | `Job` |
| Chạy task định kỳ theo lịch | `CronJob` |
| Hệ thống cũ dùng kiểu replication legacy | `ReplicationController` |

## Cách hiểu tổng quát

Bạn có thể nhớ như sau:

```
Pod          = nơi container thực sự chạy
Deployment   = quản lý app stateless
ReplicaSet   = giữ đủ số lượng Pod
StatefulSet  = quản lý app stateful
DaemonSet    = chạy Pod trên mỗi Node
Job          = chạy task một lần
CronJob      = chạy Job theo lịch
```

Trong thực tế, khi deploy ứng dụng lên Kubernetes:

- Với backend API thông thường, dùng **Deployment**.
- Với database hoặc hệ thống cần dữ liệu bền vững, dùng **StatefulSet**.
- Với logging/monitoring/security agent, dùng **DaemonSet**.
- Với script xử lý một lần, dùng **Job**.
- Với script chạy định kỳ, dùng **CronJob**.

Nắm được nhóm Workload Resources này là nền tảng rất quan trọng, vì hầu hết kiến trúc Kubernetes production đều xoay quanh câu hỏi: **ứng dụng của mình nên được chạy bằng workload resource nào?**
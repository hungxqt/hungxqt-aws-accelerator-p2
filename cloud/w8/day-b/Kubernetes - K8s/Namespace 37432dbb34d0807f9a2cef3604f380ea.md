# Namespace

Namespace giúp **tách biệt tài nguyên trong cùng một cluster**. Ví dụ team dev dùng namespace `development`, team production dùng namespace `production`, mỗi bên có Pod, Service, Deployment riêng. Kubernetes mô tả namespace là cách để chia nhỏ cluster và giúp các project/team/customer khác nhau cùng chia sẻ một cluster.

Namespace thường dùng để:

| Mục đích | Ý nghĩa |
| --- | --- |
| Tách môi trường | `dev`, `staging`, `prod` |
| Tách team/project | `team-a`, `team-b`, `payment`, `auth` |
| Tránh trùng tên resource | Có thể có `api-service` trong cả `dev` và `prod` |
| Gắn quyền truy cập riêng | RBAC theo namespace |
| Giới hạn tài nguyên | ResourceQuota, LimitRange |
| Áp policy riêng | NetworkPolicy, Pod Security, admission policy |

## 2. Namespace không phải là gì?

Namespace **không phải là cluster riêng**.

Nó không tự động cô lập hoàn toàn về bảo mật hoặc network. Nếu muốn cô lập tốt hơn, bạn cần kết hợp thêm:

```
Namespace
+ RBAC
+ ResourceQuota
+ LimitRange
+ NetworkPolicy
+ Pod Security
```

Nói ngắn gọn: **Namespace chỉ là lớp phân vùng logic**, còn bảo mật/cô lập thật sự phải cấu hình thêm policy.

## 3. Các namespace mặc định

Kubernetes thường có 4 namespace ban đầu:

| Namespace | Ý nghĩa |
| --- | --- |
| `default` | Namespace mặc định nếu bạn không chỉ định namespace |
| `kube-system` | Chứa các component hệ thống của Kubernetes |
| `kube-public` | Có thể đọc bởi mọi user, thường dùng cho thông tin public trong cluster |
| `kube-node-lease` | Chứa Lease object liên quan đến heartbeat của node |

Xem namespace hiện có:

```
kubectl get namespaces
```

hoặc viết ngắn:

```
kubectl get ns
```

## 4. Tạo namespace

Cách nhanh:

```
kubectl create namespace development
```

Bằng YAML:

```
apiVersion: v1
kind: Namespace
metadata:
  name: development
```

Apply:

```
kubectl apply -f namespace.yaml
```

Kubernetes khuyến nghị tránh tạo namespace bắt đầu bằng prefix `kube-` vì prefix này dành cho namespace hệ thống.

## 5. Tạo resource trong namespace

Ví dụ tạo Deployment trong namespace `development`:

```
kubectl create deployment nginx \
--image=nginx \
--namespace=development
```

Xem Pod trong namespace đó:

```
kubectl get pods -n development
```

Nếu không có `-n`, Kubernetes sẽ dùng namespace mặc định hiện tại, thường là `default`.

## 6. Khai báo namespace trong YAML resource

Ví dụ Deployment nằm trong namespace `development`:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: development
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
```

## 7. Đặt namespace mặc định cho kubectl

Thay vì lúc nào cũng gõ:

```
kubectlget pods -n development
```

Bạn có thể set namespace mặc định:

```
kubectl config set-context --current--namespace=development
```

Sau đó chỉ cần:

```
kubectlget pods
```

Muốn quay lại `default`:

```
kubectl config set-context --current--namespace=default
```

## 8. Service DNS giữa các namespace

Khi tạo Service, Kubernetes tạo DNS dạng:

```
<service-name>.<namespace-name>.svc.cluster.local
```

Ví dụ có Service tên `api` trong namespace `production`, từ namespace khác có thể gọi:

```
api.production.svc.cluster.local
```

Nếu Pod và Service cùng namespace, có thể gọi ngắn:

```
api
```

Theo tài liệu Kubernetes, DNS đầy đủ của Service có dạng `<service-name>.<namespace-name>.svc.cluster.local`; nếu muốn gọi Service ở namespace khác thì dùng FQDN.

## 9. Xóa namespace

```
kubectl delete namespace development
```

Cẩn thận: xóa namespace sẽ xóa toàn bộ resource bên trong namespace đó. Kubernetes cũng cảnh báo rằng thao tác này xóa mọi thứ dưới namespace.

## 10. Ví dụ thực tế

Một cluster có thể chia như sau:

```
Namespace: dev
- Dành cho developer test nhanh
- Quyền thoải mái hơn
- Resource quota thấp

Namespace: staging
- Môi trường giống production
- Dùng để test trước khi release

Namespace: production
- Quyền chặt hơn
- Có quota rõ ràng
- Có NetworkPolicy
- Có monitoring/alerting nghiêm ngặt
```

## Tóm tắt dễ nhớ

**Namespace = “folder logic” trong Kubernetes cluster.**

Nó giúp bạn gom và tách resource theo môi trường, team hoặc project. Nhưng namespace **không đủ để bảo mật/cô lập hoàn toàn**; trong thực tế nên kết hợp với RBAC, ResourceQuota, LimitRange và NetworkPolicy.
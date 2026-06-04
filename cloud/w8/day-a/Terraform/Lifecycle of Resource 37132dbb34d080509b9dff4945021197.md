# Lifecycle of Resource

Terraform được hiểu như một công cụ quản lý **state** và thực hiện các thao tác **CRUD** lên resource hạ tầng. Resource có thể là EC2, S3, RDS, VPC, hoặc bất kỳ đối tượng nào mà provider hỗ trợ tạo, đọc, cập nhật và xóa. Terraform lưu trạng thái resource trong file `terraform.tfstate` để biết resource hiện tại đang tồn tại như thế nào trên infrastructure.

Nói ngắn gọn:

> Terraform không chỉ “chạy lệnh tạo resource”, mà còn theo dõi resource đó từ lúc tạo, cập nhật, kiểm tra drift, cho đến khi xóa.
> 

## Quy trình provisioning infrastructure bằng Terraform

Một flow cơ bản khi tạo infrastructure mới bằng Terraform gồm các bước sau:

```
Tạo workspace
→ Viết file cấu hình .tf
→ terraform init
→ terraform plan
→ terraform apply
→ terraform destroy nếu muốn xóa
```

Trong bài, ví dụ đầu tiên là tạo một EC2 instance trên AWS. Người dùng tạo folder làm workspace, viết file `main.tf`, khai báo provider AWS và resource `aws_instance`. Sau đó chạy `terraform init` để Terraform tải provider về workspace.

## `terraform init`

`terraform init` dùng để khởi tạo workspace Terraform. Khi chạy lệnh này, Terraform sẽ tải provider cần thiết, ví dụ AWS provider, vào thư mục `.terraform`. Đồng thời Terraform cũng tạo file `.terraform.lock.hcl` để ghi lại phiên bản provider đã được chọn.

Lệnh:

```
terraform init
```

Sau khi init, cấu trúc thư mục thường có dạng:

```
.
├── .terraform
├── .terraform.lock.hcl
└── main.tf
```

Ý nghĩa:

- `.terraform/`: chứa provider plugin.
- `.terraform.lock.hcl`: khóa phiên bản provider.
- `main.tf`: file cấu hình hạ tầng.

## `terraform plan`

`terraform plan` dùng để xem trước Terraform sẽ làm gì với infrastructure thật. Lệnh này chưa tạo, sửa hoặc xóa resource ngay, mà chỉ hiển thị kế hoạch thực thi. Trong bài, khi tạo EC2 mới, output có dòng `Plan: 1 to add, 0 to change, 0 to destroy`, nghĩa là Terraform sẽ thêm 1 resource mới.

Lệnh:

```bash
terraform plan
```

Một số ký hiệu thường gặp trong plan:

| Ký hiệu | Ý nghĩa |
| --- | --- |
| `+` | Resource sẽ được tạo mới |
| `~` | Resource sẽ được cập nhật |
| `-` | Resource sẽ bị xóa |
| `-/+` | Resource cũ bị xóa rồi tạo lại |
| `Plan: 1 to add, 0 to change, 0 to destroy` | Tóm tắt số resource sẽ thêm, sửa, xóa |

`terraform plan` cũng giúp phát hiện lỗi cú pháp trong file Terraform trước khi apply. Bài viết cũng nhắc rằng có thể dùng `-out` để lưu kết quả plan, sau đó dùng lại khi apply, đặc biệt hữu ích trong CI/CD.

Ví dụ:

```
terraform plan -out plan.out
terraform apply "plan.out"
```

## `terraform apply`

`terraform apply` dùng để thực thi kế hoạch và tạo/sửa/xóa resource thật trên cloud. Khi chạy `apply`, Terraform sẽ chạy plan lại, hiển thị thay đổi, rồi yêu cầu nhập `yes` để xác nhận. Chỉ khi nhập đúng `yes`, Terraform mới thực hiện hành động.

Lệnh:

```
terraform apply
```

Có thể bỏ qua bước xác nhận bằng:

```bash
terraform apply -auto-approve
```

Sau khi apply thành công, Terraform tạo file:

```
terraform.tfstate
```

File này lưu trạng thái hiện tại của resource, ví dụ EC2 ID, AMI, tags, public IP, private IP, v.v. Terraform dùng state file để biết resource nào đang được quản lý và trạng thái hiện tại của chúng.

## `terraform destroy`

`terraform destroy` dùng để xóa các resource đang được Terraform quản lý. Khi chạy destroy, Terraform cũng chạy plan trước để liệt kê resource nào sẽ bị xóa, sau đó yêu cầu xác nhận. Sau khi destroy xong, state file vẫn tồn tại nhưng phần `resources` có thể rỗng nếu toàn bộ resource đã bị xóa.

Lệnh:

```
terraform destroy
```

Hoặc:

```
terraform destroy -auto-approve
```

Một điểm quan trọng:

> Nếu xóa toàn bộ config trong file Terraform rồi chạy `terraform apply`, kết quả tương đương với việc chạy `terraform destroy`.
> 

## Data block trong Terraform

Ngoài `resource` block, Terraform còn có `data` block.

`resource` block dùng để tạo và quản lý resource.

`data` block dùng để đọc hoặc truy vấn thông tin resource có sẵn từ provider, nhưng không tạo resource mới. Trong bài, tác giả dùng `data "aws_ami"` để lấy AMI Ubuntu mới nhất thay vì hardcode AMI ID trong file Terraform.

Ví dụ:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "hello" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "HelloWorld"
  }
}
```

Điểm cần nhớ:

- `data` chỉ đọc dữ liệu.
- `data` không tạo resource.
- Khi chạy `terraform plan`, số resource được tạo không tính `data block`.
- `data` giúp cấu hình linh hoạt hơn, tránh hardcode giá trị như AMI ID.

## Life cycle của resource trong Terraform

Theo bài viết, tất cả resource type trong Terraform đều triển khai một dạng CRUD interface gồm các function hook chính: `Create()`, `Read()`, `Update()`, `Delete()`. Các function này được provider thực thi khi Terraform gặp điều kiện tương ứng. Còn data type chỉ có `Read()` vì data block chỉ đọc thông tin, không tạo/sửa/xóa resource.

### Các hook chính

| Hook | Khi nào được gọi | Ý nghĩa |
| --- | --- | --- |
| `Create()` | Khi resource chưa tồn tại và cần tạo mới | Gọi API provider để tạo resource |
| `Read()` | Khi plan hoặc refresh state | Đọc trạng thái hiện tại của resource |
| `Update()` | Khi resource cần cập nhật | Gọi API để sửa resource |
| `Delete()` | Khi resource cần bị xóa | Gọi API để xóa resource |

## Quá trình `plan` hoạt động như thế nào?

Khi chạy `terraform plan`, Terraform thực hiện 3 bước chính:

```
1. Đọc file configuration và state file
2. So sánh desired state với current state
3. Xuất execution plan
```

Terraform đọc cấu hình `.tf`, đọc state file nếu có, sau đó xác định hành động cần làm: `Create`, `Read`, `Update`, `Delete`, hoặc không làm gì cả, tức `No-op`.

Có thể hiểu đơn giản:

```
Config hiện tại bạn viết
        ↓
Terraform state đang lưu
        ↓
Resource thật trên cloud
        ↓
Terraform tính toán cần tạo, sửa, xóa hay giữ nguyên
```

Biểu đồ minh họa của quá trình plan:

![image.png](Lifecycle%20of%20Resource/image.png)

## Các trạng thái trong vòng đời resource

### Create resource

Khi resource chưa tồn tại trong state và trong infrastructure, Terraform sẽ tạo mới resource.

Ví dụ trong bài là tạo S3 bucket:

```
resource "aws_s3_bucket" "terraform-bucket" {
  bucket = "terraform-series-bucket"

  tags = {
    Name = "Terraform Series"
  }
}
```

Khi chạy:

```
terraform apply-auto-approve
```

Terraform gọi `Create()` của resource type `aws_s3_bucket`. Bên trong `Create()` có logic gọi AWS API để tạo S3 bucket thật trên AWS.

Biểu đồ luồng create:

![image.png](Lifecycle%20of%20Resource/image%201.png)

### No-op

`No-op` nghĩa là không có hành động nào cần thực hiện.

Trường hợp này xảy ra khi:

- Resource đã tồn tại trong state.
- Config không thay đổi.
- Resource thật trên cloud vẫn giống với state/config.

Khi chạy `terraform plan`, Terraform gọi `Read()` để đọc trạng thái resource thật từ AWS, so sánh với state file. Nếu không có gì khác biệt, Terraform sẽ báo không có resource nào cần thêm, sửa hoặc xóa.

Ví dụ kết quả:

```
Plan: 0 to add, 0 to change, 0 to destroy.
```

Biểu đồ luồng No-op:

![image.png](Lifecycle%20of%20Resource/image%202.png)

### Update resource

Trong Terraform không có lệnh riêng tên là `terraform update`. Để cập nhật resource, ta sửa file `.tf`, sau đó chạy lại:

```
terraform plan
terraform apply
```

Terraform sẽ tự so sánh config mới với state hiện tại để quyết định cần update resource như thế nào.

Có 2 kiểu update quan trọng:

#### Normal update

Resource được cập nhật trực tiếp, không cần xóa resource cũ.

Ví dụ thường gặp:

```
tags = {
  Name = "New Name"
}
```

Nếu attribute đó cho phép update trực tiếp, Terraform sẽ update in-place.

Output thường có dạng:

```
~ update in-place
```

#### Force new / Replace

Một số attribute không thể sửa trực tiếp. Khi thay đổi các attribute này, Terraform buộc phải xóa resource cũ rồi tạo resource mới.

Trong bài, khi đổi tên S3 bucket từ:

```
bucket = "terraform-series-bucket"
```

sang:

```
bucket = "terraform-series-bucket-update"
```

Terraform báo:

```
-/+ destroy and then create replacement
```

Lý do là `bucket` là một thuộc tính dạng **force new**, nên Terraform phải recreate resource.

Cần đặc biệt cẩn thận với các resource quan trọng như database, vì thay đổi một thuộc tính force new có thể khiến resource bị destroy rồi create lại. Bài viết cũng nhấn mạnh nên luôn chạy `terraform plan` trước khi deploy để phát hiện các thay đổi nguy hiểm kiểu này.

Biểu đồ luồng Update:

![image.png](Lifecycle%20of%20Resource/image%203.png)

### Delete resource

Khi chạy:

```
terraform destroy
```

Terraform đọc state file để biết resource nào đang được quản lý, sau đó gọi `Delete()` của resource type tương ứng để xóa resource thật trên cloud. Trong ví dụ S3, Terraform gọi `Delete()` của `aws_s3_bucket`.

Sau khi destroy, workspace có thể xuất hiện thêm file:

```
terraform.tfstate.backup
```

File này là bản backup của state trước đó, dùng để xem lại trạng thái resource trước khi bị thay đổi hoặc xóa.

Biểu đồ luồng delete:

![image.png](Lifecycle%20of%20Resource/image%204.png)

## Resource drift

`Resource drift` xảy ra khi resource thật trên cloud bị thay đổi bên ngoài Terraform.

Ví dụ:

- Bạn tạo S3 bằng Terraform.
- Sau đó có người vào AWS Console sửa tags của S3.
- File `.tf` không đổi.
- State Terraform đang lưu vẫn là trạng thái cũ.
- Resource thật trên AWS đã khác.

Terraform không tự động sửa file `.tf` khi có người thay đổi resource bên ngoài. Nhưng khi chạy `terraform plan` hoặc `terraform apply`, Terraform sẽ phát hiện resource thật đã thay đổi và báo: `Objects have changed outside of Terraform`.

Sau đó Terraform sẽ cố đưa resource thật quay về trạng thái được mô tả trong file config, trừ khi bạn cấu hình bỏ qua thay đổi đó, ví dụ bằng `ignore_changes`. Trong bài, khi tags của S3 bị sửa ngoài AWS Console, Terraform phát hiện drift và lên kế hoạch update tags về lại giá trị trong file Terraform.

## Tóm tắt luồng lifecycle

Có thể ghi nhớ vòng đời resource như sau:

```
Write config
   ↓
terraform init
   ↓
terraform plan
   ↓
Terraform đọc config + state + resource thật
   ↓
Xác định hành động:
   - Create
   - Read
   - Update
   - Delete
   - No-op
   ↓
terraform apply / destroy
   ↓
Cập nhật terraform.tfstate
```

## Bảng ghi nhớ nhanh

| Thành phần | Vai trò |
| --- | --- |
| `main.tf` | File khai báo desired state |
| `provider` | Plugin giúp Terraform gọi API tới cloud/service |
| `resource` | Đối tượng Terraform sẽ tạo/sửa/xóa |
| `data` | Đọc dữ liệu có sẵn, không tạo resource |
| `terraform init` | Khởi tạo workspace, tải provider |
| `terraform plan` | Xem trước thay đổi |
| `terraform apply` | Áp dụng thay đổi |
| `terraform destroy` | Xóa resource |
| `terraform.tfstate` | Lưu trạng thái resource đang được quản lý |
| `terraform.tfstate.backup` | Backup state trước đó |
| `Create()` | Tạo resource |
| `Read()` | Đọc trạng thái resource |
| `Update()` | Cập nhật resource |
| `Delete()` | Xóa resource |
| `No-op` | Không cần thay đổi gì |
| `Resource drift` | Resource thật bị thay đổi ngoài Terraform |

## Kết luận cần nhớ

Terraform hoạt động dựa trên việc so sánh giữa:

```
Desired state: trạng thái mong muốn trong file .tf
Current state: trạng thái Terraform lưu trong terraform.tfstate
Real state: trạng thái thật trên cloud
```

Từ đó Terraform quyết định cần tạo mới, cập nhật, xóa, recreate hoặc không làm gì. Điểm quan trọng nhất khi làm Terraform là **luôn chạy `terraform plan` trước khi apply**, vì plan giúp phát hiện resource nào sắp bị tạo, sửa, xóa, hoặc bị recreate do thay đổi thuộc tính `force new`.
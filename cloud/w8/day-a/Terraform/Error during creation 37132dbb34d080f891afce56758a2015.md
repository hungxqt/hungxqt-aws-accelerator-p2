# Error during creation

Trong Terraform, **nếu đang tạo resource mà bị lỗi thì Terraform không tự “rollback” toàn bộ như transaction database**. Kết quả phụ thuộc resource đã tạo tới đâu.

### 1. Nếu lỗi xảy ra trước khi resource được tạo

Ví dụ sai IAM permission, sai region, sai input, quota không đủ.

Terraform sẽ dừng `apply`, resource đó **không được ghi vào state**, lần sau chạy lại `terraform apply` thì Terraform sẽ thử tạo lại.

```
terraform plan
terraform apply
```

### 2. Nếu một số resource đã tạo thành công, rồi resource sau bị lỗi

Terraform sẽ giữ những resource đã tạo thành công trong **state**. Lần sau chạy `terraform plan/apply`, Terraform so sánh state với cấu hình hiện tại và chỉ tiếp tục xử lý phần còn thiếu hoặc phần chưa đúng. `terraform apply` là lệnh thực thi các hành động đã được plan để tạo, cập nhật hoặc xoá infrastructure.

Ví dụ:

```
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "private" { ... }
resource "aws_instance" "app" { ... }
```

Nếu VPC và subnet tạo xong, nhưng EC2 lỗi, thì state có thể đã có VPC/subnet. Lần sau Terraform thường chỉ tạo lại EC2.

### 3. Nếu resource bị tạo “nửa chừng”

Đây là case nguy hiểm hơn. Ví dụ AWS đã tạo resource thật, nhưng Terraform chưa kịp ghi state, hoặc provider báo lỗi sau khi resource đã tồn tại.

Khi đó có thể xảy ra:

```
Error: resource already exists
```

Lúc này bạn nên kiểm tra thực tế trên AWS và state:

```
terraform state list
terraform plan
```

Nếu resource **đã tồn tại ngoài cloud nhưng chưa có trong state**, cách đúng thường là import nó vào state:

```
terraform import aws_xxx.name <resource-id>
```

HashiCorp cũng khuyến nghị import thủ công những resource đã được tạo nhưng chưa được lưu vào state sau một lần apply lỗi, để tránh state bị lệch với hạ tầng thật.

### 4. Nếu resource bị đánh dấu `tainted`

Một số trường hợp Terraform nhận ra resource có thể ở trạng thái lỗi hoặc chưa hoàn chỉnh, nó sẽ đánh dấu resource là **tainted**. Resource tainted nghĩa là resource có tồn tại nhưng có thể không hoạt động đúng, nên Terraform sẽ thay thế nó trong lần `plan/apply` tiếp theo.

Ví dụ khi `provisioner` chạy lúc tạo resource bị lỗi, Terraform sẽ mark resource đó là tainted để lần sau destroy và recreate.

Có thể ép Terraform recreate resource bằng:

```
terraform apply-replace="aws_instance.example"
```

Cách này hiện được khuyến nghị hơn việc dùng `terraform taint`.

### Tóm lại

Khi `terraform apply` bị lỗi:

```
Terraform dừng tại lỗi
Không rollback toàn bộ
Resource đã tạo thành công thường được lưu vào state
Resource lỗi có thể chưa có trong state hoặc bị tainted
Lần sau apply, Terraform tiếp tục từ trạng thái hiện tại
```

Quy trình xử lý an toàn:

```
terraform plan
terraform state list
# kiểm tra resource thật trên AWS Console/CLI
terraform import ...# nếu resource đã tồn tại nhưng chưa có state
terraform apply-replace=...# nếu resource lỗi cần tạo lại
terraform apply
```

Nói ngắn gọn: **Terraform không đảm bảo “all-or-nothing”. Apply có thể bị partial apply, nên state là thứ cần kiểm tra đầu tiên sau khi lỗi.**
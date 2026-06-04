# Lifecycle meta-argument

`lifecycle` là **meta-argument** dùng bên trong resource để điều chỉnh cách Terraform tạo, cập nhật, thay thế hoặc bảo vệ resource trong quá trình `plan/apply`. Meta-argument là argument đặc biệt có sẵn trong ngôn ngữ Terraform, không phải argument riêng của provider. HashiCorp mô tả `lifecycle` là block dùng để tùy chỉnh các giai đoạn lifecycle của resource.

Cú pháp chung:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
    ignore_changes        = [tags]
  }
}
```

## `create_before_destroy`

Mặc định, khi một thay đổi buộc Terraform phải thay thế resource, Terraform thường **destroy resource cũ trước**, rồi mới **create resource mới**. Với:

```
lifecycle {
  create_before_destroy = true
}
```

Terraform sẽ cố gắng **tạo resource mới trước**, sau đó mới xoá resource cũ. Cái này hữu ích để giảm downtime, ví dụ đổi Launch Template, target group, instance, hoặc tài nguyên cần thay thế. HashiCorp lưu ý rằng rule này cần dùng cẩn thận vì nhiều resource yêu cầu tên phải unique, nên resource cũ và mới có thể không cùng tồn tại được nếu trùng tên.

Ví dụ:

```hcl
resource "aws_lb_target_group" "app" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }
}
```

Lưu ý: nếu tên `app-tg` bắt buộc unique, Terraform có thể không tạo được cái mới trước khi xoá cái cũ. Khi đó bạn cần dùng tên có suffix/random hoặc thiết kế lại naming.

## `prevent_destroy`

Dùng để chặn Terraform xoá resource quan trọng:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Nếu plan có hành động destroy resource này, Terraform sẽ báo lỗi và không cho apply. Thường dùng cho RDS, S3 bucket quan trọng, production database, KMS key, v.v. HashiCorp cũng nhấn mạnh rằng `prevent_destroy` **không bảo vệ resource nếu bạn xoá cả block resource khỏi file `.tf`**; rule này chỉ có hiệu lực khi lifecycle block vẫn còn trong configuration.

Ví dụ:

```hcl
resource "aws_db_instance" "prod" {
  identifier = "prod-db"

  lifecycle {
    prevent_destroy = true
  }
}
```

Nếu chạy:

```
terraform destroy
```

Terraform sẽ từ chối xoá resource này.

## `ignore_changes`

Dùng để bảo Terraform **bỏ qua thay đổi ở một số attribute** khi plan update.

Ví dụ:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  tags = {
    Name = "web-server"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
```

Nếu ai đó hoặc hệ thống khác thay đổi `tags` ngoài Terraform, lần sau chạy `terraform plan`, Terraform sẽ không cố sửa `tags` về như trong code. Theo tài liệu, Terraform vẫn xét các attribute này khi create resource, nhưng bỏ qua chúng khi lập plan update.

Có thể ignore một field cụ thể:

```hcl
lifecycle {
  ignore_changes = [
    tags["LastModifiedBy"]
  ]
}
```

Hoặc ignore tất cả thay đổi:

```hcl
lifecycle {
  ignore_changes = all
}
```

Nhưng `ignore_changes = all` nên dùng rất hạn chế, vì Terraform gần như chỉ còn quản lý create/destroy, không còn quản lý update.

## `replace_triggered_by`

Dùng để ép resource bị **replace** khi resource hoặc attribute khác thay đổi.

Ví dụ:

```hcl
resource "aws_ecs_service" "app" {
  name = "app-service"
  # ...
}

resource "aws_appautoscaling_target" "ecs_target" {
  # ...

  lifecycle {
    replace_triggered_by = [
      aws_ecs_service.app.id
    ]
  }
}
```

Nghĩa là khi `aws_ecs_service.app.id` thay đổi, Terraform sẽ replace `aws_appautoscaling_target.ecs_target`. Theo tài liệu, `replace_triggered_by` chỉ reference được managed resources hoặc attribute của managed resources, vì Terraform dựa vào planned actions của các resource đó để quyết định replace.

## `precondition`

Dùng để kiểm tra điều kiện **trước khi Terraform thao tác với resource**.

Ví dụ:

```hcl
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  lifecycle {
    precondition {
      condition     = data.aws_ami.amazon_linux.architecture == "x86_64"
      error_message = "AMI must be x86_64."
    }
  }
}
```

Nếu condition sai, Terraform dừng lại và in `error_message`. `precondition` hữu ích khi bạn muốn validate logic hạ tầng trước khi apply, ví dụ AMI phải đúng architecture, subnet phải thuộc VPC mong muốn, instance type phải thuộc danh sách cho phép. Terraform đánh giá `precondition` sau `count` và `for_each`, nên có thể dùng `count.index` hoặc `each.key` trong điều kiện.

## `postcondition`

Dùng để kiểm tra điều kiện **sau khi Terraform đọc hoặc tạo resource**. Nếu điều kiện sai, Terraform chặn các resource downstream phụ thuộc vào resource đó.

Ví dụ:

```hcl
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  lifecycle {
    postcondition {
      condition     = self.public_dns != ""
      error_message = "EC2 instance must have a public DNS."
    }
  }
}
```

Ở đây `self` đại diện cho resource hiện tại. Sau khi tạo EC2, Terraform kiểm tra `public_dns`. Nếu rỗng, Terraform báo lỗi. HashiCorp ghi rằng `postcondition` có thể dùng trong `resource`, `data`, và `ephemeral` blocks.

## `action_trigger`

Trong tài liệu Terraform mới, `lifecycle` còn có `action_trigger`, dùng để tự động gọi action ở các thời điểm như `before_create`, `after_create`, `before_update`, `after_update`.

Ví dụ dạng khái niệm:

```hcl
resource "..." "example" {
  lifecycle {
    action_trigger {
      events  = ["after_create"]
      actions = [
        action.some_type.some_action
      ]
    }
  }
}
```

Cái này thuộc nhóm tính năng mới hơn, không phải pattern phổ biến như `create_before_destroy`, `prevent_destroy`, `ignore_changes`.

## Bảng tóm tắt dễ nhớ

| Rule | Mục đích | Khi nào dùng |
| --- | --- | --- |
| `create_before_destroy` | Tạo mới trước, xoá cũ sau | Giảm downtime khi replace |
| `prevent_destroy` | Chặn xoá resource | Bảo vệ DB, S3, KMS, production resource |
| `ignore_changes` | Bỏ qua thay đổi một số attribute | Attribute bị thay đổi bởi hệ thống khác |
| `replace_triggered_by` | Ép replace khi resource khác đổi | Khi dependency logic không tự thể hiện đủ |
| `precondition` | Kiểm tra trước khi thao tác | Validate input/resource trước apply |
| `postcondition` | Kiểm tra sau khi thao tác | Đảm bảo output/state đạt yêu cầu |
| `action_trigger` | Gọi action theo lifecycle event | Tự động chạy action trước/sau create/update |

## Điểm cần nhớ

`lifecycle` ảnh hưởng đến cách Terraform xây dựng dependency graph, nên nhiều giá trị trong lifecycle phải là literal value vì Terraform xử lý chúng khá sớm, trước khi evaluate expression phức tạp.

Quan trọng nhất: **lifecycle không thay đổi bản chất resource**, mà chỉ thay đổi **cách Terraform xử lý vòng đời của resource đó**.

Ví dụ ngắn gọn:

```hcl
resource "aws_db_instance" "main" {
  identifier = "my-prod-db"
  engine     = "postgres"
  # ...

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      password
    ]
  }
}
```

Ý nghĩa:

Terraform vẫn quản lý RDS này, nhưng:

`prevent_destroy = true` giúp tránh xoá nhầm database.

`ignore_changes = [password]` giúp Terraform không cố update password nếu password được rotate bởi Secrets Manager hoặc cơ chế khác.
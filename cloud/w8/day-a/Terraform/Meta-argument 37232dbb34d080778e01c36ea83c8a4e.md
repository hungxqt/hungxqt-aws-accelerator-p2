# Meta-argument

**Meta-argument trong Terraform** là các argument đặc biệt được Terraform xây dựng sẵn trong ngôn ngữ cấu hình. Chúng không phải là thuộc tính riêng của AWS/Azure/GCP provider, mà dùng để điều khiển **cách Terraform tạo, quản lý, phụ thuộc, lặp, hoặc bảo vệ resource/module**. Theo tài liệu Terraform, meta-arguments có thể dùng trong resource, và phần lớn cũng dùng được trong module blocks.

Ví dụ argument thường:

```
resource "aws_instance" "web" {
  ami           = "ami-xxxx"
  instance_type = "t3.micro"
}
```

Ở đây `ami` và `instance_type` là **argument thường**, do AWS provider định nghĩa.

Còn meta-argument:

```
resource "aws_instance" "web" {
  count         = 2
  ami           = "ami-xxxx"
  instance_type = "t3.micro"
}
```

Ở đây `count` là **meta-argument**, do Terraform định nghĩa, dùng để tạo nhiều instance từ cùng một resource block.

### Các meta-argument quan trọng

| Meta-argument | Dùng để làm gì |
| --- | --- |
| `count` | Tạo nhiều resource/module giống nhau theo số lượng |
| `for_each` | Tạo nhiều resource/module dựa trên map hoặc set |
| `depends_on` | Khai báo dependency thủ công khi Terraform không tự suy luận được |
| `provider` | Chọn provider configuration cụ thể cho resource |
| `providers` | Truyền provider configuration vào module |
| `lifecycle` | Điều khiển vòng đời resource: tạo trước khi xoá, chặn xoá, bỏ qua thay đổi, ép replace, validate điều kiện |

## `count`

Dùng khi muốn tạo nhiều resource giống nhau theo số lượng.

```
resource "aws_instance" "server" {
  count = 3

  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  tags = {
    Name = "server-${count.index}"
  }
}
```

Kết quả Terraform tạo:

```
aws_instance.server[0]
aws_instance.server[1]
aws_instance.server[2]
```

`count` nhận một số nguyên, và giá trị này phải được biết trước khi Terraform thực hiện thao tác với remote resource.

## `for_each`

Dùng khi muốn tạo nhiều resource theo từng phần tử của map hoặc set.

```
resource "aws_iam_user" "users" {
  for_each = toset(["hung", "minh", "nam"])

  name = each.key
}
```

Kết quả Terraform tạo:

```
aws_iam_user.users["hung"]
aws_iam_user.users["minh"]
aws_iam_user.users["nam"]
```

`for_each` phù hợp hơn `count` khi mỗi resource có một key rõ ràng, ví dụ user name, subnet name, environment name. Terraform yêu cầu key của `for_each` phải được biết trước khi apply.

## `depends_on`

Thông thường Terraform tự suy luận dependency qua reference:

```
resource "aws_instance" "web" {
  iam_instance_profile = aws_iam_instance_profile.example.name
}
```

Nhưng nếu có dependency ẩn, Terraform không nhìn thấy trực tiếp, ta dùng `depends_on`:

```
resource "aws_instance" "web" {
  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  depends_on = [
    aws_iam_role_policy.example
  ]
}
```

`depends_on` nên dùng khi thật sự cần, vì Terraform khuyến nghị ưu tiên dependency tự nhiên thông qua expression references trước.

## `provider`

Dùng khi có nhiều cấu hình provider, ví dụ deploy AWS ở nhiều region.

```
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

resource "aws_instance" "server_west" {
  provider = aws.west

  ami           = "ami-xxxx"
  instance_type = "t3.micro"
}
```

Ở đây resource `server_west` dùng provider AWS alias `west`, tức region `us-west-2`, thay vì provider mặc định. Terraform cho phép resource, data source hoặc module chọn provider configuration khác bằng `provider = <PROVIDER>.<ALIAS>`.

## `providers`

Dùng trong `module` để truyền provider configuration từ root module vào child module.

```
module "network_west" {
  source = "./modules/network"

  providers = {
    aws = aws.west
  }
}
```

Nếu không chỉ định, child module thường kế thừa provider mặc định từ parent module. Khi cần dùng provider alias hoặc multi-region, ta truyền rõ bằng `providers`.

## `lifecycle`

`lifecycle` dùng để điều chỉnh cách Terraform xử lý vòng đời resource: create, update, replace, destroy.

Ví dụ:

```
resource "aws_db_instance" "main" {
  allocated_storage = 20
  engine            = "postgres"
  instance_class    = "db.t3.micro"

  lifecycle {
    prevent_destroy = true
  }
}
```

Một số rule quan trọng trong `lifecycle`:

```
lifecycle {
  create_before_destroy = true
  prevent_destroy       = true
  ignore_changes        = [tags]
  replace_triggered_by  = [aws_ecs_service.app.id]
}
```

Ý nghĩa:

| Rule | Ý nghĩa |
| --- | --- |
| `create_before_destroy` | Tạo resource mới trước, rồi mới xoá resource cũ |
| `prevent_destroy` | Chặn Terraform destroy resource quan trọng |
| `ignore_changes` | Bỏ qua thay đổi ở một số attribute |
| `replace_triggered_by` | Ép replace resource khi resource/attribute khác thay đổi |
| `precondition` | Kiểm tra điều kiện trước khi tạo/cập nhật |
| `postcondition` | Kiểm tra điều kiện sau khi tạo/cập nhật |

Ví dụ hay gặp:

```
resource "aws_instance" "web" {
  ami           = "ami-xxxx"
  instance_type = "t3.micro"

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
```

Nghĩa là nếu tag bị thay đổi bên ngoài Terraform, Terraform sẽ không cố sửa lại tag đó trong lần plan/apply tiếp theo. Terraform chỉ cho `ignore_changes` áp dụng lên attribute thật của resource, không áp dụng lên meta-argument khác.

[Lifecycle meta-argument](Meta-argument/Lifecycle%20meta-argument%2037232dbb34d0806d8f22d097993ad84b.md)
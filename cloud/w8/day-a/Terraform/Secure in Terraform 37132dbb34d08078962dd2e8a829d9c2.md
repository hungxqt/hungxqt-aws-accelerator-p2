# Secure in Terraform

Trong Terraform, **secure** nghĩa là viết và vận hành IaC sao cho không lộ secret, không mất state, không cấp quyền quá rộng, và mọi thay đổi hạ tầng đều được kiểm soát.

## Không hard-code secret trong `.tf`

Không nên viết trực tiếp như sau:

```
provider "aws" {
  region     = "ap-southeast-1"
  access_key = "AKIA..."
  secret_key = "..."
}
```

Nên dùng credential từ môi trường, AWS profile, OIDC, HCP Terraform variables, Vault hoặc Secrets Manager. Terraform khuyến nghị dùng biến môi trường hoặc nguồn cấu hình thay thế để tránh đưa credential vào code version control.

Ví dụ tốt hơn:

```
provider "aws" {
  region = var.aws_region
}
```

Sau đó để AWS credentials được lấy từ:

```
aws configure
```

hoặc trong CI/CD dùng OIDC assume role.

## Hiểu đúng về `sensitive`

`Sensitive` chỉ giúp **ẩn giá trị khỏi CLI output/UI**, chứ không có nghĩa là secret không nằm trong state. Terraform vẫn có thể lưu sensitive values trong state và plan files; ai đọc được state thì vẫn có thể đọc được secret.

Ví dụ:

```
variable "database_password" {
  type      = string
  sensitive = true
}
```

Dùng như vậy là tốt, nhưng **chưa đủ an toàn**. Vẫn phải bảo vệ `terraform.tfstate`.

## Bảo vệ Terraform state

State là phần cực kỳ quan trọng vì Terraform dùng state để map resource trong cloud với resource trong code. Terraform mặc định lưu state local trong file `terraform.tfstate`, nhưng HashiCorp khuyến nghị dùng HCP Terraform hoặc remote backend để lưu state an toàn hơn và hỗ trợ cộng tác.

Không nên:

```
git add terraform.tfstate
```

Nên có `.gitignore`:

```
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

Nếu dùng AWS S3 backend, nên bật:

```
terraform {
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Ngoài ra, quyền đọc/ghi state nên chỉ cấp cho CI/CD hoặc người thật sự cần. HashiCorp cũng cảnh báo rằng state có thể chứa metadata và thông tin nhạy cảm; truy cập state quá rộng có thể làm lộ thông tin hoặc gây drift.

## Dùng `ephemeral` cho dữ liệu nhạy cảm tạm thời

Terraform mới hỗ trợ `ephemeral` để giá trị chỉ tồn tại trong lúc chạy, không lưu vào plan hoặc state. Đây là cách tốt hơn cho token tạm thời, password tạm thời hoặc credential ngắn hạn.

Ví dụ:

```
variable "api_token" {
  type      = string
  sensitive = true
  ephemeral = true
}
```

Có thể hiểu đơn giản:

```
sensitive = ẩn khi hiển thị
ephemeral = không lưu vào state/plan
```

## Cấp quyền theo nguyên tắc least privilege

Tài khoản hoặc role chạy Terraform không nên có quyền `AdministratorAccess` lâu dài. Nên tách role theo môi trường:

```
terraform-dev-role
terraform-staging-role
terraform-prod-role
```

Ví dụ role chạy Terraform cho ECS chỉ nên có quyền tạo/sửa những resource liên quan như ECS, IAM role cần thiết, ALB, Security Group, CloudWatch Logs, ECR, chứ không nên có toàn quyền toàn account.

Trong production, nên chạy Terraform qua CI/CD hoặc HCP Terraform thay vì máy cá nhân.

## Pin version provider và module

Nên khóa Terraform version và provider version để tránh thay đổi ngoài ý muốn:

```
terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

Với module, nên dùng version rõ ràng:

```
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.0"
}
```

Không nên dùng module không rõ nguồn gốc, hoặc dùng branch `main` trực tiếp cho production.

## Kiểm soát thay đổi bằng plan, review và policy

Workflow an toàn nên là:

```
Developer tạo Pull Request
        ↓
terraform fmt
terraform validate
terraform plan
        ↓
Review plan
        ↓
Policy check
        ↓
Manual approval nếu là production
        ↓
terraform apply
```

Với HCP Terraform, có thể dùng policy enforcement để kiểm tra plan trước khi apply. HCP Terraform hỗ trợ Sentinel hoặc OPA để viết policy, ví dụ chặn tạo public S3 bucket, chặn mở port SSH ra `0.0.0.0/0`, hoặc bắt buộc resource phải có tag.

Ví dụ policy nên enforce:

```
Không cho Security Group mở port 22 từ 0.0.0.0/0
Không cho S3 bucket public
Bắt buộc EBS/RDS/S3 encryption
Bắt buộc tag: Environment, Owner, Project
Không cho tạo resource production ngoài region cho phép
```

## Secure resource ngay trong Terraform code

Ví dụ Security Group không an toàn:

```
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

Tốt hơn:

```
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.office_ip_cidr]
}
```

Ví dụ S3 nên bật block public access:

```
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Ví dụ RDS nên bật encryption:

```
resource "aws_db_instance" "main" {
  identifier        = "app-db"
  engine            = "postgres"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20

  storage_encrypted = true

  username = var.db_username
  password = var.db_password
}
```

## Checklist secure Terraform

| Nhóm | Việc cần làm |
| --- | --- |
| Secret | Không hard-code password, token, access key |
| Variable | Dùng `sensitive = true` cho secret |
| State | Không commit `terraform.tfstate` |
| Backend | Dùng remote backend, encryption, locking |
| IAM | Role chạy Terraform phải least privilege |
| Provider | Không để credential trong provider block |
| Module | Pin version module/provider |
| CI/CD | Chạy `fmt`, `validate`, `plan`, review trước apply |
| Production | Có manual approval trước `apply` |
| Policy | Dùng Sentinel/OPA hoặc scanner để chặn cấu hình nguy hiểm |
| Resource | Bật encryption, tắt public access, hạn chế CIDR rộng |

## Tóm gọn

Trong Terraform, secure quan trọng nhất là:

```
Không lộ secret
Không lộ state
Không cấp quyền quá rộng
Không apply trực tiếp lên production
Không dùng module/provider không kiểm soát
Không cho tạo resource sai chuẩn bảo mật
```

Câu dễ nhớ:

> `sensitive` giúp ẩn secret khỏi output, nhưng bảo mật thật sự nằm ở việc bảo vệ state, credential, IAM role, backend và CI/CD workflow.
>
# Backend

Trong Terraform, **backend** là nơi Terraform lưu **state file** (`terraform.tfstate`). State là dữ liệu Terraform dùng để biết resource nào trong code đang tương ứng với resource thật trên cloud. Backend được khai báo trong block `terraform`.

Ví dụ đơn giản:

```
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "dev/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
```

Nghĩa là Terraform sẽ lưu state vào S3 bucket thay vì lưu file `terraform.tfstate` trên máy local.

## Backend dùng để làm gì?

Backend có 3 vai trò chính:

Thứ nhất, **quy định nơi lưu state**. Mặc định Terraform dùng backend `local`, tức là lưu state trong file local trên máy của bạn.

Thứ hai, **hỗ trợ làm việc nhóm**. Nếu state chỉ nằm trên máy một người, các thành viên khác không có state mới nhất, rất dễ gây conflict hoặc tạo sai resource. Remote backend cho phép nhiều người cùng dùng chung state ở một nơi như S3, Azure Blob, GCS, HCP Terraform.

Thứ ba, **state locking**. Một số backend hỗ trợ khóa state khi đang chạy `terraform plan` hoặc `terraform apply`, giúp tránh việc nhiều người cùng apply một lúc làm hỏng state.

## Backend khác gì provider?

**Provider** dùng để Terraform giao tiếp với cloud/service, ví dụ AWS, Azure, Google Cloud.

```
provider "aws" {
  region = "ap-southeast-1"
}
```

Provider trả lời câu hỏi:

> Terraform sẽ tạo resource ở đâu?
> 

Còn **backend** trả lời câu hỏi:

> Terraform sẽ lưu state ở đâu?
> 

Ví dụ:

```
terraform {
  backend "s3" {
    bucket = "my-tfstate-bucket"
    key    = "dev/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region = "ap-southeast-1"
}
```

Ở đây:

```
backend "s3"
```

nghĩa là state lưu trong S3.

```
provider "aws"
```

nghĩa là Terraform dùng AWS provider để tạo resource AWS.

## Backend khác gì state?

**State** là dữ liệu Terraform lưu lại.

Ví dụ state ghi nhớ rằng:

```
aws_instance.web
```

đang tương ứng với EC2 instance thật có ID:

```
i-0123456789abcdef
```

Còn **backend** là nơi chứa state đó.

Có thể hiểu đơn giản:

```
State   = nội dung dữ liệu Terraform lưu
Backend = nơi lưu dữ liệu đó
```

## Một số loại backend phổ biến

| Backend | Ý nghĩa |
| --- | --- |
| `local` | Lưu state trên máy local, mặc định của Terraform |
| `s3` | Lưu state trong Amazon S3 |
| `azurerm` | Lưu state trong Azure Storage |
| `gcs` | Lưu state trong Google Cloud Storage |
| `remote` / HCP Terraform | Lưu state và chạy workflow qua HCP Terraform |

Với AWS, backend `s3` rất phổ biến. S3 backend lưu state dưới dạng object trong bucket, tại đường dẫn được khai báo bằng `key`.

## S3 Backend

**S3 backend** là backend dùng **Amazon S3 bucket** để lưu Terraform state.

Ví dụ:

```
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "dev/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
```

Trong đó:

```
bucket = "my-terraform-state-bucket"
```

là S3 bucket dùng để lưu state.

```
key = "dev/terraform.tfstate"
```

là đường dẫn object state trong bucket.

```
region = "ap-southeast-1"
```

là region của bucket.

Terraform official docs cũng mô tả rằng S3 backend lưu state tại object path được khai báo bằng `key` trong S3 bucket được khai báo bằng `bucket`.

### Vì sao cần S3 Backend?

Mặc định Terraform dùng **local backend**, nghĩa là state nằm trên máy bạn:

```
terraform.tfstate
```

Cách này phù hợp khi học/lab nhỏ. Nhưng khi làm team hoặc CI/CD thì không ổn, vì mỗi người có thể có state khác nhau.

S3 backend giải quyết vấn đề này bằng cách đưa state lên một nơi dùng chung:

```
Local machine
    ↓
Terraform
    ↓
S3 bucket chứa terraform.tfstate
```

AWS cũng khuyến nghị remote backend vì nó giúp collaboration, backup/recovery, locking, CI/CD workflow và quản trị state tốt hơn.

### Kiến trúc trong bài Viblo

Bài Viblo mô tả S3 backend gồm các thành phần chính:

```
IAM
DynamoDB
S3 Bucket
KMS
```

Trong bài đó:

| Thành phần | Vai trò |
| --- | --- |
| IAM | Cho Terraform quyền truy cập S3, DynamoDB, KMS |
| S3 Bucket | Lưu file `terraform.tfstate` |
| DynamoDB | Dùng để lock state |
| KMS | Mã hóa state trong S3 |

Bài Viblo giải thích DynamoDB được dùng để ghi lock key của một process, còn S3 bucket lưu state sau khi Terraform chạy xong, và KMS dùng để mã hóa state trong S3.

Tuy nhiên, điểm cần cập nhật là: **DynamoDB locking hiện đã deprecated trong Terraform S3 backend**. Terraform hiện khuyến nghị dùng **S3 native locking** với `use_lockfile = true`.

### Cấu hình S3 Backend hiện nên dùng

Cách hiện tại nên viết:

```
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "environments/development/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Điểm quan trọng là:

```
use_lockfile = true
```

Dòng này bật **S3 state locking**. Terraform docs nói state locking của S3 backend là tính năng opt-in, tức là phải bật thủ công.

Khi bật locking, Terraform sẽ tạo lock file dạng:

```
environments/development/terraform.tfstate.tflock
```

File này giúp ngăn nhiều người hoặc nhiều pipeline ghi vào cùng state cùng lúc.

### Cách cũ trong bài Viblo

Bài Viblo dùng cấu hình kiểu cũ:

```
terraform {
  backend "s3" {
    bucket         = "terraform-series-s3-backend"
    key            = "test-project"
    region         = "us-west-2"
    encrypt        = true
    role_arn       = "arn:aws:iam::<ACCOUNT_ID>:role/HpiS3BackendRole"
    dynamodb_table = "terraform-series-s3-backend"
  }
}
```

Ý nghĩa:

```
dynamodb_table = "terraform-series-s3-backend"
```

là dùng DynamoDB table để lock state.

Nhưng hiện tại, `dynamodb_table` bị đánh dấu **deprecated** trong S3 backend. Terraform docs nói DynamoDB-based locking sẽ bị loại bỏ trong một minor version tương lai, và khuyến nghị dùng `use_lockfile` thay thế.

Vì vậy, nếu bạn học theo bài Viblo, nên sửa tư duy như sau:

```
Cũ:
S3 lưu state + DynamoDB lock

Mới:
S3 lưu state + S3 lock file
```

### S3 Bucket nên cấu hình gì?

Một S3 bucket dùng làm Terraform backend nên có ít nhất:

#### Versioning

Nên bật versioning để có thể khôi phục state nếu bị lỗi hoặc ghi sai.

```
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

Terraform docs cũng khuyến nghị bật S3 Bucket Versioning để phục hồi state khi có xóa nhầm hoặc lỗi do con người.

#### Encryption

Nên bật server-side encryption.

```
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

Hoặc dùng KMS:

```
resource "aws_kms_key" "tfstate" {
  description = "KMS key for Terraform state"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
  }
}
```

Nếu dùng KMS key riêng cho S3 backend, Terraform cần các quyền KMS như `kms:Encrypt`, `kms:Decrypt`, và `kms:GenerateDataKey`.

### IAM permission cần cho S3 backend

Nếu không dùng workspace phức tạp, quyền cơ bản cần có là:

```
{
  "Version":"2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action":"s3:ListBucket",
      "Resource":"arn:aws:s3:::my-terraform-state-bucket"
    },
    {
      "Effect":"Allow",
      "Action": [
"s3:GetObject",
"s3:PutObject"
      ],
      "Resource":"arn:aws:s3:::my-terraform-state-bucket/environments/development/terraform.tfstate"
    },
    {
      "Effect":"Allow",
      "Action": [
"s3:GetObject",
"s3:PutObject",
"s3:DeleteObject"
      ],
      "Resource":"arn:aws:s3:::my-terraform-state-bucket/environments/development/terraform.tfstate.tflock"
    }
  ]
}
```

Terraform docs nói khi dùng `use_lockfile`, lock file cần quyền `s3:GetObject`, `s3:PutObject`, và `s3:DeleteObject`; còn state file chính không cần `s3:DeleteObject` vì Terraform không xóa state file.

### Quy trình tạo S3 Backend

Có một điểm rất quan trọng: **backend phải tồn tại trước khi Terraform dùng nó**.

Tức là bạn không thể vừa khai báo backend S3, vừa mong Terraform tự dùng chính backend đó khi nó chưa được tạo.

Thường sẽ có 2 bước:

#### Bước 1: Bootstrap backend infrastructure

Tạo trước:

```
S3 bucket
Versioning
Encryption
IAM policy/role
```

Ban đầu bước này có thể dùng local state.

#### Bước 2: Dùng backend đó cho project thật

Sau khi bucket đã có, trong project chính bạn khai báo:

```
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "dev/app/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Sau đó chạy:

```
terraform init
```

Nếu trước đó bạn đang có local state, Terraform có thể hỏi có muốn migrate state lên backend mới không.

### Phân tách state theo môi trường

Không nên để tất cả môi trường dùng chung một state file.

Ví dụ nên tách:

```
dev/app/terraform.tfstate
staging/app/terraform.tfstate
prod/app/terraform.tfstate
```

Tương ứng:

```
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "dev/app/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

AWS cũng khuyến nghị tách backend theo từng environment để giảm phạm vi ảnh hưởng, hạn chế lỗi ở development/test ảnh hưởng production, và kiểm soát quyền production chặt hơn.

### Tóm tắt dễ nhớ

```
S3 backend = lưu Terraform state trên S3
state file = terraform.tfstate
locking = ngăn nhiều người/pipeline ghi state cùng lúc
KMS/encryption = bảo vệ nội dung state
versioning = khôi phục state khi bị lỗi
IAM = kiểm soát ai được đọc/ghi state
```

So sánh cách cũ và cách mới:

| Nội dung | Cách cũ trong bài Viblo | Cách hiện tại nên dùng |
| --- | --- | --- |
| Lưu state | S3 | S3 |
| Lock state | DynamoDB | S3 lockfile |
| Config locking | `dynamodb_table` | `use_lockfile = true` |
| Trạng thái | Legacy/deprecated | Recommended |
| Có cần DynamoDB không? | Có | Không bắt buộc |

Cấu hình nên nhớ nhất hiện tại:

```
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "environments/development/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Nói ngắn gọn: **bài Viblo vẫn đúng về ý tưởng S3 backend, nhưng phần DynamoDB locking đã cũ. Hiện tại nên dùng S3 backend với `use_lockfile = true` để vừa lưu remote state, vừa lock state an toàn hơn và đơn giản hơn.**

## Remote Backend với Terraform Cloud - HCP Terraform cloud integration

**Remote backend** là cách đưa Terraform state lên một hệ thống remote thay vì lưu ở máy local.

Với Terraform Cloud/HCP Terraform, state không còn nằm trong file local:

```
terraform.tfstate
```

mà được lưu trong **workspace** trên HCP Terraform.

Có thể hiểu đơn giản:

```
Local machine
    ↓ chạy terraform plan/apply
HCP Terraform
    ↓ quản lý run, state, variables, credentials
Cloud provider như AWS/Azure/GCP
```

HCP Terraform cho phép Terraform CLI kết nối với workspace trên cloud. Khi dùng CLI-driven workflow, các lệnh như `terraform plan` và `terraform apply` mặc định được thực thi trong môi trường remote của HCP Terraform, sau đó log được stream về terminal local.

### Terraform Cloud/HCP Terraform giúp gì?

Terraform Cloud/HCP Terraform không chỉ lưu state. Nó còn hỗ trợ:

| Chức năng | Ý nghĩa |
| --- | --- |
| Remote state | Lưu state tập trung trong workspace |
| State history | Lưu lịch sử state version |
| Remote run | Chạy `plan` / `apply` trên môi trường remote |
| Variable management | Quản lý biến và credentials trong workspace |
| Team collaboration | Nhiều người cùng quản lý infrastructure |
| Run history | Lưu lịch sử các lần plan/apply |
| Policy / cost estimation | Hỗ trợ kiểm soát policy và ước tính chi phí tùy plan/tính năng |

Theo tài liệu HashiCorp, workspace trong HCP Terraform chứa state, variables, credentials/secrets, run history và các thông tin cần thiết để quản lý một nhóm infrastructure resource.

### Có 3 workflow chính

Terraform Cloud có 3 cách sử dụng:

```
Version Control Workflow
CLI-driven Workflow
API-driven Workflow
```

Ý nghĩa:

| Workflow | Cách hoạt động |
| --- | --- |
| Version Control Workflow | Kết nối workspace với GitHub/GitLab/Bitbucket. Khi push code hoặc tạo PR, Terraform Cloud tự chạy plan/apply theo workflow |
| CLI-driven Workflow | Bạn vẫn chạy `terraform plan`, `terraform apply` từ terminal, nhưng run có thể được thực thi trên HCP Terraform |
| API-driven Workflow | Gọi API để upload config, tạo run, trigger workflow |

Trong bài này, tác giả dùng **CLI-driven workflow** để demo remote backend. Đây cũng là workflow mà tài liệu HCP Terraform mô tả khi dùng Terraform CLI với HCP Terraform.

### Cấu hình hiện tại nên dùng: `cloud` block

Với Terraform version **1.1 trở lên**, nên dùng `cloud` block:

```
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      name = "my-workspace"
    }
  }
}
```

Trong đó:

```
organization = "my-org"
```

là tên organization trên HCP Terraform.

```
workspaces {
  name = "my-workspace"
}
```

là workspace Terraform sẽ liên kết tới.

Tài liệu HashiCorp nói `cloud` block được dùng để kết nối Terraform CLI với HCP Terraform. Sau khi thêm hoặc thay đổi `cloud` block, bạn cần chạy lại `terraform init`.

### `cloud` block khác gì `backend "remote"`?

Đây là điểm quan trọng.

Bài Viblo gọi đây là **remote backend**, nhưng code trong bài dùng:

```
terraform {
  cloud {
    organization = "HPI"

    workspaces {
      name = "terraform-series-remote-backend"
    }
  }
}
```

Cách này là **HCP Terraform cloud integration**, không phải dạng backend block truyền thống như:

```
terraform {
  backend "remote" {
    organization = "my-org"

    workspaces {
      name = "my-workspace"
    }
  }
}
```

Theo tài liệu hiện tại, `backend "remote"` được giới thiệu từ Terraform v0.11.13, nhưng từ Terraform v1.1.0 trở lên HashiCorp khuyến nghị dùng **HCP Terraform cloud integration** bằng `cloud` block thay vì `remote backend`.

Tóm tắt:

```
Terraform >= 1.1
→ nên dùng cloud block

Terraform cũ hơn 1.1
→ có thể dùng backend "remote"
```

### Quy trình dùng HCP Terraform với CLI-driven workflow

Quy trình cơ bản như sau:

```
1. Tạo tài khoản HCP Terraform
2. Tạo organization
3. Tạo workspace
4. Thêm cloud block vào code Terraform
5. Chạy terraform login
6. Chạy terraform init
7. Cấu hình variables / credentials trong workspace
8. Chạy terraform plan / apply
```

Ví dụ file `main.tf`:

```
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      name = "dev-networking"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_s3_bucket" "example" {
  bucket = "my-example-bucket-123456"
}
```

Sau đó login:

```
terraform login
```

Lệnh này dùng để tạo và lưu token giúp Terraform CLI xác thực với HCP Terraform. Tài liệu HashiCorp cũng khuyến nghị dùng `terraform login` để cung cấp credential truy cập HCP Terraform.

Tiếp theo chạy:

```
terraform init
```

Sau khi init thành công, chạy:

```
terraform plan
terraform apply
```

### Vì sao trong bài bị lỗi AWS credential?

Trong bài Viblo, sau khi chạy `terraform plan`, Terraform báo lỗi vì không tìm thấy AWS credential.

Lý do là: khi dùng remote execution, Terraform không chạy hoàn toàn trên máy local nữa. Nó chạy trong môi trường remote của Terraform Cloud/HCP Terraform. Vì vậy, AWS credential trên máy local của bạn không tự động có trong môi trường remote. Bài Viblo cũng giải thích rằng credential cần được cấu hình trên Terraform Cloud.

Ví dụ nếu dùng AWS access key tĩnh, bạn có thể khai báo trong workspace variables:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Hai biến này nên để kiểu:

```
Environment variable
Sensitive = true
```

HCP Terraform hỗ trợ cả **Terraform variables** và **environment variables**. Environment variables thường dùng để lưu provider credentials như AWS, Azure, Google Cloud.

### Cách hiện đại hơn: Dynamic Provider Credentials

Trong bài Viblo, tác giả dùng static credentials:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Cách này vẫn có thể dùng, nhưng về security thì hiện nay nên ưu tiên **dynamic provider credentials** nếu có thể.

Với AWS, HCP Terraform hỗ trợ OIDC để lấy temporary credentials cho từng run. Cách này giúp tránh lưu access key dài hạn, giảm nhu cầu rotate secret thủ công, và credential chỉ có hiệu lực trong thời gian plan/apply.

So sánh:

| Cách | Đặc điểm |
| --- | --- |
| Static credentials | Lưu `AWS_ACCESS_KEY_ID` và `AWS_SECRET_ACCESS_KEY` trong workspace |
| Dynamic credentials | HCP Terraform dùng OIDC để assume IAM role trên AWS |
| Nên dùng cho học/lab | Static credentials có thể dễ hơn |
| Nên dùng cho production | Dynamic credentials an toàn hơn |

Trong bài cũ, cách phổ biến là khai báo:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

trong Terraform Cloud workspace.

Cách này vẫn chạy được, nhưng ý tưởng mới hơn là dùng **dynamic provider credentials** qua OIDC. HCP Terraform có thể dùng OIDC để assume AWS IAM role và tạo temporary credentials cho từng lần plan/apply. Credential chỉ có hiệu lực trong thời gian run.

Với AWS, workspace cần các environment variables kiểu:

```
TFC_AWS_PROVIDER_AUTH = true
TFC_AWS_RUN_ROLE_ARN = arn:aws:iam::<account-id>:role/<role-name>
AWS_REGION = ap-southeast-1
```

Hoặc tách quyền plan/apply riêng:

```
TFC_AWS_PLAN_ROLE_ARN
TFC_AWS_APPLY_ROLE_ARN
```

HashiCorp ghi rõ `TFC_AWS_PROVIDER_AUTH=true` là biến bắt buộc để HCP Terraform thử authenticate với AWS, và `TFC_AWS_RUN_ROLE_ARN` là role ARN mà HCP Terraform sẽ assume.

### Workspace trong HCP Terraform là gì?

Workspace trong HCP Terraform là nơi quản lý một nhóm infrastructure.

Một workspace thường chứa:

```
Terraform configuration
Variables
Credentials/secrets
State
Run history
```

Điểm dễ nhầm là **HCP Terraform workspace** khác với **Terraform CLI workspace**.

Terraform CLI workspace thường là các workspace như:

```
terraform workspace new dev
terraform workspace select prod
```

Còn HCP Terraform workspace là một đối tượng trên nền tảng HCP Terraform, có state, variables, quyền truy cập, run history và cấu hình riêng. Tài liệu HashiCorp nhấn mạnh hai khái niệm này có cùng tên nhưng hoạt động khác nhau.

### Khi chạy `terraform plan`, chuyện gì xảy ra?

Nếu workspace bật remote operations, luồng hoạt động sẽ như sau:

```
Bạn chạy terraform plan ở terminal
        ↓
Terraform CLI gửi configuration lên HCP Terraform
        ↓
HCP Terraform chạy plan trên remote worker
        ↓
Log được stream về terminal
        ↓
State vẫn được quản lý trong workspace
```

Điểm quan trọng: nếu bạn bấm `Ctrl + C`, thường bạn chỉ dừng việc stream log về terminal, còn run remote có thể vẫn tiếp tục chạy trên HCP Terraform. Bài Viblo cũng lưu ý điểm này, và tài liệu HashiCorp xác nhận CLI-driven workflow chạy plan/apply trong môi trường remote, sau đó stream output về local terminal.

### Remote execution và local execution

HCP Terraform có thể hoạt động theo hai kiểu:

| Execution mode | Ý nghĩa |
| --- | --- |
| Remote execution | `plan` / `apply` chạy trên HCP Terraform |
| Local execution | `plan` / `apply` chạy trên máy local, HCP Terraform chủ yếu lưu state |

Mặc định với CLI-driven workflow, các operation như `plan` và `apply` được thực thi remote. Tuy nhiên workspace cũng có thể cấu hình local execution; khi đó HCP Terraform hoạt động giống một backend lưu state tiêu chuẩn.

### Ý tưởng governance mới: policy-as-code

Với team hoặc production, HCP Terraform không chỉ chạy `plan/apply`, mà còn có thể kiểm tra policy trước khi apply.

Ví dụ policy có thể bắt buộc:

```
Không được tạo S3 public
Không được tạo resource thiếu tag
Không được deploy production ngoài region cho phép
Không được mở Security Group 0.0.0.0/0 vào port nhạy cảm
```

HCP Terraform hỗ trợ policy-as-code bằng Sentinel và Open Policy Agent, áp dụng policy set vào organization, project hoặc workspace; mỗi run sẽ được kiểm tra Terraform plan trước khi apply.

### Nếu infrastructure nằm trong private network

Nếu resource của bạn nằm trong private network hoặc on-premises, ý tưởng mới là dùng **HCP Terraform Agent**.

Mô hình:

```
HCP Terraform
     ↓
Agent Pool
     ↓
Agent chạy trong private network
     ↓
Private AWS/VPC/on-prem resources
```

Agent pool cho phép HCP Terraform giao tiếp với isolated, private hoặc on-premises infrastructure. Khi workspace hoặc Stack dùng agent execution mode, agent trong pool sẽ thực hiện run.

### Ý tưởng mới nhất ở mức lớn hơn: Stacks

Nếu project lớn, có nhiều component và nhiều environment, HCP Terraform có thêm khái niệm **Stacks**.

Stacks cho phép tách Terraform configuration thành nhiều component, rồi deploy và quản lý các component đó qua nhiều environment. Đây là cách tổ chức cao hơn workspace truyền thống, dùng khi infrastructure phức tạp và cần rollout theo nhiều deployment.

Ví dụ ý tưởng:

```
Stack: xbrain-platform

Components:
  networking
  database
  ecs
  cloudfront
  monitoring

Deployments:
  dev
  staging
  prod
```

### So sánh S3 backend và HCP Terraform backend

| Tiêu chí | S3 Backend | HCP Terraform / Terraform Cloud |
| --- | --- | --- |
| Lưu state | S3 bucket | HCP Terraform workspace |
| Locking | S3 lockfile hoặc cơ chế backend hỗ trợ | Managed bởi HCP Terraform |
| Quản lý variables | Tự quản lý qua local/env/CI/CD | Quản lý trực tiếp trong workspace |
| Credentials | Tự cấu hình trong máy/CI/CD | Lưu trong workspace hoặc dùng dynamic credentials |
| Run history | Không có sẵn như HCP Terraform | Có run history |
| UI quản lý | Chủ yếu qua AWS S3 | Có UI workspace, state, runs, variables |
| Phù hợp | Team dùng AWS, muốn tự kiểm soát backend | Team muốn quản lý Terraform tập trung và có governance |

### Ghi nhớ nhanh

```
Local backend
→ state nằm trên máy local

S3 backend
→ state nằm trong S3 bucket

HCP Terraform / Terraform Cloud
→ state nằm trong workspace
→ có thể chạy plan/apply remote
→ quản lý variables, credentials, run history, team access
```

Cấu hình nên nhớ:

```
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      name = "my-workspace"
    }
  }
}
```

Sau đó:

```
terraform login
terraform init
terraform plan
terraform apply
```

## Locking

**Locking** trong Terraform thường là **state locking**.

Nó có nghĩa là: khi Terraform đang chạy một thao tác có thể ghi/sửa state, ví dụ `apply`, Terraform sẽ **khóa state lại** để người khác hoặc process khác không thể ghi vào cùng state đó cùng lúc. Mục đích là tránh làm hỏng hoặc ghi đè `terraform.tfstate`.

Ví dụ dễ hiểu:

```
User A chạy terraform apply
→ Terraform khóa state

User B cũng chạy terraform apply cùng lúc
→ Terraform không cho ghi state
→ phải chờ hoặc báo lỗi lock
```

### Vì sao cần locking?

Terraform state là “bộ nhớ” của Terraform. Nếu 2 người cùng `apply` một lúc vào cùng state, có thể xảy ra lỗi như:

```
Người A tạo resource A
Người B xóa hoặc sửa resource B
Cả hai cùng ghi terraform.tfstate
→ state bị sai, thiếu hoặc conflict
```

Vì vậy locking giúp đảm bảo tại một thời điểm chỉ có **một Terraform process** được phép ghi state.

### Locking hoạt động khi nào?

Terraform tự động lock state cho các operation có thể ghi state. Bạn thường không cần gọi lệnh lock thủ công. Nếu backend hỗ trợ locking, Terraform sẽ tự dùng locking khi cần.

Ví dụ các lệnh thường cần lock:

```
terraform apply
terraform destroy
terraform import
terraform statemv
terraform staterm
```

`terraform plan` cũng có thể cần lock nếu có refresh state.

### Với S3 backend thì bật locking như thế nào?

Với backend `s3`, state locking là tính năng **opt-in**, tức là phải bật lên. Cách hiện tại là dùng:

```
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "dev/terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = true
  }
}
```

`use_lockfile = true` sẽ bật S3 state locking bằng lock file. Lock file thường có dạng:

```
dev/terraform.tfstate.tflock
```

Terraform docs hiện ghi rằng S3 backend hỗ trợ locking bằng `use_lockfile`; DynamoDB-based locking vẫn tồn tại để migration nhưng đã bị deprecated và sẽ bị gỡ trong một minor version tương lai.

### IAM permission cần thêm khi dùng S3 locking

Nếu bật:

```
use_lockfile = true
```

thì IAM role/user chạy Terraform cần quyền với file `.tflock`:

```
{
  "Effect":"Allow",
  "Action": [
"s3:GetObject",
"s3:PutObject",
"s3:DeleteObject"
  ],
  "Resource":"arn:aws:s3:::my-terraform-state-bucket/dev/terraform.tfstate.tflock"
}
```

Terraform cần `GetObject`, `PutObject`, và `DeleteObject` trên lock file khi `use_lockfile` được bật. Với state file chính thì thường cần `GetObject` và `PutObject`, còn `DeleteObject` không cần thiết cho state file chính.

### Khi bị lỗi lock thì sao?

Bạn có thể gặp lỗi kiểu:

```
Error acquiring the state lock
```

Nghĩa là có process khác đang giữ lock, hoặc lần chạy trước bị lỗi khiến lock chưa được giải phóng.

Cách xử lý đúng thường là:

```
terraform apply-lock-timeout=5m
```

Lệnh này bảo Terraform chờ tối đa 5 phút để lấy lock trước khi báo lỗi. `terraform apply` hỗ trợ `-lock-timeout=DURATION`, ví dụ `3s`, `5m`, để retry lấy lock trong một khoảng thời gian.

Không nên dùng:

```
terraform apply-lock=false
```

Vì nó tắt state locking. Terraform docs cảnh báo đây là nguy hiểm nếu có người/process khác cũng đang thao tác cùng workspace/state.

### Force unlock là gì?

Nếu Terraform bị crash hoặc pipeline bị kill giữa chừng, lock có thể bị kẹt. Khi đó có thể dùng:

```
terraform force-unlock <LOCK_ID>
```

Nhưng chỉ nên dùng khi chắc chắn không còn ai đang chạy Terraform. HashiCorp cảnh báo `force-unlock` có thể gây nhiều writer cùng lúc nếu unlock nhầm lock của người khác. Terraform yêu cầu `LOCK_ID` để tránh unlock sai lock.

### Tóm tắt dễ nhớ

```
backend = nơi lưu state
state   = file ghi nhớ infrastructure
locking = khóa state để tránh nhiều người cùng ghi
```

Với AWS S3 backend hiện nên dùng:

```
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "dev/terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = true
  }
}
```

Nói ngắn gọn: **locking bảo vệ state file khỏi bị ghi đồng thời**, đặc biệt quan trọng khi làm việc nhóm hoặc chạy Terraform qua CI/CD.

## Lưu ý quan trọng

Sau khi thêm hoặc sửa backend, bạn phải chạy lại:

```
terraform init
```

Terraform cần `init` để cấu hình backend trước khi chạy `plan`, `apply`, hoặc thao tác với state.

Một configuration chỉ được khai báo **một backend block**. Backend block cũng không được dùng biến như `var.bucket_name`, `local.name`, hoặc data source attribute bên trong.

Không nên hardcode credential trong backend config. HashiCorp khuyến nghị dùng environment variables hoặc cơ chế credential mặc định của cloud provider, vì backend config có thể được lưu trong thư mục `.terraform` hoặc plan file.

## Tóm tắt dễ nhớ

```
provider = dùng cloud/service nào để tạo resource
resource = tạo cái gì
state    = Terraform ghi nhớ cái gì đã tạo
backend  = state được lưu ở đâu
```

Ví dụ trong AWS:

```
AWS provider  -> tạo EC2, VPC, S3, ECS...
Terraform state -> ghi nhớ các resource đã tạo
S3 backend    -> lưu file state vào S3
```

Nên dùng backend remote như S3 khi làm project thật hoặc làm việc nhóm. Backend local chỉ phù hợp học thử, lab nhỏ, hoặc làm một mình trên máy cá nhân.
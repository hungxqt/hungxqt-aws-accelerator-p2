# Functional programming

## Functional programming trong Terraform là gì?

Terraform chủ yếu là công cụ **declarative Infrastructure as Code**: ta mô tả trạng thái mong muốn của hạ tầng, Terraform sẽ tự tính toán cách tạo, sửa hoặc xoá tài nguyên.

Tuy nhiên, trong Terraform ta vẫn có thể “lập trình” ở mức cấu hình bằng cách dùng:

- **Input variables** để truyền tham số.
- **Output values** để in ra kết quả sau khi tạo tài nguyên.
- **Functions** để xử lý chuỗi, danh sách, map, file.
- **Expressions** để biến đổi dữ liệu.
- **`count` / `for_each`** để tạo nhiều resource động.
- **`for` expressions** để duyệt và tạo list/map mới.
- **`locals`** để khai báo giá trị dùng lại nhiều lần.

Mục tiêu chính là giúp code Terraform **linh hoạt hơn, ít lặp lại hơn, dễ tái sử dụng hơn**.

## Input Variables

### Variable dùng để làm gì?

Ban đầu, nếu cấu hình EC2 bị gán cứng như sau:

```
resource "aws_instance" "hello" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
}
```

thì muốn đổi `instance_type`, ta phải sửa trực tiếp file `.tf`. Cách này không linh hoạt. Vì vậy Terraform cho phép khai báo **input variable** để truyền giá trị từ bên ngoài vào.

Ví dụ:

```
variable "instance_type" {
  type        = string
  description = "Instance type of the EC2"
}
```

Sau đó dùng trong resource:

```
resource "aws_instance" "hello" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}
```

Cú pháp truy cập biến:

```
var.<VARIABLE_NAME>
```

Ví dụ:

```
var.instance_type
```

### Kiểu dữ liệu của variable

Terraform hỗ trợ các kiểu dữ liệu cơ bản và phức tạp. Trong bài viết, các kiểu được nhắc đến gồm: `string`, `number`, `bool`, `list`, `set`, `map`, `object`, `tuple`.

Nhóm cơ bản:

```
string
number
bool
```

Nhóm phức tạp:

```
list()
set()
map()
object()
tuple()
```

Ví dụ:

```
variable "instance_type" {
  type = string
}
```

## Gán giá trị cho variable

Terraform có thể đọc giá trị variable từ file `terraform.tfvars`.

Ví dụ file `terraform.tfvars`:

```
instance_type = "t2.micro"
```

Khi chạy:

```
terraform apply
```

Terraform sẽ tự động load file `terraform.tfvars`.

Nếu muốn dùng file variable khác, ví dụ `production.tfvars`, ta có thể chạy:

```
terraform apply-var-file="production.tfvars"
```

Ví dụ file `production.tfvars`:

```
instance_type = "t3.small"
```

Cách này rất hữu ích khi có nhiều môi trường như:

```
development
staging
production
```

Mỗi môi trường có thể dùng một file `.tfvars` riêng.

## Validate variable

Terraform cho phép kiểm tra giá trị đầu vào của variable bằng block `validation`.

Ví dụ:

```
variable "instance_type" {
  type        = string
  description = "Instance type of the EC2"

  validation {
    condition     = contains(["t2.micro", "t3.small"], var.instance_type)
    error_message = "Value not allow."
  }
}
```

Ý nghĩa:

```
contains(["t2.micro", "t3.small"], var.instance_type)
```

dùng để kiểm tra `var.instance_type` có nằm trong danh sách được cho phép hay không. Nếu người dùng nhập giá trị khác, Terraform sẽ báo lỗi khi chạy `terraform plan` hoặc `terraform apply`.

Ví dụ sai:

```
instance_type = "t3.micro"
```

Vì `"t3.micro"` không nằm trong danh sách:

```
["t2.micro", "t3.small"]
```

nên Terraform sẽ báo lỗi.

## Output values

### Output dùng để làm gì?

`output` dùng để in ra giá trị sau khi Terraform tạo hoặc cập nhật hạ tầng.

Ví dụ sau khi tạo EC2, ta muốn lấy public IP:

```
output "ec2" {
  value = {
    public_ip = aws_instance.hello.public_ip
  }
}
```

Sau khi chạy `terraform apply`, Terraform sẽ in giá trị output ra terminal. Trong bài viết, output được dùng để hiển thị public IP của EC2 sau khi resource được tạo.

## Count parameter

### Vấn đề

Nếu muốn tạo 2 EC2, ta có thể copy resource block:

```
resource "aws_instance" "hello1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}

resource "aws_instance" "hello2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}
```

Nhưng nếu cần tạo 10, 50 hoặc 100 EC2 thì không thể copy thủ công như vậy.

### Dùng `count`

`count` là một **meta-argument** của Terraform, nghĩa là nó không thuộc riêng provider AWS mà là cú pháp chung của Terraform. Nó có thể được dùng trong nhiều loại resource block khác nhau.

Ví dụ tạo 5 EC2:

```
resource "aws_instance" "hello" {
  count         = 5
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}
```

Khi dùng `count`, Terraform sẽ tạo ra nhiều instance của cùng một resource.

Cách truy cập từng resource:

```
aws_instance.hello[0]
aws_instance.hello[1]
aws_instance.hello[2]
```

Ví dụ output:

```
output "ec2" {
  value = {
    public_ip1 = aws_instance.hello[0].public_ip
    public_ip2 = aws_instance.hello[1].public_ip
    public_ip3 = aws_instance.hello[2].public_ip
    public_ip4 = aws_instance.hello[3].public_ip
    public_ip5 = aws_instance.hello[4].public_ip
  }
}
```

Nhược điểm là phần output vẫn bị lặp. Vì vậy bài viết chuyển sang dùng `for expressions`.

## For each

`for_each` trong Terraform là một **meta-argument** dùng để tạo nhiều resource/module giống cấu trúc nhau nhưng có định danh riêng, thay vì phải viết nhiều block lặp lại. Terraform hỗ trợ `for_each` với **map** hoặc **set of strings**, và mỗi phần tử sẽ tạo ra một instance riêng của resource/module đó.

### Hiểu đơn giản

Thay vì viết 3 resource như này:

```
resource "aws_s3_bucket" "bucket_1" {
  bucket = "app-dev-data"
}

resource "aws_s3_bucket" "bucket_2" {
  bucket = "app-dev-logs"
}

resource "aws_s3_bucket" "bucket_3" {
  bucket = "app-dev-backup"
}
```

Ta có thể dùng `for_each`:

```
resource "aws_s3_bucket" "this" {
  for_each = toset(["data", "logs", "backup"])

  bucket = "app-dev-${each.key}"
}
```

Terraform sẽ tạo ra:

```
aws_s3_bucket.this["data"]
aws_s3_bucket.this["logs"]
aws_s3_bucket.this["backup"]
```

### Cú pháp cơ bản

```
resource "resource_type" "resource_name" {
  for_each = <map hoặc set>

  name = each.key
}
```

Bên trong block có 2 biến đặc biệt:

| Biến | Ý nghĩa |
| --- | --- |
| `each.key` | Key của phần tử hiện tại |
| `each.value` | Value của phần tử hiện tại |

Ví dụ với **map**:

```
resource "aws_s3_bucket" "this" {
  for_each = {
    data   = "Data bucket"
    logs   = "Log bucket"
    backup = "Backup bucket"
  }

  bucket = "my-app-${each.key}"

  tags = {
    Name        = each.key
    Description = each.value
  }
}
```

Ở đây:

```
each.key   = data, logs, backup
each.value = Data bucket, Log bucket, Backup bucket
```

### `for_each` với map object

Đây là cách dùng thực tế hơn, vì mỗi resource có thể có cấu hình riêng.

Ví dụ tạo nhiều subnet:

```
variable "private_subnets" {
  default = {
    private_1 = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "ap-southeast-1a"
    }

    private_2 = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "ap-southeast-1b"
    }
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = each.key
  }
}
```

Terraform sẽ tạo:

```
aws_subnet.private["private_1"]
aws_subnet.private["private_2"]
```

Điểm mạnh ở đây là mỗi subnet có thể có `cidr_block`, `availability_zone`, tag khác nhau.

### So sánh `for_each` với `count`

| Tiêu chí | `count` | `for_each` |
| --- | --- | --- |
| Dựa trên | Số lượng | Map hoặc set |
| Định danh resource | Index: `[0]`, `[1]`, `[2]` | Key: `["private_1"]`, `["private_2"]` |
| Phù hợp khi | Resource giống nhau nhiều | Resource có tên/cấu hình riêng |
| Độ ổn định | Dễ bị ảnh hưởng khi đổi thứ tự list | Ổn định hơn vì dùng key |
| Truy cập | `count.index` | `each.key`, `each.value` |

Ví dụ với `count`:

```
resource "aws_subnet" "private" {
  count = 2

  cidr_block = var.private_subnet_cidrs[count.index]
}
```

Ví dụ với `for_each`:

```
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  cidr_block = each.value.cidr_block
}
```

Nên dùng `for_each` khi mỗi resource cần một tên/key rõ ràng, ví dụ subnet theo AZ, IAM user theo username, security group rule theo tên rule, hoặc route table association theo subnet. Terraform cũng nêu rằng mỗi instance tạo bởi `for_each` được Terraform tạo, cập nhật hoặc xóa riêng biệt khi apply.

## For expressions

### For expression dùng để làm gì?

`for` expression cho phép duyệt qua list, set hoặc map để tạo ra một list/map mới.

Cú pháp cơ bản:

```
[for <value> in <list> : <return_value>]
```

Ví dụ:

```
[for s in var.words : upper(s)]
```

Ý nghĩa: duyệt từng phần tử trong `var.words`, sau đó chuyển từng phần tử thành chữ hoa bằng hàm `upper()`.

### Dùng `for` để lấy public IP của nhiều EC2

Thay vì viết:

```
public_ip1 = aws_instance.hello[0].public_ip
public_ip2 = aws_instance.hello[1].public_ip
public_ip3 = aws_instance.hello[2].public_ip
```

ta có thể viết:

```
output "ec2" {
  value = {
    public_ip = [for v in aws_instance.hello : v.public_ip]
  }
}
```

Kết quả là `public_ip` sẽ là một list chứa public IP của tất cả EC2.

## Format function

### `format()` dùng để làm gì?

`format()` dùng để tạo chuỗi theo định dạng mong muốn.

Ví dụ trong bài:

```
output "ec2" {
  value = {
    for i, v in aws_instance.hello :
    format("public_ip%d", i + 1) => v.public_ip
  }
}
```

Ý nghĩa:

- `i` là index.
- `v` là từng EC2 instance.
- `format("public_ip%d", i + 1)` tạo key dạng `public_ip1`, `public_ip2`, `public_ip3`, ...
- `v.public_ip` là giá trị public IP tương ứng.

Kết quả output có dạng:

```
ec2 = {
  public_ip1 = "..."
  public_ip2 = "..."
  public_ip3 = "..."
}
```

Hàm `format()` giúp tạo key động thay vì phải viết thủ công từng dòng.

## File function

### `file()` dùng để làm gì?

`file()` dùng để đọc nội dung từ một file bên ngoài và đưa nội dung đó vào Terraform config.

Trong bài viết, ví dụ S3 bucket có phần policy JSON khá dài. Nếu nhúng trực tiếp JSON vào `main.tf`, file Terraform sẽ khó đọc. Vì vậy ta có thể tách policy ra file riêng, ví dụ:

```
s3_static_policy.json
```

Sau đó dùng:

```
policy = file("s3_static_policy.json")
```

Ý nghĩa: Terraform đọc nội dung file `s3_static_policy.json` và gán vào thuộc tính `policy`.

Cách này giúp file `.tf` gọn hơn, đặc biệt khi policy JSON dài.

## Fileset function

### `fileset()` dùng để làm gì?

`fileset()` dùng để lấy danh sách file trong một thư mục theo pattern.

Ví dụ thư mục:

```
.
├── index.html
├── index.css
```

Khi dùng:

```
fileset(path.module, "*")
```

Terraform sẽ lấy danh sách các file phù hợp với pattern. Trong bài, `fileset()` được dùng để lấy toàn bộ file trong thư mục `static-web` và upload lên S3.

Ví dụ:

```
resource "aws_s3_bucket_object" "object" {
  for_each = fileset(path.module, "static-web/**/*")

  bucket = aws_s3_bucket.static.id
  key    = replace(each.value, "static-web", "")
  source = each.value

  etag         = filemd5("${each.value}")
  content_type = lookup(
    local.mime_types,
    split(".", each.value)[length(split(".", each.value)) - 1]
  )
}
```

Ý nghĩa tổng quát:

- `fileset(path.module, "static-web/**/*")`: lấy tất cả file trong thư mục `static-web`.
- `for_each`: tạo một object S3 cho từng file.
- `each.value`: đại diện cho từng file đang được duyệt.
- `replace(each.value, "static-web", "")`: bỏ phần tiền tố `static-web` khỏi key trên S3.
- `filemd5(each.value)`: tính hash MD5 của file để Terraform biết file có thay đổi hay không.
- `lookup(...)`: tìm content type tương ứng với phần mở rộng file.
- `split(".", each.value)`: tách tên file theo dấu `.` để lấy extension.

## Local values

### `locals` dùng để làm gì?

`locals` dùng để khai báo giá trị nội bộ trong Terraform config. Giá trị này có thể được tái sử dụng nhiều lần trong cùng module.

Ví dụ:

```
locals {
  one  = 1
  two  = 2
  name = "max"
  flag = true
}
```

Cách truy cập:

```
local.name
local.flag
```

Khác với `variable`, `locals` không cần khai báo `type`. Ta gán thẳng giá trị cho nó. Trong bài viết, `locals` được dùng để khai báo map `mime_types`, giúp ánh xạ extension của file sang content type tương ứng.

Ví dụ:

```
locals {
  mime_types = {
    html  = "text/html"
    css   = "text/css"
    js    = "application/javascript"
    json  = "application/json"
    jpg   = "image/jpeg"
    png   = "image/png"
    svg   = "image/svg+xml"
  }
}
```

Sau đó dùng:

```
content_type = lookup(
  local.mime_types,
  split(".", each.value)[length(split(".", each.value)) - 1]
)
```

Ý nghĩa: lấy extension của file, sau đó tìm content type tương ứng trong `local.mime_types`.

## Tổng hợp các hàm / cú pháp quan trọng trong bài

| Thành phần | Công dụng |
| --- | --- |
| `var.<name>` | Truy cập input variable |
| `terraform.tfvars` | File mặc định để gán giá trị cho variable |
| `-var-file` | Chỉ định file variable khác |
| `validation` | Kiểm tra giá trị đầu vào của variable |
| `contains()` | Kiểm tra một giá trị có nằm trong list hay không |
| `output` | In giá trị sau khi apply |
| `count` | Tạo nhiều bản sao của cùng một resource |
| `[index]` | Truy cập resource được tạo bằng `count` |
| `for` expression | Duyệt list/map/set để tạo dữ liệu mới |
| `format()` | Tạo chuỗi theo định dạng |
| `file()` | Đọc nội dung từ file ngoài |
| `fileset()` | Lấy danh sách file theo pattern |
| `for_each` | Tạo resource theo từng phần tử trong map/set |
| `each.value` | Giá trị hiện tại trong vòng lặp `for_each` |
| `replace()` | Thay thế chuỗi |
| `filemd5()` | Tính MD5 của file |
| `lookup()` | Tìm giá trị trong map |
| `split()` | Tách chuỗi thành list |
| `length()` | Lấy độ dài list/string |
| `locals` | Khai báo giá trị nội bộ dùng lại trong module |
| `local.<key>` | Truy cập local value |

## Ý chính cần nhớ

Terraform không chỉ là viết resource cố định. Ta có thể dùng **variables, expressions, functions và loops** để cấu hình linh hoạt hơn.

`variable` giúp truyền tham số từ bên ngoài vào Terraform.

`terraform.tfvars` giúp tách giá trị cấu hình khỏi code chính.

`validation` giúp kiểm soát giá trị đầu vào, tránh cấu hình sai.

`output` giúp lấy thông tin sau khi hạ tầng được tạo, ví dụ public IP của EC2.

`count` giúp tạo nhiều resource giống nhau mà không cần copy-paste.

`for expression` giúp xử lý list/map một cách gọn gàng.

`format()` giúp tạo key hoặc chuỗi động.

`file()` giúp đọc nội dung file ngoài, rất hữu ích với policy JSON.

`fileset()` kết hợp với `for_each` rất mạnh khi cần tạo resource dựa trên nhiều file.

`locals` giúp gom các giá trị dùng lại nhiều lần, làm code dễ đọc và dễ bảo trì hơn.

## Ví dụ tổng hợp dễ hiểu

Ví dụ tạo nhiều EC2 và output IP:

```
variable "instance_type" {
  type        = string
  description = "Instance type of EC2"

  validation {
    condition     = contains(["t2.micro", "t3.small"], var.instance_type)
    error_message = "Instance type is not allowed."
  }
}

resource "aws_instance" "hello" {
  count         = 5
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}

output "ec2_public_ips" {
  value = {
    for i, instance in aws_instance.hello :
    format("public_ip%d", i + 1) => instance.public_ip
  }
}
```

File `terraform.tfvars`:

```
instance_type = "t2.micro"
```

Kết quả mong muốn:

```
ec2_public_ips = {
  public_ip1 = "..."
  public_ip2 = "..."
  public_ip3 = "..."
  public_ip4 = "..."
  public_ip5 = "..."
}
```

## Cách hiểu ngắn gọn

Bài này có thể hiểu là:

> Terraform functional programming là cách dùng biến, hàm, biểu thức và vòng lặp để biến file Terraform từ cấu hình tĩnh thành cấu hình linh hoạt, tái sử dụng được và dễ mở rộng hơn.
> 

Thay vì viết nhiều resource lặp lại, ta để Terraform tự sinh cấu hình dựa trên dữ liệu đầu vào.
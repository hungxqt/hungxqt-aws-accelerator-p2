# Terraform

Terraform là công cụ **Infrastructure as Code** của HashiCorp. Nó cho phép bạn định nghĩa tài nguyên và hạ tầng bằng các file cấu hình **dễ đọc với con người**, theo kiểu **khai báo**, đồng thời quản lý vòng đời của hạ tầng.

Việc sử dụng Terraform có một số lợi ích so với quản lý hạ tầng thủ công:

- Terraform có thể quản lý hạ tầng trên nhiều nền tảng cloud khác nhau.
- Ngôn ngữ cấu hình dễ đọc giúp bạn viết mã hạ tầng nhanh hơn.
- State của Terraform cho phép bạn theo dõi các thay đổi của tài nguyên trong suốt quá trình triển khai.
- Bạn có thể commit các file cấu hình lên hệ thống quản lý phiên bản để cộng tác an toàn khi làm việc với hạ tầng.

**Các công cụ Infrastructure as Code (IaC)** cho phép bạn quản lý hạ tầng bằng **file cấu hình**, thay vì thao tác thủ công qua giao diện đồ họa.

IaC giúp bạn **xây dựng, thay đổi và quản lý hạ tầng** theo cách:

- An toàn
- Nhất quán
- Có thể lặp lại
- Dễ kiểm soát phiên bản
- Dễ tái sử dụng
- Dễ chia sẻ với người khác

## Terraform’s main components

### Terraform core

Terraform Core is the engine that reads configuration, builds the dependency graph, compares desired state to current state, creates an execution plan, and applies changes. The standard workflow is **write, plan, apply**. `terraform plan` previews proposed changes, while `terraform apply` executes them.

Terraform Core là “bộ máy chính” của Terraform. Nó đọc file cấu hình, xây dựng sơ đồ phụ thuộc giữa các tài nguyên, so sánh trạng thái mong muốn với trạng thái hiện tại, tạo kế hoạch thực thi, rồi áp dụng các thay đổi. Workflow tiêu chuẩn của Terraform là: viết cấu hình, chạy plan, rồi apply. `terraform plan` dùng để xem trước các thay đổi sẽ được thực hiện, còn `terraform apply` dùng để thực sự thực thi các thay đổi đó.

### Providers

Providers are plugins that Terraform uses to interact with cloud platforms, SaaS services, and other APIs. Providers expose **resource types** and **data sources**. You configure them with `provider` blocks and declare installation requirements in the `terraform` block using `required_providers`.

Provider là các “plugin” mà Terraform dùng để giao tiếp với các nền tảng cloud, dịch vụ SaaS hoặc các API khác. Provider cung cấp các loại resource và data source. Bạn cấu hình provider bằng `provider block`, và khai báo yêu cầu cài đặt provider trong `terraform block` thông qua `required_providers`.

### Resources

A resource represents an infrastructure object Terraform manages, such as a VM, VPC, DNS record, or database. Resources are declared with `resource` blocks and referenced by `TYPE.LABEL`.

Resource đại diện cho một đối tượng hạ tầng mà Terraform quản lý, ví dụ như máy ảo, VPC, bản ghi DNS hoặc database. Resource được khai báo bằng `resource block` và được tham chiếu theo cú pháp `TYPE.LABEL`.

### Data sources

Data sources let Terraform read information from external systems or provider APIs without managing the lifecycle of that object. They are declared with `data` blocks and are useful for looking up existing IDs, metadata, remote outputs, and service information.

Data source cho phép Terraform đọc thông tin từ hệ thống bên ngoài hoặc API của provider mà không quản lý vòng đời của đối tượng đó. Data source được khai báo bằng `data` block và thường dùng để tra cứu ID có sẵn, metadata, remote output hoặc thông tin của một dịch vụ.

### Modules

A module is a reusable container for Terraform configuration. Every configuration has a **root module**, and it can call **child modules** with `module` blocks. Modules improve organization, reuse, and encapsulation. Terraform can load modules from the local filesystem, registries, and version control sources.

Module là một “khối đóng gói” có thể tái sử dụng trong Terraform. Mỗi Terraform configuration đều có một root module, và root module có thể gọi các child module thông qua `module`  block. Module giúp tổ chức code tốt hơn, tái sử dụng dễ hơn và che giấu bớt chi tiết triển khai bên trong. Terraform có thể tải module từ thư mục local, Terraform Registry hoặc các nguồn quản lý mã nguồn như GitHub.

[Module](Terraform/Module%2037132dbb34d08046a03bf38ee14de577.md)

### State

Terraform uses state to map configuration to real infrastructure and to track what it manages. State is central to planning, detecting drift, and determining what actions are needed. Terraform also supports remote state patterns, including `terraform_remote_state`, though HashiCorp recommends `tfe_outputs` for HCP Terraform or Terraform Enterprise when only outputs are needed.

Terraform sử dụng `state` để ánh xạ giữa cấu hình Terraform và hạ tầng thật bên ngoài, đồng thời theo dõi những tài nguyên mà Terraform đang quản lý. State đóng vai trò trung tâm trong việc lập kế hoạch thay đổi, phát hiện drift, và xác định Terraform cần tạo, sửa hay xóa tài nguyên nào. Terraform cũng hỗ trợ các mô hình remote state, bao gồm `terraform_remote_state`, tuy nhiên HashiCorp khuyến nghị dùng `tfe_outputs` trong HCP Terraform hoặc Terraform Enterprise nếu bạn chỉ cần đọc outputs.

[State](Terraform/State%2037432dbb34d080e0ac63f5038294d45c.md)

### Backends

Backends define where state is stored and how operations interact with that storage. Backend settings are configured inside the `terraform` block.

Backend định nghĩa nơi Terraform lưu `state` và cách Terraform tương tác với nơi lưu trữ đó. Cấu hình backend được đặt bên trong `terraform` block.

[Backend](Terraform/Backend%2037132dbb34d08095bc4ce0ff7e8d7b29.md)

### CLI

The `terraform` command provides the command line interface. Core commands include `init`, `plan`, `apply`, `validate`, and `fmt`. `validate` checks configuration syntax and internal consistency, while `fmt` rewrites files into Terraform’s canonical format.

Lệnh `terraform` cung cấp giao diện dòng lệnh, hay CLI, để người dùng làm việc với Terraform. Các lệnh cốt lõi gồm `init`, `plan`, `apply`, `validate`, và `fmt`. Trong đó, `validate` dùng để kiểm tra cú pháp và tính nhất quán bên trong của cấu hình, còn `fmt` dùng để định dạng lại file Terraform theo chuẩn format của Terraform.

**Terraform CLI** là công cụ dòng lệnh `terraform` dùng để làm việc với Terraform: khởi tạo project, tải provider/module, kiểm tra cấu hình, tạo execution plan, apply hạ tầng, destroy hạ tầng, quản lý state, import resource, quản lý workspace, test module và chạy Terraform trong CI/CD

[CLI](Terraform/CLI%2037332dbb34d080a38c0ae31a5ebd524a.md)

### Provisioners

**Provisioners** là cơ chế trong Terraform dùng để chạy một số thao tác phụ sau khi resource được tạo, ví dụ: chạy command, chạy script, copy file cấu hình lên server, hoặc thực hiện thao tác dọn dẹp trước khi destroy resource. HashiCorp mô tả provisioners là cách để “upload files, run commands and scripts” nhằm chuẩn bị resource sau khi Terraform tạo ra nó.

Tuy nhiên, cần nhớ một ý rất quan trọng: **provisioners không phải là cách được khuyến nghị cho hầu hết trường hợp**. Terraform được thiết kế chủ yếu cho mô hình **immutable infrastructure**, nên HashiCorp khuyến nghị dùng các giải pháp chuyên dụng hơn như cloud-init, user data, image baking, configuration management, hoặc tính năng native của provider trước khi dùng provisioners.

[Provisioners](Terraform/Provisioners%2037132dbb34d08000a381fe139ff69c90.md)

## Lifecycle of Resource

[Lifecycle of Resource](Terraform/Lifecycle%20of%20Resource%2037132dbb34d080509b9dff4945021197.md)

## Terraform configuration language basics

Terraform’s language is declarative. You describe the desired end state, and Terraform determines the actions needed to reach it. The language is built from these main syntax elements:

### Arguments

An argument sets a named value using `name = expression`.

Một argument thiết lập một giá trị có tên bằng cú pháp `name = expression`.

```
instance_type = "t3.micro"
```

### Meta-argument

Meta arguments are built into the Terraform language and control how resources and modules are created and managed. They are distinct from provider specific arguments.

**Meta-arguments** là các đối số được tích hợp sẵn trong ngôn ngữ Terraform, dùng để kiểm soát cách các **resource** và **module** được tạo ra và quản lý. Chúng khác với các đối số riêng của từng **provider**.

[Meta-argument](Terraform/Meta-argument%2037232dbb34d080778e01c36ea83c8a4e.md)

### Blocks

A block is a container for configuration. Blocks have a type and sometimes labels.

Block là một “khối chứa” cấu hình. Block có một loại `type` và đôi khi có thêm `labels`.

```
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}
```

Phân tích:

| Thành phần | Ý nghĩa |
| --- | --- |
| `resource` | **block type** — loại block |
| `"aws_instance"` | label thứ nhất — loại resource AWS |
| `"web"` | label thứ hai — tên resource trong Terraform |
| `{ ... }` | phần thân block, chứa cấu hình bên trong |

[Block](Terraform/Block%2037232dbb34d080b2a600f889d602b9d9.md)

### Identifiers

Identifiers name arguments, local values, variables, resources, and block labels. The official syntax page defines the identifier rules and treats arguments and blocks as the two fundamental structural forms.

**Identifiers** là các tên định danh dùng để đặt tên cho nhiều thành phần trong Terraform, ví dụ như:

- arguments
- local values
- variables
- resources
- block labels

Nói đơn giản, **identifier** là “tên” mà Terraform dùng để nhận diện một thành phần nào đó trong cấu hình.

### Comments

Terraform supports line and block comments.

```
# Line comment
// Also valid
/* Block comment */
```

### Files

Terraform typically reads `.tf` files and variable definitions from `.tfvars` or `.tfvars.json`. Root module configuration can be split across multiple files in one directory and Terraform merges them as a single module. Variable values can come from CLI flags, environment variables, variable definition files, or HCP Terraform workspace settings.

Terraform thường đọc các file cấu hình `.tf`, và đọc giá trị biến từ các file `.tfvars` hoặc `.tfvars.json`. Một root module có thể được chia thành nhiều file trong cùng một thư mục, và Terraform sẽ xem tất cả các file đó như một module duy nhất. Giá trị của variable có thể đến từ nhiều nguồn: CLI flags, environment variables, variable definition files, hoặc HCP Terraform workspace settings.

## Terraform functions and built-in functions

Terraform functions are part of the **expression system**. In Terraform, expressions are how configuration computes values, and built-in functions are one of the core mechanisms used to transform, combine, validate, and normalize those values. HashiCorp describes expressions as the feature set that lets Terraform evaluate literal values, references, arithmetic, conditionals, and built-in functions.

Các hàm trong Terraform là một phần của **hệ thống expression**. Trong Terraform, expression là cách cấu hình tính toán ra giá trị, và các hàm built-in là một trong những cơ chế cốt lõi dùng để biến đổi, kết hợp, kiểm tra hợp lệ và chuẩn hóa các giá trị đó.

Terraform’s built-in functions are called with standard function syntax:

```
max(5, 12, 9)
```

Each function has a defined argument contract and return type. Some functions accept a fixed number of arguments, while others accept a variable number. A function call evaluates to its return value.

Mỗi hàm có một **quy ước về đối số** và **kiểu giá trị trả về** được xác định rõ ràng. Một số hàm nhận số lượng đối số cố định, trong khi một số hàm khác có thể nhận số lượng đối số thay đổi.

Một lời gọi hàm sẽ được đánh giá và trả về **giá trị kết quả** của hàm đó.

[Functional programming](Terraform/Functional%20programming%2037132dbb34d080a793fede9b23223e35.md)

[Terraform functions](Terraform/Terraform%20functions%2034032dbb34d0802c9b8deefa3c7ee10b.md)

## Terraform expressions

A Terraform expression is anything that **produces a value** inside a Terraform configuration. The simplest expressions are literals (giá trị được viết trực tiếp trong code) such as `"hello"` or `5`, while more advanced expressions can reference resource data, perform arithmetic, evaluate conditions, transform collections, and call built in functions. Terraform also notes that expression support depends on context, because some parts of the language restrict which kinds of expressions are allowed. HashiCorp specifically recommends `terraform console` for experimenting with expression behavior.

Một **Terraform expression** là bất kỳ thứ gì tạo ra một giá trị bên trong cấu hình Terraform. Những expression đơn giản nhất là **literal** — tức là các giá trị được viết trực tiếp trong code — chẳng hạn như `"hello"` hoặc `5`. Những expression nâng cao hơn có thể tham chiếu dữ liệu của resource, thực hiện phép tính số học, đánh giá điều kiện, biến đổi collection, và gọi các hàm built-in.

Terraform cũng lưu ý rằng việc hỗ trợ expression còn phụ thuộc vào **ngữ cảnh**, vì một số phần trong ngôn ngữ Terraform có giới hạn về loại expression được phép sử dụng. HashiCorp đặc biệt khuyến nghị sử dụng `terraform console` để thử nghiệm và quan sát hành vi của expression.

### Where expressions fit in the language

Terraform’s native syntax is built from **arguments** and **blocks**. An argument assigns a value to a name, and the value on the right side of `=` is typically an expression. Blocks define higher level constructs such as `resource`, `variable`, `output`, and other Terraform features. In practice, expressions are the value language used inside this block and argument structure.

Cú pháp gốc của Terraform được xây dựng từ **argument** và **block**. Một **argument** dùng để gán một giá trị cho một tên, và phần giá trị nằm bên phải dấu `=` thường là một **expression**.

Ví dụ: `instance_type = "t2.micro”` , trong đó `"t2.micro"` là một expression, vì nó tạo ra một giá trị.

Còn **block** dùng để định nghĩa các cấu trúc cấp cao hơn, chẳng hạn như `resource`, `variable`, `output`, và các tính năng khác của Terraform.

Trong thực tế, **expression chính là phần ngôn ngữ dùng để tạo ra giá trị bên trong cấu trúc block và argument của Terraform**.

### The documented components of Terraform expressions

HashiCorp’s expressions section breaks the topic into these official parts:

- Types and values
- Strings and templates
- References to values
- Operators
- Function calls
- Conditional expressions
- For expressions
- Splat expressions
- Dynamic blocks
- Type constraints
- Version constraints

That list is the official scope of the Terraform expressions reference area, and it is the right mental model for learning the feature set completely.

[Terraform expressions](Terraform/Terraform%20expressions%2034032dbb34d080058e3fe1c33ef6097f.md)

## Importing, moving, and refactoring

These are major modern Terraform capabilities that belong in any comprehensive note.

### Refresh

[Refresh](Terraform/Refresh%2037132dbb34d080eeb156f4771cbdf434.md)

### Generated configuration during import

Terraform docs also describe generating resource configuration during `plan` with `generate-config-out` in supported import workflows.

## Core workflow and commands

### `terraform init`

Initializes the working directory, installs providers and modules, and prepares backend configuration. This is part of the official write, plan, apply workflow.

Khởi tạo thư mục làm việc, cài đặt các provider và module, đồng thời chuẩn bị cấu hình backend. Đây là một phần trong quy trình chính thức **write, plan, apply**

### `terraform plan`

Builds an execution plan by reading current state, refreshing knowledge of real infrastructure, and comparing that against configuration. It is the safe preview step before changes.

Tạo **execution plan** bằng cách đọc trạng thái hiện tại, làm mới thông tin về hạ tầng thực tế, rồi so sánh với cấu hình Terraform. Đây là bước xem trước an toàn trước khi thực hiện thay đổi.

### `terraform apply`

Executes the changes in a plan to create, update, or destroy infrastructure.

Thực thi các thay đổi trong một **plan** để tạo mới, cập nhật hoặc hủy hạ tầng.

### `terraform validate`

Validates configuration syntax and internal consistency.

Kiểm tra tính hợp lệ của cú pháp cấu hình và sự nhất quán nội bộ.

### `terraform fmt`

Reformats configuration into canonical Terraform style.

## Typical Terraform project structure

```hcl
terraform-project/
├── environments/
│   ├── dev/
│   │   ├── [backend.tf](http://backend.tf/)
│   │   ├── [terraform.tf](http://terraform.tf/)
│   │   ├── [providers.tf](http://providers.tf/)
│   │   ├── [variables.tf](http://variables.tf/)
│   │   ├── terraform.tfvars
│   │   ├── [main.tf](http://main.tf/)
│   │   ├── [network.tf](http://network.tf/)
│   │   ├── [compute.tf](http://compute.tf/)
│   │   ├── [outputs.tf](http://outputs.tf/)
│   │   └── [versions.tf](http://versions.tf/)
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
├── modules/
│   ├── vpc/
│   │   ├── [README.md](http://readme.md/)
│   │   ├── [main.tf](http://main.tf/)
│   │   ├── [variables.tf](http://variables.tf/)
│   │   ├── [outputs.tf](http://outputs.tf/)
│   │   └── [versions.tf](http://versions.tf/)
│   ├── app/
│   │   ├── [README.md](http://readme.md/)
│   │   ├── [main.tf](http://main.tf/)
│   │   ├── [variables.tf](http://variables.tf/)
│   │   ├── [outputs.tf](http://outputs.tf/)
│   │   └── [versions.tf](http://versions.tf/)
│   └── database/
│       └── ...
├── examples/
│   └── simple/
│       └── [main.tf](http://main.tf/)
├── .gitignore
├── [README.md](http://readme.md/)
└── Makefile
```

### What each part is for

1. Root module
    
    The directory where you run Terraform is treated as the **root module**. This is the deployable entry point for one environment or workload. It typically wires together providers, backend, variables, and child modules.
    
    Common files:
    
    - **`terraform.tf`**
    Contains the `terraform` block, especially `required_version` and `required_providers`. HashiCorp explicitly recommends this filename.
    - **`backend.tf`**
    Contains backend configuration for state storage. HashiCorp recommends separating backend config into this file.
    - **`providers.tf`**
    Holds provider blocks and configuration.
    - **`main.tf`**
    Usually the primary composition file with resources, data sources, and module calls.
    - **`variables.tf`**
    Input variable declarations.
    - **`outputs.tf`**
    Output values, ideally kept in alphabetical order per the style guide.
    - **`terraform.tfvars`** or `.auto.tfvars`
    Environment specific variable values. Terraform recognizes variable definition files as part of configuration structure.
2. Logical split files
    
    When the project grows, HashiCorp recommends grouping by concern, such as:
    
    ```
    network.tf
    security.tf
    compute.tf
    storage.tf
    dns.tf
    iam.tf
    monitoring.tf
    ```
    
    That is preferred over a huge single `main.tf` once the codebase becomes harder to navigate.
    
3. Child modules
    
    Reusable modules should live separately from root environment code. HashiCorp’s standard module structure for reusable modules includes:
    
    ```
    module-name/
    ├── README.md
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── modules/
    │   └── nested-submodule/
    ├── examples/
    │   └── example-a/
    ```
    
    This is the official recommended structure for reusable modules, especially when they are distributed or published. The Registry also expects the standard module structure.
    

[Terraform AWS](Terraform/Terraform%20AWS%2033932dbb34d080a782d3e4ba41a95855.md)

[Secure in Terraform](Terraform/Secure%20in%20Terraform%2037132dbb34d08078962dd2e8a829d9c2.md)

[Error during creation](Terraform/Error%20during%20creation%2037132dbb34d080f891afce56758a2015.md)
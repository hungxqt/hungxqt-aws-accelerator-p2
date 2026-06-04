# Terraform expressions

# Core mental model

## Expressions are declarative, not general purpose programming

Terraform expressions exist to compute values for configuration, not to turn Terraform into a general purpose language. They are designed around infrastructure declarations, dependency inference, type checking, and plan time versus apply time evaluation. For example, Terraform automatically infers dependencies when one expression references another managed object, and it also carries unknown values through expressions during planning.

**Expressions trong Terraform** tồn tại để **tính toán giá trị cho cấu hình**, chứ không phải để biến Terraform thành một ngôn ngữ lập trình đa dụng.

Chúng được thiết kế xoay quanh việc **khai báo hạ tầng**, bao gồm:

- Suy luận dependency giữa các tài nguyên
- Kiểm tra kiểu dữ liệu
- Đánh giá giá trị tại thời điểm `plan`
- Đánh giá giá trị tại thời điểm `apply`

Ví dụ, Terraform có thể tự động suy luận dependency khi một expression tham chiếu đến một object do Terraform quản lý. Đồng thời, Terraform cũng có thể truyền các giá trị chưa biết xuyên suốt các expression trong giai đoạn planning.

Nói dễ hiểu hơn:

> Expression trong Terraform dùng để tính toán và liên kết giá trị trong file cấu hình hạ tầng. Nó không được thiết kế để viết logic phức tạp như Python hay JavaScript.
> 

## Context matters

Not every Terraform location accepts every expression form. Some contexts require literal values, some restrict references to resource attributes, and some meta arguments must be resolved before Terraform can safely evaluate later expressions. This is why expressions feel powerful but still controlled.

Không phải vị trí nào trong Terraform cũng chấp nhận mọi dạng **expression**. Một số ngữ cảnh yêu cầu giá trị phải là **literal value** — tức giá trị được viết trực tiếp. Một số ngữ cảnh khác hạn chế việc tham chiếu đến thuộc tính của resource. Ngoài ra, một số **meta-arguments** phải được Terraform xác định trước, trước khi Terraform có thể đánh giá an toàn các expression ở bước sau.

Đó là lý do vì sao expression trong Terraform tuy rất mạnh, nhưng vẫn được kiểm soát chặt chẽ.

Nói dễ hiểu hơn:

> Terraform cho phép dùng expression để tính toán giá trị, nhưng không phải chỗ nào cũng được dùng tùy ý. Có những chỗ Terraform cần biết giá trị từ sớm để xây dựng dependency graph, xác định số lượng resource, hoặc quyết định cách xử lý resource trước khi đi sâu vào phần cấu hình bên trong.
> 

# Types and values

## Primitive and complex types

Terraform documents these value types:

- `string`
- `number`
- `bool`
- `list` or `tuple`
- `set`
- `map` or `object`

Strings, numbers, and booleans are primitive types. Lists, tuples, maps, objects, and sets are complex or structural types.

## Null

Terraform defines **`null`** as a special value with no type. It is commonly used to represent omission or absence. This is especially important in optional inputs and in expression patterns where Terraform should behave as if an argument were not set.

## Type conversion

Terraform will often perform automatic type conversion when a context expects a particular type. If conversion is impossible, Terraform raises a type mismatch error. One critical exception is that **automatic type conversion does not occur with the equality operators**, which makes equality checks stricter than many authors first expect.

## Sets are unordered

Sets are unordered collections, so Terraform does not let you access a set element directly by index. If you need index based access, the official guidance is to convert the set to a list first, for example with `tolist(...)`.

# Strings and templates

## Quoted strings and heredocs

Terraform supports two string literal forms:

- quoted strings such as `"hello"`
- heredoc strings for multi line text

Both support template sequences.

## Interpolation

Inside strings, `${ ... }` evaluates an expression and inserts its string form into the result.

```
"Hello, ${var.name}!"
```

Terraform’s docs describe this as interpolation inside a string template.

## Template directives

Terraform also supports `%{ ... }` template directives for logic inside strings, such as conditional content or iteration over collections. The docs also note optional strip markers `~` to remove surrounding whitespace when formatting multi line templates cleanly.

## Practical rule

Use string templates when the final result must be a string. If you are building structured data such as lists or objects, prefer native expressions over string assembly, because that keeps values typed and easier to validate. This is an inference from how Terraform separates typed expressions from string templating.

# References to named values

## The main named value categories

Terraform officially documents these main named value kinds:

- Resources
- Input variables
- Local values
- Child module outputs
- Data sources
- Filesystem and workspace info
- Block local values

Each of these can appear in expressions and can be combined with other expressions.

## Important limitation on named values

Although many named values look like objects because they use dot separated paths, Terraform says they are **not real objects** in the general expression sense. You must use them exactly as documented. You cannot arbitrarily swap dot notation with bracket notation at the parent namespace level, and you cannot iterate over the parent namespace itself like `aws_instance` to enumerate all resources of that type.

## Dependency inference

When one resource or module expression refers to another object, Terraform analyzes the reference and infers an **implicit dependency**. This is one of the most important expression side effects in Terraform, because expressions are not just about value computation. They also help Terraform build the execution graph.

# Operators

## Operator groups

Terraform groups operators into arithmetic, equality, comparison, and logical categories. Each group expects specific input types, and Terraform may attempt automatic conversion when appropriate.

## Arithmetic operators

These are used with numeric values:

- `a + b`
- `a - b`
- `a * b`
- `a / b`
- `a % b`

Use them only where numeric semantics are intended.

## Equality operators

Terraform supports:

- `a == b`
- `a != b`

Remember that Terraform does **not** automatically type convert for equality tests, so `"1" == 1` is not something you should rely on.

## Comparison operators

Terraform documents:

- `<`
- `<=`
- `>`
- `>=`

These expect number values and return booleans.

## Logical operators

Terraform supports:

- `!`
- `&&`
- `||`

Terraform also explicitly notes there is **no dedicated XOR operator**. For booleans, exclusive or can often be represented using `!=`.

## Important distinction

The `? :` conditional form is **not** treated as an operator in the operators reference. Terraform documents it separately as a conditional expression.

# Function calls

## Syntax

Function calls follow this official pattern:

```
<FUNCTION NAME>(<ARGUMENT 1>, <ARGUMENT 2>)
```

A function call evaluates to the function’s return value. Some functions accept a fixed number of arguments, while others accept a variable number.

## Expanding arguments

If you already have arguments in a tuple or list, Terraform lets you expand them into separate function arguments using `...`.

```
min([55, 3453, 2]...)
```

That is an official expression feature documented on the function calls page.

## Built in and provider defined functions

Terraform documents many **built in functions** and also supports **provider defined functions**. You cannot define your own functions directly in Terraform configuration language, but providers can expose namespaced functions. HashiCorp’s documentation covers built in functions and built in provider defined functions.

## Function categories

The official functions catalog groups functions by purpose, such as string, numeric, collection, encoding, filesystem, date and time, hash and crypto, IP network, and type conversion operations. The catalog page is the canonical latest reference for the full function list.

## Sensitive and nonsensitive functions

Terraform provides `sensitive(...)` and `nonsensitive(...)`, but the docs recommend marking variables or outputs as sensitive directly whenever possible. HashiCorp also warns that `nonsensitive(...)` should be used sparingly and only when you are certain sensitive content has been fully removed.

# Conditional expressions

## Syntax

Terraform’s conditional expression syntax is:

```
condition ? true_val : false_val
```

It returns one of two values depending on a boolean condition.

## Type rules

The two result expressions may be any type, but Terraform requires them to have a compatible result type so the overall expression type can be determined even before the condition is known. If they differ, Terraform tries to find a common convertible type automatically.

## Good use cases

Use conditionals for optional arguments, tag selection, environment dependent values, feature switches, and validation friendly configuration. The official docs also show conditions combined with functions and operators as long as the condition resolves to a boolean.

# For expressions

## Purpose

A `for` expression transforms one complex value into another complex value. Each input element may produce one output element or zero output elements.

## Basic forms

Tuple style output:

```
[for s in var.list : upper(s)]
```

Object style output:

```
{ for name, user in var.users : name => user }
```

These are the two major patterns to remember.

## Filtering

A `for` expression can include an `if` clause to include only selected elements:

```
[for s in var.list : upper(s) if s != ""]
```

This is Terraform’s official filtering mechanism within collection transformations.

## Ordering behavior

When converting from unordered collections to ordered ones, Terraform imposes an ordering:

- Maps and objects are sorted lexically by key or attribute name
- Sets of strings are sorted lexically by value

This matters for deterministic plans and outputs.

## Limitation

`for` expressions produce values. They do **not** generate nested configuration blocks. For repeated nested blocks, Terraform says to use **dynamic blocks** instead.

# Splat expressions

## What splat does

Splat expressions provide a concise way to project an attribute across a list, set, or tuple of objects. They are especially useful when you want “the same attribute from every element.”

## Important map limitation

Splat works with lists, sets, and tuples. It does **not** work the same way for maps or objects. Terraform explicitly says that if you need similar behavior for maps or objects, use a `for` expression instead. This is especially relevant because resources created with `for_each` appear as a **map of objects**, not a list.

## Special null behavior

Terraform documents a special case:

- non null single value with splat becomes a single element tuple
- `null` with splat becomes an empty tuple

This is extremely useful for optional object inputs that should become zero or one nested blocks in a dynamic block pattern.

## Legacy note

The docs recommend the newer `[*]` style rather than the older legacy attribute only splat form because the old form has subtle and often confusing behavior.

# Dynamic blocks

## What they are

A `dynamic` block acts like a `for` expression for **nested blocks** rather than values. It iterates over a complex value and emits one nested block per element.

## Its components

A dynamic block has these official components:

- **label**: the nested block type to generate
- **for_each**: the collection or structural value to iterate over
- **iterator**: optional temporary variable name for the current element
- **labels**: optional generated block labels
- **content**: the body of each generated nested block

The iterator object has `key` and `value` attributes.

## Important restriction

Dynamic blocks can generate arguments that belong to the configured resource, data source, provider, or provisioner, but they **cannot generate meta argument blocks** such as `lifecycle` or `provisioner`, because Terraform must process those earlier.

# Type constraints and their relationship to expressions

## Not ordinary expressions

Type constraints look similar to expressions, but Terraform documents them as a **special syntax** that is valid only in specific places, primarily the `type` argument of an input variable.

## Their components

Type constraints are built from:

- **type keywords**
- **type constructors**

Type keywords are unquoted symbols for static types. Type constructors are function like forms that carry more detail, such as collection or object member types.

## Why they matter to expression authors

Even though type constraints are not regular runtime expressions, they define what values expressions are allowed to produce. They are essential for module interfaces, validation, and predictable expression behavior. Terraform also documents advanced areas such as `any` and optional object attributes.

# Unknown values and plan time behavior

## Known after apply

Terraform uses special **unknown value placeholders** during planning when a value cannot be predicted yet, such as a remote generated ID. Terraform automatically propagates unknowns through expressions. For example, combining a known value with an unknown usually yields an unknown result. In plan output, these appear as **`(known after apply)`**.

## Where unknowns matter most

HashiCorp highlights several important effects:

- `count` cannot be unknown because Terraform must know how many instances to plan
- a data source depending on unknown input may be deferred to apply
- unknown module inputs remain unknown inside the child module
- unknown output values remain unknown to parent modules
- some type issues involving unknowns may only fail at apply time

These are critical details for debugging expression behavior in real infrastructure code.

# Expression related value components in modules

## Variables

Variables define the **input interface** of a module. They are referenced with `var.<NAME>`. Terraform also supports `validation` blocks on variables, where the `condition` itself is an expression and `error_message` explains the failure. Sensitive variables can be marked with `sensitive = true`, and Terraform also documents `ephemeral` for omitting a variable from state and plan files, with added restrictions.

## Locals

Locals define named expressions scoped to a module. Their purpose is to improve reuse, readability, and consistency. They are the main “expression composition” mechanism when you want to calculate something once and use it in several places.

## Outputs

Outputs export computed values from a module. Expressions inside outputs often expose resource attributes, transformed values, or aggregated module results. Output sensitivity should be declared directly where appropriate.

## Child module outputs

Child module outputs are named values available to the parent module and are a first class expression component in cross module composition.

## Data sources

Data sources can be referenced in expressions like resources, but if their configuration depends on unknown values, Terraform may defer reading them until apply.

## Filesystem and workspace values

Terraform explicitly includes filesystem and workspace information as named values available to expressions. The docs also caution that some of these, aside from `path.module`, are best used only in the root module to avoid reuse issues.

## Block local values

Some nested contexts introduce temporary symbols such as `each`, `count`, or iterator names in dynamic blocks. These block local values are part of the named value model and are only valid inside their defining context.

# Practical expression patterns

## Literal values

```
name  = "web"
count = 3
enabled = true
```

These are the simplest expressions and often the starting point before introducing references or computation.

## Referencing other values

```
instance_type = var.instance_type
vpc_id        = aws_vpc.main.id
```

These create both computed values and implicit graph dependencies.

## Conditional selection

```
instance_type = var.environment == "prod" ? "m6i.large" : "t3.micro"
```

Use when one of two values should be chosen from a boolean condition.

## Collection transformation

```
[for s in var.subnets : upper(s)]
```

Use for mapping, filtering, regrouping, and reshaping collections.

## Dynamic nested blocks

```
dynamic "setting" {
  for_each = var.settings
  content {
    name  = setting.value.name
    value = setting.value.value
  }
}
```

Use when a provider schema expects repeated nested blocks, not just repeated values.

# Key distinctions that often confuse people

## Expressions versus type constraints

Expressions compute runtime values. Type constraints describe allowed value shapes and are only valid in limited declaration contexts.

## For expressions versus dynamic blocks

`for` produces **values**. `dynamic` produces **nested blocks**. This is one of the most important distinctions in Terraform language design.

## Splat versus for

Use splat for straightforward projection over lists, sets, or tuples. Use `for` when you need filtering, reshaping, key generation, map support, or clearer control. For `for_each` resources, prefer `for` because those resources appear as maps.

## Sensitive marking versus sensitive function

Terraform recommends declaring sensitivity at variable or output boundaries where possible, instead of wrapping downstream expressions with `sensitive(...)`.

## Plan time unknowns versus actual runtime values

An expression can be valid even if the final value is not yet known during planning. But some constructs, especially `count`, require fully known values earlier.

# Best practice summary

## Write expressions that preserve types

Prefer typed values and collections over building strings that merely look like structured data. Terraform’s type system, conversion rules, and validation are most helpful when values stay typed.

## Keep module interfaces explicit

Use variable types, validation, locals, and outputs to make expression behavior readable and predictable. HashiCorp’s module value guidance is built around this interface idea.

## Be careful with null, sets, and unknowns

These three areas are common sources of subtle bugs:

- `null` can mean omission
- sets are unordered
- unknown values can defer decisions until apply

Terraform documents each of these clearly, and strong expression design takes all three into account.

## Prefer modern splat syntax

Use `[*]`, not the legacy attribute only form. HashiCorp explicitly recommends the newer syntax.
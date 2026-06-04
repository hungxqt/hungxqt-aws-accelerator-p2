# Terraform functions

# Components that make Terraform functions work

To really understand Terraform functions, you also need the Terraform language components around them.

## Expressions

Functions live inside Terraform expressions. Expressions compute values for arguments, outputs, locals, and other configuration constructs. Not every context accepts every expression form, because some places restrict expressions to literals or forbid resource references.

## Types and values

Functions consume and return Terraform values. Terraform supports primitive and complex values, and functions are heavily tied to type handling. Terraform also performs some automatic type conversion when needed, though not in every context. For example, strings can often convert to numbers or booleans if the string is a valid representation, but automatic conversion does **not** happen for the equality operator.

## Indices and attributes

Many functions work with collections and objects, so you need to understand Terraform’s indexing rules. Lists and tuples use numeric index syntax, while maps and objects use string keys. Object attributes can be accessed with dot notation when the attribute name is a valid identifier. HashiCorp recommends bracket notation for maps with arbitrary user-specified keys.

## References to named values

Functions often consume named values such as:

- resources
- input variables
- local values
- child module outputs
- data sources
- filesystem and workspace info
- block-local values

A key nuance is that many of these dot-shaped references are **not real objects**. You must use them exactly as defined by Terraform, and you cannot treat the parent symbol as an iterable object.

## Other language building blocks used with functions

The expression system around functions also includes:

- strings and templates
- operators
- conditional expressions
- for expressions

This matters because in real Terraform, functions are rarely used alone. They are usually combined with references, conditionals, and comprehensions.

# Function call behavior

## Syntax

Terraform uses:

```
FUNCTION_NAME(arg1, arg2)
```

Some functions support arbitrary argument counts.

## Argument expansion

If you already have a list or tuple and want Terraform to pass its elements as separate arguments, you can use `...` expansion:

```
min([55, 2453, 2]...)
```

This syntax is special to function calls. HashiCorp explicitly notes it must be three periods, not the Unicode ellipsis character.

## Sensitive values

If a sensitive value is used as a function argument, Terraform conservatively marks the result as sensitive too, regardless of whether the function would reveal the secret directly.

## Pure functions versus special functions

Most Terraform built-in functions are effectively **pure**, meaning the result depends only on their arguments. A small subset interacts with outside state or time. The documentation specifically calls out `file`, `templatefile`, `timestamp`, and `uuid` as special cases.

HashiCorp also explains that `file` and `templatefile` are evaluated during initial configuration validation, so they are intended only for files that already exist as a static part of the configuration. You cannot use them to read files generated dynamically during the same plan or apply.

# Official function categories

HashiCorp organizes Terraform built-in functions into these main categories: **numeric, string, collection, encoding, filesystem, date and time, hash and crypto, IP network, type conversion**, plus a set of **Terraform-specific provider-defined functions** in the `terraform` provider. The docs also note that standard Terraform configuration files support all functions, while other configuration types such as Terraform Stacks support only subsets in component and deployment configurations.

# Numeric functions

Official numeric functions include:

- `ceil`
- `floor`
- `log`
- `max`
- `min`
- `parseint`
- `pow`
- `signum`

## What they are for

These functions support arithmetic normalization, comparisons across multiple numeric inputs, exponentiation, and parsing string input into numeric form. `max` and `min` are especially common in guardrail-style logic, while `parseint` is useful when external input arrives as text.

# String functions

Official string functions include:

- `chomp`
- `endswith`
- `format`
- `formatlist`
- `indent`
- `join`
- `lower`
- `regex`
- `regexall`
- `replace`
- `split`
- `startswith`
- `strcontains`
- `strrev`
- `substr`
- `title`
- `trim`
- `trimprefix`
- `trimsuffix`
- `trimspace`
- `upper`

## What they are for

These functions support text cleanup, pattern matching, formatting, templating support, naming normalization, and string decomposition. In practice, they are used heavily for resource naming, tagging, environment key generation, and data cleanup before values are fed into providers. `format` and `join` are especially common because many provider arguments need carefully constructed strings.

# Collection functions

Official collection functions include:

- `alltrue`
- `anytrue`
- `chunklist`
- `coalesce`
- `coalescelist`
- `compact`
- `concat`
- `contains`
- `distinct`
- `element`
- `flatten`
- `index`
- `keys`
- `length`
- `lookup`
- `matchkeys`
- `merge`
- `one`
- `range`
- `reverse`
- `setintersection`
- `setproduct`
- `setsubtract`
- `setunion`
- `slice`
- `sort`
- `sum`
- `transpose`
- `values`
- `zipmap`
- `tolist`
- `tomap`

## What they are for

These are the backbone of practical Terraform data transformation. They handle list, set, tuple, map, and object manipulation, and they are the functions most often combined with `for` expressions and `for_each`. `merge`, `flatten`, `zipmap`, `lookup`, `keys`, `values`, and `contains` are among the most useful for module design and dynamic infrastructure generation.

## Important nuances

The `element` function still exists, but the official docs say you should use native index syntax `list[index]` in most cases and only use `element` when you need its special wrap-around behavior.

The `one` function is useful when you have a collection expected to contain zero or one element and want a scalar-or-null result. HashiCorp documents it in relation to splat operator behavior.

# Encoding functions

Official encoding functions include:

- `base64decode`
- `base64encode`
- `base64gzip`
- `csvdecode`
- `jsondecode`
- `jsonencode`
- `textdecodebase64`
- `textencodebase64`
- `urlencode`
- `yamldecode`
- `yamlencode`

## What they are for

These functions convert between Terraform values and serialized text formats. `jsonencode` and `jsondecode` are critical when interfacing with APIs, policies, templates, and provider arguments that expect JSON. YAML and CSV functions are also valuable when importing external structured content into Terraform expressions.

## Practical significance

Encoding functions are one of the main bridges between Terraform’s typed value model and the string-based data exchanged with cloud providers, templates, and external systems.

# Filesystem functions

Official filesystem functions include:

- `abspath`
- `dirname`
- `pathexpand`
- `basename`
- `file`
- `fileexists`
- `fileset`
- `filebase64`
- `templatefile`

## What they are for

These functions work with local file paths and file content. They are frequently used to load templates, user-data scripts, policies, JSON payloads, and other static artifacts packaged with a Terraform module.

## Important limitations

The `file` function reads a file and returns its contents as a string. The official docs state that Terraform strings are Unicode, so `file` interprets file contents as **UTF-8 text**.

HashiCorp also states that `file` and `templatefile` are evaluated from static configuration files during validation, so they are not appropriate for reading files created later during the same Terraform run.

# Date and time functions

Official date and time functions include:

- `formatdate`
- `plantimestamp`
- `timeadd`
- `timecmp`
- `timestamp`

## What they are for

These functions support time comparisons, time arithmetic, and formatting. They are useful for expiry logic, timestamping, metadata generation, and schedule-related calculations.

## Important nuance

`timestamp` is one of the special impure-style functions called out by HashiCorp because its value changes over time. This can affect the relationship between plan and apply if used carelessly. `plantimestamp` exists to anchor time to plan creation.

# Hash and crypto functions

Official hash and crypto functions include:

- `base64sha256`
- `base64sha512`
- `bcrypt`
- `filebase64sha256`
- `filebase64sha512`
- `filemd5`
- `filesha1`
- `filesha256`
- `filesha512`
- `md5`
- `rsadecrypt`
- `sha1`
- `sha256`
- `sha512`
- `uuid`
- `uuidv5`

## What they are for

These functions support checksums, content hashing, deterministic identifiers, decryption in limited scenarios, and content-change tracking. File hash functions are commonly used to detect when templates or artifacts change so Terraform can react accordingly.

## Important nuance

`uuid` is one of the special functions HashiCorp highlights because it produces a fresh random-style result per call, which has implications for deterministic planning. `uuidv5`, by contrast, is deterministic for the same inputs.

# IP network functions

Official IP network functions include:

- `cidrhost`
- `cidrnetmask`
- `cidrsubnet`
- `cidrsubnets`

## What they are for

These functions are used for subnet planning, host address derivation, and programmatic network allocation. They are especially important in modules that generate VPCs, subnets, route layouts, or IP plans from higher-level inputs.

# Type conversion and control functions

Official type conversion and value-control functions include:

- `can`
- `ephemeralasnull`
- `issensitive`
- `nonsensitive`
- `sensitive`
- `tobool`
- `tolist`
- `tomap`
- `tonumber`
- `toset`
- `tostring`
- `try`
- `type`

## What they are for

These functions handle safe evaluation, typing, normalization, and sensitivity marking. They are central to defensive Terraform authoring, especially in shared modules where input may be inconsistent or partially optional.

## The most operationally important ones

### `can`

`can` evaluates an expression and returns whether it succeeded without errors. It is useful when probing optional structures or validating whether an expression is safe to use.

### `try`

`try` evaluates arguments in order and returns the first one that does not error. It is one of the best tools for normalization layers in `locals` blocks.

### `type`

`type` returns the type of a value and is useful for debugging and understanding Terraform’s type system.

### Sensitivity functions

Terraform includes dedicated sensitivity functions: `issensitive`, `sensitive`, and `nonsensitive`. This is important because sensitivity in Terraform is a first-class behavioral property, not merely a documentation convention.

# Terraform-specific provider-defined functions

The Terraform docs also list built-in provider-defined functions under the `terraform` provider:

- `provider::terraform::encode_tfvars`
- `provider::terraform::decode_tfvars`
- `provider::terraform::encode_expr`
- `type` is also listed in that section for reference context on the page

## Why these matter

These are specialized helpers for Terraform-native representations such as `.tfvars` content and Terraform expression encoding. They are not the same thing as general built-in language functions, but they are officially documented alongside them because they are part of Terraform’s broader function ecosystem.

# Function support across configuration file types

HashiCorp explicitly notes that **standard Terraform configuration files** support all functions, while other configuration types, including **Terraform Stacks** deployment and component files, support only a subset. The function tables on the official page indicate which functions are available in `.hcl`, `.tfcomponent.hcl`, and `.tfdeploy.hcl` contexts.

This is important in modern Terraform usage because function availability is no longer a purely global assumption across every HashiCorp configuration surface.

# How functions fit into real Terraform architecture

## Functions are not the same as operators

Operators such as arithmetic and comparisons are part of the language syntax, while functions are named callable transformations. Both participate in expressions, but they solve different problems. HashiCorp documents operators separately from function calls.

## Functions are not the same as templates

String interpolation and template directives are part of Terraform’s string/template language, whereas functions are expression-level building blocks. They often work together, especially with `templatefile`, `format`, `join`, `jsonencode`, and `yamlencode`.

## Functions are not the same as `for` expressions

A `for` expression transforms a collection by iterating, while a function performs a named computation. In practice they are often composed together, such as using a `for` expression to build an object and then `merge`, `flatten`, or `toset` to normalize it.

## Functions are deeply tied to modules

Modules are collections of resources managed together, and functions are essential for making modules reusable, typed, defensive, and expressive. They shape input normalization, output formatting, conditional defaults, collection transformation, and network math.
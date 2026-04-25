# dataprep

[![CI](https://github.com/nao1215/dataprep/actions/workflows/ci.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/dataprep)](https://hex.pm/packages/dataprep)


![dataprep_logo](https://raw.githubusercontent.com/nao1215/dataprep/main/doc/img/dataprep-logo-small.png)

Composable, type-driven preprocessing and validation combinator library for Gleam.

dataprep is a combinator toolkit, not a rule catalog.

- Built-in and user-defined rules are identical in power.
- No domain-specific rules (email, URL, UUID). Write your own or use a dedicated package.
- No schema, no DSL, no reflection.
- Prep transforms. Validator checks. They do not mix.
- Errors are your types, not ours.

## Requirements

- Gleam 1.15 or later
- Erlang/OTP 27 or later

## Install

```sh
gleam add dataprep
```

## Quick start

```gleam
import dataprep/prep
import dataprep/validated.{type Validated}
import dataprep/rules

pub type User {
  User(name: String, age: Int)
}

pub type Err {
  NameEmpty
  AgeTooYoung
}

pub fn validate_user(name: String, age: Int) -> Validated(User, Err) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check_name = rules.not_empty(NameEmpty)
  let check_age = rules.min_int(0, AgeTooYoung)

  validated.map2(
    User,
    name |> clean |> check_name,
    check_age(age),
  )
}

// validate_user("  Alice ", 25)   -> Valid(User("alice", 25))
// validate_user("", -1)           -> Invalid([NameEmpty, AgeTooYoung])
```

## Examples

### Field validation with structured error context

Attach field names to errors so callers can identify which field failed.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator

pub type FormError {
  Field(name: String, detail: FieldDetail)
}

pub type FieldDetail {
  Empty
  TooShort(min: Int)
  TooLong(max: Int)
}

pub fn validate_username(raw: String) -> Validated(String, FormError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check =
    rules.not_empty(Empty)
    |> validator.guard(
      rules.min_length(3, TooShort(3))
      |> validator.both(rules.max_length(20, TooLong(20))),
    )
    |> validator.label("username", Field)

  raw |> clean |> check
}

// validate_username("  Al  ")
//   -> Invalid([Field("username", TooShort(3))])
// validate_username("  Alice  ")
//   -> Valid("alice")
```

### Parse then validate

Use `validated.and_then` to bridge type-changing parsing with
same-type validation. Parsing short-circuits; validation accumulates.

```gleam
import dataprep/parse
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator

pub type AgeError {
  NotAnInteger(raw: String)
  TooYoung(min: Int)
  TooOld(max: Int)
}

pub fn validate_age(raw: String) -> Validated(Int, AgeError) {
  let check_range =
    rules.min_int(0, TooYoung(0))
    |> validator.both(rules.max_int(150, TooOld(150)))

  parse.int(raw, NotAnInteger)
  |> validated.and_then(check_range)
}

// validate_age("abc") -> Invalid([NotAnInteger("abc")])
// validate_age("200") -> Invalid([TooOld(150)])
// validate_age("25")  -> Valid(25)
```

### Nested error labeling with map3

Combine multiple fields into a domain type. All errors from all
fields are accumulated with their field names.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator

pub type SignupForm {
  SignupForm(name: String, email: String, age: Int)
}

pub type SignupError {
  Field(name: String, detail: Detail)
}

pub type Detail {
  Empty
  TooShort(min: Int)
  OutOfRange(min: Int, max: Int)
}

fn validate_name(raw: String) -> Validated(String, SignupError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check =
    rules.not_empty(Empty)
    |> validator.guard(rules.min_length(2, TooShort(2)))
    |> validator.label("name", Field)
  raw |> clean |> check
}

fn validate_email(raw: String) -> Validated(String, SignupError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check =
    rules.not_empty(Empty)
    |> validator.label("email", Field)
  raw |> clean |> check
}

fn validate_age(age: Int) -> Validated(Int, SignupError) {
  let check =
    rules.min_int(0, OutOfRange(0, 150))
    |> validator.both(rules.max_int(150, OutOfRange(0, 150)))
    |> validator.label("age", Field)
  check(age)
}

pub fn validate_signup(
  name: String,
  email: String,
  age: Int,
) -> Validated(SignupForm, SignupError) {
  validated.map3(
    SignupForm,
    validate_name(name),
    validate_email(email),
    validate_age(age),
  )
}

// validate_signup("", "", 200)
//   -> Invalid([
//        Field("name", Empty),
//        Field("email", Empty),
//        Field("age", OutOfRange(0, 150)),
//      ])
```

### Pattern matching with `rules.matches` / `matches_string`

`matches` and `matches_string` use `regexp.check` semantics — they
pass as long as the pattern hits **anywhere** in the input. A
pattern like `[0-9]+` will accept `"abc123def"` because the digit
run matches a substring. For the validation case (\"the **whole**
string must look like an email / slug / number\"), use the
`matches_fully` / `matches_fully_string` siblings, which compare
the matched span against the entire input.

Use `matches` when the regex is dynamic (built from user input or
config) — the `regexp.from_string` `Result` stays visible. Use
`matches_string` when the pattern is a literal at the call site:
the helper compiles internally and panics on a malformed literal,
which is a programmer error there is no useful recovery from.

```gleam
import dataprep/rules
import dataprep/validated.{type Validated}
import gleam/regexp
import gleam/result

pub type TagError {
  BadFormat
}

// Literal pattern with full-match semantics — the convenience
// helper compiles once at construction. No `let assert Ok(_)`
// boilerplate at the call site, and a substring hit on a partial
// pattern (like `[a-z0-9-]+`) does NOT silently slip through.
pub fn validate_tag(raw: String) -> Validated(String, TagError) {
  let check =
    rules.matches_fully_string(pattern: "[a-z0-9-]+", error: BadFormat)
  check(raw)
}

// Dynamic pattern — the caller controls the compile error.
pub fn validate_with(
  raw: String,
  pattern: String,
) -> Result(Validated(String, TagError), regexp.CompileError) {
  use re <- result.map(regexp.from_string(pattern))
  rules.matches(pattern: re, error: BadFormat)(raw)
}

// validate_tag("ok-1") -> Valid("ok-1")
// validate_tag("BAD!") -> Invalid([BadFormat])
```

More examples are available in the [doc/recipes/](https://github.com/nao1215/dataprep/tree/main/doc/recipes) directory of the repository.

## Modules

| Module | Responsibility |
|--------|---------------|
| `dataprep/prep` | Infallible transformations: `trim`, `lowercase`, `uppercase`, `collapse_space`, `replace`, `default`. Compose with `then` or `sequence`. |
| `dataprep/validator` | Checks without transformation: `check`, `predicate`, `both`, `all`, `alt`, `guard`, `map_error`, `label`, `each`, `optional`. |
| `dataprep/validated` | Applicative error accumulation: `map`, `map_error`, `and_then`, `from_result`, `from_result_map`, `to_result`, `map2`..`map5`, `sequence`, `traverse`, `traverse_indexed`. |
| `dataprep/non_empty_list` | At-least-one guarantee for error lists: `single`, `cons`, `append`, `concat`, `map`, `flat_map`, `to_list`, `from_list`. |
| `dataprep/rules` | Built-in rules: `not_empty`, `not_blank`, `matches`, `matches_string`, `matches_fully`, `matches_fully_string`, `min_length`, `max_length`, `length_between`, `min_int`, `max_int`, `min_float`, `max_float`, `non_negative_int`, `non_negative_float`, `one_of`, `equals`. |
| `dataprep/parse` | Parse helpers: `int`, `float`. Bridge `String` to typed `Validated` with custom error mapping. |

## Composition overview

| Phase | Combinator | Errors | When to use |
|-------|-----------|--------|-------------|
| Prep | `prep.then` | (none) | Chain infallible transforms |
| Validate | `validator.both` / `all` | Accumulate all | Independent checks on same value |
| Validate | `validator.alt` | Accumulate on full failure | Accept alternative forms |
| Validate | `validator.guard` | Short-circuit | Skip if prerequisite fails |
| Combine | `validated.map2`..`map5` | Accumulate all | Build domain types from independent fields |
| Bridge | `validated.and_then` | Short-circuit | Parse then validate (type changes) |
| Bridge | `parse.int` / `parse.float` | Short-circuit | String to typed Validated in one step |
| Bridge | `raw \|> prep \|> validator` | (prep has none) | Apply infallible transform before validation |
| Collection | `validated.sequence` / `traverse` | Accumulate all | Validate a list of values |
| Collection | `validator.each` | Accumulate all | Apply a validator to every list element |
| Collection | `validator.optional` | (none if None) | Skip validation for absent values |

## Development

This project uses [mise](https://mise.jdx.dev/) to manage Gleam and Erlang versions, and [just](https://just.systems/) as a task runner.

```sh
mise install    # install Gleam and Erlang
just ci         # format check, typecheck, build, test
just test       # gleam test
just format     # gleam format
just check      # all checks without deps download
```

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](https://github.com/nao1215/dataprep/blob/main/CONTRIBUTING.md) for details.

## License

[MIT](https://github.com/nao1215/dataprep/blob/main/LICENSE)

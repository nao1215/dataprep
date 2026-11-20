# dataprep

[![CI](https://github.com/nao1215/dataprep/actions/workflows/ci.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/ci.yml)
[![Gitleaks](https://github.com/nao1215/dataprep/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/gitleaks.yml)
[![Trivy](https://github.com/nao1215/dataprep/actions/workflows/trivy.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/trivy.yml)
[![OSV-Scanner](https://github.com/nao1215/dataprep/actions/workflows/osv-scan.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/osv-scan.yml)
[![Hex](https://img.shields.io/hexpm/v/dataprep)](https://hex.pm/packages/dataprep)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/dataprep/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/dataprep)](https://hex.pm/packages/dataprep)
[![License](https://img.shields.io/github/license/nao1215/dataprep)](./LICENSE)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/nao1215/dataprep/badge)](https://scorecard.dev/viewer/?uri=github.com/nao1215/dataprep)

![dataprep_logo](https://raw.githubusercontent.com/nao1215/dataprep/main/doc/img/dataprep-logo-small.png)

Composable, type-driven preprocessing and validation combinators for Gleam. Prep functions transform, validators check, and the two never mix. Errors are your own types, and your own rules have the same power as the built-in ones. There is no schema, DSL or reflection.

## Requirements

- Gleam 1.14 or later
- Erlang/OTP 27 or later (when targeting Erlang)
- Node.js 18 or later (when targeting JavaScript)

The package has no FFI and no target-specific code, so one `Validator(a, e)` can run on the server (wisp, mist) and in the browser (Lustre forms).

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
// validate_user("", -1)           -> Invalid (errors: NameEmpty, AgeTooYoung)
```

Each `rules.*` function returns a validator (`fn(a) -> Validated(a, e)`), not a transformed value, so one rule cannot be piped into another. Combine them with `validator.both` to run both checks and collect every error, or with `validator.and_then` to skip later checks once one fails:

```gleam
import dataprep/rules
import dataprep/validator

// ✗ Won't compile — piping a validator fn into another rule
let check = rules.not_empty(Empty) |> rules.min_length(3, TooShort)

// ✓ Correct — combine validators explicitly
let check =
  rules.not_empty(Empty)
  |> validator.and_then(rules.min_length(3, TooShort))
```

## Examples

### Field validation with structured error context

`validator.label` attaches the field name to each error.

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
    |> validator.and_then(
      rules.min_length(3, TooShort(3))
      |> validator.both(rules.max_length(20, TooLong(20))),
    )
    |> validator.label("username", Field)

  raw |> clean |> check
}

// validate_username("  Al  ")
//   -> Invalid (errors: Field("username", TooShort(3)))
// validate_username("  Alice  ")
//   -> Valid("alice")
```

`Invalid` holds an opaque `NonEmptyList(e)`, so list-literal patterns do not work on it. Use `non_empty_list.head/1` for the first error or `non_empty_list.to_list/1` for all of them:

```gleam
import dataprep/non_empty_list
import dataprep/validated

let assert validated.Invalid(nel) = validate_username("  Al  ")
let first = non_empty_list.head(nel)
let all = non_empty_list.to_list(nel)
```

### Parse then validate

`validated.and_then` connects a parser that changes the type to a validator on the parsed value. Parsing stops at the first error; validation collects them all.

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

// validate_age("abc") -> Invalid (errors: NotAnInteger("abc"))
// validate_age("200") -> Invalid (errors: TooOld(150))
// validate_age("25")  -> Valid(25)
```

### Pattern matching with `rules.matches` / `matches_string`

`matches` and `matches_string` pass when the pattern hits anywhere in the input, as `regexp.check` does, so `[0-9]+` accepts `"abc123def"`. To require the whole string to match, use `matches_fully` / `matches_fully_string`.

There are three ways to build a regex validator:

- Pass a compiled `regexp.Regexp` to `matches` / `matches_fully`. A bad pattern shows up as the `Result` of `regexp.from_string`.
- Pass a literal to `matches_string` / `matches_fully_string`. It panics on a malformed pattern, so use it only for patterns hard-coded at the call site.
- For patterns from config or users, `matches_string_checked` / `matches_fully_string_checked` return `Result(Validator, RegexRuleError)`.

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
// validate_tag("BAD!") -> Invalid (errors: BadFormat)
```

### `default` vs `default_when_blank`

`prep.default(fallback)` replaces only the empty string `""`; whitespace-only input (`" "`, `"\t"`, `"\r\n"`) passes through. `prep.default_when_blank(fallback)` also replaces whitespace-only input.

```gleam
import dataprep/prep

let strict = prep.default("N/A")
strict("")          // "N/A"
strict(" ")         // " "          ← passed through
strict("\t")        // "\t"         ← passed through
strict("hi")        // "hi"

let lenient = prep.default_when_blank("N/A")
lenient("")         // "N/A"
lenient(" ")        // "N/A"        ← whitespace-only treated as blank
lenient("\t\n")     // "N/A"
lenient("  hi  ")   // "  hi  "     ← original input preserved on non-blank

// Want the trimmed form on the non-blank path? Compose explicitly:
let normalised = prep.trim() |> prep.then(first: _, next: prep.default("N/A"))
normalised("  hi  ") // "hi"
normalised("   ")    // "N/A"
```

More examples (signup form, API payload, Lustre form, wisp request, CSV row, query parameters) are in [doc/recipes/](https://github.com/nao1215/dataprep/tree/main/doc/recipes). [doc/recipes/custom_parsers.md](doc/recipes/custom_parsers.md) builds `positive_int`, `bounded_string`, `uuid_v4_lowercase` and `enum_of_strings_ci` parsers from the primitives.

## Modules

| Module | Responsibility |
|--------|---------------|
| `dataprep/prep` | Infallible transformations: `trim`, `lowercase`, `uppercase`, `collapse_space` (ASCII whitespace only), `collapse_unicode_space` (full Unicode `\s`), `replace` (panics on empty target), `replace_checked` (`Result`-returning sibling for runtime-supplied targets), `default`, `default_when_blank`. Compose with `then` or `sequence`. |
| `dataprep/validator` | Checks without transformation: `check`, `predicate`, `both`, `all`, `alt`, `and_then`, `map_error`, `label`, `each`, `optional`. |
| `dataprep/validated` | Applicative error accumulation: `map`, `map_error`, `and_then`, `from_result`, `from_result_map`, `to_result`, `map2`..`map5`, `combine2`..`combine5` (pipe-friendly, fixed arity), `and_map` (pipe-friendly applicative chain, any arity), `sequence`, `traverse`, `traverse_indexed`. |
| `dataprep/non_empty_list` | At-least-one guarantee for error lists: `single`, `cons`, `append`, `concat`, `map`, `flat_map`, `to_list`, `from_list`. |
| `dataprep/rules` | Built-in rules: `not_empty`, `not_blank`, `matches`, `matches_string`, `matches_string_checked`, `matches_fully`, `matches_fully_string`, `matches_fully_string_checked`, `min_length`, `max_length`, `length_between`, `min_int`, `max_int`, `min_float`, `max_float`, `non_negative_int`, `non_negative_float`, `one_of`, `equals`. |
| `dataprep/parse` | Parse helpers: `int`, `float`, `float_strict`. Bridge `String` to typed `Validated` with custom error mapping. |

## Composition overview

| Phase | Combinator | Errors | When to use |
|-------|-----------|--------|-------------|
| Prep | `prep.then` | (none) | Chain infallible transforms |
| Validate | `validator.both` / `all` | Accumulate all | Independent checks on same value |
| Validate | `validator.alt` | Accumulate on full failure | Accept alternative forms |
| Validate | `validator.and_then` | Short-circuit | Skip if prerequisite fails |
| Combine | `validated.map2`..`map5` / `combine2`..`combine5` / `and_map` | Accumulate all | Build domain types from independent fields (use `combineN` / `and_map` to pipe the first value in) |
| Bridge | `validated.and_then` | Short-circuit | Parse then validate (type changes) |
| Bridge | `parse.int` / `parse.float` | Short-circuit | String to typed Validated in one step |
| Bridge | `raw \|> prep \|> validator` | (prep has none) | Apply infallible transform before validation |
| Collection | `validated.sequence` / `traverse` | Accumulate all | Validate a list of values |
| Collection | `validator.each` | Accumulate all | Apply a validator to every list element |
| Collection | `validator.optional` | (none if None) | Skip validation for absent values |

## Scope

dataprep ships building blocks only: string transforms (`prep`), generic checks (`validator`, `rules`), error accumulation (`validated`, `non_empty_list`) and `String` to `Int` / `Float` parsers (`parse`). It does not provide:

- `email`, `url`, `uri` parsing (use a URI- or email-specific package)
- `iso_datetime` / time arithmetic (use a `gleam_time`-shaped package)
- `uuid` / `ulid` generation (use a UUID-shaped package)
- JSON shape validation (use a JSON-schema package)
- HTML / XML sanitisation (use a sanitiser package)

These have large specifications of their own. Compose the primitives into the parser you need, or add a domain package next to dataprep.

## Testing

| Technique | Bug class caught here |
|---|---|
| Examples and unit tests | [Wrong results at documented edge cases, drifted recipes](doc/testing.md#examples-and-unit-tests) |
| Laws | [Accumulation and short-circuit mixed up, wrong error order](doc/testing.md#laws) |
| Generated properties | [Broken identity, associativity, idempotence and round trips](doc/testing.md#generated-properties) |
| Mutation testing | [Assertions that miss a changed operator or branch](doc/testing.md#mutation-testing) |

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

## Verifying releases

Each GitHub Release attaches the Hex package tarball (`dataprep-<version>.tar`),
`checksums.txt`, a cosign signature bundle (`checksums.txt.sigstore.json`) and
build provenance (`dataprep-<version>.intoto.jsonl`). Download the assets, then:

```sh
gh attestation verify dataprep-<version>.tar --repo nao1215/dataprep

cosign verify-blob \
  --bundle checksums.txt.sigstore.json \
  --certificate-identity-regexp '^https://github\.com/nao1215/dataprep/\.github/workflows/release\.yml@refs/tags/v' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  checksums.txt
sha256sum --check checksums.txt
```

## License

[MIT](https://github.com/nao1215/dataprep/blob/main/LICENSE)

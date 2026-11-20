# Recipe: building your own parser

dataprep has no domain parsers such as `email` or `uuid`. These recipes build them from `prep`, `rules`, `validator` and `parse`; `test/dataprep/cookbook_test.gleam` checks each one.

The recipes share one error type so they can be combined in the same form:

```gleam
pub type Err {
  NotAnInteger(raw: String)
  NotPositive
  WrongLength(min: Int, max: Int, got: Int)
  NotUuid(raw: String)
  NotAllowed(raw: String)
}
```

## `positive_int`

Parse to `Int`, then require `> 0`. `validated.and_then` stops if the parse fails.

```gleam
import dataprep/parse
import dataprep/validated.{type Validated}
import dataprep/validator

fn positive_int(raw: String) -> Validated(Int, Err) {
  use n <- validated.and_then(parse.int(raw, NotAnInteger))
  validator.predicate(fn(x) { x > 0 }, NotPositive)(n)
}
```

## `bounded_string`

Trim, then require a length in `[min, max]`.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import gleam/string

fn bounded_string(
  min: Int,
  max: Int,
) -> fn(String) -> Validated(String, Err) {
  fn(raw: String) {
    let trimmed = prep.run(prep: prep.trim(), value: raw)
    rules.length_between(
      minimum: min,
      maximum: max,
      error: WrongLength(min, max, string.length(trimmed)),
    )(trimmed)
  }
}
```

## `uuid_v4_lowercase`

Trim and lowercase with `prep.then`, then match a regex.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}

fn uuid_v4_lowercase(raw: String) -> Validated(String, Err) {
  let normalized =
    prep.run(
      prep: prep.then(first: prep.trim(), next: prep.lowercase()),
      value: raw,
    )
  rules.matches_fully_string(
    pattern: "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}",
    error: NotUuid(raw),
  )(normalized)
}
```

## `enum_of_strings_ci`

Case-insensitive match against an allow-list passed by the caller.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}

fn enum_of_strings_ci(
  allowed: List(String),
) -> fn(String) -> Validated(String, Err) {
  fn(raw: String) {
    let normalized = prep.run(prep: prep.lowercase(), value: raw)
    rules.one_of(allowed: allowed, error: NotAllowed(raw))(normalized)
  }
}
```

Each recipe normalises the input with `prep.run`, checks it with a `rules` or `validator` combinator, and uses `validated.and_then` when a step depends on an earlier one.

# Architecture: Prep vs Validator

`dataprep` ships **two complementary concepts** that look superficially
similar but have different algebraic properties. New users routinely
hit a wall when they need both ("trim, lowercase, then check this is a
valid email") and don't yet know which side of the library handles
which step. This page is the single doc that resolves that.

If you only read one section: **Prep transforms input, Validator
checks input.** Wire them in that order.

## Decision table

| You want to ... | Reach for | Module |
|---|---|---|
| Lowercase / trim / collapse whitespace / replace substrings — operations that **always succeed** | `Prep(a) = fn(a) -> a` | `dataprep/prep` |
| Reject inputs that fail a rule, accumulating one or more typed errors | `Validator(a, e)` | `dataprep/validator` |
| First normalise, then check — the common form-validation shape | Compose `Prep` then `Validator` (recipe below) | both |

`Prep` and `Validator` form a clean two-stage pipeline. `Prep` runs
through `then` / `sequence`; `Validator` runs through `validator.both`
/ `validator.guard` / etc.; they meet at the boundary where you call
the validator on the prep'd value.

## Why two types?

- `Prep(a) = fn(a) -> a`. **Total**, no `Result`, no errors. Composes
  with `prep.then` / `prep.sequence` as a monoid: combining two preps
  is just function composition. No error plumbing means the call site
  is clean — `clean(name)` returns a `String`, not a `Result(String,
  _)`.
- `Validator(a, e) = fn(a) -> Validated(a, e)`. **Fallible**, returns
  `Validated(a, e)` (= `Valid(a) | Invalid(NonEmptyList(e))`).
  Composes monadically via `validator.both` (accumulate) and
  `validator.guard` (short-circuit). Errors are *your* domain types,
  not strings.

Splitting them keeps each type's algebra clean. A single
`fn(a) -> Result(a, e)` would force every transform to thread the
error type, even when the transform itself can never fail. That's
the *Prep infallibility contract*: by guaranteeing transforms never
fail, the caller never has to handle a `Result(_, _)` from
`prep.lowercase`. Validation lives in its own type with its own
algebra, and the boundary between them is explicit.

The cost of the split: there is no `Prep`-shaped fallible operation.
A check that wants to reject input is a `Validator`, full stop. The
`Prep` family does not include a `prep.parse_int` because parsing can
fail — that lives in `dataprep/parse` which returns a `Validated(Int,
e)` and bridges into the `Validator` world via `validated.and_then`.

## Composition recipe

The canonical pipeline:

1. **Build a `Prep`** with the normalisations the field needs.
   Compose with `prep.then` (left-to-right) or `prep.sequence`.
2. **Apply the prep** to the raw input to get a normalised value.
3. **Build a `Validator`** with the rules the normalised value must
   satisfy. Compose with `validator.both` (accumulate) /
   `validator.guard` (short-circuit) / `validator.label` (attach
   field name).
4. **Apply the validator** to the prep'd value to get a
   `Validated(a, e)`.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator

pub type FormError {
  Field(name: String, detail: Detail)
}

pub type Detail {
  Empty
  TooShort(min: Int)
  TooLong(max: Int)
}

pub fn validate_username(raw: String) -> Validated(String, FormError) {
  // Step 1: build the prep
  let clean =
    prep.trim()
    |> prep.then(first: _, next: prep.lowercase())
    |> prep.then(first: _, next: prep.collapse_space())

  // Step 3: build the validator
  let check =
    rules.not_empty(Empty)
    |> validator.guard(
      rules.min_length(3, TooShort(3))
      |> validator.both(rules.max_length(20, TooLong(20))),
    )
    |> validator.label("username", Field)

  // Steps 2 + 4: apply prep, then validator
  raw
  |> clean
  |> check
}

// validate_username("  AlICE  ") -> Valid("alice")
// validate_username("Al")        -> Invalid([Field("username", TooShort(3))])
// validate_username("")          -> Invalid([Field("username", Empty)])
```

## When the rules are fallible *and* type-changing

Some validation steps want to **change the type** as well as fail
(e.g. parse `"42"` into `42 : Int`). The `dataprep/parse` module
covers that: it produces a `Validated(b, e)` directly, and you bridge
into the rest of the validator pipeline with `validated.and_then`:

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
```

Reach for `Prep` when the operation is total. Reach for `Validator`
when the operation can reject. Reach for `parse` + `and_then` when the
operation can also change the type.

## Worked end-to-end pipeline

A user-signup form combining `Prep` (normalisation), `Validator`
(string rules), `parse` (parse-then-validate), and field labelling
into a single domain type:

```gleam
import dataprep/parse
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
  NotAnInteger(raw: String)
  OutOfRange(min: Int, max: Int)
}

pub fn validate_signup(
  raw_name: String,
  raw_email: String,
  raw_age: String,
) -> Validated(SignupForm, SignupError) {
  let normalise =
    prep.trim() |> prep.then(first: _, next: prep.lowercase())

  let name_check =
    rules.not_empty(Empty)
    |> validator.guard(rules.min_length(2, TooShort(2)))
    |> validator.label("name", Field)

  let email_check =
    rules.not_empty(Empty)
    |> validator.label("email", Field)

  let age_validated =
    parse.int(raw_age, fn(_) { Field("age", NotAnInteger(raw_age)) })
    |> validated.and_then(
      rules.min_int(0, OutOfRange(0, 150))
      |> validator.both(rules.max_int(150, OutOfRange(0, 150)))
      |> validator.label("age", Field),
    )

  validated.map3(
    SignupForm,
    raw_name |> normalise |> name_check,
    raw_email |> normalise |> email_check,
    age_validated,
  )
}
```

## See also

- [`prep.gleam`](../src/dataprep/prep.gleam) — the `Prep` family
- [`validator.gleam`](../src/dataprep/validator.gleam) — the
  `Validator` family
- [`parse.gleam`](../src/dataprep/parse.gleam) — type-changing
  parsing returning `Validated(b, e)`
- [`laws.md`](./laws.md) — documented behavioural laws of `Validator`
  and `Validated`
- [`recipes/`](./recipes/) — first-party recipes (Wisp request,
  Lustre form)

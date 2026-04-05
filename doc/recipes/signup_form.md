# Recipe: Signup Form Validation

Validate a signup form with name, email, and password fields.
Each field is preprocessed, validated independently, and errors
are accumulated with field labels.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator
import gleam/string

pub type SignupForm {
  SignupForm(name: String, email: String, password: String)
}

pub type FormError {
  Field(name: String, detail: FieldDetail)
}

pub type FieldDetail {
  Empty
  TooShort(min: Int)
  TooLong(max: Int)
  NoAtSign
}

// --- Field processors ---

fn validate_name(raw: String) -> Validated(String, FormError) {
  let clean =
    prep.sequence([prep.trim(), prep.lowercase(), prep.collapse_space()])
  let check =
    rules.not_empty(Empty)
    |> validator.guard(
      rules.min_length(2, TooShort(2))
      |> validator.both(rules.max_length(50, TooLong(50))),
    )
    |> validator.label("name", Field)

  raw |> clean |> check
}

fn validate_email(raw: String) -> Validated(String, FormError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check =
    rules.not_empty(Empty)
    |> validator.guard(
      validator.predicate(fn(s) { string.contains(s, "@") }, NoAtSign),
    )
    |> validator.label("email", Field)

  raw |> clean |> check
}

fn validate_password(raw: String) -> Validated(String, FormError) {
  let check =
    rules.not_empty(Empty)
    |> validator.guard(
      rules.min_length(8, TooShort(8))
      |> validator.both(rules.max_length(128, TooLong(128))),
    )
    |> validator.label("password", Field)

  check(raw)
}

// --- Combine ---

pub fn validate_signup(
  name: String,
  email: String,
  password: String,
) -> Validated(SignupForm, FormError) {
  validated.map3(
    SignupForm,
    validate_name(name),
    validate_email(email),
    validate_password(password),
  )
}

// validate_signup("", "bad", "short")
//   -> Invalid([
//        Field("name", Empty),
//        Field("email", NoAtSign),
//        Field("password", TooShort(8)),
//      ])
//
// validate_signup("  Alice  ", "ALICE@EXAMPLE.COM", "securepass123")
//   -> Valid(SignupForm("alice", "alice@example.com", "securepass123"))
```

Key patterns used:
- `prep.sequence` for multi-step normalization
- `validator.guard` to skip length checks on empty strings
- `validator.both` for independent checks on the same field
- `validator.label` to tag errors with field names
- `validated.map3` to combine three fields with error accumulation

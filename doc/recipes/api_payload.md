# Recipe: API Payload Validation

Validate a JSON API request payload after decoding.
Demonstrates alt (accept multiple formats) and guard
(prerequisite checks before expensive validation).

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator
import gleam/list
import gleam/string

pub type CreatePostRequest {
  CreatePostRequest(title: String, slug: String, status: String)
}

pub type ApiError {
  Field(name: String, detail: ApiDetail)
}

pub type ApiDetail {
  Required
  TooShort(min: Int)
  TooLong(max: Int)
  InvalidSlug
  InvalidUuid
  InvalidIdFormat
  InvalidStatus
}

// --- Slug / UUID-like checks ---

fn is_slug(s: String) -> Bool {
  let chars = string.to_graphemes(s)
  chars != []
  && list.all(chars, fn(c) {
    c == "-" || { c >= "a" && c <= "z" } || { c >= "0" && c <= "9" }
  })
}

fn is_uuid_like(s: String) -> Bool {
  string.length(s) == 36 && string.contains(s, "-")
}

// --- Field processors ---

fn validate_title(raw: String) -> Validated(String, ApiError) {
  let clean = prep.trim()
  let check =
    rules.not_empty(Required)
    |> validator.guard(
      rules.min_length(3, TooShort(3))
      |> validator.both(rules.max_length(200, TooLong(200))),
    )
    |> validator.label("title", Field)

  raw |> clean |> check
}

fn validate_slug(raw: String) -> Validated(String, ApiError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())

  // non-empty guard, then accept either a slug or a UUID
  let check =
    rules.not_empty(Required)
    |> validator.guard(
      validator.predicate(is_slug, InvalidSlug)
      |> validator.alt(validator.predicate(is_uuid_like, InvalidUuid))
      |> validator.map_error(fn(_) { InvalidIdFormat }),
    )
    |> validator.label("slug", Field)

  raw |> clean |> check
}

fn validate_status(raw: String) -> Validated(String, ApiError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check =
    rules.one_of(["draft", "published", "archived"], InvalidStatus)
    |> validator.label("status", Field)

  raw |> clean |> check
}

// --- Combine ---

pub fn validate_create_post(
  title: String,
  slug: String,
  status: String,
) -> Validated(CreatePostRequest, ApiError) {
  validated.map3(
    CreatePostRequest,
    validate_title(title),
    validate_slug(slug),
    validate_status(status),
  )
}

// validate_create_post("", "INVALID!!!", "unknown")
//   -> Invalid([
//        Field("title", Required),
//        Field("slug", InvalidIdFormat),
//        Field("status", InvalidStatus),
//      ])
//
// validate_create_post("My Post", "my-post", "draft")
//   -> Valid(CreatePostRequest("My Post", "my-post", "draft"))
//
// validate_create_post("My Post", "550e8400-e29b-41d4-a716-446655440000", "published")
//   -> Valid(CreatePostRequest("My Post", "550e8400-e29b-41d4-a716-446655440000", "published"))
```

Key patterns used:
- `validator.alt` to accept either slug or UUID format
- `validator.map_error` to simplify alt's accumulated errors into a single error
- `rules.one_of` for enum-like validation
- `validator.guard` to skip length checks when the field is empty
- `validated.map3` for field-level error accumulation

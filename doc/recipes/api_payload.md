# Recipe: API Payload Validation

Validate a JSON API request payload after decoding.
Demonstrates `alt` (accept multiple formats), `matches` with
pre-compiled regex, `optional` fields, and `each` for tag lists.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator
import gleam/list
import gleam/option.{type Option}
import gleam/regexp
import gleam/string

pub type CreatePostRequest {
  CreatePostRequest(
    title: String,
    slug: String,
    status: String,
    tags: List(String),
    subtitle: Option(String),
  )
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
  InvalidTag
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
    rules.not_blank(Required)
    |> validator.guard(rules.length_between(3, 200, TooShort(3)))
    |> validator.label("title", Field)

  raw |> clean |> check
}

fn validate_slug(raw: String) -> Validated(String, ApiError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
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

// Uses validator.each to validate every tag in the list.
fn validate_tags(tags: List(String)) -> Validated(List(String), ApiError) {
  let assert Ok(tag_re) = regexp.from_string("^[a-z0-9-]+$")
  let check_tag =
    rules.not_empty(Required)
    |> validator.guard(rules.matches(tag_re, InvalidTag))
  validator.each(check_tag)(tags)
  |> validated.map_error(fn(e) { Field("tags", e) })
}

// Uses validator.optional to skip validation when absent.
fn validate_subtitle(
  raw: Option(String),
) -> Validated(Option(String), ApiError) {
  let check =
    rules.not_blank(Required)
    |> validator.guard(rules.length_between(3, 100, TooShort(3)))
  validator.optional(check)(raw)
  |> validated.map_error(fn(e) { Field("subtitle", e) })
}

// --- Combine ---

pub fn validate_create_post(
  title: String,
  slug: String,
  status: String,
  tags: List(String),
  subtitle: Option(String),
) -> Validated(CreatePostRequest, ApiError) {
  validated.map5(
    CreatePostRequest,
    validate_title(title),
    validate_slug(slug),
    validate_status(status),
    validate_tags(tags),
    validate_subtitle(subtitle),
  )
}

// validate_create_post("", "INVALID!!!", "unknown", ["", "!!!"], option.None)
//   -> Invalid([
//        Field("title", Required),
//        Field("slug", InvalidIdFormat),
//        Field("status", InvalidStatus),
//        Field("tags", Required),
//        Field("tags", InvalidTag),
//      ])
//
// validate_create_post(
//   "My Post", "my-post", "draft", ["gleam", "fp"], option.Some("A subtitle"),
// )
//   -> Valid(CreatePostRequest(
//        "My Post", "my-post", "draft", ["gleam", "fp"], Some("A subtitle"),
//      ))
```

Key patterns used:
- `rules.not_blank` instead of `rules.not_empty` (rejects whitespace-only)
- `rules.length_between` instead of separate `min_length` + `max_length`
- `rules.matches` with pre-compiled `Regexp` (no runtime crash on bad patterns)
- `validator.each` to validate every element in the tags list
- `validator.optional` to skip validation when subtitle is None
- `validator.alt` to accept either slug or UUID format
- `validated.map5` for five-field accumulation

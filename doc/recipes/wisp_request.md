# Recipe: Wisp Request Validation

Validate a JSON-bodied HTTP request in a [Wisp](https://hexdocs.pm/wisp/)
handler, accumulate every field error in one response, and reject the
request with a structured 400 payload when validation fails.

This recipe shows where each `dataprep` building block fits in a real
server pipeline:

- `wisp.require_json` (or your decoder of choice) lifts the raw request
  body into a Gleam record with field-level types,
- `dataprep/prep` normalizes whitespace, case, and other "clean before
  validate" concerns,
- `dataprep/parse` converts string-valued query parameters into typed
  values without ad-hoc `int.parse |> result.map_error` chains,
- `dataprep/validator` + `dataprep/rules` express the business rules,
- `dataprep/validated.mapN` combines the per-field results so the
  response carries every error at once instead of just the first.

```gleam
import dataprep/non_empty_list
import dataprep/parse
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated, Invalid, Valid}
import dataprep/validator
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/string
import wisp.{type Request, type Response}

// --- Domain ----------------------------------------------------------------

pub type CreateUser {
  CreateUser(name: String, email: String, age: Int)
}

pub type ApiError {
  Field(name: String, detail: ApiDetail)
}

pub type ApiDetail {
  Required
  TooShort(min: Int)
  TooLong(max: Int)
  NoAtSign
  NotAnInteger(raw: String)
  TooYoung(min: Int)
}

// --- Decoded payload (raw shape arriving over the wire) --------------------

pub type CreateUserPayload {
  CreateUserPayload(name: String, email: String, age: String)
}

fn payload_decoder() -> decode.Decoder(CreateUserPayload) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  // age arrives as a string here so we can show parse.int handling end-to-end.
  use age <- decode.field("age", decode.string)
  decode.success(CreateUserPayload(name:, email:, age:))
}

// --- Per-field validators --------------------------------------------------

fn validate_name(raw: String) -> Validated(String, ApiError) {
  let clean =
    prep.sequence([prep.trim(), prep.collapse_space()])
  let check =
    rules.not_blank(Required)
    |> validator.guard(rules.length_between(2, 80, TooShort(2)))
    |> validator.label("name", Field)

  raw |> clean |> check
}

fn validate_email(raw: String) -> Validated(String, ApiError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check =
    rules.not_blank(Required)
    |> validator.guard(
      validator.predicate(fn(s) { string.contains(s, "@") }, NoAtSign),
    )
    |> validator.label("email", Field)

  raw |> clean |> check
}

fn validate_age(raw: String) -> Validated(Int, ApiError) {
  parse.int(prep.trim()(raw), NotAnInteger)
  |> validated.map_error(fn(e) { Field("age", e) })
  |> validated.and_then(
    rules.min_int(13, TooYoung(13))
    |> validator.label("age", Field),
  )
}

// --- Combine per-field results so the response shows EVERY error -----------

pub fn validate_create_user(
  payload: CreateUserPayload,
) -> Validated(CreateUser, ApiError) {
  validated.map3(
    CreateUser,
    validate_name(payload.name),
    validate_email(payload.email),
    validate_age(payload.age),
  )
}

// --- Wisp handler ----------------------------------------------------------
// require_json decodes the request body. From there the Validated value is
// the only thing we case on -- one match arm per outcome, no early returns.

pub fn handle_create_user(req: Request) -> Response {
  use json_body <- wisp.require_json(req)
  case decode.run(json_body, payload_decoder()) {
    Error(_) -> wisp.bad_request("invalid JSON shape")
    Ok(payload) ->
      case validate_create_user(payload) {
        Valid(user) -> create_user_in_db(user)
        Invalid(errors) -> error_response(errors)
      }
  }
}

fn error_response(errors) -> Response {
  // Render the accumulated errors back as a JSON body. Every failing field
  // appears at once -- that's the whole point of using validated.mapN
  // instead of and_then.
  let body =
    json.object([
      #("errors", json.array(non_empty_list.to_list(errors), encode_error)),
    ])
  wisp.json_response(json.to_string_tree(body), 400)
}

fn encode_error(err: ApiError) -> json.Json {
  let Field(name, detail) = err
  json.object([
    #("field", json.string(name)),
    #("detail", json.string(format_detail(detail))),
  ])
}

fn format_detail(detail: ApiDetail) -> String {
  case detail {
    Required -> "required"
    TooShort(min) -> "must be at least " <> int.to_string(min) <> " characters"
    TooLong(max) -> "must be at most " <> int.to_string(max) <> " characters"
    NoAtSign -> "must contain @"
    NotAnInteger(raw) -> "not an integer: " <> raw
    TooYoung(min) -> "must be at least " <> int.to_string(min)
  }
}
```

Example responses:

```text
POST /users  { "name": "", "email": "bad", "age": "x" }
-> 400  {
     "errors": [
       { "field": "name",  "detail": "required" },
       { "field": "email", "detail": "must contain @" },
       { "field": "age",   "detail": "not an integer: x" }
     ]
   }

POST /users  { "name": "Alice", "email": "ALICE@EXAMPLE.COM", "age": "30" }
-> 200  Valid(CreateUser("Alice", "alice@example.com", 30))
```

## Query parameters

For `GET` endpoints the same shape applies: pull the raw strings off
`wisp.get_query(req)`, then push them through per-field validators that
use `parse.int` / `parse.float` for the type coercion. See
[`query_params.md`](./query_params.md) for a focused query-parameter
recipe.

## Multipart / form fields

For multipart form posts, use Wisp's `wisp.require_form(req)` to pull
the form values, then validate exactly as above. Each form field is a
`String`, so the same `prep` → `validator` → `validated.mapN` shape
applies. For repeated fields (e.g. `tags[]`), use `validator.each` to
validate every value while accumulating.

## Key patterns used

- `prep.sequence` / `prep.trim` / `prep.lowercase` for canonicalization
  before validation
- `parse.int` instead of the `int.parse |> result.map_error` chain — keeps
  the validation pipeline reading top-to-bottom
- `validator.guard` so length checks don't fire on empty inputs (the
  user already gets a `Required` error)
- `validator.label` with a `Field` wrapper so every error carries the
  field name the API consumer needs
- `validated.map3` (or `mapN`) to accumulate every field error in one
  response, rather than `and_then` which would short-circuit and only
  report the first failure

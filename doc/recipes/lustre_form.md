# Recipe: Lustre Form Validation

Validate a [Lustre](https://hexdocs.pm/lustre/) browser form on submit,
keep per-field error messages in the model, and render them inline next
to each input.

This recipe shows the same `dataprep` building blocks as the Wisp recipe
applied to a browser-side flow:

- the model holds raw `String` field values plus a `dict` of accumulated
  errors,
- `dataprep/prep` normalizes whitespace before validation,
- `dataprep/rules` + `dataprep/validator` express the per-field rules,
- `dataprep/validated.mapN` accumulates errors so the user sees every
  problem at once instead of one at a time,
- the same validator code can later be lifted into a shared module and
  reused from a Wisp handler on the server (see [`wisp_request.md`](./wisp_request.md)).

```gleam
import dataprep/non_empty_list
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated, Invalid, Valid}
import dataprep/validator
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/attribute.{class, name, type_, value}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// --- Domain ----------------------------------------------------------------

pub type Profile {
  Profile(display_name: String, email: String, bio: String)
}

pub type FieldError {
  Required
  TooShort(min: Int)
  TooLong(max: Int)
  NoAtSign
}

// --- Model -----------------------------------------------------------------

pub type Model {
  Model(
    display_name: String,
    email: String,
    bio: String,
    // Errors live in a dict keyed by field name so the view can look up
    // "what is wrong with this specific input?" in O(1).
    errors: Dict(String, List(FieldError)),
    saved: Bool,
  )
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  #(Model("", "", "", dict.new(), False), effect.none())
}

// --- Messages --------------------------------------------------------------

pub type Msg {
  UserChangedDisplayName(String)
  UserChangedEmail(String)
  UserChangedBio(String)
  UserSubmitted
}

// --- Per-field validators (the entire dataprep surface lives here) --------

fn validate_display_name(raw: String) -> Validated(String, FieldError) {
  let clean =
    prep.sequence([prep.trim(), prep.collapse_space()])
  let check =
    rules.not_blank(Required)
    |> validator.guard(rules.length_between(2, 50, TooShort(2)))

  raw |> clean |> check
}

fn validate_email(raw: String) -> Validated(String, FieldError) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check =
    rules.not_blank(Required)
    |> validator.guard(
      validator.predicate(fn(s) { string.contains(s, "@") }, NoAtSign),
    )

  raw |> clean |> check
}

fn validate_bio(raw: String) -> Validated(String, FieldError) {
  // Optional field at the dataprep layer would use validator.optional
  // around an Option(String). Here the empty string is a valid bio,
  // and we only need a length cap.
  rules.max_length(280, TooLong(280))(prep.trim()(raw))
}

fn validate_profile(model: Model) -> Validated(Profile, #(String, FieldError)) {
  // The mapN combination accumulates errors from every field. We tag
  // each branch with its field name with map_error so the view can
  // group errors by input.
  validated.map3(
    Profile,
    validate_display_name(model.display_name)
      |> validated.map_error(fn(e) { #("display_name", e) }),
    validate_email(model.email)
      |> validated.map_error(fn(e) { #("email", e) }),
    validate_bio(model.bio)
      |> validated.map_error(fn(e) { #("bio", e) }),
  )
}

// --- Update ----------------------------------------------------------------

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserChangedDisplayName(value) -> #(
      Model(..model, display_name: value, saved: False),
      effect.none(),
    )
    UserChangedEmail(value) -> #(
      Model(..model, email: value, saved: False),
      effect.none(),
    )
    UserChangedBio(value) -> #(
      Model(..model, bio: value, saved: False),
      effect.none(),
    )

    UserSubmitted ->
      case validate_profile(model) {
        Valid(_profile) -> #(
          Model(..model, errors: dict.new(), saved: True),
          // Hand off to whatever side-effect saves the profile -- HTTP
          // request, local storage, lustre/server-component msg, etc.
          effect.none(),
        )
        Invalid(errors) -> #(
          Model(..model, errors: group_by_field(errors), saved: False),
          effect.none(),
        )
      }
  }
}

fn group_by_field(
  errors: non_empty_list.NonEmptyList(#(String, FieldError)),
) -> Dict(String, List(FieldError)) {
  // Fold the accumulated errors into a dict keyed by field name so the
  // view can render "errors for THIS input" in one lookup.
  list.fold(non_empty_list.to_list(errors), dict.new(), fn(acc, pair) {
    let #(field, err) = pair
    dict.upsert(acc, field, fn(existing) {
      case existing {
        Some(es) -> list.append(es, [err])
        None -> [err]
      }
    })
  })
}

// --- View ------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  html.form([event.on_submit(UserSubmitted)], [
    field_view(
      "Display name",
      "display_name",
      model.display_name,
      UserChangedDisplayName,
      model.errors,
    ),
    field_view(
      "Email",
      "email",
      model.email,
      UserChangedEmail,
      model.errors,
    ),
    field_view("Bio", "bio", model.bio, UserChangedBio, model.errors),
    html.button([type_("submit")], [element.text("Save profile")]),
    case model.saved {
      True -> html.p([class("ok")], [element.text("Saved.")])
      False -> element.none()
    },
  ])
}

fn field_view(
  label: String,
  field_name: String,
  current: String,
  on_change: fn(String) -> Msg,
  errors: Dict(String, List(FieldError)),
) -> Element(Msg) {
  html.label([], [
    element.text(label),
    html.input([
      type_("text"),
      name(field_name),
      value(current),
      event.on_input(on_change),
    ]),
    case dict.get(errors, field_name) {
      Ok(messages) ->
        html.ul(
          [class("errors")],
          list.map(messages, fn(e) {
            html.li([], [element.text(format_error(e))])
          }),
        )
      Error(_) -> element.none()
    },
  ])
}

fn format_error(err: FieldError) -> String {
  case err {
    Required -> "Required."
    TooShort(min) -> "Must be at least " <> int.to_string(min) <> " chars."
    TooLong(max) -> "Must be at most " <> int.to_string(max) <> " chars."
    NoAtSign -> "Must contain @."
  }
}
```

Example states:

```text
On submit with display_name="", email="bad", bio="...":
  errors -> {
    "display_name": [Required],
    "email":        [NoAtSign],
  }
  view -> renders the validation message under each input.

On submit with display_name="Alice", email="alice@example.com", bio="...":
  errors -> {}     (cleared)
  saved  -> True
  view   -> renders "Saved." below the form.
```

## Sharing validators with the server

Because `dataprep` is target-agnostic, the per-field validators
(`validate_display_name`, `validate_email`, ...) can live in a shared
module that compiles on both the BEAM and JavaScript targets. The Wisp
handler in [`wisp_request.md`](./wisp_request.md) and the Lustre form
above can `import` the same module and stay in sync without duplicating
business rules.

The recommended split:

```text
src/myapp/profile/rules.gleam      # shared: dataprep validators only
src/myapp/server/profile_api.gleam # imports rules.gleam, returns 400
src/myapp/web/profile_form.gleam   # imports rules.gleam, renders errors
```

## Validate on submit, not on every keystroke

The example only validates inside the `UserSubmitted` branch. That keeps
the typing experience quiet and ensures the user sees the full set of
errors at once when they ask for it. If you want live feedback, run the
validator from inside `UserChangedX` and store the result in the model —
the validator code does not change, only when it runs.

## Key patterns used

- `prep.sequence` / `prep.trim` / `prep.lowercase` for canonicalization
  before validation
- `validator.guard` so length checks don't fire on empty inputs (the
  user already gets a `Required` error)
- `validated.map3` to accumulate every field error in one go, so the
  view can render them all at once
- `validated.map_error` to tag each error with the field name the view
  needs to render it under the right input
- The same validator module can be reused from a Wisp handler — see
  [`wisp_request.md`](./wisp_request.md)

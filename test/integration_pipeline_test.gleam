//// Integration tests for the canonical Prep → Validator pipeline
//// documented in `doc/architecture.md`. These exist so the recipe
//// snippet on the architecture page cannot drift out of sync with
//// the actual API: every helper used in the recipe is exercised
//// here, and CI catches the moment a signature shifts.

import dataprep/non_empty_list
import dataprep/parse
import dataprep/prep
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator

// ---------------------------------------------------------------------------
// Decision-table sanity checks: each module's primary shape.
// ---------------------------------------------------------------------------

pub fn prep_is_total_test() -> Nil {
  // Prep always returns the same type; never produces errors.
  let prepper = prep.lowercase()
  assert prepper("HELLO") == "hello"
  assert prepper("") == ""
}

pub fn validator_returns_validated_test() -> Nil {
  // Validator returns Validated(a, e); on success the value is
  // returned unchanged.
  let check = rules.not_empty(EmptyName)
  assert check("hi") == Valid("hi")
  assert check("") == Invalid(non_empty_list.single(EmptyName))
}

// ---------------------------------------------------------------------------
// Pipeline recipe: prep then validator.
// Mirrors the username example in doc/architecture.md exactly.
// ---------------------------------------------------------------------------

pub type Detail {
  Empty
  TooShort(min: Int)
  TooLong(max: Int)
}

pub type FormError {
  Field(name: String, detail: Detail)
}

fn validate_username(raw: String) -> validated.Validated(String, FormError) {
  let clean =
    prep.trim()
    |> prep.then(first: _, next: prep.lowercase())
    |> prep.then(first: _, next: prep.collapse_space())

  let check =
    rules.not_empty(Empty)
    |> validator.guard(
      rules.min_length(3, TooShort(3))
      |> validator.both(rules.max_length(20, TooLong(20))),
    )
    |> validator.label("username", Field)

  raw |> clean |> check
}

pub fn pipeline_recipe_happy_path_test() -> Nil {
  // Prep normalises whitespace + case; the cleaned value passes the
  // validator chain.
  assert validate_username("  AlICE  ") == Valid("alice")
}

pub fn pipeline_recipe_too_short_test() -> Nil {
  // The cleaned value is "al" (length 2). min_length(3) fails;
  // validator.label wraps the detail with "username".
  assert validate_username("Al")
    == Invalid(non_empty_list.single(Field("username", TooShort(3))))
}

pub fn pipeline_recipe_empty_short_circuits_test() -> Nil {
  // not_empty fires first; validator.guard skips the inner length
  // checks. Only the Empty detail is reported.
  assert validate_username("")
    == Invalid(non_empty_list.single(Field("username", Empty)))
}

pub fn pipeline_recipe_whitespace_only_routes_to_empty_test() -> Nil {
  // After trim, "  " becomes "" — empty triggers not_empty.
  assert validate_username("   ")
    == Invalid(non_empty_list.single(Field("username", Empty)))
}

// ---------------------------------------------------------------------------
// Type-changing step: parse then validate.
// Mirrors the `validate_age` example in doc/architecture.md.
// ---------------------------------------------------------------------------

pub type AgeError {
  NotAnInteger(raw: String)
  TooYoung(min: Int)
  TooOld(max: Int)
}

fn validate_age(raw: String) -> validated.Validated(Int, AgeError) {
  let check_range =
    rules.min_int(0, TooYoung(0))
    |> validator.both(rules.max_int(150, TooOld(150)))

  parse.int(raw, NotAnInteger)
  |> validated.and_then(check_range)
}

pub fn parse_then_validate_happy_path_test() -> Nil {
  assert validate_age("25") == Valid(25)
}

pub fn parse_then_validate_parse_failure_short_circuits_test() -> Nil {
  // parse failure short-circuits — the range checks never run.
  assert validate_age("abc")
    == Invalid(non_empty_list.single(NotAnInteger("abc")))
}

pub fn parse_then_validate_range_failure_test() -> Nil {
  assert validate_age("200") == Invalid(non_empty_list.single(TooOld(150)))
}

// ---------------------------------------------------------------------------
// Decision-table check: a sentinel error type used only by
// `validator_returns_validated_test`.
// ---------------------------------------------------------------------------

pub type DecisionTableError {
  EmptyName
}

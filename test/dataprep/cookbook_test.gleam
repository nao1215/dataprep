//// Verifies that the recipes documented in README's "Building your own
//// parser" section compile and behave as advertised. Each recipe is a
//// composition of `prep` / `rules` / `validator` / `parse` primitives —
//// no new dataprep functionality is introduced here.

import dataprep/non_empty_list
import dataprep/parse
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated, Invalid, Valid}
import dataprep/validator
import gleam/string

pub type Err {
  NotAnInteger(raw: String)
  NotPositive
  WrongLength(min: Int, max: Int, got: Int)
  NotUuid(raw: String)
  NotAllowed(raw: String)
}

// --- Recipe 1: positive_int ---
// Parse to Int, then enforce > 0.

fn positive_int(raw: String) -> Validated(Int, Err) {
  use n <- validated.and_then(parse.int(raw, NotAnInteger))
  validator.predicate(fn(x) { x > 0 }, NotPositive)(n)
}

pub fn cookbook_positive_int_pass_test() -> Nil {
  assert positive_int("42") == Valid(42)
}

pub fn cookbook_positive_int_zero_rejected_test() -> Nil {
  assert positive_int("0") == Invalid(non_empty_list.single(NotPositive))
}

pub fn cookbook_positive_int_negative_rejected_test() -> Nil {
  assert positive_int("-1") == Invalid(non_empty_list.single(NotPositive))
}

pub fn cookbook_positive_int_not_a_number_test() -> Nil {
  assert positive_int("abc")
    == Invalid(non_empty_list.single(NotAnInteger("abc")))
}

// --- Recipe 2: bounded_string ---
// Trim, then enforce length is in [min, max].

fn bounded_string(min: Int, max: Int) -> fn(String) -> Validated(String, Err) {
  fn(raw: String) {
    let trimmed = prep.run(prep: prep.trim(), value: raw)
    rules.length_between(
      minimum: min,
      maximum: max,
      error: WrongLength(min, max, string.length(trimmed)),
    )(trimmed)
  }
}

pub fn cookbook_bounded_string_in_range_test() -> Nil {
  assert bounded_string(3, 10)("  hello  ") == Valid("hello")
}

pub fn cookbook_bounded_string_too_short_test() -> Nil {
  assert bounded_string(5, 10)("hi")
    == Invalid(non_empty_list.single(WrongLength(5, 10, 2)))
}

// --- Recipe 3: uuid_v4_lowercase ---
// Trim + lowercase + regex match.

fn uuid_v4_lowercase(raw: String) -> Validated(String, Err) {
  let normalized =
    prep.run(
      prep: prep.then(first: prep.trim(), next: prep.lowercase()),
      value: raw,
    )
  rules.matches_string(
    pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    error: NotUuid(raw),
  )(normalized)
}

pub fn cookbook_uuid_lowercase_pass_test() -> Nil {
  assert uuid_v4_lowercase("550e8400-e29b-41d4-a716-446655440000")
    == Valid("550e8400-e29b-41d4-a716-446655440000")
}

pub fn cookbook_uuid_uppercase_normalized_test() -> Nil {
  // Uppercase input is normalised to lowercase before matching.
  assert uuid_v4_lowercase("550E8400-E29B-41D4-A716-446655440000")
    == Valid("550e8400-e29b-41d4-a716-446655440000")
}

pub fn cookbook_uuid_v1_rejected_test() -> Nil {
  // Version digit other than 4 is rejected.
  let raw = "550e8400-e29b-11d4-a716-446655440000"
  assert uuid_v4_lowercase(raw) == Invalid(non_empty_list.single(NotUuid(raw)))
}

// --- Recipe 4: enum_of_strings_ci ---
// Lowercase, then one_of allowed.

fn enum_of_strings_ci(
  allowed: List(String),
) -> fn(String) -> Validated(String, Err) {
  fn(raw: String) {
    let normalized = prep.run(prep: prep.lowercase(), value: raw)
    rules.one_of(allowed: allowed, error: NotAllowed(raw))(normalized)
  }
}

pub fn cookbook_enum_ci_match_test() -> Nil {
  let level_validator = enum_of_strings_ci(["debug", "info", "warn", "error"])
  assert level_validator("INFO") == Valid("info")
}

pub fn cookbook_enum_ci_no_match_test() -> Nil {
  let level_validator = enum_of_strings_ci(["debug", "info", "warn", "error"])
  assert level_validator("trace")
    == Invalid(non_empty_list.single(NotAllowed("trace")))
}

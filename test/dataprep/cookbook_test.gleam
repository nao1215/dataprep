//// Verifies that small parser recipes compose from dataprep and the
//// standard library without new dataprep functionality.

import dataprep
import gleam/int
import gleam/result
import gleam/string
import non_empty_list.{type NonEmptyList}

pub type Err {
  NotAnInteger(raw: String)
  NotPositive
  WrongLength(min: Int, max: Int, got: Int)
  NotUuid(raw: String)
  NotAllowed(raw: String)
}

// --- Recipe 1: positive_int ---
// Parse to Int, then enforce > 0.

fn positive_int(raw: String) -> Result(Int, NonEmptyList(Err)) {
  use n <- result.try(
    int.parse(raw)
    |> result.replace_error(non_empty_list.single(NotAnInteger(raw))),
  )
  dataprep.predicate(fn(x) { x > 0 }, otherwise: NotPositive)(n)
}

pub fn cookbook_positive_int_pass_test() -> Nil {
  assert positive_int("42") == Ok(42)
}

pub fn cookbook_positive_int_zero_rejected_test() -> Nil {
  assert positive_int("0") == Error(non_empty_list.single(NotPositive))
}

pub fn cookbook_positive_int_negative_rejected_test() -> Nil {
  assert positive_int("-1") == Error(non_empty_list.single(NotPositive))
}

pub fn cookbook_positive_int_not_a_number_test() -> Nil {
  assert positive_int("abc")
    == Error(non_empty_list.single(NotAnInteger("abc")))
}

// --- Recipe 2: bounded_string ---
// Trim, then enforce length is in [min, max] with one error value.

fn bounded_string(
  min: Int,
  max: Int,
) -> fn(String) -> Result(String, NonEmptyList(Err)) {
  fn(raw: String) {
    let trimmed = string.trim(raw)
    let error = WrongLength(min, max, string.length(trimmed))
    dataprep.both(
      dataprep.min_length(minimum: min, error:),
      dataprep.max_length(maximum: max, error:),
    )(trimmed)
  }
}

pub fn cookbook_bounded_string_in_range_test() -> Nil {
  assert bounded_string(3, 10)("  hello  ") == Ok("hello")
}

pub fn cookbook_bounded_string_too_short_test() -> Nil {
  assert bounded_string(5, 10)("hi")
    == Error(non_empty_list.single(WrongLength(5, 10, 2)))
}

// --- Recipe 3: uuid_v4_lowercase ---
// Trim + lowercase + regex match.

fn uuid_v4_lowercase(raw: String) -> Result(String, NonEmptyList(Err)) {
  let normalized = raw |> string.trim |> string.lowercase
  // nolint: assert_ok_pattern -- the UUID pattern is a fixed, known-valid literal
  let assert Ok(check) =
    dataprep.full_match(
      pattern: "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}",
      error: NotUuid(raw),
    )
    as "the UUID pattern compiles"
  check(normalized)
}

pub fn cookbook_uuid_lowercase_pass_test() -> Nil {
  assert uuid_v4_lowercase("550e8400-e29b-41d4-a716-446655440000")
    == Ok("550e8400-e29b-41d4-a716-446655440000")
}

pub fn cookbook_uuid_uppercase_normalized_test() -> Nil {
  // Uppercase input is normalised to lowercase before matching.
  assert uuid_v4_lowercase("550E8400-E29B-41D4-A716-446655440000")
    == Ok("550e8400-e29b-41d4-a716-446655440000")
}

pub fn cookbook_uuid_v1_rejected_test() -> Nil {
  // Version digit other than 4 is rejected.
  let raw = "550e8400-e29b-11d4-a716-446655440000"
  assert uuid_v4_lowercase(raw) == Error(non_empty_list.single(NotUuid(raw)))
}

// --- Recipe 4: enum_of_strings_ci ---
// Lowercase, then one_of allowed.

fn enum_of_strings_ci(
  allowed: List(String),
) -> fn(String) -> Result(String, NonEmptyList(Err)) {
  fn(raw: String) {
    let normalized = string.lowercase(raw)
    dataprep.one_of(allowed: allowed, error: NotAllowed(raw))(normalized)
  }
}

pub fn cookbook_enum_ci_match_test() -> Nil {
  let level_validator = enum_of_strings_ci(["debug", "info", "warn", "error"])
  assert level_validator("INFO") == Ok("info")
}

pub fn cookbook_enum_ci_no_match_test() -> Nil {
  let level_validator = enum_of_strings_ci(["debug", "info", "warn", "error"])
  assert level_validator("trace")
    == Error(non_empty_list.single(NotAllowed("trace")))
}

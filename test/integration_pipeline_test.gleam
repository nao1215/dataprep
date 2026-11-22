//// Integration tests for the normalise-then-validate pipeline: plain
//// string functions clean the input, then validators check it.

import dataprep
import gleam/int
import gleam/result
import gleam/string
import non_empty_list.{type NonEmptyList}

pub fn validator_returns_result_test() -> Nil {
  // A validator returns Result(a, NonEmptyList(e)); on success the value
  // is returned unchanged.
  let check = dataprep.not_empty(EmptyName)
  assert check("hi") == Ok("hi")
  assert check("") == Error(non_empty_list.single(EmptyName))
}

// ---------------------------------------------------------------------------
// Pipeline recipe: normalise, then validate.
// ---------------------------------------------------------------------------

pub type Detail {
  Empty
  TooShort(min: Int)
  TooLong(max: Int)
}

pub type FormError {
  Field(name: String, detail: Detail)
}

fn validate_username(raw: String) -> Result(String, NonEmptyList(FormError)) {
  let check =
    dataprep.not_empty(Empty)
    |> dataprep.and_then(
      dataprep.min_length(3, TooShort(3))
      |> dataprep.both(dataprep.max_length(20, TooLong(20))),
    )
    |> dataprep.map_error(with: fn(detail) { Field("username", detail) })

  raw
  |> string.trim
  |> string.lowercase
  |> dataprep.collapse_space
  |> check
}

pub fn pipeline_recipe_happy_path_test() -> Nil {
  // Normalising fixes whitespace and case; the cleaned value passes the
  // validator chain.
  assert validate_username("  AlICE  ") == Ok("alice")
}

pub fn pipeline_recipe_too_short_test() -> Nil {
  // The cleaned value is "al" (length 2). min_length(3) fails;
  // map_error wraps the detail with "username".
  assert validate_username("Al")
    == Error(non_empty_list.single(Field("username", TooShort(3))))
}

pub fn pipeline_recipe_empty_short_circuits_test() -> Nil {
  // not_empty fires first; and_then skips the inner length checks. Only
  // the Empty detail is reported.
  assert validate_username("")
    == Error(non_empty_list.single(Field("username", Empty)))
}

pub fn pipeline_recipe_whitespace_only_routes_to_empty_test() -> Nil {
  // After trim, "  " becomes "" — empty triggers not_empty.
  assert validate_username("   ")
    == Error(non_empty_list.single(Field("username", Empty)))
}

// ---------------------------------------------------------------------------
// Type-changing step: parse then validate.
// ---------------------------------------------------------------------------

pub type AgeError {
  NotAnInteger(raw: String)
  TooYoung(min: Int)
  TooOld(max: Int)
}

fn validate_age(raw: String) -> Result(Int, NonEmptyList(AgeError)) {
  let check_range =
    dataprep.min_int(0, TooYoung(0))
    |> dataprep.both(dataprep.max_int(150, TooOld(150)))

  int.parse(raw)
  |> result.replace_error(non_empty_list.single(NotAnInteger(raw)))
  |> result.try(check_range)
}

pub fn parse_then_validate_happy_path_test() -> Nil {
  assert validate_age("25") == Ok(25)
}

pub fn parse_then_validate_parse_failure_short_circuits_test() -> Nil {
  // parse failure short-circuits — the range checks never run.
  assert validate_age("abc")
    == Error(non_empty_list.single(NotAnInteger("abc")))
}

pub fn parse_then_validate_range_failure_test() -> Nil {
  assert validate_age("200") == Error(non_empty_list.single(TooOld(150)))
}

// ---------------------------------------------------------------------------
// Form recipe: validate two fields on their own and combine them.
// ---------------------------------------------------------------------------

pub type User {
  User(name: String, age: Int)
}

fn validate_user(
  name: String,
  age: String,
) -> Result(User, NonEmptyList(String)) {
  let name = dataprep.not_empty("name is required")(string.trim(name))
  let age =
    int.parse(age)
    |> result.replace_error(non_empty_list.single("age is not a number"))
    |> result.try(dataprep.min_int(18, "must be an adult"))
  dataprep.map2(name, age, with: User)
}

pub fn form_recipe_valid_test() -> Nil {
  assert validate_user(" Ann ", "30") == Ok(User("Ann", 30))
}

pub fn form_recipe_accumulates_both_fields_test() -> Nil {
  assert validate_user(" ", "x")
    == Error(non_empty_list.new("name is required", ["age is not a number"]))
}

// ---------------------------------------------------------------------------
// Sentinel error type used only by `validator_returns_result_test`.
// ---------------------------------------------------------------------------

pub type DecisionTableError {
  EmptyName
}

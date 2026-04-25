import dataprep/non_empty_list
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator
import gleam/regexp

type Err {
  IsBlank
  BadFormat
  BadLength
  TooSmallFloat
  TooBigFloat
  Negative
}

fn compile_regexp(pattern: String) -> regexp.Regexp {
  // nolint: assert_ok_pattern -- test regex literals are fixed and known-valid
  let assert Ok(compiled) = regexp.from_string(pattern)
  compiled
}

// --- not_blank ---

pub fn not_blank_pass_test() -> Nil {
  assert rules.not_blank(IsBlank)("hello") == Valid("hello")
}

pub fn not_blank_fail_empty_test() -> Nil {
  assert rules.not_blank(IsBlank)("") == Invalid(non_empty_list.single(IsBlank))
}

pub fn not_blank_fail_whitespace_test() -> Nil {
  assert rules.not_blank(IsBlank)("   ")
    == Invalid(non_empty_list.single(IsBlank))
}

pub fn not_blank_fail_tabs_newlines_test() -> Nil {
  assert case rules.not_blank(IsBlank)("\t\n  ") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn not_blank_pass_with_content_test() -> Nil {
  assert rules.not_blank(IsBlank)("  hello  ") == Valid("  hello  ")
}

// --- matches ---

pub fn matches_pass_test() -> Nil {
  let pattern = compile_regexp("^[a-z0-9]+$")
  assert rules.matches(pattern: pattern, error: BadFormat)("abc123")
    == Valid("abc123")
}

pub fn matches_fail_test() -> Nil {
  let pattern = compile_regexp("^[a-z]+$")
  assert rules.matches(pattern: pattern, error: BadFormat)("abc123")
    == Invalid(non_empty_list.single(BadFormat))
}

pub fn matches_empty_string_test() -> Nil {
  let pattern = compile_regexp("^.+$")
  assert case rules.matches(pattern: pattern, error: BadFormat)("") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn matches_with_guard_test() -> Nil {
  let pattern = compile_regexp("^[a-z]+$")
  let validator_under_test =
    rules.not_empty(IsBlank)
    |> validator.guard(
      pre: _,
      main: rules.matches(pattern: pattern, error: BadFormat),
    )
  assert validator_under_test("") == Invalid(non_empty_list.single(IsBlank))
  assert validator_under_test("ABC")
    == Invalid(non_empty_list.single(BadFormat))
  assert validator_under_test("abc") == Valid("abc")
}

// --- matches_string ---

pub fn matches_string_pass_test() -> Nil {
  assert rules.matches_string(pattern: "^[a-z0-9]+$", error: BadFormat)(
      "abc123",
    )
    == Valid("abc123")
}

pub fn matches_string_fail_test() -> Nil {
  assert rules.matches_string(pattern: "^[a-z]+$", error: BadFormat)("abc123")
    == Invalid(non_empty_list.single(BadFormat))
}

pub fn matches_string_compiles_pattern_once_test() -> Nil {
  // The returned validator is reusable; compilation happens once at
  // construction, not per element.
  let check = rules.matches_string(pattern: "^[a-z]+$", error: BadFormat)
  assert check("abc") == Valid("abc")
  assert check("ABC") == Invalid(non_empty_list.single(BadFormat))
}

// --- length_between ---

pub fn length_between_pass_test() -> Nil {
  assert rules.length_between(minimum: 2, maximum: 5, error: BadLength)("abc")
    == Valid("abc")
}

pub fn length_between_exact_min_test() -> Nil {
  assert rules.length_between(minimum: 2, maximum: 5, error: BadLength)("ab")
    == Valid("ab")
}

pub fn length_between_exact_max_test() -> Nil {
  assert rules.length_between(minimum: 2, maximum: 5, error: BadLength)("abcde")
    == Valid("abcde")
}

pub fn length_between_fail_short_test() -> Nil {
  assert case
    rules.length_between(minimum: 2, maximum: 5, error: BadLength)("a")
  {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn length_between_fail_long_test() -> Nil {
  assert case
    rules.length_between(minimum: 2, maximum: 5, error: BadLength)("abcdef")
  {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- min_float / max_float ---

pub fn min_float_pass_test() -> Nil {
  assert rules.min_float(minimum: 1.0, error: TooSmallFloat)(1.5) == Valid(1.5)
}

pub fn min_float_boundary_test() -> Nil {
  assert rules.min_float(minimum: 1.0, error: TooSmallFloat)(1.0) == Valid(1.0)
}

pub fn min_float_fail_test() -> Nil {
  assert case rules.min_float(minimum: 1.0, error: TooSmallFloat)(0.5) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn max_float_pass_test() -> Nil {
  assert rules.max_float(maximum: 10.0, error: TooBigFloat)(5.0) == Valid(5.0)
}

pub fn max_float_boundary_test() -> Nil {
  assert rules.max_float(maximum: 10.0, error: TooBigFloat)(10.0) == Valid(10.0)
}

pub fn max_float_fail_test() -> Nil {
  assert case rules.max_float(maximum: 10.0, error: TooBigFloat)(10.1) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn min_max_float_combined_test() -> Nil {
  let validator_under_test =
    rules.min_float(minimum: 0.0, error: TooSmallFloat)
    |> validator.both(
      first: _,
      second: rules.max_float(maximum: 100.0, error: TooBigFloat),
    )
  assert validator_under_test(50.0) == Valid(50.0)
  assert case validator_under_test(-0.1) {
    Invalid(_) -> True
    Valid(_) -> False
  }
  assert case validator_under_test(100.1) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- non_negative_int / non_negative_float ---

pub fn non_negative_int_pass_test() -> Nil {
  assert rules.non_negative_int(Negative)(0) == Valid(0)
  assert rules.non_negative_int(Negative)(42) == Valid(42)
}

pub fn non_negative_int_fail_test() -> Nil {
  assert rules.non_negative_int(Negative)(-1)
    == Invalid(non_empty_list.single(Negative))
}

pub fn non_negative_float_pass_test() -> Nil {
  assert rules.non_negative_float(Negative)(0.0) == Valid(0.0)
  assert rules.non_negative_float(Negative)(1.5) == Valid(1.5)
}

pub fn non_negative_float_fail_test() -> Nil {
  assert rules.non_negative_float(Negative)(-0.1)
    == Invalid(non_empty_list.single(Negative))
}

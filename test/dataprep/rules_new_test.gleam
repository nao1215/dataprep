import dataprep/non_empty_list
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator
import gleam/regexp

pub type Err {
  IsBlank
  BadFormat
  TooShort(min: Int)
  TooLong(max: Int)
  BadLength
  TooSmallFloat
  TooBigFloat
  Negative
}

// --- not_blank ---

pub fn not_blank_pass_test() {
  let assert Valid("hello") = rules.not_blank(IsBlank)("hello")
}

pub fn not_blank_fail_empty_test() {
  let assert Invalid(nel) = rules.not_blank(IsBlank)("")
  let assert [IsBlank] = non_empty_list.to_list(nel)
}

pub fn not_blank_fail_whitespace_test() {
  let assert Invalid(nel) = rules.not_blank(IsBlank)("   ")
  let assert [IsBlank] = non_empty_list.to_list(nel)
}

pub fn not_blank_fail_tabs_newlines_test() {
  let assert Invalid(_) = rules.not_blank(IsBlank)("\t\n  ")
}

pub fn not_blank_pass_with_content_test() {
  let assert Valid("  hello  ") = rules.not_blank(IsBlank)("  hello  ")
}

// --- matches ---

pub fn matches_pass_test() {
  let assert Ok(re) = regexp.from_string("^[a-z0-9]+$")
  let assert Valid("abc123") = rules.matches(re, BadFormat)("abc123")
}

pub fn matches_fail_test() {
  let assert Ok(re) = regexp.from_string("^[a-z]+$")
  let assert Invalid(nel) = rules.matches(re, BadFormat)("abc123")
  let assert [BadFormat] = non_empty_list.to_list(nel)
}

pub fn matches_empty_string_test() {
  let assert Ok(re) = regexp.from_string("^.+$")
  let assert Invalid(_) = rules.matches(re, BadFormat)("")
}

pub fn matches_with_guard_test() {
  let assert Ok(re) = regexp.from_string("^[a-z]+$")
  let v =
    rules.not_empty(IsBlank)
    |> validator.guard(rules.matches(re, BadFormat))
  let assert Invalid(nel) = v("")
  let assert [IsBlank] = non_empty_list.to_list(nel)
  let assert Invalid(nel2) = v("ABC")
  let assert [BadFormat] = non_empty_list.to_list(nel2)
  let assert Valid("abc") = v("abc")
}

// --- length_between ---

pub fn length_between_pass_test() {
  let assert Valid("abc") = rules.length_between(2, 5, BadLength)("abc")
}

pub fn length_between_exact_min_test() {
  let assert Valid("ab") = rules.length_between(2, 5, BadLength)("ab")
}

pub fn length_between_exact_max_test() {
  let assert Valid("abcde") = rules.length_between(2, 5, BadLength)("abcde")
}

pub fn length_between_fail_short_test() {
  let assert Invalid(_) = rules.length_between(2, 5, BadLength)("a")
}

pub fn length_between_fail_long_test() {
  let assert Invalid(_) = rules.length_between(2, 5, BadLength)("abcdef")
}

// --- min_float / max_float ---

pub fn min_float_pass_test() {
  let assert Valid(1.5) = rules.min_float(1.0, TooSmallFloat)(1.5)
}

pub fn min_float_boundary_test() {
  let assert Valid(1.0) = rules.min_float(1.0, TooSmallFloat)(1.0)
}

pub fn min_float_fail_test() {
  let assert Invalid(_) = rules.min_float(1.0, TooSmallFloat)(0.5)
}

pub fn max_float_pass_test() {
  let assert Valid(5.0) = rules.max_float(10.0, TooBigFloat)(5.0)
}

pub fn max_float_boundary_test() {
  let assert Valid(10.0) = rules.max_float(10.0, TooBigFloat)(10.0)
}

pub fn max_float_fail_test() {
  let assert Invalid(_) = rules.max_float(10.0, TooBigFloat)(10.1)
}

pub fn min_max_float_combined_test() {
  let v =
    rules.min_float(0.0, TooSmallFloat)
    |> validator.both(rules.max_float(100.0, TooBigFloat))
  let assert Valid(50.0) = v(50.0)
  let assert Invalid(_) = v(-0.1)
  let assert Invalid(_) = v(100.1)
}

// --- non_negative_int / non_negative_float ---

pub fn non_negative_int_pass_test() {
  let assert Valid(0) = rules.non_negative_int(Negative)(0)
  let assert Valid(42) = rules.non_negative_int(Negative)(42)
}

pub fn non_negative_int_fail_test() {
  let assert Invalid(nel) = rules.non_negative_int(Negative)(-1)
  let assert [Negative] = non_empty_list.to_list(nel)
}

pub fn non_negative_float_pass_test() {
  let assert Valid(0.0) = rules.non_negative_float(Negative)(0.0)
  let assert Valid(1.5) = rules.non_negative_float(Negative)(1.5)
}

pub fn non_negative_float_fail_test() {
  let assert Invalid(nel) = rules.non_negative_float(Negative)(-0.1)
  let assert [Negative] = non_empty_list.to_list(nel)
}

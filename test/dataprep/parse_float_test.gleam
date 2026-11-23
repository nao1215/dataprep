import dataprep
import gleam/list
import gleam/string

// --- basics ---

pub fn parse_float_pass_test() -> Nil {
  assert dataprep.parse_float("3.14") == Ok(3.14)
}

pub fn parse_float_negative_test() -> Nil {
  assert dataprep.parse_float("-1.5") == Ok(-1.5)
}

pub fn parse_float_zero_test() -> Nil {
  assert dataprep.parse_float("0.0") == Ok(0.0)
}

pub fn parse_float_fail_test() -> Nil {
  assert dataprep.parse_float("abc") == Error(Nil)
}

pub fn parse_float_fail_empty_test() -> Nil {
  assert dataprep.parse_float("") == Error(Nil)
}

// --- integer literals (#6) ---

pub fn parse_float_accepts_integer_literal_test() -> Nil {
  assert dataprep.parse_float("5") == Ok(5.0)
}

pub fn parse_float_accepts_negative_integer_literal_test() -> Nil {
  assert dataprep.parse_float("-7") == Ok(-7.0)
}

pub fn parse_float_accepts_zero_integer_literal_test() -> Nil {
  assert dataprep.parse_float("0") == Ok(0.0)
}

// --- scientific notation (#6) ---

pub fn parse_float_accepts_scientific_no_decimal_test() -> Nil {
  assert dataprep.parse_float("1e3") == Ok(1000.0)
}

pub fn parse_float_accepts_scientific_with_decimal_test() -> Nil {
  assert dataprep.parse_float("1.5e-2") == Ok(0.015)
}

pub fn parse_float_accepts_scientific_uppercase_e_test() -> Nil {
  assert dataprep.parse_float("5E3") == Ok(5000.0)
}

pub fn parse_float_accepts_scientific_negative_mantissa_test() -> Nil {
  assert dataprep.parse_float("-2e2") == Ok(-200.0)
}

pub fn parse_float_rejects_scientific_missing_exponent_test() -> Nil {
  assert dataprep.parse_float("5e") == Error(Nil)
}

pub fn parse_float_rejects_scientific_non_integer_exponent_test() -> Nil {
  assert dataprep.parse_float("1e1.5") == Error(Nil)
}

// --- scientific notation overflow (#77) ---
//
// A value past the IEEE 754 double range (~1.8e308) must return
// Error(Nil) instead of crashing on Erlang or becoming Infinity on
// JavaScript.

pub fn parse_float_accepts_exponent_at_upper_boundary_test() -> Nil {
  assert dataprep.parse_float("1e308") == Ok(1.0e308)
}

pub fn parse_float_rejects_exponent_just_past_upper_boundary_test() -> Nil {
  assert dataprep.parse_float("1e309") == Error(Nil)
}

pub fn parse_float_rejects_far_overflow_exponent_test() -> Nil {
  assert dataprep.parse_float("1.5e3000") == Error(Nil)
}

pub fn parse_float_rejects_overflow_exponent_with_negative_mantissa_test() -> Nil {
  assert dataprep.parse_float("-1e309") == Error(Nil)
}

pub fn parse_float_preserves_underflow_to_zero_test() -> Nil {
  // Underflow rounds to 0.0; only overflow is an error.
  assert dataprep.parse_float("1e-3000") == Ok(0.0)
}

// --- plain-integer overflow (#80) ---

pub fn parse_float_accepts_long_digit_at_upper_boundary_test() -> Nil {
  let raw = string.repeat("9", 308)
  // nolint: assert_ok_pattern -- a 308-digit integer literal stays within the IEEE 754 range
  let assert Ok(_) = dataprep.parse_float(raw)
  Nil
}

pub fn parse_float_rejects_long_digit_overflow_test() -> Nil {
  let raw = string.repeat("9", 309)
  assert dataprep.parse_float(raw) == Error(Nil)
}

pub fn parse_float_accepts_long_decimal_literal_test() -> Nil {
  // More than 308 characters, but not a plain integer: the decimal point
  // keeps it out of the integer-overflow guard, and its value is 1.0.
  let raw = "1." <> string.repeat("0", 320)
  assert dataprep.parse_float(raw) == Ok(1.0)
}

pub fn parse_float_rejects_far_overflow_long_digit_test() -> Nil {
  let raw = string.repeat("9", 1000)
  assert dataprep.parse_float(raw) == Error(Nil)
}

pub fn parse_float_rejects_negative_long_digit_overflow_test() -> Nil {
  let raw = "-" <> string.repeat("9", 309)
  assert dataprep.parse_float(raw) == Error(Nil)
}

// --- grammar ---

pub fn parse_float_scientific_explicit_plus_exponent_test() -> Nil {
  // Standard scientific notation accepts a leading `+` on the exponent.
  assert dataprep.parse_float("1.5e+2") == Ok(150.0)
}

pub fn parse_float_scientific_explicit_plus_exponent_integer_mantissa_test() -> Nil {
  assert dataprep.parse_float("5e+3") == Ok(5000.0)
}

pub fn parse_float_scientific_explicit_plus_exponent_uppercase_test() -> Nil {
  assert dataprep.parse_float("1.5E+10") == Ok(15_000_000_000.0)
}

pub fn parse_float_rejects_thousand_separator_comma_test() -> Nil {
  // Locale-formatted thousand separators must not slide through as
  // 1000x-too-small values.
  assert dataprep.parse_float("3,000") == Error(Nil)
}

pub fn parse_float_rejects_space_separator_test() -> Nil {
  assert dataprep.parse_float("3 000") == Error(Nil)
}

pub fn parse_float_rejects_trailing_letters_test() -> Nil {
  assert dataprep.parse_float("12.50abc") == Error(Nil)
}

pub fn parse_float_rejects_unit_suffix_test() -> Nil {
  assert dataprep.parse_float("3K") == Error(Nil)
}

pub fn parse_float_rejects_leading_dot_test() -> Nil {
  // The grammar requires digits before the dot.
  assert dataprep.parse_float(".5") == Error(Nil)
}

pub fn parse_float_rejects_trailing_dot_test() -> Nil {
  assert dataprep.parse_float("3.") == Error(Nil)
}

pub fn parse_float_rejects_double_dot_test() -> Nil {
  assert dataprep.parse_float("3.0.0") == Error(Nil)
}

pub fn parse_float_rejects_whitespace_around_value_test() -> Nil {
  // Parsing must not auto-trim; callers compose with
  // `string.trim` if they want to trim first.
  assert dataprep.parse_float("  3.14  ") == Error(Nil)
}

pub fn parse_float_accepts_thousand_separator_period_test() -> Nil {
  // "3.000" is unambiguously 3.0 in en_US locale and syntactically a
  // valid float. The grammar only catches structural
  // garbage; locale ambiguity inside a syntactically-valid float
  // cannot be resolved at this layer.
  assert dataprep.parse_float("3.000") == Ok(3.0)
}

// --- overflow decided by the result, not the exponent ---
//
// An exponent of 308 or less can still overflow once the mantissa is
// above 1.0. Erlang used to raise `badarith` and JavaScript returned
// `Ok(Infinity)`.

pub fn parse_float_rejects_mantissa_overflow_within_exponent_limit_test() -> Nil {
  assert dataprep.parse_float("2.0e308") == Error(Nil)
  assert dataprep.parse_float("10e308") == Error(Nil)
  assert dataprep.parse_float("-10e308") == Error(Nil)
}

pub fn parse_float_rejects_fractional_mantissa_overflow_test() -> Nil {
  assert dataprep.parse_float("2.0e308") == Error(Nil)
  assert dataprep.parse_float("9.9e308") == Error(Nil)
}

pub fn parse_float_rejects_plus_signed_long_digit_overflow_test() -> Nil {
  let raw = "+1" <> string.repeat("0", 309)
  assert dataprep.parse_float(raw) == Error(Nil)
}

pub fn parse_float_accepts_largest_finite_value_test() -> Nil {
  assert dataprep.parse_float("1.7976931348623157e308")
    == Ok(1.7976931348623157e308)
  assert dataprep.parse_float("17976931348623157e292")
    == Ok(1.7976931348623157e308)
}

pub fn parse_float_rounds_values_just_above_the_largest_float_down_test() -> Nil {
  // Below the midpoint between the largest float and 2^1024, a value
  // rounds to the largest float, as Python's float() and JavaScript's
  // Number() do. At the midpoint and above it overflows.
  assert dataprep.parse_float("1.797693134862315807e308")
    == Ok(1.7976931348623157e308)
  assert dataprep.parse_float("-1.797693134862315807e308")
    == Ok(-1.7976931348623157e308)
  assert dataprep.parse_float("1.79769313486231581e308") == Error(Nil)
}

pub fn parse_float_accepts_zero_with_huge_exponent_test() -> Nil {
  // The value is 0.0, which is finite, so it is not an overflow.
  assert dataprep.parse_float("0e999") == Ok(0.0)
  assert dataprep.parse_float("0e999") == Ok(0.0)
}

pub fn parse_float_accepts_finite_value_with_exponent_past_308_test() -> Nil {
  assert dataprep.parse_float("0.1e309") == Ok(1.0e308)
  assert dataprep.parse_float("0.1e309") == Ok(1.0e308)
}

pub fn parse_float_accepts_long_leading_zero_integer_test() -> Nil {
  let raw = string.repeat("0", 400) <> "5"
  assert dataprep.parse_float(raw) == Ok(5.0)
}

pub fn parse_float_underflows_far_negative_exponent_to_zero_test() -> Nil {
  // An exponent too large for a float used to crash Erlang in
  // `int.to_float`.
  let raw = "1e-" <> string.repeat("9", 400)
  assert dataprep.parse_float(raw) == Ok(0.0)
}

pub fn parse_float_rejects_huge_positive_exponent_test() -> Nil {
  let raw = "1e" <> string.repeat("9", 400)
  assert dataprep.parse_float(raw) == Error(Nil)
}

// --- rejects commas on both targets ---
//
// Erlang's `binary_to_float` reads `,` as a decimal point, so a parser
// that relied on it would accept "3,5" on Erlang only.

pub fn parse_float_rejects_decimal_comma_test() -> Nil {
  assert dataprep.parse_float("3,5") == Error(Nil)
  assert dataprep.parse_float("3,000") == Error(Nil)
  assert dataprep.parse_float("1,0e5") == Error(Nil)
}

pub fn parse_float_rejects_incomplete_shapes_test() -> Nil {
  ["-", "+1", "--1", "1e", "1e+", "1.e5", "1.5e-", "1.5e1.5", "1٥"]
  |> list.each(fn(raw) {
    assert dataprep.parse_float(raw) == Error(Nil)
  })
}

pub fn parse_float_reports_negative_zero_as_zero_test() -> Nil {
  ["-0", "-0.0", "-0e5", "-0.0e-3"]
  |> list.each(fn(raw) {
    assert dataprep.parse_float(raw) == dataprep.parse_float("0")
  })
}

pub fn parse_float_rejects_a_huge_digit_string_test() -> Nil {
  let raw = "1" <> string.repeat("0", 1_000_000)
  assert dataprep.parse_float(raw) == Error(Nil)
}

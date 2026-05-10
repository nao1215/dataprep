import dataprep/non_empty_list
import dataprep/parse
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator

type Err {
  NotAnInteger(raw: String)
  NotAFloat(raw: String)
  TooSmall(min: Int)
  TooBig(max: Int)
}

// --- parse.int ---

pub fn int_pass_test() -> Nil {
  assert parse.int("42", NotAnInteger) == Valid(42)
}

pub fn int_negative_test() -> Nil {
  assert parse.int("-10", NotAnInteger) == Valid(-10)
}

pub fn int_zero_test() -> Nil {
  assert parse.int("0", NotAnInteger) == Valid(0)
}

pub fn int_fail_test() -> Nil {
  assert parse.int("abc", NotAnInteger)
    == Invalid(non_empty_list.single(NotAnInteger("abc")))
}

pub fn int_fail_float_string_test() -> Nil {
  assert parse.int("1.5", NotAnInteger)
    == Invalid(non_empty_list.single(NotAnInteger("1.5")))
}

pub fn int_fail_empty_test() -> Nil {
  assert parse.int("", NotAnInteger)
    == Invalid(non_empty_list.single(NotAnInteger("")))
}

// --- parse.float ---

pub fn float_pass_test() -> Nil {
  assert parse.float("3.14", NotAFloat) == Valid(3.14)
}

pub fn float_negative_test() -> Nil {
  assert parse.float("-1.5", NotAFloat) == Valid(-1.5)
}

pub fn float_zero_test() -> Nil {
  assert parse.float("0.0", NotAFloat) == Valid(0.0)
}

pub fn float_fail_test() -> Nil {
  assert parse.float("abc", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("abc")))
}

pub fn float_fail_empty_test() -> Nil {
  assert parse.float("", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("")))
}

// --- parse.float leniency: integer literals (#6) ---

pub fn float_accepts_integer_literal_test() -> Nil {
  assert parse.float("5", NotAFloat) == Valid(5.0)
}

pub fn float_accepts_negative_integer_literal_test() -> Nil {
  assert parse.float("-7", NotAFloat) == Valid(-7.0)
}

pub fn float_accepts_zero_integer_literal_test() -> Nil {
  assert parse.float("0", NotAFloat) == Valid(0.0)
}

// --- parse.float leniency: scientific notation (#6) ---

pub fn float_accepts_scientific_no_decimal_test() -> Nil {
  assert parse.float("1e3", NotAFloat) == Valid(1000.0)
}

pub fn float_accepts_scientific_with_decimal_test() -> Nil {
  assert parse.float("1.5e-2", NotAFloat) == Valid(0.015)
}

pub fn float_accepts_scientific_uppercase_e_test() -> Nil {
  assert parse.float("5E3", NotAFloat) == Valid(5000.0)
}

pub fn float_accepts_scientific_negative_mantissa_test() -> Nil {
  assert parse.float("-2e2", NotAFloat) == Valid(-200.0)
}

pub fn float_rejects_scientific_missing_exponent_test() -> Nil {
  assert parse.float("5e", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("5e")))
}

pub fn float_rejects_scientific_non_integer_exponent_test() -> Nil {
  assert parse.float("1e1.5", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("1e1.5")))
}

pub fn float_rejects_garbage_with_e_test() -> Nil {
  assert parse.float("abc", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("abc")))
}

// --- parse.float scientific notation overflow (#77) ---
//
// `gleam/float.power` calls Erlang's `math:pow/2`, which raises `Badarith`
// once the result exceeds the IEEE 754 double range (~1.8e308). Before
// the fix, `parse.float("1e309", _)` panicked the calling actor instead
// of returning the `Invalid` shape the type signature promises.

pub fn float_accepts_exponent_at_upper_boundary_test() -> Nil {
  assert parse.float("1e308", NotAFloat) == Valid(1.0e308)
}

pub fn float_rejects_exponent_just_past_upper_boundary_test() -> Nil {
  assert parse.float("1e309", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("1e309")))
}

pub fn float_rejects_far_overflow_exponent_test() -> Nil {
  assert parse.float("1.5e3000", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("1.5e3000")))
}

pub fn float_rejects_overflow_exponent_with_negative_mantissa_test() -> Nil {
  assert parse.float("-1e309", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("-1e309")))
}

pub fn float_preserves_underflow_to_zero_test() -> Nil {
  // `math:pow(10, -3000)` underflows to 0.0 without raising Badarith,
  // so the lenient behaviour stays Valid(0.0) — only overflow is
  // funnelled into Invalid. This codifies the choice documented in
  // #77's "asymmetry" note.
  assert parse.float("1e-3000", NotAFloat) == Valid(0.0)
}

pub fn float_strict_rejects_overflow_exponent_test() -> Nil {
  assert parse.float_strict("1e309", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("1e309")))
}

// --- parse.float_strict (#67) ---

pub fn float_strict_pass_test() -> Nil {
  assert parse.float_strict("3.14", NotAFloat) == Valid(3.14)
}

pub fn float_strict_negative_test() -> Nil {
  assert parse.float_strict("-1.5", NotAFloat) == Valid(-1.5)
}

pub fn float_strict_integer_literal_test() -> Nil {
  assert parse.float_strict("5", NotAFloat) == Valid(5.0)
}

pub fn float_strict_zero_test() -> Nil {
  assert parse.float_strict("0", NotAFloat) == Valid(0.0)
}

pub fn float_strict_scientific_test() -> Nil {
  assert parse.float_strict("1.5e-2", NotAFloat) == Valid(0.015)
}

pub fn float_strict_scientific_uppercase_test() -> Nil {
  assert parse.float_strict("5E3", NotAFloat) == Valid(5000.0)
}

pub fn float_strict_scientific_explicit_plus_exponent_test() -> Nil {
  // Standard scientific notation (IEEE 754, ECMAScript, Python, Rust, Go)
  // accepts a leading `+` on the exponent. Strict must accept what lenient
  // accepts -- the docstring guarantees strict is a subset of lenient. (#74)
  assert parse.float_strict("1.5e+2", NotAFloat) == Valid(150.0)
}

pub fn float_strict_scientific_explicit_plus_exponent_integer_mantissa_test() -> Nil {
  assert parse.float_strict("5e+3", NotAFloat) == Valid(5000.0)
}

pub fn float_strict_scientific_explicit_plus_exponent_uppercase_test() -> Nil {
  assert parse.float_strict("1.5E+10", NotAFloat) == Valid(15_000_000_000.0)
}

pub fn float_strict_rejects_thousand_separator_comma_test() -> Nil {
  // The whole point of float_strict: lenient parse silently returns
  // 3.0 here; strict must reject so locale-formatted thousand
  // separators don't slide through as 1000x-too-small values.
  assert parse.float_strict("3,000", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("3,000")))
}

pub fn float_strict_rejects_space_separator_test() -> Nil {
  assert parse.float_strict("3 000", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("3 000")))
}

pub fn float_strict_rejects_trailing_letters_test() -> Nil {
  assert parse.float_strict("12.50abc", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("12.50abc")))
}

pub fn float_strict_rejects_unit_suffix_test() -> Nil {
  assert parse.float_strict("3K", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("3K")))
}

pub fn float_strict_rejects_empty_test() -> Nil {
  assert parse.float_strict("", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("")))
}

pub fn float_strict_rejects_leading_dot_test() -> Nil {
  // The strict grammar requires digits before the dot.
  assert parse.float_strict(".5", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat(".5")))
}

pub fn float_strict_rejects_trailing_dot_test() -> Nil {
  assert parse.float_strict("3.", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("3.")))
}

pub fn float_strict_rejects_double_dot_test() -> Nil {
  assert parse.float_strict("3.0.0", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("3.0.0")))
}

pub fn float_strict_rejects_whitespace_around_value_test() -> Nil {
  // Strict parsing must not auto-trim; callers compose with
  // `prep.trim()` if they want trim+strict.
  assert parse.float_strict("  3.14  ", NotAFloat)
    == Invalid(non_empty_list.single(NotAFloat("  3.14  ")))
}

pub fn float_strict_accepts_thousand_separator_period_test() -> Nil {
  // "3.000" is unambiguously 3.0 in en_US locale and syntactically a
  // valid float. The strict variant only catches structural
  // garbage; locale ambiguity inside a syntactically-valid float
  // cannot be resolved at this layer.
  assert parse.float_strict("3.000", NotAFloat) == Valid(3.0)
}

// --- parse + validate pipeline ---

pub fn int_then_validate_test() -> Nil {
  assert parse.int("25", NotAnInteger)
    |> validated.and_then(
      rules.min_int(minimum: 0, error: TooSmall(0))
      |> validator.both(
        first: _,
        second: rules.max_int(maximum: 100, error: TooBig(100)),
      ),
    )
    == Valid(25)
}

pub fn int_parse_fail_short_circuits_test() -> Nil {
  assert parse.int("abc", NotAnInteger)
    |> validated.and_then(fn(_) {
      // nolint: avoid_panic -- verifies parse failure short-circuits validation
      panic as "should not reach validation after parse failure"
    })
    == Invalid(non_empty_list.single(NotAnInteger("abc")))
}

pub fn int_then_validate_out_of_range_test() -> Nil {
  assert parse.int("200", NotAnInteger)
    |> validated.and_then(rules.max_int(maximum: 100, error: TooBig(100)))
    == Invalid(non_empty_list.single(TooBig(100)))
}

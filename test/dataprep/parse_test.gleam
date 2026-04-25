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

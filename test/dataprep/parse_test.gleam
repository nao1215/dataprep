import dataprep/non_empty_list
import dataprep/parse
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator

pub type Err {
  NotAnInteger(raw: String)
  NotAFloat(raw: String)
  TooSmall(min: Int)
  TooBig(max: Int)
}

// --- parse.int ---

pub fn int_pass_test() {
  let assert Valid(42) = parse.int("42", NotAnInteger)
}

pub fn int_negative_test() {
  let assert Valid(-10) = parse.int("-10", NotAnInteger)
}

pub fn int_zero_test() {
  let assert Valid(0) = parse.int("0", NotAnInteger)
}

pub fn int_fail_test() {
  let assert Invalid(nel) = parse.int("abc", NotAnInteger)
  let assert [NotAnInteger("abc")] = non_empty_list.to_list(nel)
}

pub fn int_fail_float_string_test() {
  let assert Invalid(nel) = parse.int("1.5", NotAnInteger)
  let assert [NotAnInteger("1.5")] = non_empty_list.to_list(nel)
}

pub fn int_fail_empty_test() {
  let assert Invalid(nel) = parse.int("", NotAnInteger)
  let assert [NotAnInteger("")] = non_empty_list.to_list(nel)
}

// --- parse.float ---

pub fn float_pass_test() {
  let assert Valid(3.14) = parse.float("3.14", NotAFloat)
}

pub fn float_negative_test() {
  let assert Valid(-1.5) = parse.float("-1.5", NotAFloat)
}

pub fn float_zero_test() {
  let assert Valid(0.0) = parse.float("0.0", NotAFloat)
}

pub fn float_fail_test() {
  let assert Invalid(nel) = parse.float("abc", NotAFloat)
  let assert [NotAFloat("abc")] = non_empty_list.to_list(nel)
}

pub fn float_fail_empty_test() {
  let assert Invalid(nel) = parse.float("", NotAFloat)
  let assert [NotAFloat("")] = non_empty_list.to_list(nel)
}

// --- parse + validate pipeline ---

pub fn int_then_validate_test() {
  let result =
    parse.int("25", NotAnInteger)
    |> validated.and_then(
      rules.min_int(minimum: 0, error: TooSmall(0))
      |> validator.both(
        first: _,
        second: rules.max_int(maximum: 100, error: TooBig(100)),
      ),
    )
  let assert Valid(25) = result
}

pub fn int_parse_fail_short_circuits_test() {
  let result =
    parse.int("abc", NotAnInteger)
    |> validated.and_then(fn(_) {
      // nolint: avoid_panic -- verifies parse failure short-circuits validation
      panic as "should not reach validation after parse failure"
    })
  let assert Invalid(nel) = result
  let assert [NotAnInteger("abc")] = non_empty_list.to_list(nel)
}

pub fn int_then_validate_out_of_range_test() {
  let result =
    parse.int("200", NotAnInteger)
    |> validated.and_then(rules.max_int(maximum: 100, error: TooBig(100)))
  let assert Invalid(nel) = result
  let assert [TooBig(100)] = non_empty_list.to_list(nel)
}

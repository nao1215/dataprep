/// Parse helpers that bridge String -> typed Validated.
/// These reduce the boilerplate of int.parse / float.parse
/// + result.map_error + validated.from_result.
import dataprep/non_empty_list
import dataprep/validated.{type Validated, Invalid, Valid}
import gleam/bool
import gleam/float
import gleam/int
import gleam/result
import gleam/string

/// Parse a string as Int. On failure, call `on_error` with the
/// original string to produce the error value.
///
/// Example:
///   parse.int(raw, fn(s) { NotAnInteger(s) })
///
pub fn int(raw: String, on_error: fn(String) -> e) -> Validated(Int, e) {
  case int.parse(raw) {
    Ok(n) -> Valid(n)
    Error(Nil) -> Invalid(non_empty_list.single(on_error(raw)))
  }
}

/// Parse a string as Float. On failure, call `on_error` with the
/// original string to produce the error value.
///
/// **Lenient.** Accepts every shape `gleam/float.parse` accepts
/// (e.g. `"3.14"`, `"-0.5"`) and additionally accepts:
///
/// - integer literals — `"5"` parses as `5.0` (asymmetric strictness
///   between `parse.int` and `parse.float` was a UX trap when the
///   raw input is a user-typed numeric value).
/// - scientific notation — `"1e3"`, `"1.5e-2"`, `"5E3"` are all
///   accepted; the exponent must itself be a valid integer.
///
/// Input containing a comma, such as `"3,000"` or `"3,5"`, is rejected
/// on both targets. Erlang's float parser would otherwise read the
/// comma as a decimal point. For input that must match a fixed
/// grammar, use `float_strict/2`.
///
/// Example:
///   parse.float(raw, fn(s) { NotAFloat(s) })
///
pub fn float(raw: String, on_error: fn(String) -> e) -> Validated(Float, e) {
  case parse_lenient_float(raw) {
    Ok(x) -> Valid(x)
    Error(Nil) -> Invalid(non_empty_list.single(on_error(raw)))
  }
}

/// Parse a string as Float, rejecting any input the strict-float
/// grammar does not accept end-to-end.
///
/// Strict counterpart of `float/2`, for form fields where only the
/// grammar below is allowed.
///
/// Accepts: optional leading `-`, then digits (`"42"`) or
/// digits-dot-digits (`"3.14"`), optionally followed by a scientific
/// suffix (`[eE][+-]?\d+`, e.g. `"1.5e-2"`, `"5E3"`). Anything else —
/// commas, spaces, trailing letters, leading dots, multiple dots —
/// is rejected via `on_error`.
///
/// Example:
///   parse.float_strict("3,000", fn(s) { NotAFloat(s) })
///   // Invalid([NotAFloat("3,000")])  -- not Valid(3.0)
///
/// Equivalent to `float/2` for inputs the strict grammar accepts;
/// callers can opt into strictness without rewriting their error
/// type.
pub fn float_strict(
  raw: String,
  on_error: fn(String) -> e,
) -> Validated(Float, e) {
  use <- bool.guard(
    when: !strict_float_grammar_matches(raw),
    return: Invalid(non_empty_list.single(on_error(raw))),
  )
  case parse_lenient_float(raw) {
    Ok(value) -> Valid(value)
    Error(Nil) -> Invalid(non_empty_list.single(on_error(raw)))
  }
}

// Strict grammar: `-?digits(.digits)?([eE][+-]?digits)?`, end to end.
fn strict_float_grammar_matches(raw: String) -> Bool {
  let unsigned = case raw {
    "-" <> rest -> rest
    _ -> raw
  }
  case skip_digits(unsigned, seen: False) {
    Ok(rest) -> strict_fraction_matches(rest)
    Error(Nil) -> False
  }
}

fn strict_fraction_matches(rest: String) -> Bool {
  case rest {
    "." <> fraction ->
      case skip_digits(fraction, seen: False) {
        Ok(after) -> strict_exponent_matches(after)
        Error(Nil) -> False
      }
    _ -> strict_exponent_matches(rest)
  }
}

fn strict_exponent_matches(rest: String) -> Bool {
  case rest {
    "" -> True
    "e" <> exponent | "E" <> exponent -> {
      let digits = case exponent {
        "+" <> unsigned | "-" <> unsigned -> unsigned
        _ -> exponent
      }
      skip_digits(digits, seen: False) == Ok("")
    }
    _ -> False
  }
}

/// Drop leading ASCII digits. Fails when there is not at least one.
fn skip_digits(input: String, seen seen: Bool) -> Result(String, Nil) {
  case input {
    "0" <> rest
    | "1" <> rest
    | "2" <> rest
    | "3" <> rest
    | "4" <> rest
    | "5" <> rest
    | "6" <> rest
    | "7" <> rest
    | "8" <> rest
    | "9" <> rest -> skip_digits(rest, seen: True)
    _ if seen -> Ok(input)
    _ -> Error(Nil)
  }
}

/// The largest finite IEEE 754 double.
const max_finite_float = 1.7976931348623157e308

// Every accepted shape is rewritten into the `digits.digits[e..]` form
// that `float.parse` reads on both targets, so the target's own
// correctly rounded parser does the work and nothing is multiplied
// here. On overflow Erlang's parser fails and JavaScript's returns
// Infinity; the magnitude check maps both to `Error(Nil)`.
fn parse_lenient_float(raw: String) -> Result(Float, Nil) {
  // Erlang's `binary_to_float` reads `,` as a decimal point and
  // JavaScript does not, so commas are rejected up front.
  use <- bool.guard(when: string.contains(raw, ","), return: Error(Nil))
  case float.parse(raw) {
    Ok(value) -> finite(value)
    Error(Nil) ->
      case is_integer_literal(raw) {
        True -> parse_finite(raw <> ".0")
        False -> parse_scientific(raw)
      }
  }
}

fn parse_scientific(raw: String) -> Result(Float, Nil) {
  case string.split_once(string.lowercase(raw), on: "e") {
    Error(Nil) -> Error(Nil)
    Ok(#(mantissa, exponent)) ->
      case is_integer_literal(mantissa) {
        True -> parse_finite(mantissa <> ".0e" <> exponent)
        False -> Error(Nil)
      }
  }
}

// A sign followed by ASCII digits. Checked by scanning instead of
// `int.parse`, which would build a bignum for a huge digit string.
fn is_integer_literal(raw: String) -> Bool {
  let digits = case raw {
    "-" <> rest | "+" <> rest -> rest
    _ -> raw
  }
  skip_digits(digits, seen: False) == Ok("")
}

fn parse_finite(raw: String) -> Result(Float, Nil) {
  result.try(float.parse(raw), finite)
}

fn finite(value: Float) -> Result(Float, Nil) {
  use <- bool.guard(
    when: float.absolute_value(value) >. max_finite_float,
    return: Error(Nil),
  )
  // Erlang keeps the sign of `-0.0`, which is not equal to `0.0` on
  // OTP 27 and later; report every zero as `0.0`.
  case value == 0.0 || value == -0.0 {
    True -> Ok(0.0)
    False -> Ok(value)
  }
}

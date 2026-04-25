/// Parse helpers that bridge String -> typed Validated.
/// These reduce the boilerplate of int.parse / float.parse
/// + result.map_error + validated.from_result.
import dataprep/non_empty_list
import dataprep/validated.{type Validated, Invalid, Valid}
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
/// Accepts every shape `gleam/float.parse` accepts (e.g. `"3.14"`,
/// `"-0.5"`) and additionally accepts:
///
/// - integer literals — `"5"` parses as `5.0` (asymmetric strictness
///   between `parse.int` and `parse.float` was a UX trap when the
///   raw input is a user-typed numeric value).
/// - scientific notation — `"1e3"`, `"1.5e-2"`, `"5E3"` are all
///   accepted; the exponent must itself be a valid integer.
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

fn parse_lenient_float(raw: String) -> Result(Float, Nil) {
  case float.parse(raw) {
    Ok(x) -> Ok(x)
    Error(Nil) ->
      case int.parse(raw) {
        Ok(n) -> Ok(int.to_float(n))
        Error(Nil) -> parse_scientific(raw)
      }
  }
}

fn parse_scientific(raw: String) -> Result(Float, Nil) {
  case string.split_once(string.lowercase(raw), on: "e") {
    Error(Nil) -> Error(Nil)
    Ok(#(mantissa_str, exp_str)) -> assemble_scientific(mantissa_str, exp_str)
  }
}

fn assemble_scientific(
  mantissa_str: String,
  exp_str: String,
) -> Result(Float, Nil) {
  use mantissa <- result.try(parse_lenient_float(mantissa_str))
  use exp <- result.try(int.parse(exp_str))
  use power <- result.map(float.power(10.0, of: int.to_float(exp)))
  mantissa *. power
}

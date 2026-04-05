/// Parse helpers that bridge String -> typed Validated.
/// These reduce the boilerplate of int.parse / float.parse
/// + result.map_error + validated.from_result.
import dataprep/non_empty_list
import dataprep/validated.{type Validated, Invalid, Valid}
import gleam/float
import gleam/int

/// Parse a string as Int. On failure, call `on_error` with the
/// original string to produce the error value.
///
/// Example:
///   parse.int(raw, fn(s) { NotAnInteger(s) })
///
pub fn int(raw: String, on_error: fn(String) -> e) -> Validated(Int, e) {
  case int.parse(raw) {
    Ok(n) -> Valid(n)
    Error(_) -> Invalid(non_empty_list.single(on_error(raw)))
  }
}

/// Parse a string as Float. On failure, call `on_error` with the
/// original string to produce the error value.
///
/// Example:
///   parse.float(raw, fn(s) { NotAFloat(s) })
///
pub fn float(raw: String, on_error: fn(String) -> e) -> Validated(Float, e) {
  case float.parse(raw) {
    Ok(x) -> Valid(x)
    Error(_) -> Invalid(non_empty_list.single(on_error(raw)))
  }
}

/// Parse helpers that bridge String -> typed Validated.
/// These reduce the boilerplate of int.parse / float.parse
/// + result.map_error + validated.from_result.
import dataprep/non_empty_list
import dataprep/validated.{type Validated, Invalid, Valid}
import gleam/bool
import gleam/float
import gleam/int
import gleam/regexp
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
/// **Locale ambiguity warning.** `gleam/float.parse` is documented as
/// lenient: it returns the parsed prefix when the input has trailing
/// non-numeric bytes. Concretely, `parse.float("3,000", ...)` returns
/// `Valid(3.0)` because the parse stops at the comma. This silently
/// truncates locale-formatted thousand-separated input
/// (`de_DE` / `fr_FR` / `ja_JP` users typing `"3,000"` mean three
/// thousand, not three) and a 1000× wrong amount can flow through
/// the rest of the pipeline. For amount fields, address fields, and
/// any other input where partial-parse is a bug rather than a
/// feature, use `float_strict/2` instead. (#67)
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
/// Strict counterpart of `float/2`. The lenient `float/2` delegates
/// to `gleam/float.parse`, which silently truncates inputs like
/// `"3,000"` (returns `3.0`, parse stops at the comma). For form
/// fields where partial-parse is a bug, use this variant.
///
/// Accepts: optional leading `-`, then digits (`"42"`) or
/// digits-dot-digits (`"3.14"`), optionally followed by a scientific
/// suffix (`[eE]-?\d+`, e.g. `"1.5e-2"`, `"5E3"`). Anything else —
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

fn strict_float_grammar_matches(raw: String) -> Bool {
  // nolint: assert_ok_pattern -- the strict-float regex is a fixed, known-valid literal
  let assert Ok(strict_re) =
    regexp.from_string("^-?(?:\\d+\\.\\d+|\\d+)(?:[eE][+-]?\\d+)?$")
  regexp.check(with: strict_re, content: raw)
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
  // IEEE 754 doubles cap at ~1.8e308. `math:pow(10, n)` for n > 308
  // raises Erlang `Badarith`, which would crash the calling actor.
  // Underflow (very negative exponents) is left untouched: `math:pow`
  // silently returns 0.0, so `parse.float("1e-3000", _)` keeps yielding
  // `Valid(0.0)` exactly as before.
  use <- bool.guard(when: exp > 308, return: Error(Nil))
  use power <- result.map(float.power(10.0, of: int.to_float(exp)))
  mantissa *. power
}

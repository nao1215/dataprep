/// Parse helpers that bridge String -> typed Validated.
/// These reduce the boilerplate of int.parse / float.parse
/// + result.map_error + validated.from_result.
import dataprep/non_empty_list
import dataprep/validated.{type Validated, Invalid, Valid}
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
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
  // Pre-check the scientific exponent so we never call the target's
  // float parser with an exponent that would overflow IEEE 754 doubles.
  // Erlang's `binary_to_float` plus our `math:pow` fallback raises
  // `Badarith`; JavaScript's `parseFloat` silently returns `Infinity`.
  // Both targets need the same rejection contract, so we guard here.
  // Underflow (very negative exponents) is intentionally left alone —
  // both targets round it to 0.0 without raising.
  use <- bool.guard(
    when: has_overflowing_scientific_exponent(raw),
    return: Error(Nil),
  )
  // Plain-integer literals (no decimal point, no `e`) with more than
  // 308 significant digits overflow IEEE 754 doubles. On Erlang
  // `int.to_float` -> `erlang:float/1` raises `badarg`; on JavaScript
  // `parseInt` already returns `Infinity` (Gleam's `Int` on JS is a
  // `Number`, not a `BigInt`). Both targets need to funnel this case
  // into `Invalid`, so we guard on the raw string before either parser
  // sees it. (#80)
  use <- bool.guard(
    when: has_overflowing_plain_integer_literal(raw),
    return: Error(Nil),
  )
  case float.parse(raw) {
    Ok(x) -> Ok(x)
    Error(Nil) ->
      case int.parse(raw) {
        Ok(n) ->
          case has_overflowing_integer_magnitude(n) {
            True -> Error(Nil)
            False -> Ok(int.to_float(n))
          }
        Error(Nil) -> parse_scientific(raw)
      }
  }
}

fn has_overflowing_scientific_exponent(raw: String) -> Bool {
  case string.split_once(string.lowercase(raw), on: "e") {
    Error(Nil) -> False
    Ok(#(_, exp_str)) -> {
      // The strict-float grammar (and every mainstream float parser)
      // accepts an explicit `+` on the exponent. Normalise it away
      // before parsing as Int.
      let exp_str = case string.starts_with(exp_str, "+") {
        True -> string.drop_start(exp_str, 1)
        False -> exp_str
      }
      case int.parse(exp_str) {
        Ok(exp) -> exp > 308
        Error(Nil) -> False
      }
    }
  }
}

fn has_overflowing_integer_magnitude(n: Int) -> Bool {
  int.absolute_value(n)
  |> int.to_string
  |> string.length
  > 308
}

fn has_overflowing_plain_integer_literal(raw: String) -> Bool {
  let digits = case string.starts_with(raw, "-") {
    True -> string.drop_start(raw, 1)
    False -> raw
  }
  string.length(digits) > 308
  && list.all(string.to_graphemes(digits), is_ascii_digit_grapheme)
}

fn is_ascii_digit_grapheme(g: String) -> Bool {
  case g {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
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

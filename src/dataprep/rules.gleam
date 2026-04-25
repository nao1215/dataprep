import dataprep/validator.{type Validator}
import gleam/float
import gleam/list
import gleam/regexp
import gleam/string

/// Fails if the string is exactly "". Whitespace-only strings like
/// "  " pass this check. To reject whitespace-only input, compose
/// with prep.trim() first:
///
///   raw |> prep.trim() |> rules.not_empty(MyError)
///
pub fn not_empty(error: e) -> Validator(String, e) {
  validator.predicate(fn(s) { s != "" }, error)
}

/// Fails if the string is empty or contains only whitespace.
/// Unlike `not_empty`, this rejects `"  "` and `"\t\n"`.
/// The value is NOT trimmed -- it is returned unchanged on success.
pub fn not_blank(error: e) -> Validator(String, e) {
  validator.predicate(fn(s) { string.trim(s) != "" }, error)
}

/// Fails if the string does not match the given regular expression.
/// Takes a pre-compiled `Regexp` so a malformed pattern surfaces as a
/// `regexp.from_string` error at the call site instead of crashing
/// inside the validator.
///
/// Example:
///   import gleam/regexp
///   import dataprep/rules
///
///   let assert Ok(re) = regexp.from_string("^[a-z]+$")
///   let check = rules.matches(pattern: re, error: InvalidFormat)
///
/// For literal patterns where propagating a compile error to the
/// caller is not useful, see `matches_string`.
pub fn matches(
  pattern re: regexp.Regexp,
  error error: e,
) -> Validator(String, e) {
  validator.predicate(fn(s) { regexp.check(re, s) }, error)
}

/// Fails if the string does not match the given regular expression
/// pattern. Compiles the pattern internally; an invalid pattern
/// panics at construction time with the underlying compile error.
///
/// Use this when the pattern is a literal known at the call site
/// and a compile failure would be a programmer error there is no
/// meaningful recovery from. For dynamically-supplied patterns,
/// use `matches` together with `regexp.from_string` so the
/// `Result` is visible.
///
/// Example:
///   import dataprep/rules
///
///   let check = rules.matches_string(
///     pattern: "^[a-z0-9-]+$",
///     error: InvalidFormat,
///   )
pub fn matches_string(
  pattern pattern: String,
  error error: e,
) -> Validator(String, e) {
  case regexp.from_string(pattern) {
    Ok(re) -> matches(pattern: re, error: error)
    Error(compile_error) -> {
      let msg =
        "dataprep/rules.matches_string: invalid pattern — "
        <> compile_error.error
      panic as msg
    }
  }
}

/// Fails if the string length is less than min.
pub fn min_length(minimum min: Int, error error: e) -> Validator(String, e) {
  validator.predicate(fn(s) { string.length(s) >= min }, error)
}

/// Fails if the string length exceeds max.
pub fn max_length(maximum max: Int, error error: e) -> Validator(String, e) {
  validator.predicate(fn(s) { string.length(s) <= max }, error)
}

/// Fails if the string length is outside [min, max].
pub fn length_between(
  minimum min: Int,
  maximum max: Int,
  error error: e,
) -> Validator(String, e) {
  validator.predicate(
    fn(s) {
      let len = string.length(s)
      len >= min && len <= max
    },
    error,
  )
}

/// Fails if the int is less than min.
pub fn min_int(minimum min: Int, error error: e) -> Validator(Int, e) {
  validator.predicate(fn(n) { n >= min }, error)
}

/// Fails if the int exceeds max.
pub fn max_int(maximum max: Int, error error: e) -> Validator(Int, e) {
  validator.predicate(fn(n) { n <= max }, error)
}

/// Fails if the float is less than min.
pub fn min_float(minimum min: Float, error error: e) -> Validator(Float, e) {
  validator.predicate(fn(x) { x >=. min }, error)
}

/// Fails if the float exceeds max.
pub fn max_float(maximum max: Float, error error: e) -> Validator(Float, e) {
  validator.predicate(fn(x) { x <=. max }, error)
}

/// Fails if the int is negative (less than 0).
pub fn non_negative_int(error: e) -> Validator(Int, e) {
  validator.predicate(fn(n) { n >= 0 }, error)
}

/// Fails if the float is negative (less than 0.0).
pub fn non_negative_float(error: e) -> Validator(Float, e) {
  validator.predicate(fn(x) { float.compare(x, 0.0) != order.Lt }, error)
}

/// Fails if the value is not in the allowed list.
pub fn one_of(allowed allowed: List(a), error error: e) -> Validator(a, e) {
  validator.predicate(fn(a) { list.contains(allowed, a) }, error)
}

/// Fails if the value does not equal the expected value.
pub fn equals(expected expected: a, error error: e) -> Validator(a, e) {
  validator.predicate(fn(a) { a == expected }, error)
}

import gleam/order

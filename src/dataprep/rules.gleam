import dataprep/validator.{type Validator}
import gleam/list
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

/// Fails if the string length is less than min.
pub fn min_length(min: Int, error: e) -> Validator(String, e) {
  validator.predicate(fn(s) { string.length(s) >= min }, error)
}

/// Fails if the string length exceeds max.
pub fn max_length(max: Int, error: e) -> Validator(String, e) {
  validator.predicate(fn(s) { string.length(s) <= max }, error)
}

/// Fails if the int is less than min.
pub fn min_int(min: Int, error: e) -> Validator(Int, e) {
  validator.predicate(fn(n) { n >= min }, error)
}

/// Fails if the int exceeds max.
pub fn max_int(max: Int, error: e) -> Validator(Int, e) {
  validator.predicate(fn(n) { n <= max }, error)
}

/// Fails if the value is not in the allowed list.
pub fn one_of(allowed: List(a), error: e) -> Validator(a, e) {
  validator.predicate(fn(a) { list.contains(allowed, a) }, error)
}

/// Fails if the value does not equal the expected value.
pub fn equals(expected: a, error: e) -> Validator(a, e) {
  validator.predicate(fn(a) { a == expected }, error)
}

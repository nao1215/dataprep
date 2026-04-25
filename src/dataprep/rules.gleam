import dataprep/validator.{type Validator}
import gleam/float
import gleam/list
import gleam/regexp.{Match}
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

/// Fails if the regex does not find a match anywhere in the string.
/// This is `regexp.check` semantics — a partial / substring match
/// is enough to pass.
///
/// **Anchoring is the caller's responsibility.** A pattern like
/// `[0-9]+` accepts `"abc123def"` because the digit run matches
/// somewhere in the input. To require the entire string to match,
/// either anchor the pattern explicitly with `^...$`, or reach for
/// `matches_fully` which enforces full-string semantics regardless
/// of whether the pattern is anchored. The validation use case
/// almost always wants `matches_fully`; `matches` is exposed for
/// the cases that genuinely need substring search.
///
/// Takes a pre-compiled `Regexp` so a malformed pattern surfaces as
/// a `regexp.from_string` error at the call site instead of
/// crashing inside the validator.
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

/// Fails if the regex does not match the entire input string. Unlike
/// `matches`, a partial / substring hit is **not** enough — the
/// matched substring must equal the whole input. Equivalent to
/// Python's `re.fullmatch` semantics.
///
/// Anchoring the pattern (`^...$`) is therefore not required: the
/// validator does the equivalent check itself by comparing the first
/// match's `content` against the input. Patterns that already include
/// `^` / `$` continue to work; the anchors just become redundant.
///
/// Example:
///   import gleam/regexp
///   import dataprep/rules
///
///   let assert Ok(re) = regexp.from_string("[0-9]+")
///   let check = rules.matches_fully(pattern: re, error: NotANumber)
///
///   check("123")        // Valid("123")
///   check("abc123def")  // Invalid([NotANumber])  -- substring match rejected
pub fn matches_fully(
  pattern re: regexp.Regexp,
  error error: e,
) -> Validator(String, e) {
  validator.predicate(
    fn(s) {
      case regexp.scan(re, s) {
        [Match(content: c, ..), ..] -> c == s
        [] -> False
      }
    },
    error,
  )
}

/// Fails if the string does not match the given regular expression
/// pattern. Compiles the pattern internally; an invalid pattern
/// panics at construction time with the underlying compile error.
///
/// **Same anchoring footgun as `matches`**: a pattern like
/// `"[0-9]+"` accepts `"abc123def"` because the digit run matches
/// somewhere. Anchor explicitly with `^...$` or use
/// `matches_fully_string` for the validation case.
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
      // nolint: avoid_panic -- malformed literal regex is a programmer error; recovery is not meaningful at this call site
      panic as msg
    }
  }
}

/// Fails if the regex does not match the entire input string.
/// Compiles the pattern internally; an invalid pattern panics at
/// construction time with the underlying compile error.
///
/// Equivalent to `matches_fully` but with a literal pattern. Use
/// this for the validation use case — `"[0-9]+"` will reject
/// `"abc123def"` rather than accepting it on a substring hit, so
/// the API behaves the way readers usually assume.
///
/// Example:
///   import dataprep/rules
///
///   let check = rules.matches_fully_string(
///     pattern: "[a-z0-9-]+",
///     error: InvalidFormat,
///   )
pub fn matches_fully_string(
  pattern pattern: String,
  error error: e,
) -> Validator(String, e) {
  case regexp.from_string(pattern) {
    Ok(re) -> matches_fully(pattern: re, error: error)
    Error(compile_error) -> {
      let msg =
        "dataprep/rules.matches_fully_string: invalid pattern — "
        <> compile_error.error
      // nolint: avoid_panic -- malformed literal regex is a programmer error; recovery is not meaningful at this call site
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

import dataprep/validator.{type Validator}
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/regexp
import gleam/result
import gleam/string

/// Why a checked regex constructor refused to build a validator.
///
/// Returned by `matches_string_checked` and
/// `matches_fully_string_checked` instead of panicking, so the
/// caller controls how a malformed pattern surfaces. Mirrors the
/// information from `regexp.CompileError` without forcing the
/// caller to depend on `gleam/regexp` directly.
pub type RegexRuleError {
  InvalidPattern(reason: String, byte_index: Int)
}

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
/// `matches_fully_string` which enforces full-string semantics by
/// anchoring the pattern source to both ends internally. The
/// validation use case almost always wants `matches_fully_string`;
/// `matches` is exposed for the cases that genuinely need
/// substring search.
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
  case matches_string_checked(pattern:, error:) {
    Ok(check) -> check
    Error(InvalidPattern(reason:, ..)) -> {
      let msg = "dataprep/rules.matches_string: invalid pattern — " <> reason
      // nolint: avoid_panic -- malformed literal regex is a programmer error; recovery is not meaningful at this call site
      panic as msg
    }
  }
}

// `matches_fully(pattern: regexp.Regexp, error: e)` was removed in
// v0.22.0 because it cannot reliably implement Python `re.fullmatch`
// semantics for top-level alternation: the function received an
// already-compiled `regexp.Regexp` whose source pattern Gleam's
// stdlib does not expose, which left no way to re-anchor the pattern
// as `^(?:...)$`. Without anchoring the engine's leftmost-first
// match for inputs like `a|ab` against `"ab"` returns `"a"` and the
// validator reports `Invalid`. Use `matches_fully_string` (or
// `matches_fully_string_checked`) with the original pattern source
// instead — both compile the anchored pattern internally and
// produce the expected `re.fullmatch` behaviour. See issue #95.

/// Fails if the regex does not match the entire input string.
/// Compiles the pattern on its own, then anchored to both ends of the
/// input, so the check matches Python's `re.fullmatch`
/// semantics even for top-level alternation — e.g. pattern `"a|ab"`
/// against input `"ab"` is accepted because `ab` is one of the
/// alternatives. An invalid pattern panics at construction time
/// with the underlying compile error.
///
/// Use this for the validation use case — `"[0-9]+"` will reject
/// `"abc123def"` rather than accepting it on a substring hit, so
/// the API behaves the way readers usually assume.
///
/// The end anchor is `(?![\s\S])` rather than `$`, because Erlang's
/// `$` also matches before a final newline. Pattern `"foo"` rejects
/// `"foo\n"` on Erlang and JavaScript alike.
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
  case matches_fully_string_checked(pattern:, error:) {
    Ok(check) -> check
    Error(InvalidPattern(reason:, ..)) -> {
      let msg =
        "dataprep/rules.matches_fully_string: invalid pattern — " <> reason
      // nolint: avoid_panic -- malformed literal regex is a programmer error; recovery is not meaningful at this call site
      panic as msg
    }
  }
}

/// Like `matches_string`, but returns the compile failure as a
/// `Result` instead of panicking. Use this when the pattern is not
/// a hard-coded literal — config files, admin-supplied input, or
/// anywhere a malformed pattern is a recoverable runtime condition
/// rather than a programmer error.
///
/// On success the validator behaves identically to
/// `matches(pattern: re, error:)` over the compiled pattern, i.e.
/// uses `regexp.check` semantics (substring hit is enough).
///
/// Example:
///   import dataprep/rules
///   import gleam/result
///
///   case rules.matches_string_checked(
///     pattern: pattern_from_config,
///     error: InvalidFormat,
///   ) {
///     Ok(check) -> handle_request(check)
///     Error(rules.InvalidPattern(reason: r, ..)) -> reject_config(r)
///   }
pub fn matches_string_checked(
  pattern pattern: String,
  error error: e,
) -> Result(Validator(String, e), RegexRuleError) {
  use compiled <- result.map(compile(pattern))
  matches(pattern: compiled, error: error)
}

/// Like `matches_fully_string`, but returns the compile failure as
/// a `Result` instead of panicking. Use this for the validation use
/// case when the pattern comes from configuration or any other
/// dynamic source where a compile failure should be handled rather
/// than crashing.
///
/// On success the validator behaves identically to
/// `matches_fully_string` and matches Python `re.fullmatch`
/// semantics even for top-level alternation. A pattern that does not
/// compile on its own returns the same error as
/// `matches_string_checked`.
///
/// Example:
///   import dataprep/rules
///
///   case rules.matches_fully_string_checked(
///     pattern: pattern_from_admin,
///     error: BadFormat,
///   ) {
///     Ok(check) -> ...
///     Error(rules.InvalidPattern(reason: r, ..)) -> ...
///   }
pub fn matches_fully_string_checked(
  pattern pattern: String,
  error error: e,
) -> Result(Validator(String, e), RegexRuleError) {
  // The pattern is compiled on its own first, so a pattern such as
  // "a)|(b" cannot close the wrapper group below and slip through.
  use _ <- result.try(compile(pattern))
  // `(?![\s\S])` holds only at the real end of the input on both
  // targets; Erlang's `$` also matches before a trailing newline.
  use anchored <- result.map(
    compile("^(?:" <> pattern <> ")(?![\\s\\S])")
    |> result.map_error(fn(anchor_error) {
      // The pattern compiled alone but leaves something open at its
      // end (for example PCRE's `\Q` quoting), so point there.
      InvalidPattern(..anchor_error, byte_index: string.byte_size(pattern))
    }),
  )
  validator.predicate(fn(s) { regexp.check(anchored, s) }, error)
}

fn compile(pattern: String) -> Result(regexp.Regexp, RegexRuleError) {
  regexp.from_string(pattern)
  |> result.map_error(fn(compile_error) {
    InvalidPattern(
      reason: compile_error.error,
      byte_index: compile_error.byte_index,
    )
  })
}

/// Fails if the string length is less than min.
///
/// `min` must be non-negative. A negative `min` makes the predicate
/// vacuously true (`string.length` is always `>= 0 > min`) and the
/// resulting validator silently accepts every input — most callers
/// who reach a negative value here have a config or arithmetic bug,
/// not a deliberate "always-pass" intent, so the case is rejected
/// at construction time with a panic that names the function and
/// echoes the offending value.
pub fn min_length(minimum min: Int, error error: e) -> Validator(String, e) {
  case min < 0 {
    True -> {
      let msg =
        "dataprep/rules.min_length: minimum ("
        <> int.to_string(min)
        <> ") must be >= 0"
      // nolint: avoid_panic -- negative minimum is a programmer error; an always-pass validator would silently accept every input
      panic as msg
    }
    False -> validator.predicate(fn(s) { string.length(s) >= min }, error)
  }
}

/// Fails if the string length exceeds max.
///
/// `max` must be non-negative. A negative `max` makes the predicate
/// vacuously false (`string.length` is always `>= 0 > max`) and the
/// resulting validator silently rejects every input — same reasoning
/// as `min_length`: callers who reach a negative value here usually
/// have a config bug rather than a deliberate "always-fail" intent,
/// so the case is rejected at construction time with a panic that
/// names the function and echoes the offending value.
pub fn max_length(maximum max: Int, error error: e) -> Validator(String, e) {
  case max < 0 {
    True -> {
      let msg =
        "dataprep/rules.max_length: maximum ("
        <> int.to_string(max)
        <> ") must be >= 0"
      // nolint: avoid_panic -- negative maximum is a programmer error; an always-fail validator would silently reject every input
      panic as msg
    }
    False -> validator.predicate(fn(s) { string.length(s) <= max }, error)
  }
}

/// Fails if the string length is outside [min, max].
///
/// `min` must be less than or equal to `max`: an inverted range
/// produces a vacuously unsatisfiable predicate (no string length can
/// be both `>= min` and `<= max` when `min > max`), so any validator
/// built from it would silently reject every input. That is a
/// programmer error rather than a runtime condition, so
/// `length_between` panics at construction time with a message
/// naming the function and the offending bounds rather than returning
/// a permanently-always-fail validator. Guard the bounds at the call
/// site when `min`/`max` come from configuration or other dynamic
/// input.
pub fn length_between(
  minimum min: Int,
  maximum max: Int,
  error error: e,
) -> Validator(String, e) {
  case min > max {
    True -> {
      let msg =
        "dataprep/rules.length_between: minimum ("
        <> int.to_string(min)
        <> ") must be <= maximum ("
        <> int.to_string(max)
        <> ")"
      // nolint: avoid_panic -- inverted [min, max] is a programmer error; an always-fail validator would silently reject every input
      panic as msg
    }
    False ->
      validator.predicate(
        fn(s) {
          let len = string.length(s)
          len >= min && len <= max
        },
        error,
      )
  }
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
///
/// `allowed` must be non-empty: a set-membership check against the
/// empty set has no inhabitants, so any validator built from `[]`
/// would silently reject every input. That is a programmer error
/// rather than a runtime condition, so `one_of` panics at
/// construction time with a message naming the function rather than
/// returning a permanently-always-fail validator. Guard at the call
/// site if the allowlist comes from configuration or other dynamic
/// input (e.g.,
/// `case allowed { [] -> ...; [_, ..] -> rules.one_of(allowed, e) }`).
pub fn one_of(allowed allowed: List(a), error error: e) -> Validator(a, e) {
  case allowed {
    [] ->
      // nolint: avoid_panic -- empty allowlist is a programmer error; an always-fail validator would silently reject every input
      panic as "dataprep/rules.one_of: allowed list must be non-empty"
    [_, ..] -> validator.predicate(fn(a) { list.contains(allowed, a) }, error)
  }
}

/// Fails if the value does not equal the expected value.
pub fn equals(expected expected: a, error error: e) -> Validator(a, e) {
  validator.predicate(fn(a) { a == expected }, error)
}

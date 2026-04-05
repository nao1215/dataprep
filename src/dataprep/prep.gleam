import gleam/list
import gleam/regexp
import gleam/string

/// Prep(a) is an infallible transformation: fn(a) -> a.
/// It always succeeds and never produces errors.
pub type Prep(a) =
  fn(a) -> a

/// Sequential composition: apply p1, then apply p2 to the result.
pub fn then(p1: Prep(a), p2: Prep(a)) -> Prep(a) {
  fn(x) { p2(p1(x)) }
}

/// Compose a list of preps into a single prep.
/// Empty list returns identity.
pub fn sequence(steps: List(Prep(a))) -> Prep(a) {
  list.fold(over: steps, from: identity(), with: fn(acc, step) {
    then(acc, step)
  })
}

/// No-op prep. Returns the value unchanged.
pub fn identity() -> Prep(a) {
  fn(x) { x }
}

/// Trim leading and trailing whitespace.
pub fn trim() -> Prep(String) {
  string.trim
}

/// Convert to lowercase.
pub fn lowercase() -> Prep(String) {
  string.lowercase
}

/// Convert to uppercase.
pub fn uppercase() -> Prep(String) {
  string.uppercase
}

/// Collapse consecutive whitespace into a single space.
///
/// Uses `let assert` for the regex compilation. The pattern `\s+` is
/// a fixed, known-valid regular expression, so compilation cannot fail
/// at runtime. The assert is intentional and safe.
pub fn collapse_space() -> Prep(String) {
  let assert Ok(re) = regexp.from_string("\\s+")
  fn(s) { regexp.replace(each: re, in: s, with: " ") }
}

/// Replace all occurrences of target with replacement.
pub fn replace(target: String, replacement: String) -> Prep(String) {
  fn(s) { string.replace(in: s, each: target, with: replacement) }
}

/// Replace the value with fallback when the input is exactly "".
///
/// Note: this checks the literal empty string only. Whitespace-only
/// inputs like "  " are NOT treated as empty. If you want
/// whitespace-only values to trigger the default, compose with trim:
///
///   prep.trim() |> prep.then(prep.default("N/A"))
pub fn default(fallback: String) -> Prep(String) {
  fn(s) {
    case s {
      "" -> fallback
      _ -> s
    }
  }
}

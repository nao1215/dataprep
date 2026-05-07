import gleam/list
import gleam/regexp
import gleam/string

/// Prep(a) is an infallible transformation: fn(a) -> a.
/// It always succeeds and never produces errors.
pub type Prep(a) =
  fn(a) -> a

/// Sequential composition: apply p1, then apply p2 to the result.
pub fn then(first p1: Prep(a), next p2: Prep(a)) -> Prep(a) {
  fn(x) { p2(p1(x)) }
}

/// Compose a list of preps into a single prep.
/// Empty list returns identity.
pub fn sequence(steps: List(Prep(a))) -> Prep(a) {
  list.fold(over: steps, from: identity(), with: fn(acc, step) {
    then(first: acc, next: step)
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

/// Collapse consecutive **ASCII** whitespace into a single space.
///
/// Matches the POSIX whitespace class `[ \t\n\r\f\v]` (space, tab,
/// linefeed, carriage return, form feed, vertical tab). Unicode
/// whitespace such as NO-BREAK SPACE (U+00A0) and IDEOGRAPHIC SPACE
/// (U+3000) is **preserved** — for those use `collapse_unicode_space`
/// (it matches the wider Unicode `\s` set and replaces every run with
/// a single ASCII space).
///
/// This split avoids the silent CJK-destruction footgun of replacing
/// `姓　名` (with U+3000 between the names) with `姓 名` when the
/// caller only meant to normalise indentation.
///
/// Uses `let assert` for the regex compilation. The pattern is a
/// fixed, known-valid regular expression, so compilation cannot fail
/// at runtime. The assert is intentional and safe.
pub fn collapse_space() -> Prep(String) {
  // nolint: assert_ok_pattern -- the bracket expression is a fixed, known-valid regex literal
  let assert Ok(re) = regexp.from_string("[ \\t\\n\\r\\f\\v]+")
  fn(s) { regexp.replace(each: re, in: s, with: " ") }
}

/// Collapse consecutive Unicode whitespace into a single ASCII space.
///
/// Matches `\s+` under the regex engine's full Unicode rule, so it
/// recognises NO-BREAK SPACE (U+00A0), IDEOGRAPHIC SPACE (U+3000),
/// LINE / PARAGRAPH SEPARATOR (U+2028 / U+2029), the various EN/EM
/// SPACEs (U+2000..U+200A), etc. Each run — even one made entirely of
/// non-ASCII whitespace — is rewritten to a single ASCII U+0020.
///
/// Reach for `collapse_space` instead when the caller wants to keep
/// CJK / typographic whitespace intact and only fold ASCII runs.
///
/// Uses `let assert` for the regex compilation. The pattern `\s+` is
/// a fixed, known-valid regular expression, so compilation cannot
/// fail at runtime. The assert is intentional and safe.
pub fn collapse_unicode_space() -> Prep(String) {
  // nolint: assert_ok_pattern -- "\\s+" is a fixed, known-valid regex literal
  let assert Ok(re) = regexp.from_string("\\s+")
  fn(s) { regexp.replace(each: re, in: s, with: " ") }
}

/// Replace all occurrences of target with replacement.
pub fn replace(
  target target: String,
  replacement replacement: String,
) -> Prep(String) {
  fn(s) { string.replace(in: s, each: target, with: replacement) }
}

/// Replace the value with fallback when the input is exactly the
/// literal empty string `""`.
///
/// Whitespace-only inputs like `" "`, `"\t"`, `"  \n  "` are
/// **passed through unchanged** — only `s == ""` triggers the
/// fallback. Reach for `default_when_blank` instead when you want
/// the broader \"missing or whitespace-only\" check, or compose with
/// `trim`:
///
///   prep.trim() |> prep.then(first: _, next: prep.default("N/A"))
pub fn default(fallback: String) -> Prep(String) {
  fn(s) {
    case s {
      "" -> fallback
      _ -> s
    }
  }
}

/// Replace the value with fallback when the input is the literal
/// empty string `""` **or** consists only of whitespace (per
/// `string.trim`).
///
/// Examples that fire the fallback: `""`, `" "`, `"\t"`, `"\r\n"`,
/// `"  \n  "`. Examples that do not: `"a"`, `" a "`, `"\t hello"`.
///
/// Equivalent to `prep.trim() |> prep.then(prep.default(fallback))`
/// when the trimmed value is what the caller wants to keep on the
/// non-blank path. The dedicated helper preserves the **original**
/// (un-trimmed) input on the non-blank path, which matches the
/// `default` posture: only substitute, never edit. Use the explicit
/// `trim |> default` composition when the trimmed form is the
/// desired output.
pub fn default_when_blank(fallback: String) -> Prep(String) {
  fn(s) {
    case string.trim(s) {
      "" -> fallback
      _ -> s
    }
  }
}

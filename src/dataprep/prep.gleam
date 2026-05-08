//// `dataprep/prep` — infallible transformations on a single value.
////
//// Reach for this module when the operation **always succeeds**:
//// trim, lowercase, collapse whitespace, replace substrings, fall
//// back to a default. Compose with `then` / `sequence`.
////
//// For fallible checks (\"is this non-empty?\", \"does this match a
//// pattern?\") use `dataprep/validator`. The two compose cleanly —
//// see [`doc/architecture.md`](../../doc/architecture.md) for the
//// decision table, the canonical Prep → Validator pipeline recipe,
//// and a worked end-to-end example.
////
//// ## Applying a Prep
////
//// `Prep(a)` is a type alias for `fn(a) -> a`, so applying a built
//// prep is **just calling it like a function** — no wrapper module
//// function is needed:
////
//// ```gleam
//// let pipeline = prep.then(first: prep.trim(), next: prep.uppercase())
//// let cleaned = pipeline(\"  hello  \")  // \"HELLO\"
//// ```
////
//// For readers who prefer a named entry point — pipeline-style or
//// when threading a prep through multiple call sites — `prep.run/2`
//// is a thin alias of the function call: `prep.run(pipeline, value)`
//// is identical to `pipeline(value)`. Pick whichever reads better at
//// your call site; both compile to the same code.

import gleam/list
import gleam/regexp
import gleam/string

/// Prep(a) is an infallible transformation: fn(a) -> a.
/// It always succeeds and never produces errors.
pub type Prep(a) =
  fn(a) -> a

/// Sequential composition: apply p1, then apply p2 to the result.
///
/// FP-leaning users often grep for `compose` first; `prep.compose/2`
/// is a labelled alias of this function with the same semantics.
/// Both forms accept positional and labelled arguments.
pub fn then(first p1: Prep(a), next p2: Prep(a)) -> Prep(a) {
  fn(x) { p2(p1(x)) }
}

/// Sequential composition: same as `then/2`, exposed under the FP
/// `compose` name so callers coming from Haskell `(.)`, Elm `<<`,
/// or lodash `_.flow` find the entry point on first grep. The label
/// reads `compose(first:, then:)` — the second label is `then` (not
/// `next`) to mirror the prose "first do f, *then* do g". Output is
/// byte-identical to `then(first:, next:)`. (#61)
pub fn compose(first p1: Prep(a), then p2: Prep(a)) -> Prep(a) {
  then(first: p1, next: p2)
}

/// Compose a list of preps into a single prep.
///
/// `identity()` is the identity element of sequential composition,
/// so `sequence([])` returns a prep that leaves every input
/// unchanged. This is a deliberate monoid law (see
/// `test/dataprep/laws_test.gleam`) and lets callers build prep
/// lists incrementally — for example via
/// `list.filter(all_preps, by_feature_flag)` — without a special
/// case when the resulting list happens to be empty.
pub fn sequence(steps: List(Prep(a))) -> Prep(a) {
  list.fold(over: steps, from: identity(), with: fn(acc, step) {
    then(first: acc, next: step)
  })
}

/// No-op prep. Returns the value unchanged.
pub fn identity() -> Prep(a) {
  fn(x) { x }
}

/// Apply a `Prep(a)` to a value. Thin alias of the function call:
/// `prep.run(p, value)` is identical to `p(value)`. The two forms
/// compile to the same code; reach for `run/2` when a named entry
/// point reads better at the call site (pipelines, currying, threading
/// the prep value through multiple call sites). Discoverability hook
/// for users who grep for "apply" / "run" before learning the type
/// alias trick (#60).
pub fn run(prep prep: Prep(a), value value: a) -> a {
  prep(value)
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

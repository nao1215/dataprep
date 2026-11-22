import dataprep/prep
import gleam/list
import gleam/result
import gleam/string

// --- identity ---

pub fn identity_test() -> Nil {
  let prepper = prep.identity()
  assert prepper("hello") == "hello"
}

pub fn identity_empty_test() -> Nil {
  let prepper = prep.identity()
  assert prepper("") == ""
}

// --- trim ---

pub fn trim_test() -> Nil {
  let prepper = prep.trim()
  assert prepper("  hello  ") == "hello"
}

pub fn trim_empty_test() -> Nil {
  assert prep.trim()("") == ""
}

pub fn trim_only_whitespace_test() -> Nil {
  assert prep.trim()("   \t\n  ") == ""
}

pub fn trim_no_whitespace_test() -> Nil {
  assert prep.trim()("hello") == "hello"
}

// --- lowercase ---

pub fn lowercase_test() -> Nil {
  let prepper = prep.lowercase()
  assert prepper("HELLO") == "hello"
}

pub fn lowercase_mixed_test() -> Nil {
  assert prep.lowercase()("Hello World") == "hello world"
}

pub fn lowercase_empty_test() -> Nil {
  assert prep.lowercase()("") == ""
}

pub fn lowercase_already_lower_test() -> Nil {
  assert prep.lowercase()("abc") == "abc"
}

// --- uppercase ---

pub fn uppercase_test() -> Nil {
  let prepper = prep.uppercase()
  assert prepper("hello") == "HELLO"
}

pub fn uppercase_empty_test() -> Nil {
  assert prep.uppercase()("") == ""
}

// --- collapse_space ---

pub fn collapse_space_test() -> Nil {
  let prepper = prep.collapse_space()
  assert prepper("a   b\t\tc") == "a b c"
}

pub fn collapse_space_single_space_test() -> Nil {
  assert prep.collapse_space()("a b") == "a b"
}

pub fn collapse_space_leading_trailing_test() -> Nil {
  assert prep.collapse_space()("  hello   world  ") == " hello world "
}

pub fn collapse_space_empty_test() -> Nil {
  assert prep.collapse_space()("") == ""
}

pub fn collapse_space_tabs_and_newlines_test() -> Nil {
  assert prep.collapse_space()("\t\na\n\n\tb\t") == " a b "
}

pub fn collapse_space_preserves_nbsp_test() -> Nil {
  // NO-BREAK SPACE (U+00A0) is Unicode whitespace but not in the
  // ASCII whitespace class, so collapse_space leaves it alone.
  let nbsp = "\u{00A0}"
  let input = "a" <> nbsp <> nbsp <> "b"
  assert prep.collapse_space()(input) == input
}

pub fn collapse_space_preserves_ideographic_space_test() -> Nil {
  // IDEOGRAPHIC SPACE (U+3000) — full-width Japanese space — must
  // survive `collapse_space` for CJK callers (姓　名 stays intact).
  let ideographic = "\u{3000}"
  let input = "姓" <> ideographic <> ideographic <> "名"
  assert prep.collapse_space()(input) == input
}

pub fn collapse_space_collapses_ascii_runs_around_unicode_whitespace_test() -> Nil {
  // ASCII runs collapse, but the surrounding Unicode whitespace stays.
  let nbsp = "\u{00A0}"
  let input = "a   " <> nbsp <> "   b"
  assert prep.collapse_space()(input) == "a " <> nbsp <> " b"
}

// --- collapse_unicode_space ---

pub fn collapse_unicode_space_collapses_nbsp_test() -> Nil {
  // The opt-in Unicode variant DOES fold NO-BREAK SPACE runs into a
  // single ASCII space.
  let nbsp = "\u{00A0}"
  let input = "a" <> nbsp <> nbsp <> "b"
  assert prep.collapse_unicode_space()(input) == "a b"
}

pub fn collapse_unicode_space_collapses_ideographic_test() -> Nil {
  let ideographic = "\u{3000}"
  let input = "a" <> ideographic <> ideographic <> "b"
  assert prep.collapse_unicode_space()(input) == "a b"
}

pub fn collapse_unicode_space_collapses_ascii_runs_test() -> Nil {
  // Behaves identically to the old `collapse_space` for pure-ASCII input.
  assert prep.collapse_unicode_space()("a   b\t\tc") == "a b c"
}

pub fn collapse_unicode_space_empty_test() -> Nil {
  assert prep.collapse_unicode_space()("") == ""
}

// --- replace ---

pub fn replace_test() -> Nil {
  let prepper = prep.replace(target: "-", replacement: "_")
  assert prepper("foo-bar-baz") == "foo_bar_baz"
}

pub fn replace_no_match_test() -> Nil {
  assert prep.replace(target: "-", replacement: "_")("hello") == "hello"
}

pub fn replace_absent_target_test() -> Nil {
  assert prep.replace(target: "x", replacement: "y")("hello") == "hello"
}

pub fn replace_to_empty_test() -> Nil {
  assert prep.replace(target: "e", replacement: "")("hello") == "hllo"
}

// --- replace_checked (runtime-supplied target, regression guard for #106) ---
//
// prep.replace panics at construction time on an empty target. That is the
// right default for known-good code, but runtime-supplied targets (user input,
// config, CSV) need a recoverable path. replace_checked returns the same prep
// as replace for a valid target, and Error(EmptyTarget) instead of panicking.
// These tests pin that the two constructors agree so they cannot drift.

pub fn replace_checked_valid_target_test() -> Nil {
  assert prep.replace_checked(target: "-", replacement: "_")
    |> result.map(fn(prepper) { prepper("foo-bar-baz") })
    == Ok("foo_bar_baz")
}

pub fn replace_checked_empty_target_is_error_test() -> Nil {
  assert prep.replace_checked(target: "", replacement: "X")
    == Error(prep.EmptyTarget)
}

pub fn replace_checked_matches_replace_for_valid_target_test() -> Nil {
  // Regression anchor: the checked Ok path must behave identically to the
  // unchecked constructor for the same valid arguments.
  let unchecked = prep.replace(target: "e", replacement: "3")
  assert prep.replace_checked(target: "e", replacement: "3")
    |> result.map(fn(checked) { checked("level eleven") })
    == Ok(unchecked("level eleven"))
}

pub fn replace_checked_no_match_test() -> Nil {
  assert prep.replace_checked(target: "x", replacement: "y")
    |> result.map(fn(prepper) { prepper("hello") })
    == Ok("hello")
}

// --- default ---

pub fn default_empty_string_test() -> Nil {
  let prepper = prep.default("N/A")
  assert prepper("") == "N/A"
}

pub fn default_non_empty_test() -> Nil {
  let prepper = prep.default("N/A")
  assert prepper("hello") == "hello"
}

pub fn default_whitespace_only_test() -> Nil {
  let prepper = prep.default("N/A")
  assert prepper("   ") == "   "
}

// `default` only fires on the literal empty string. Pin the boundary
// so a future regression that broadens it (e.g. accepting `" "`)
// flips the test red.
pub fn default_pinned_literal_only_contract_test() -> Nil {
  let prepper = prep.default("FALLBACK")
  assert prepper("") == "FALLBACK"
  assert prepper(" ") == " "
  assert prepper("\t") == "\t"
  assert prepper("abc") == "abc"
}

pub fn default_trim_then_default_composition_test() -> Nil {
  // Documented composition for "fall back when blank, otherwise keep
  // the trimmed form". This pattern is mentioned in the docstring; the
  // test pins it so a `then` shape change cannot silently rot the doc.
  let prepper = prep.trim() |> prep.then(first: _, next: prep.default("N/A"))
  assert prepper("") == "N/A"
  assert prepper("   ") == "N/A"
  assert prepper("\t\n") == "N/A"
  assert prepper("  hi  ") == "hi"
}

// --- default_when_blank ---

pub fn default_when_blank_empty_test() -> Nil {
  let prepper = prep.default_when_blank("N/A")
  assert prepper("") == "N/A"
}

pub fn default_when_blank_whitespace_only_test() -> Nil {
  let prepper = prep.default_when_blank("N/A")
  assert prepper(" ") == "N/A"
  assert prepper("\t") == "N/A"
  assert prepper("  \n  ") == "N/A"
  assert prepper("\r\n") == "N/A"
}

pub fn default_when_blank_non_blank_preserves_input_test() -> Nil {
  // Non-blank: the original (un-trimmed) input is returned. The
  // helper substitutes, it does not edit; reach for
  // `trim |> default` if the trimmed form is what the caller wants.
  let prepper = prep.default_when_blank("N/A")
  assert prepper("hi") == "hi"
  assert prepper("  hi  ") == "  hi  "
  assert prepper("\thello\n") == "\thello\n"
}

// --- then (composition) ---

pub fn then_test() -> Nil {
  let prepper = prep.trim() |> prep.then(first: _, next: prep.lowercase())
  assert prepper("  HELLO  ") == "hello"
}

pub fn then_order_matters_test() -> Nil {
  // trim then default("X") -> "  " becomes "" becomes "X"
  let trim_then_default =
    prep.trim() |> prep.then(first: _, next: prep.default("X"))
  assert trim_then_default("  ") == "X"

  // default("X") then trim -> "  " is not "", so default is no-op, then trim -> ""
  let default_then_trim =
    prep.default("X") |> prep.then(first: _, next: prep.trim())
  assert default_then_trim("  ") == ""
}

pub fn then_three_steps_test() -> Nil {
  let prepper =
    prep.trim()
    |> prep.then(first: _, next: prep.lowercase())
    |> prep.then(first: _, next: prep.collapse_space())
  assert prepper("  Hello   World  ") == "hello world"
}

// --- sequence ---

pub fn sequence_test() -> Nil {
  let prepper =
    prep.sequence([prep.trim(), prep.lowercase(), prep.collapse_space()])
  assert prepper("  John   DOE  ") == "john doe"
}

pub fn sequence_empty_test() -> Nil {
  let prepper = prep.sequence([])
  assert prepper("unchanged") == "unchanged"
}

pub fn sequence_single_test() -> Nil {
  let prepper = prep.sequence([prep.trim()])
  assert prepper("  hello  ") == "hello"
}

// --- composition patterns ---

pub fn trim_then_default_test() -> Nil {
  let prepper = prep.trim() |> prep.then(first: _, next: prep.default("N/A"))
  assert prepper("   ") == "N/A"
  assert prepper("hello") == "hello"
  assert prepper("") == "N/A"
}

pub fn full_pipeline_test() -> Nil {
  let clean =
    prep.sequence([
      prep.trim(),
      prep.lowercase(),
      prep.collapse_space(),
      prep.replace(target: ".", replacement: ""),
    ])
  assert clean("  John.  DOE.  Jr  ") == "john doe jr"
}

// --- compose/2: FP-named alias of then/2 (#61) ---

pub fn compose_matches_then_test() -> Nil {
  let via_then = prep.then(first: prep.trim(), next: prep.uppercase())
  let via_compose = prep.compose(first: prep.trim(), then: prep.uppercase())
  // Same input must produce the same output via either entry point.
  assert via_then("  hello  ") == via_compose("  hello  ")
  assert via_then("  hello  ") == "HELLO"
}

pub fn compose_with_default_test() -> Nil {
  let pipeline = prep.compose(first: prep.trim(), then: prep.default("N/A"))
  assert pipeline("   ") == "N/A"
  assert pipeline("hello") == "hello"
  assert pipeline("") == "N/A"
}

pub fn compose_associativity_with_then_test() -> Nil {
  // (trim ∘ lowercase) ∘ collapse must equal trim ∘ (lowercase ∘ collapse)
  // for total transformations on the same type — pinning the monoid
  // law on the alias side.
  let trim_step = prep.trim()
  let lower_step = prep.lowercase()
  let collapse_step = prep.collapse_space()
  let left =
    prep.compose(
      first: prep.compose(first: trim_step, then: lower_step),
      then: collapse_step,
    )
  let right =
    prep.compose(
      first: trim_step,
      then: prep.compose(first: lower_step, then: collapse_step),
    )
  let input = "  Hello   WORLD  "
  assert left(input) == right(input)
}

// --- run/2: discoverability hook for the function-call form (#60) ---

pub fn run_is_function_call_test() -> Nil {
  let pipeline = prep.then(first: prep.trim(), next: prep.uppercase())
  // run/2 must be byte-identical to calling the prep value directly.
  assert prep.run(pipeline, "  hello  ") == pipeline("  hello  ")
}

pub fn run_with_identity_test() -> Nil {
  // identity()'s `run` is the identity function on the value.
  assert prep.run(prep.identity(), "untouched") == "untouched"
}

pub fn run_with_sequence_test() -> Nil {
  let clean =
    prep.sequence([prep.trim(), prep.lowercase(), prep.collapse_space()])
  assert prep.run(clean, "  John.  DOE.  Jr  ") == "john. doe. jr"
}

// --- collapse_space / collapse_unicode_space: exact character sets ---
//
// Both used PCRE classes (`\v`, `\s`) whose meaning differs from the
// JavaScript engine, so U+0085, U+2028 and U+FEFF collapsed on one
// target only. Each code point below must behave the same on both.

const ascii_space_codepoints = [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20]

// Unicode White_Space.
const unicode_space_codepoints = [
  0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2000, 0x2001, 0x2002,
  0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x2028, 0x2029,
  0x202F, 0x205F, 0x3000,
]

// Not White_Space, though some engines treat a few of them as `\s`.
const non_space_codepoints = [0x180E, 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF]

fn doubled(codepoint: Int) -> String {
  // nolint: assert_ok_pattern -- every test code point is a valid scalar value
  let assert Ok(c) = string.utf_codepoint(codepoint)
    as "test code points are valid scalar values"
  let char = string.from_utf_codepoints([c])
  "a" <> char <> char <> "b"
}

pub fn collapse_space_folds_exactly_ascii_whitespace_test() -> Nil {
  let collapse = prep.collapse_space()
  list.each(ascii_space_codepoints, fn(cp) {
    assert #(cp, collapse(doubled(cp))) == #(cp, "a b")
  })
  unicode_space_codepoints
  |> list.filter(fn(cp) { !list.contains(ascii_space_codepoints, cp) })
  |> list.append(non_space_codepoints)
  |> list.each(fn(cp) {
    assert #(cp, collapse(doubled(cp))) == #(cp, doubled(cp))
  })
}

pub fn collapse_unicode_space_folds_exactly_unicode_whitespace_test() -> Nil {
  let collapse = prep.collapse_unicode_space()
  list.each(unicode_space_codepoints, fn(cp) {
    assert #(cp, collapse(doubled(cp))) == #(cp, "a b")
  })
  list.each(non_space_codepoints, fn(cp) {
    assert #(cp, collapse(doubled(cp))) == #(cp, doubled(cp))
  })
}

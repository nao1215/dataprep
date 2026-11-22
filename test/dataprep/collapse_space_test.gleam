import dataprep
import gleam/list
import gleam/string

// --- collapse_space ---

pub fn collapse_space_test() -> Nil {
  assert dataprep.collapse_space("a   b\t\tc") == "a b c"
}

pub fn collapse_space_single_space_test() -> Nil {
  assert dataprep.collapse_space("a b") == "a b"
}

pub fn collapse_space_leading_trailing_test() -> Nil {
  assert dataprep.collapse_space("  hello   world  ") == " hello world "
}

pub fn collapse_space_empty_test() -> Nil {
  assert dataprep.collapse_space("") == ""
}

pub fn collapse_space_tabs_and_newlines_test() -> Nil {
  assert dataprep.collapse_space("\t\na\n\n\tb\t") == " a b "
}

pub fn collapse_space_preserves_nbsp_test() -> Nil {
  // NO-BREAK SPACE (U+00A0) is Unicode whitespace but not in the
  // ASCII whitespace class, so collapse_space leaves it alone.
  let nbsp = "\u{00A0}"
  let input = "a" <> nbsp <> nbsp <> "b"
  assert dataprep.collapse_space(input) == input
}

pub fn collapse_space_preserves_ideographic_space_test() -> Nil {
  // IDEOGRAPHIC SPACE (U+3000) — full-width Japanese space — must
  // survive `collapse_space` for CJK callers (姓　名 stays intact).
  let ideographic = "\u{3000}"
  let input = "姓" <> ideographic <> ideographic <> "名"
  assert dataprep.collapse_space(input) == input
}

pub fn collapse_space_collapses_ascii_runs_around_unicode_whitespace_test() -> Nil {
  // ASCII runs collapse, but the surrounding Unicode whitespace stays.
  let nbsp = "\u{00A0}"
  let input = "a   " <> nbsp <> "   b"
  assert dataprep.collapse_space(input) == "a " <> nbsp <> " b"
}

// --- collapse_unicode_space ---

pub fn collapse_unicode_space_collapses_nbsp_test() -> Nil {
  // The opt-in Unicode variant DOES fold NO-BREAK SPACE runs into a
  // single ASCII space.
  let nbsp = "\u{00A0}"
  let input = "a" <> nbsp <> nbsp <> "b"
  assert dataprep.collapse_unicode_space(input) == "a b"
}

pub fn collapse_unicode_space_collapses_ideographic_test() -> Nil {
  let ideographic = "\u{3000}"
  let input = "a" <> ideographic <> ideographic <> "b"
  assert dataprep.collapse_unicode_space(input) == "a b"
}

pub fn collapse_unicode_space_collapses_ascii_runs_test() -> Nil {
  // Behaves identically to the old `collapse_space` for pure-ASCII input.
  assert dataprep.collapse_unicode_space("a   b\t\tc") == "a b c"
}

pub fn collapse_unicode_space_empty_test() -> Nil {
  assert dataprep.collapse_unicode_space("") == ""
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
  let collapse = dataprep.collapse_space
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
  let collapse = dataprep.collapse_unicode_space
  list.each(unicode_space_codepoints, fn(cp) {
    assert #(cp, collapse(doubled(cp))) == #(cp, "a b")
  })
  list.each(non_space_codepoints, fn(cp) {
    assert #(cp, collapse(doubled(cp))) == #(cp, doubled(cp))
  })
}

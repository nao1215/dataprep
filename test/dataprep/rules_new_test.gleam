import dataprep
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string
import non_empty_list

type Err {
  IsBlank
  BadFormat
  TooSmallFloat
  TooBigFloat
}

fn compile_regexp(pattern: String) -> regexp.Regexp {
  // nolint: assert_ok_pattern -- test regex literals are fixed and known-valid
  let assert Ok(compiled) = regexp.from_string(pattern)
  compiled
}

fn full_match(pattern: String) -> dataprep.Validator(String, Err) {
  unwrap_checked(dataprep.full_match(pattern: pattern, error: BadFormat))
}

fn unwrap_checked(
  result: Result(dataprep.Validator(String, Err), regexp.CompileError),
) -> dataprep.Validator(String, Err) {
  // nolint: assert_ok_pattern -- test patterns are fixed and known-valid
  let assert Ok(check) = result
  check
}

// --- not_blank ---

pub fn not_blank_pass_test() -> Nil {
  assert dataprep.not_blank(IsBlank)("hello") == Ok("hello")
}

pub fn not_blank_fail_empty_test() -> Nil {
  assert dataprep.not_blank(IsBlank)("")
    == Error(non_empty_list.single(IsBlank))
}

pub fn not_blank_fail_whitespace_test() -> Nil {
  assert dataprep.not_blank(IsBlank)("   ")
    == Error(non_empty_list.single(IsBlank))
}

pub fn not_blank_fail_tabs_newlines_test() -> Nil {
  assert result.is_error(dataprep.not_blank(IsBlank)("\t\n  "))
}

pub fn not_blank_pass_with_content_test() -> Nil {
  assert dataprep.not_blank(IsBlank)("  hello  ") == Ok("  hello  ")
}

pub fn not_blank_rejects_unicode_whitespace_test() -> Nil {
  // Python's str.isspace and JavaScript's String.prototype.trim treat
  // these as whitespace, and so does collapse_unicode_space.
  ["\u{3000}", "\u{A0}", "\u{2007}", "\u{1680}", "\u{205F}", " \u{3000}\t"]
  |> list.each(fn(raw) {
    assert #(raw, dataprep.not_blank(IsBlank)(raw))
      == #(raw, Error(non_empty_list.single(IsBlank)))
  })
}

pub fn not_blank_accepts_characters_outside_white_space_test() -> Nil {
  // Direction marks and the byte order mark are not White_Space.
  ["\u{200E}", "\u{200F}", "\u{FEFF}"]
  |> list.each(fn(raw) {
    assert #(raw, dataprep.not_blank(IsBlank)(raw)) == #(raw, Ok(raw))
  })
}

// --- matches ---

pub fn matches_pass_test() -> Nil {
  let pattern = compile_regexp("^[a-z0-9]+$")
  assert dataprep.matches(pattern: pattern, error: BadFormat)("abc123")
    == Ok("abc123")
}

pub fn matches_fail_test() -> Nil {
  let pattern = compile_regexp("^[a-z]+$")
  assert dataprep.matches(pattern: pattern, error: BadFormat)("abc123")
    == Error(non_empty_list.single(BadFormat))
}

pub fn matches_empty_string_test() -> Nil {
  let pattern = compile_regexp("^.+$")
  assert result.is_error(dataprep.matches(pattern: pattern, error: BadFormat)(
    "",
  ))
}

pub fn matches_with_guard_test() -> Nil {
  let pattern = compile_regexp("^[a-z]+$")
  let validator_under_test =
    dataprep.not_empty(IsBlank)
    |> dataprep.and_then(
      first: _,
      then: dataprep.matches(pattern: pattern, error: BadFormat),
    )
  assert validator_under_test("") == Error(non_empty_list.single(IsBlank))
  assert validator_under_test("ABC") == Error(non_empty_list.single(BadFormat))
  assert validator_under_test("abc") == Ok("abc")
}

// --- unanchored matches ---
//
// `matches` documents that it is `regexp.check`-shaped: a substring
// hit is enough. These tests pin that contract so a regression that
// silently anchors the predicate would fail loudly.

pub fn matches_unanchored_pattern_accepts_substring_hit_test() -> Nil {
  let pattern = compile_regexp("[0-9]+")
  assert dataprep.matches(pattern: pattern, error: BadFormat)("abc123def")
    == Ok("abc123def")
}

// --- full_match ---

pub fn full_match_full_match_passes_test() -> Nil {
  assert full_match("[0-9]+")("123") == Ok("123")
}

pub fn full_match_no_match_at_all_is_rejected_test() -> Nil {
  assert full_match("[0-9]+")("abc") == Error(non_empty_list.single(BadFormat))
}

pub fn full_match_empty_input_with_star_pattern_test() -> Nil {
  // `.*` matches the empty string, and the empty match equals the
  // empty input — full-match semantics.
  assert full_match(".*")("") == Ok("")
}

pub fn full_match_empty_input_with_plus_pattern_test() -> Nil {
  // `.+` requires at least one character; the empty input has no
  // match at all and is rejected.
  assert full_match(".+")("") == Error(non_empty_list.single(BadFormat))
}

pub fn full_match_pass_test() -> Nil {
  assert full_match("[a-z0-9-]+")("ok-1") == Ok("ok-1")
}

pub fn full_match_substring_hit_is_rejected_test() -> Nil {
  // The headline #7 case: literal pattern + substring match must be
  // rejected by the _fully variant.
  assert full_match("[0-9]+")("abc123def")
    == Error(non_empty_list.single(BadFormat))
}

pub fn full_match_top_level_alternation_test() -> Nil {
  // Regression for #47: under leftmost-first alternation the engine
  // would otherwise pick the shorter `a` and reject `"ab"` even
  // though `ab` is one of the alternatives. `full_match_string`
  // anchors the source pattern as `^(?:a|ab)$` internally, which
  // restores Python `re.fullmatch` semantics.
  let check = full_match("a|ab")
  assert check("a") == Ok("a")
  assert check("ab") == Ok("ab")
  assert check("abc") == Error(non_empty_list.single(BadFormat))
}

pub fn full_match_trailing_newline_is_rejected_test() -> Nil {
  // Pins cross-target consistency: Erlang's `re` treats `$` as
  // matching before a final newline by default, JavaScript's
  // `RegExp` does not. The predicate checks scan-match content
  // against the input length, so both runtimes reject a trailing
  // newline that the pattern did not opt into. (#47 follow-up.)
  let check = full_match("foo")
  assert check("foo") == Ok("foo")
  assert check("foo\n") == Error(non_empty_list.single(BadFormat))
}

pub fn full_match_alternation_realistic_patterns_test() -> Nil {
  // Real-world allowlists from #47: each branch must accept any
  // alternative spelling without depending on branch order.
  let scheme = full_match("http|https")
  assert scheme("http") == Ok("http")
  assert scheme("https") == Ok("https")
  assert scheme("ftp") == Error(non_empty_list.single(BadFormat))

  let yesno = full_match("yes|y|true|t")
  assert yesno("yes") == Ok("yes")
  assert yesno("y") == Ok("y")
  assert yesno("true") == Ok("true")
  assert yesno("t") == Ok("t")
  assert yesno("maybe") == Error(non_empty_list.single(BadFormat))
}

pub fn full_match_invalid_pattern_returns_error_test() -> Nil {
  assert case dataprep.full_match(pattern: "(unclosed", error: BadFormat) {
    Error(regexp.CompileError(..)) -> True
    Ok(_) -> False
  }
}

// --- min_float / max_float ---

pub fn min_float_pass_test() -> Nil {
  assert dataprep.min_float(minimum: 1.0, error: TooSmallFloat)(1.5) == Ok(1.5)
}

pub fn min_float_boundary_test() -> Nil {
  assert dataprep.min_float(minimum: 1.0, error: TooSmallFloat)(1.0) == Ok(1.0)
}

pub fn min_float_fail_test() -> Nil {
  assert result.is_error(dataprep.min_float(minimum: 1.0, error: TooSmallFloat)(
    0.5,
  ))
}

pub fn max_float_pass_test() -> Nil {
  assert dataprep.max_float(maximum: 10.0, error: TooBigFloat)(5.0) == Ok(5.0)
}

pub fn max_float_boundary_test() -> Nil {
  assert dataprep.max_float(maximum: 10.0, error: TooBigFloat)(10.0) == Ok(10.0)
}

pub fn max_float_fail_test() -> Nil {
  assert result.is_error(dataprep.max_float(maximum: 10.0, error: TooBigFloat)(
    10.1,
  ))
}

pub fn min_max_float_combined_test() -> Nil {
  let validator_under_test =
    dataprep.min_float(minimum: 0.0, error: TooSmallFloat)
    |> dataprep.both(
      first: _,
      second: dataprep.max_float(maximum: 100.0, error: TooBigFloat),
    )
  assert validator_under_test(50.0) == Ok(50.0)
  assert result.is_error(validator_under_test(-0.1))
  assert result.is_error(validator_under_test(100.1))
}

// --- full_match: pattern injection and the real end ---
//
// The pattern was spliced into `^(?:` <> pattern <> `)$`, so a pattern
// that does not compile on its own, such as "a)|(b", closed the
// wrapper group and was accepted. Erlang's `$` also matched before a
// trailing newline, so "a|a\n" rejected "a\n" on Erlang only.

pub fn full_match_rejects_unbalanced_pattern_test() -> Nil {
  assert case dataprep.full_match(pattern: "a)|(b", error: BadFormat) {
    Error(regexp.CompileError(..)) -> True
    Ok(_) -> False
  }
}

pub fn full_match_reports_same_error_as_pattern_test() -> Nil {
  ["ab(", "ab)", "[", "a)|(b"]
  |> list.each(fn(pattern) {
    let fully = dataprep.full_match(pattern: pattern, error: BadFormat)
    let plain = regexp.from_string(pattern)
    // nolint: assert_ok_pattern -- every pattern in the list is malformed
    let assert Error(fully_error) = fully as "pattern does not compile"
    // nolint: assert_ok_pattern -- every pattern in the list is malformed
    let assert Error(plain_error) = plain as "pattern does not compile"
    assert #(pattern, fully_error) == #(pattern, plain_error)
  })
}

pub fn full_match_accepts_alternative_ending_in_newline_test() -> Nil {
  let check = full_match("a|a\n")
  assert check("a\n") == Ok("a\n")
  assert check("a") == Ok("a")
}

pub fn full_match_rejects_trailing_newline_test() -> Nil {
  let check = full_match("[a-z]+")
  assert check("abc\n") == Error(non_empty_list.single(BadFormat))
  assert check("abc\n\n") == Error(non_empty_list.single(BadFormat))
}

// --- full_match compiles every pattern that compiles on its own ---
//
// Erlang's PCRE accepts constructs that used to break the anchoring
// wrapper: verbs such as "(*UTF)" that must come first, a "\Q" quote
// left open at the end, and a "#" comment in extended mode. JavaScript
// rejects all of them on their own, so on that target both sides fail.

pub fn full_match_compiles_whenever_the_pattern_compiles_test() -> Nil {
  [
    "(*UTF)a", "(*UCP)(*CR)a", "(*LIMIT_MATCH=100)a", "\\Qa.b", "a\\Q",
    "(?x)a # comment", "a(?x)b # tail", "(*CR)(?x)a # c", "(*NUL)(?x)a # c",
    "(*CRLF)(?x)a # c", "(*ANY)(?x)a # c", "\\\\Q", "a|ab", "a(?R)?b",
    "a(*ACCEPT)b", "(?<x>a)(?R)?b", "(*UTF)a(?0)?b", "a(?R)?(?x) # c",
  ]
  |> list.each(fn(pattern) {
    let alone = result.is_ok(regexp.from_string(pattern))
    let full = result.is_ok(dataprep.full_match(pattern:, error: BadFormat))
    assert #(pattern, full) == #(pattern, alone)
  })
}

/// `a(?R)?b` on its own matches the strings of n `a`s followed by n `b`s.
/// Every string of `a` and `b` up to 8 characters is checked.
pub fn full_match_recursion_matches_balanced_strings_test() -> Nil {
  case dataprep.full_match(pattern: "a(?R)?b", error: BadFormat) {
    Error(error) -> {
      assert Error(error) == regexp.from_string("a(?R)?b")
    }
    Ok(check) ->
      strings_up_to(8)
      |> list.each(fn(input) {
        let half = string.length(input) / 2
        let balanced =
          half > 0
          && input == string.repeat("a", half) <> string.repeat("b", half)
        assert #(input, result.is_ok(check(input))) == #(input, balanced)
      })
  }
}

fn strings_up_to(length: Int) -> List(String) {
  case length {
    0 -> [""]
    _ -> {
      let shorter = strings_up_to(length - 1)
      list.append(
        [""],
        list.flat_map(shorter, fn(text) { [text <> "a", text <> "b"] }),
      )
      |> list.unique
    }
  }
}

pub fn full_match_keeps_the_meaning_of_patterns_with_pcre_extras_test() -> Nil {
  [
    #("(*UTF)a", "a", True),
    #("(*UTF)a", "aa", False),
    #("\\Qa.b", "a.b", True),
    #("\\Qa.b", "axb", False),
    #("(?x)a # comment", "a", True),
    #("(?x)a # comment", "a # comment", False),
    #("a(?x)b # tail", "ab", True),
    #("(*CR)(?x)a # c", "a", True),
    #("(*NUL)(?x)a # c", "a", True),
    #("(*LF)(?x)a # c", "a", True),
    #("(*CRLF)(?x)a # c", "a", True),
    // `(?R)` recurses into the pattern, not into the anchors around it.
    #("a(?R)?b", "ab", True),
    #("a(?R)?b", "aabb", True),
    #("a(?R)?b", "aaabbb", True),
    #("a(?R)?b", "aab", False),
    #("a(?R)?b", "abab", False),
    #("a(?0)?b", "aabb", True),
    #("(?<x>a)(?R)?b", "aabb", True),
    #("(*UTF)a(?R)?b", "aabb", True),
    #("(?:a(?R)?b|c)", "aacbb", True),
    // `(*ACCEPT)` ends the match where it is, which is a full match only at
    // the end of the input.
    #("a(*ACCEPT)b", "a", True),
    #("a(*ACCEPT)b", "ab", False),
    #("a(*ACCEPT)b", "axyz", False),
    #("a(?R)?(*ACCEPT)b", "aa", True),
    #("a(?R)?(*ACCEPT)b", "aab", False),
    #("a(?=b(*ACCEPT))b", "ab", True),
    // Items inside a class, a quote or a comment are text.
    #("[(?R)]+", "(?R)", True),
    #("[(?R)]+", "ab", False),
    #("\\Q(?R)\\E", "(?R)", True),
    #("a(?#(?R))b", "ab", True),
  ]
  |> list.each(fn(example) {
    let #(pattern, input, expected) = example
    case dataprep.full_match(pattern:, error: BadFormat) {
      // JavaScript rejects these patterns on their own, with the same error.
      Error(error) -> {
        assert Error(error) == regexp.from_string(pattern)
      }
      Ok(check) -> {
        assert #(pattern, input, result.is_ok(check(input)))
          == #(pattern, input, expected)
      }
    }
  })
}

import dataprep/prep

// --- identity ---

pub fn identity_test() {
  let p = prep.identity()
  let assert "hello" = p("hello")
}

pub fn identity_empty_test() {
  let p = prep.identity()
  let assert "" = p("")
}

// --- trim ---

pub fn trim_test() {
  let p = prep.trim()
  let assert "hello" = p("  hello  ")
}

pub fn trim_empty_test() {
  let assert "" = prep.trim()("")
}

pub fn trim_only_whitespace_test() {
  let assert "" = prep.trim()("   \t\n  ")
}

pub fn trim_no_whitespace_test() {
  let assert "hello" = prep.trim()("hello")
}

// --- lowercase ---

pub fn lowercase_test() {
  let p = prep.lowercase()
  let assert "hello" = p("HELLO")
}

pub fn lowercase_mixed_test() {
  let assert "hello world" = prep.lowercase()("Hello World")
}

pub fn lowercase_empty_test() {
  let assert "" = prep.lowercase()("")
}

pub fn lowercase_already_lower_test() {
  let assert "abc" = prep.lowercase()("abc")
}

// --- uppercase ---

pub fn uppercase_test() {
  let p = prep.uppercase()
  let assert "HELLO" = p("hello")
}

pub fn uppercase_empty_test() {
  let assert "" = prep.uppercase()("")
}

// --- collapse_space ---

pub fn collapse_space_test() {
  let p = prep.collapse_space()
  let assert "a b c" = p("a   b\t\tc")
}

pub fn collapse_space_single_space_test() {
  let assert "a b" = prep.collapse_space()("a b")
}

pub fn collapse_space_leading_trailing_test() {
  let assert " hello world " = prep.collapse_space()("  hello   world  ")
}

pub fn collapse_space_empty_test() {
  let assert "" = prep.collapse_space()("")
}

pub fn collapse_space_tabs_and_newlines_test() {
  let assert " a b " = prep.collapse_space()("\t\na\n\n\tb\t")
}

// --- replace ---

pub fn replace_test() {
  let p = prep.replace("-", "_")
  let assert "foo_bar_baz" = p("foo-bar-baz")
}

pub fn replace_no_match_test() {
  let assert "hello" = prep.replace("-", "_")("hello")
}

pub fn replace_absent_target_test() {
  let assert "hello" = prep.replace("x", "y")("hello")
}

pub fn replace_to_empty_test() {
  let assert "hllo" = prep.replace("e", "")("hello")
}

// --- default ---

pub fn default_empty_string_test() {
  let p = prep.default("N/A")
  let assert "N/A" = p("")
}

pub fn default_non_empty_test() {
  let p = prep.default("N/A")
  let assert "hello" = p("hello")
}

pub fn default_whitespace_only_test() {
  let p = prep.default("N/A")
  let assert "   " = p("   ")
}

// --- then (composition) ---

pub fn then_test() {
  let p = prep.trim() |> prep.then(prep.lowercase())
  let assert "hello" = p("  HELLO  ")
}

pub fn then_order_matters_test() {
  // trim then default("X") -> "  " becomes "" becomes "X"
  let p1 = prep.trim() |> prep.then(prep.default("X"))
  let assert "X" = p1("  ")

  // default("X") then trim -> "  " is not "", so default is no-op, then trim -> ""
  let p2 = prep.default("X") |> prep.then(prep.trim())
  let assert "" = p2("  ")
}

pub fn then_three_steps_test() {
  let p =
    prep.trim()
    |> prep.then(prep.lowercase())
    |> prep.then(prep.collapse_space())
  let assert "hello world" = p("  Hello   World  ")
}

// --- sequence ---

pub fn sequence_test() {
  let p = prep.sequence([prep.trim(), prep.lowercase(), prep.collapse_space()])
  let assert "john doe" = p("  John   DOE  ")
}

pub fn sequence_empty_test() {
  let p = prep.sequence([])
  let assert "unchanged" = p("unchanged")
}

pub fn sequence_single_test() {
  let p = prep.sequence([prep.trim()])
  let assert "hello" = p("  hello  ")
}

// --- composition patterns ---

pub fn trim_then_default_test() {
  let p = prep.trim() |> prep.then(prep.default("N/A"))
  let assert "N/A" = p("   ")
  let assert "hello" = p("hello")
  let assert "N/A" = p("")
}

pub fn full_pipeline_test() {
  let clean =
    prep.sequence([
      prep.trim(),
      prep.lowercase(),
      prep.collapse_space(),
      prep.replace(".", ""),
    ])
  let assert "john doe jr" = clean("  John.  DOE.  Jr  ")
}

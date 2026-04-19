import dataprep/prep

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

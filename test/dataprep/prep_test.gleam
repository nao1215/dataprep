import dataprep/prep

pub fn identity_test() {
  let p = prep.identity()
  let assert "hello" = p("hello")
}

pub fn trim_test() {
  let p = prep.trim()
  let assert "hello" = p("  hello  ")
}

pub fn lowercase_test() {
  let p = prep.lowercase()
  let assert "hello" = p("HELLO")
}

pub fn uppercase_test() {
  let p = prep.uppercase()
  let assert "HELLO" = p("hello")
}

pub fn collapse_space_test() {
  let p = prep.collapse_space()
  let assert "a b c" = p("a   b\t\tc")
}

pub fn replace_test() {
  let p = prep.replace("-", "_")
  let assert "foo_bar_baz" = p("foo-bar-baz")
}

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

pub fn then_test() {
  let p = prep.trim() |> prep.then(prep.lowercase())
  let assert "hello" = p("  HELLO  ")
}

pub fn sequence_test() {
  let p = prep.sequence([prep.trim(), prep.lowercase(), prep.collapse_space()])
  let assert "john doe" = p("  John   DOE  ")
}

pub fn sequence_empty_test() {
  let p = prep.sequence([])
  let assert "unchanged" = p("unchanged")
}

pub fn trim_then_default_test() {
  let p = prep.trim() |> prep.then(prep.default("N/A"))
  let assert "N/A" = p("   ")
  let assert "hello" = p("hello")
  let assert "N/A" = p("")
}

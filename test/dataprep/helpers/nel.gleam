import dataprep/non_empty_list.{type NonEmptyList}

/// Test helper: build a NonEmptyList from `first` and a `rest` list.
/// Construction goes through the public `from_list` API; the
/// `[first, ..rest]` input is structurally non-empty so the unwrap
/// branch is unreachable.
pub fn make(first first: a, rest rest: List(a)) -> NonEmptyList(a) {
  // nolint: assert_ok_pattern -- [first, ..rest] is non-empty by construction
  let assert Ok(value) = non_empty_list.from_list([first, ..rest])
  value
}

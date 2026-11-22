import dataprep
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import non_empty_list

type Err {
  TooShort
  TooLong
  IsEmpty
  NotUuid
  NotSlug
  FieldError(path: String, detail: Err)
}

// --- check ---

pub fn check_ok_test() -> Nil {
  let validator_under_test = dataprep.check(fn(_) { Ok(Nil) })
  assert validator_under_test("anything") == Ok("anything")
}

pub fn check_error_test() -> Nil {
  let validator_under_test =
    dataprep.check(fn(s: String) {
      case string.length(s) >= 3 {
        True -> Ok(Nil)
        False -> Error(TooShort)
      }
    })
  assert result.is_error(validator_under_test("ab"))
}

pub fn check_value_dependent_error_test() -> Nil {
  let validator_under_test =
    dataprep.check(fn(s: String) {
      case string.length(s) {
        0 -> Error(IsEmpty)
        n if n < 3 -> Error(TooShort)
        _ -> Ok(Nil)
      }
    })
  assert validator_under_test("") == Error(non_empty_list.single(IsEmpty))
  assert validator_under_test("ab") == Error(non_empty_list.single(TooShort))
  assert validator_under_test("abc") == Ok("abc")
}

// --- predicate ---

pub fn predicate_pass_test() -> Nil {
  let validator_under_test = dataprep.predicate(fn(n: Int) { n > 0 }, TooShort)
  assert validator_under_test(5) == Ok(5)
}

pub fn predicate_fail_test() -> Nil {
  let validator_under_test = dataprep.predicate(fn(n: Int) { n > 0 }, TooShort)
  assert result.is_error(validator_under_test(-1))
}

pub fn predicate_boundary_test() -> Nil {
  let validator_under_test = dataprep.predicate(fn(n: Int) { n > 0 }, TooShort)
  assert result.is_error(validator_under_test(0))
  assert validator_under_test(1) == Ok(1)
}

// --- both ---

pub fn both_all_pass_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  assert validator_under_test("hello") == Ok("hello")
}

pub fn both_accumulates_errors_test() -> Nil {
  let v1 = dataprep.predicate(fn(_: String) { False }, TooShort)
  let v2 = dataprep.predicate(fn(_: String) { False }, TooLong)
  let validator_under_test = dataprep.both(first: v1, second: v2)
  assert validator_under_test("x")
    == Error(non_empty_list.new(TooShort, [TooLong]))
}

pub fn both_first_fails_only_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, TooShort)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(_) { True }, TooLong),
    )
  assert validator_under_test("x") == Error(non_empty_list.single(TooShort))
}

pub fn both_second_fails_only_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { True }, TooShort)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(_) { False }, TooLong),
    )
  assert validator_under_test("x") == Error(non_empty_list.single(TooLong))
}

pub fn both_preserves_input_value_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  assert validator_under_test("test") == Ok("test")
}

pub fn both_chained_three_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, IsEmpty)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(_) { False }, TooShort),
    )
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(_) { False }, TooLong),
    )
  assert validator_under_test("x")
    == Error(non_empty_list.new(IsEmpty, [TooShort, TooLong]))
}

// --- all ---

pub fn all_empty_validators_test() -> Nil {
  let validator_under_test = dataprep.all([])
  assert validator_under_test("anything") == Ok("anything")
}

pub fn all_single_pass_test() -> Nil {
  let validator_under_test =
    dataprep.all([dataprep.predicate(fn(_: String) { True }, IsEmpty)])
  assert validator_under_test("x") == Ok("x")
}

pub fn all_single_fail_test() -> Nil {
  let validator_under_test =
    dataprep.all([dataprep.predicate(fn(_: String) { False }, IsEmpty)])
  assert validator_under_test("x") == Error(non_empty_list.single(IsEmpty))
}

pub fn all_accumulates_test() -> Nil {
  let validator_under_test =
    dataprep.all([
      dataprep.predicate(fn(_: String) { False }, TooShort),
      dataprep.predicate(fn(_: String) { True }, IsEmpty),
      dataprep.predicate(fn(_: String) { False }, TooLong),
    ])
  assert validator_under_test("x")
    == Error(non_empty_list.new(TooShort, [TooLong]))
}

pub fn all_all_fail_test() -> Nil {
  let validator_under_test =
    dataprep.all([
      dataprep.predicate(fn(_: String) { False }, IsEmpty),
      dataprep.predicate(fn(_: String) { False }, TooShort),
      dataprep.predicate(fn(_: String) { False }, TooLong),
    ])
  assert validator_under_test("x")
    == Error(non_empty_list.new(IsEmpty, [TooShort, TooLong]))
}

pub fn all_all_pass_test() -> Nil {
  let validator_under_test =
    dataprep.all([
      dataprep.predicate(fn(_: String) { True }, IsEmpty),
      dataprep.predicate(fn(_: String) { True }, TooShort),
    ])
  assert validator_under_test("x") == Ok("x")
}

// --- alt ---

pub fn alt_first_succeeds_skips_second_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { True }, NotUuid)
    |> dataprep.alt(first: _, second: fn(_) {
      // nolint: avoid_panic -- verifies alt short-circuits after success
      panic as "alt must not evaluate second branch when first succeeds"
    })
  assert validator_under_test("test") == Ok("test")
}

pub fn alt_second_succeeds_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, NotUuid)
    |> dataprep.alt(
      first: _,
      second: dataprep.predicate(fn(_) { True }, NotSlug),
    )
  assert validator_under_test("test") == Ok("test")
}

pub fn alt_both_fail_accumulates_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, NotUuid)
    |> dataprep.alt(
      first: _,
      second: dataprep.predicate(fn(_) { False }, NotSlug),
    )
  assert validator_under_test("test")
    == Error(non_empty_list.new(NotUuid, [NotSlug]))
}

pub fn alt_chained_three_first_wins_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, IsEmpty)
    |> dataprep.alt(
      first: _,
      second: dataprep.predicate(fn(_) { True }, TooShort),
    )
    |> dataprep.alt(first: _, second: fn(_) {
      // nolint: avoid_panic -- verifies later alt branches are skipped
      panic as "third alt branch should not run"
    })
  assert validator_under_test("x") == Ok("x")
}

pub fn alt_chained_three_all_fail_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, IsEmpty)
    |> dataprep.alt(
      first: _,
      second: dataprep.predicate(fn(_) { False }, TooShort),
    )
    |> dataprep.alt(
      first: _,
      second: dataprep.predicate(fn(_) { False }, TooLong),
    )
  assert validator_under_test("x")
    == Error(non_empty_list.new(IsEmpty, [TooShort, TooLong]))
}

// --- and_then ---

pub fn and_then_pre_fails_skips_main_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.and_then(first: _, then: fn(_) {
      // nolint: avoid_panic -- verifies and_then short-circuits on pre failure
      panic as "and_then must not evaluate main when pre fails"
    })
  assert validator_under_test("") == Error(non_empty_list.single(IsEmpty))
}

pub fn and_then_pre_passes_then_main_runs_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.and_then(
      first: _,
      then: dataprep.predicate(fn(_) { False }, TooShort),
    )
  assert validator_under_test("hello") == Error(non_empty_list.single(TooShort))
}

pub fn and_then_both_pass_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.and_then(
      first: _,
      then: dataprep.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  assert validator_under_test("hello") == Ok("hello")
}

pub fn and_then_does_not_accumulate_test() -> Nil {
  // and_then is short-circuit, NOT accumulation
  // when pre fails, we only see pre's error, not main's
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, IsEmpty)
    |> dataprep.and_then(
      first: _,
      then: dataprep.predicate(fn(_) { False }, TooShort),
    )
  assert validator_under_test("x") == Error(non_empty_list.single(IsEmpty))
}

pub fn and_then_chained_test() -> Nil {
  // and_then(non_empty, and_then(min_length, max_length))
  let validator_under_test =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.and_then(
      first: _,
      then: dataprep.predicate(
        fn(s: String) { string.length(s) >= 3 },
        TooShort,
      )
        |> dataprep.and_then(
          first: _,
          then: dataprep.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
        ),
    )
  assert validator_under_test("") == Error(non_empty_list.single(IsEmpty))
  assert validator_under_test("ab") == Error(non_empty_list.single(TooShort))
  assert validator_under_test("abc") == Ok("abc")
}

// --- map_error ---

pub fn map_error_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, TooShort)
    |> dataprep.map_error(fn(e) { FieldError("name", e) })
  assert validator_under_test("x")
    == Error(non_empty_list.single(FieldError("name", TooShort)))
}

pub fn map_error_valid_passes_through_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { True }, TooShort)
    |> dataprep.map_error(fn(e) { FieldError("name", e) })
  assert validator_under_test("x") == Ok("x")
}

pub fn map_error_multiple_errors_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(_: String) { False }, TooShort)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(_) { False }, TooLong),
    )
    |> dataprep.map_error(fn(e) { FieldError("field", e) })
  assert validator_under_test("x")
    == Error(
      non_empty_list.new(FieldError("field", TooShort), [
        FieldError("field", TooLong),
      ]),
    )
}

// --- composition: both + alt + and_then ---

pub fn both_then_alt_test() -> Nil {
  // v1: must be non-empty AND short
  // v2: must be non-empty AND long
  // alt: either form is ok
  let short =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(s) { string.length(s) <= 3 }, TooLong),
    )
  let long =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.both(
      first: _,
      second: dataprep.predicate(fn(s) { string.length(s) >= 10 }, TooShort),
    )
  let validator_under_test = dataprep.alt(first: short, second: long)

  assert validator_under_test("ab") == Ok("ab")
  assert validator_under_test("abcdefghijk") == Ok("abcdefghijk")
}

pub fn and_then_composed_with_both_test() -> Nil {
  let validator_under_test =
    dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> dataprep.and_then(
      first: _,
      then: dataprep.predicate(
        fn(s: String) { string.length(s) >= 3 },
        TooShort,
      )
        |> dataprep.both(
          first: _,
          second: dataprep.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
        ),
    )
  assert validator_under_test("") == Error(non_empty_list.single(IsEmpty))
  assert validator_under_test("hello") == Ok("hello")
}

// --- each composes with all/both/alt/and_then (issue #21) ---

/// Issue #21 reproduction: validate "≤ N items in the list" AND
/// "each item satisfies X" using `dataprep.all` over a single
/// `Validator(List(a), e)`. Before the fix, `each` returned the
/// raw `fn(List(a)) -> Validated(...)` arrow which forced callers
/// to write a 7-line bridge to lift it back into `Validator`.
pub fn each_composes_with_all_over_parent_list_test() -> Nil {
  let item_v = dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
  let validator_under_test =
    dataprep.all([
      dataprep.predicate(
        fn(items: List(String)) { list.length(items) <= 3 },
        TooLong,
      ),
      dataprep.each(item_v),
    ])

  // Happy path: list ≤ 3 and every item is non-empty.
  assert validator_under_test(["a", "b"]) == Ok(["a", "b"])

  // Single failure: parent rule fails (too many items), per-item
  // rule passes — only TooLong surfaces.
  assert validator_under_test(["a", "b", "c", "d"])
    == Error(non_empty_list.single(TooLong))

  // Single failure: parent rule passes, per-item rule fails on one
  // element — only IsEmpty surfaces.
  assert validator_under_test(["a", "", "b"])
    == Error(non_empty_list.single(IsEmpty))
}

/// Confirms `each` now composes with `both` exactly like any other
/// `Validator(List(a), e)` would.
pub fn each_composes_with_both_over_parent_list_test() -> Nil {
  let item_v = dataprep.predicate(fn(s: String) { s != "" }, IsEmpty)
  let validator_under_test =
    dataprep.both(
      first: dataprep.predicate(
        fn(items: List(String)) { list.length(items) <= 3 },
        TooLong,
      ),
      second: dataprep.each(item_v),
    )

  assert validator_under_test(["a"]) == Ok(["a"])

  // Both rules fail: errors accumulate.
  assert result.is_error(validator_under_test(["", "", "", ""]))
}

// --- optional composes with all/both/alt/and_then (issue #21) ---

/// Mirror of #21 for `optional`: returns a `Validator(Option(a), e)`
/// so it can sit in an `all` list alongside other Optional-level
/// rules without an adapter wrapper.
pub fn optional_composes_with_all_over_parent_option_test() -> Nil {
  let inner =
    dataprep.predicate(fn(s: String) { string.length(s) >= 3 }, TooShort)
  let validator_under_test =
    dataprep.all([
      dataprep.predicate(option.is_some, IsEmpty),
      dataprep.optional(inner),
    ])

  // Some + valid inner → both rules pass.
  assert validator_under_test(option.Some("hello")) == Ok(option.Some("hello"))

  // None → presence check fails, optional inner short-circuits to
  // Ok(None). Only IsEmpty surfaces.
  assert validator_under_test(option.None)
    == Error(non_empty_list.single(IsEmpty))

  // Some but inner fails → presence check passes, inner fails.
  assert validator_under_test(option.Some("ab"))
    == Error(non_empty_list.single(TooShort))
}

// --- not_empty ---

pub fn not_empty_rejects_empty_string_test() -> Nil {
  let validator_under_test = dataprep.not_empty(IsEmpty)
  assert validator_under_test("") == Error(non_empty_list.single(IsEmpty))
}

pub fn not_empty_accepts_non_empty_string_test() -> Nil {
  let validator_under_test = dataprep.not_empty(IsEmpty)
  assert validator_under_test("hello") == Ok("hello")
}

pub fn not_empty_accepts_whitespace_only_string_test() -> Nil {
  // Whitespace-only is non-empty by string equality, so `required`
  // alone accepts it. Callers who want "required after trimming"
  // pipe through `dataprep.trim` upstream — documented in the validator
  // doc comment.
  let validator_under_test = dataprep.not_empty(IsEmpty)
  assert validator_under_test("   ") == Ok("   ")
}

pub fn not_empty_matches_predicate_form_test() -> Nil {
  // not_empty must agree with the spelt-out predicate form.
  let via_not_empty = dataprep.not_empty(IsEmpty)
  let via_predicate = dataprep.predicate(fn(s) { s != "" }, IsEmpty)
  assert via_not_empty("") == via_predicate("")
  assert via_not_empty("ok") == via_predicate("ok")
  assert via_not_empty(" ") == via_predicate(" ")
}

pub fn not_empty_composes_with_all_test() -> Nil {
  let validator_under_test =
    dataprep.all([
      dataprep.not_empty(IsEmpty),
      dataprep.predicate(fn(s) { string.length(s) <= 32 }, TooLong),
    ])
  assert validator_under_test("ok") == Ok("ok")
  // Empty triggers IsEmpty; the >32 check passes for "" so only
  // IsEmpty surfaces.
  assert validator_under_test("") == Error(non_empty_list.single(IsEmpty))
}

// --- linear all ---
//
// all used to append each new error group onto the accumulated errors,
// which was quadratic in the number of failing validators.

pub fn all_many_failing_validators_test() -> Nil {
  let count = 100_000
  let failing = list.repeat(dataprep.predicate(fn(_) { False }, "bad"), count)
  // nolint: assert_ok_pattern -- every validator fails by construction
  let assert Error(errors) = dataprep.all(failing)("x")
    as "every validator fails"
  assert non_empty_list.length(errors) == count
}

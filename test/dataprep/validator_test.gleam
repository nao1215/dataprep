import dataprep/helpers/nel
import dataprep/non_empty_list
import dataprep/validated.{Invalid, Valid}
import dataprep/validator
import gleam/list
import gleam/option
import gleam/string

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
  let validator_under_test = validator.check(fn(_) { Ok(Nil) })
  assert validator_under_test("anything") == Valid("anything")
}

pub fn check_error_test() -> Nil {
  let validator_under_test =
    validator.check(fn(s: String) {
      case string.length(s) >= 3 {
        True -> Ok(Nil)
        False -> Error(TooShort)
      }
    })
  assert case validator_under_test("ab") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn check_value_dependent_error_test() -> Nil {
  let validator_under_test =
    validator.check(fn(s: String) {
      case string.length(s) {
        0 -> Error(IsEmpty)
        n if n < 3 -> Error(TooShort)
        _ -> Ok(Nil)
      }
    })
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
  assert validator_under_test("ab") == Invalid(non_empty_list.single(TooShort))
  assert validator_under_test("abc") == Valid("abc")
}

// --- predicate ---

pub fn predicate_pass_test() -> Nil {
  let validator_under_test = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  assert validator_under_test(5) == Valid(5)
}

pub fn predicate_fail_test() -> Nil {
  let validator_under_test = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  assert case validator_under_test(-1) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn predicate_boundary_test() -> Nil {
  let validator_under_test = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  assert case validator_under_test(0) {
    Invalid(_) -> True
    Valid(_) -> False
  }
  assert validator_under_test(1) == Valid(1)
}

// --- both ---

pub fn both_all_pass_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  assert validator_under_test("hello") == Valid("hello")
}

pub fn both_accumulates_errors_test() -> Nil {
  let v1 = validator.predicate(fn(_: String) { False }, TooShort)
  let v2 = validator.predicate(fn(_: String) { False }, TooLong)
  let validator_under_test = validator.both(first: v1, second: v2)
  assert validator_under_test("x")
    == Invalid(nel.make(first: TooShort, rest: [TooLong]))
}

pub fn both_first_fails_only_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { True }, TooLong),
    )
  assert validator_under_test("x") == Invalid(non_empty_list.single(TooShort))
}

pub fn both_second_fails_only_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { True }, TooShort)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
  assert validator_under_test("x") == Invalid(non_empty_list.single(TooLong))
}

pub fn both_preserves_input_value_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  assert validator_under_test("test") == Valid("test")
}

pub fn both_chained_three_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooShort),
    )
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
  assert validator_under_test("x")
    == Invalid(nel.make(first: IsEmpty, rest: [TooShort, TooLong]))
}

// --- also (alias of both) ---

pub fn also_chained_three_matches_both_test() -> Nil {
  let v1 = validator.predicate(fn(_: String) { False }, IsEmpty)
  let v2 = validator.predicate(fn(_: String) { False }, TooShort)
  let v3 = validator.predicate(fn(_: String) { False }, TooLong)

  let via_also =
    v1
    |> validator.also(first: _, second: v2)
    |> validator.also(first: _, second: v3)
  let via_both =
    v1
    |> validator.both(first: _, second: v2)
    |> validator.both(first: _, second: v3)

  assert via_also("x") == via_both("x")
}

pub fn also_accumulates_errors_test() -> Nil {
  let v1 = validator.predicate(fn(_: String) { False }, TooShort)
  let v2 = validator.predicate(fn(_: String) { False }, TooLong)
  let validator_under_test = validator.also(first: v1, second: v2)
  assert validator_under_test("x")
    == Invalid(nel.make(first: TooShort, rest: [TooLong]))
}

// --- all ---

pub fn all_empty_validators_test() -> Nil {
  let validator_under_test = validator.all([])
  assert validator_under_test("anything") == Valid("anything")
}

pub fn all_single_pass_test() -> Nil {
  let validator_under_test =
    validator.all([validator.predicate(fn(_: String) { True }, IsEmpty)])
  assert validator_under_test("x") == Valid("x")
}

pub fn all_single_fail_test() -> Nil {
  let validator_under_test =
    validator.all([validator.predicate(fn(_: String) { False }, IsEmpty)])
  assert validator_under_test("x") == Invalid(non_empty_list.single(IsEmpty))
}

pub fn all_accumulates_test() -> Nil {
  let validator_under_test =
    validator.all([
      validator.predicate(fn(_: String) { False }, TooShort),
      validator.predicate(fn(_: String) { True }, IsEmpty),
      validator.predicate(fn(_: String) { False }, TooLong),
    ])
  assert validator_under_test("x")
    == Invalid(nel.make(first: TooShort, rest: [TooLong]))
}

pub fn all_all_fail_test() -> Nil {
  let validator_under_test =
    validator.all([
      validator.predicate(fn(_: String) { False }, IsEmpty),
      validator.predicate(fn(_: String) { False }, TooShort),
      validator.predicate(fn(_: String) { False }, TooLong),
    ])
  assert validator_under_test("x")
    == Invalid(nel.make(first: IsEmpty, rest: [TooShort, TooLong]))
}

pub fn all_all_pass_test() -> Nil {
  let validator_under_test =
    validator.all([
      validator.predicate(fn(_: String) { True }, IsEmpty),
      validator.predicate(fn(_: String) { True }, TooShort),
    ])
  assert validator_under_test("x") == Valid("x")
}

// --- alt ---

pub fn alt_first_succeeds_skips_second_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { True }, NotUuid)
    |> validator.alt(first: _, second: fn(_) {
      // nolint: avoid_panic -- verifies alt short-circuits after success
      panic as "alt must not evaluate second branch when first succeeds"
    })
  assert validator_under_test("test") == Valid("test")
}

pub fn alt_second_succeeds_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, NotUuid)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { True }, NotSlug),
    )
  assert validator_under_test("test") == Valid("test")
}

pub fn alt_both_fail_accumulates_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, NotUuid)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { False }, NotSlug),
    )
  assert validator_under_test("test")
    == Invalid(nel.make(first: NotUuid, rest: [NotSlug]))
}

pub fn alt_chained_three_first_wins_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { True }, TooShort),
    )
    |> validator.alt(first: _, second: fn(_) {
      // nolint: avoid_panic -- verifies later alt branches are skipped
      panic as "third alt branch should not run"
    })
  assert validator_under_test("x") == Valid("x")
}

pub fn alt_chained_three_all_fail_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { False }, TooShort),
    )
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
  assert validator_under_test("x")
    == Invalid(nel.make(first: IsEmpty, rest: [TooShort, TooLong]))
}

// --- and_then ---

pub fn and_then_pre_fails_skips_main_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.and_then(pre: _, main: fn(_) {
      // nolint: avoid_panic -- verifies and_then short-circuits on pre failure
      panic as "and_then must not evaluate main when pre fails"
    })
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
}

pub fn and_then_pre_passes_then_main_runs_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.and_then(
      pre: _,
      main: validator.predicate(fn(_) { False }, TooShort),
    )
  assert validator_under_test("hello")
    == Invalid(non_empty_list.single(TooShort))
}

pub fn and_then_both_pass_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.and_then(
      pre: _,
      main: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  assert validator_under_test("hello") == Valid("hello")
}

pub fn and_then_does_not_accumulate_test() -> Nil {
  // and_then is short-circuit, NOT accumulation
  // when pre fails, we only see pre's error, not main's
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.and_then(
      pre: _,
      main: validator.predicate(fn(_) { False }, TooShort),
    )
  assert validator_under_test("x") == Invalid(non_empty_list.single(IsEmpty))
}

pub fn and_then_chained_test() -> Nil {
  // and_then(non_empty, and_then(min_length, max_length))
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.and_then(
      pre: _,
      main: validator.predicate(
        fn(s: String) { string.length(s) >= 3 },
        TooShort,
      )
        |> validator.and_then(
          pre: _,
          main: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
        ),
    )
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
  assert validator_under_test("ab") == Invalid(non_empty_list.single(TooShort))
  assert validator_under_test("abc") == Valid("abc")
}

// --- map_error ---

pub fn map_error_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.map_error(fn(e) { FieldError("name", e) })
  assert validator_under_test("x")
    == Invalid(non_empty_list.single(FieldError("name", TooShort)))
}

pub fn map_error_valid_passes_through_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { True }, TooShort)
    |> validator.map_error(fn(e) { FieldError("name", e) })
  assert validator_under_test("x") == Valid("x")
}

pub fn map_error_multiple_errors_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
    |> validator.map_error(fn(e) { FieldError("field", e) })
  assert validator_under_test("x")
    == Invalid(
      nel.make(first: FieldError("field", TooShort), rest: [
        FieldError("field", TooLong),
      ]),
    )
}

// --- label ---

pub fn label_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.label("user.name", FieldError)
  assert validator_under_test("x")
    == Invalid(non_empty_list.single(FieldError("user.name", TooShort)))
}

pub fn label_valid_passes_through_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { True }, TooShort)
    |> validator.label("user.name", FieldError)
  assert validator_under_test("x") == Valid("x")
}

pub fn label_multiple_errors_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooShort),
    )
    |> validator.label("email", FieldError)
  assert validator_under_test("x")
    == Invalid(
      nel.make(first: FieldError("email", IsEmpty), rest: [
        FieldError("email", TooShort),
      ]),
    )
}

// --- composition: both + alt + and_then ---

pub fn both_then_alt_test() -> Nil {
  // v1: must be non-empty AND short
  // v2: must be non-empty AND long
  // alt: either form is ok
  let short =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(s) { string.length(s) <= 3 }, TooLong),
    )
  let long =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(s) { string.length(s) >= 10 }, TooShort),
    )
  let validator_under_test = validator.alt(first: short, second: long)

  assert validator_under_test("ab") == Valid("ab")
  assert validator_under_test("abcdefghijk") == Valid("abcdefghijk")
}

pub fn and_then_composed_with_both_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.and_then(
      pre: _,
      main: validator.predicate(
        fn(s: String) { string.length(s) >= 3 },
        TooShort,
      )
        |> validator.both(
          first: _,
          second: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
        ),
    )
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
  assert validator_under_test("hello") == Valid("hello")
}

// --- each composes with all/both/alt/and_then (issue #21) ---

/// Issue #21 reproduction: validate "≤ N items in the list" AND
/// "each item satisfies X" using `validator.all` over a single
/// `Validator(List(a), e)`. Before the fix, `each` returned the
/// raw `fn(List(a)) -> Validated(...)` arrow which forced callers
/// to write a 7-line bridge to lift it back into `Validator`.
pub fn each_composes_with_all_over_parent_list_test() -> Nil {
  let item_v = validator.predicate(fn(s: String) { s != "" }, IsEmpty)
  let validator_under_test =
    validator.all([
      validator.predicate(
        fn(items: List(String)) { list.length(items) <= 3 },
        TooLong,
      ),
      validator.each(item_v),
    ])

  // Happy path: list ≤ 3 and every item is non-empty.
  assert validator_under_test(["a", "b"]) == Valid(["a", "b"])

  // Single failure: parent rule fails (too many items), per-item
  // rule passes — only TooLong surfaces.
  assert validator_under_test(["a", "b", "c", "d"])
    == Invalid(non_empty_list.single(TooLong))

  // Single failure: parent rule passes, per-item rule fails on one
  // element — only IsEmpty surfaces.
  assert validator_under_test(["a", "", "b"])
    == Invalid(non_empty_list.single(IsEmpty))
}

/// Confirms `each` now composes with `both` exactly like any other
/// `Validator(List(a), e)` would.
pub fn each_composes_with_both_over_parent_list_test() -> Nil {
  let item_v = validator.predicate(fn(s: String) { s != "" }, IsEmpty)
  let validator_under_test =
    validator.both(
      first: validator.predicate(
        fn(items: List(String)) { list.length(items) <= 3 },
        TooLong,
      ),
      second: validator.each(item_v),
    )

  assert validator_under_test(["a"]) == Valid(["a"])

  // Both rules fail: errors accumulate.
  assert case validator_under_test(["", "", "", ""]) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- optional composes with all/both/alt/and_then (issue #21) ---

/// Mirror of #21 for `optional`: returns a `Validator(Option(a), e)`
/// so it can sit in an `all` list alongside other Optional-level
/// rules without an adapter wrapper.
pub fn optional_composes_with_all_over_parent_option_test() -> Nil {
  let inner =
    validator.predicate(fn(s: String) { string.length(s) >= 3 }, TooShort)
  let validator_under_test =
    validator.all([
      validator.predicate(option.is_some, IsEmpty),
      validator.optional(inner),
    ])

  // Some + valid inner → both rules pass.
  assert validator_under_test(option.Some("hello"))
    == Valid(option.Some("hello"))

  // None → presence check fails, optional inner short-circuits to
  // Valid(None). Only IsEmpty surfaces.
  assert validator_under_test(option.None)
    == Invalid(non_empty_list.single(IsEmpty))

  // Some but inner fails → presence check passes, inner fails.
  assert validator_under_test(option.Some("ab"))
    == Invalid(non_empty_list.single(TooShort))
}

// --- required: convenience for the canonical "non-empty string" check (#62) ---

pub fn required_rejects_empty_string_test() -> Nil {
  let validator_under_test = validator.required(IsEmpty)
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
}

pub fn required_accepts_non_empty_string_test() -> Nil {
  let validator_under_test = validator.required(IsEmpty)
  assert validator_under_test("hello") == Valid("hello")
}

pub fn required_accepts_whitespace_only_string_test() -> Nil {
  // Whitespace-only is non-empty by string equality, so `required`
  // alone accepts it. Callers who want "required after trimming"
  // pipe through `prep.trim` upstream — documented in the validator
  // doc comment.
  let validator_under_test = validator.required(IsEmpty)
  assert validator_under_test("   ") == Valid("   ")
}

pub fn required_matches_predicate_form_test() -> Nil {
  // The convenience must produce byte-identical Validated values to
  // the spelt-out predicate form on the same inputs.
  let via_required = validator.required(IsEmpty)
  let via_predicate = validator.predicate(fn(s) { s != "" }, IsEmpty)
  assert via_required("") == via_predicate("")
  assert via_required("ok") == via_predicate("ok")
  assert via_required(" ") == via_predicate(" ")
}

pub fn required_composes_with_all_test() -> Nil {
  let validator_under_test =
    validator.all([
      validator.required(IsEmpty),
      validator.predicate(fn(s) { string.length(s) <= 32 }, TooLong),
    ])
  assert validator_under_test("ok") == Valid("ok")
  // Empty triggers IsEmpty; the >32 check passes for "" so only
  // IsEmpty surfaces.
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
}

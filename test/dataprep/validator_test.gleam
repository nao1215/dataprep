import dataprep/non_empty_list
import dataprep/validated.{Invalid, Valid}
import dataprep/validator
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
    == Invalid(non_empty_list.NonEmptyList(first: TooShort, rest: [TooLong]))
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
    == Invalid(
      non_empty_list.NonEmptyList(first: IsEmpty, rest: [TooShort, TooLong]),
    )
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
    == Invalid(non_empty_list.NonEmptyList(first: TooShort, rest: [TooLong]))
}

pub fn all_all_fail_test() -> Nil {
  let validator_under_test =
    validator.all([
      validator.predicate(fn(_: String) { False }, IsEmpty),
      validator.predicate(fn(_: String) { False }, TooShort),
      validator.predicate(fn(_: String) { False }, TooLong),
    ])
  assert validator_under_test("x")
    == Invalid(
      non_empty_list.NonEmptyList(first: IsEmpty, rest: [TooShort, TooLong]),
    )
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
    == Invalid(non_empty_list.NonEmptyList(first: NotUuid, rest: [NotSlug]))
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
    == Invalid(
      non_empty_list.NonEmptyList(first: IsEmpty, rest: [TooShort, TooLong]),
    )
}

// --- guard ---

pub fn guard_pre_fails_skips_main_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(pre: _, main: fn(_) {
      // nolint: avoid_panic -- verifies guard short-circuits on pre failure
      panic as "guard must not evaluate main when pre fails"
    })
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
}

pub fn guard_pre_passes_then_main_runs_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(
      pre: _,
      main: validator.predicate(fn(_) { False }, TooShort),
    )
  assert validator_under_test("hello")
    == Invalid(non_empty_list.single(TooShort))
}

pub fn guard_both_pass_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(
      pre: _,
      main: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  assert validator_under_test("hello") == Valid("hello")
}

pub fn guard_does_not_accumulate_test() -> Nil {
  // guard is short-circuit, NOT accumulation
  // when pre fails, we only see pre's error, not main's
  let validator_under_test =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.guard(
      pre: _,
      main: validator.predicate(fn(_) { False }, TooShort),
    )
  assert validator_under_test("x") == Invalid(non_empty_list.single(IsEmpty))
}

pub fn guard_chained_test() -> Nil {
  // guard(non_empty, guard(min_length, max_length))
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(
      pre: _,
      main: validator.predicate(
        fn(s: String) { string.length(s) >= 3 },
        TooShort,
      )
        |> validator.guard(
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
      non_empty_list.NonEmptyList(first: FieldError("field", TooShort), rest: [
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
      non_empty_list.NonEmptyList(first: FieldError("email", IsEmpty), rest: [
        FieldError("email", TooShort),
      ]),
    )
}

// --- composition: both + alt + guard ---

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

pub fn guard_then_both_test() -> Nil {
  let validator_under_test =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(
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

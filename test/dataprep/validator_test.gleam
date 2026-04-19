import dataprep/non_empty_list
import dataprep/validated.{Invalid, Valid}
import dataprep/validator
import gleam/string

pub type Err {
  TooShort
  TooLong
  IsEmpty
  NotUuid
  NotSlug
  FieldError(path: String, detail: Err)
}

// --- check ---

pub fn check_ok_test() {
  let v = validator.check(fn(_) { Ok(Nil) })
  let assert Valid("anything") = v("anything")
}

pub fn check_error_test() {
  let v =
    validator.check(fn(s: String) {
      case string.length(s) >= 3 {
        True -> Ok(Nil)
        False -> Error(TooShort)
      }
    })
  let assert Invalid(_) = v("ab")
}

pub fn check_value_dependent_error_test() {
  let v =
    validator.check(fn(s: String) {
      case string.length(s) {
        0 -> Error(IsEmpty)
        n if n < 3 -> Error(TooShort)
        _ -> Ok(Nil)
      }
    })
  let assert Invalid(nel) = v("")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
  let assert Invalid(nel2) = v("ab")
  let assert [TooShort] = non_empty_list.to_list(nel2)
  let assert Valid("abc") = v("abc")
}

// --- predicate ---

pub fn predicate_pass_test() {
  let v = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  let assert Valid(5) = v(5)
}

pub fn predicate_fail_test() {
  let v = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  let assert Invalid(_) = v(-1)
}

pub fn predicate_boundary_test() {
  let v = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  let assert Invalid(_) = v(0)
  let assert Valid(1) = v(1)
}

// --- both ---

pub fn both_all_pass_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  let assert Valid("hello") = v("hello")
}

pub fn both_accumulates_errors_test() {
  let v1 = validator.predicate(fn(_: String) { False }, TooShort)
  let v2 = validator.predicate(fn(_: String) { False }, TooLong)
  let v = validator.both(first: v1, second: v2)
  let assert Invalid(nel) = v("x")
  let assert [TooShort, TooLong] = non_empty_list.to_list(nel)
}

pub fn both_first_fails_only_test() {
  let v =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { True }, TooLong),
    )
  let assert Invalid(nel) = v("x")
  let assert [TooShort] = non_empty_list.to_list(nel)
}

pub fn both_second_fails_only_test() {
  let v =
    validator.predicate(fn(_: String) { True }, TooShort)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
  let assert Invalid(nel) = v("x")
  let assert [TooLong] = non_empty_list.to_list(nel)
}

pub fn both_preserves_input_value_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  let assert Valid(result) = v("test")
  let assert "test" = result
}

pub fn both_chained_three_test() {
  let v =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooShort),
    )
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
  let assert Invalid(nel) = v("x")
  let assert [IsEmpty, TooShort, TooLong] = non_empty_list.to_list(nel)
}

// --- all ---

pub fn all_empty_validators_test() {
  let v = validator.all([])
  let assert Valid("anything") = v("anything")
}

pub fn all_single_pass_test() {
  let v = validator.all([validator.predicate(fn(_: String) { True }, IsEmpty)])
  let assert Valid("x") = v("x")
}

pub fn all_single_fail_test() {
  let v = validator.all([validator.predicate(fn(_: String) { False }, IsEmpty)])
  let assert Invalid(nel) = v("x")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
}

pub fn all_accumulates_test() {
  let v =
    validator.all([
      validator.predicate(fn(_: String) { False }, TooShort),
      validator.predicate(fn(_: String) { True }, IsEmpty),
      validator.predicate(fn(_: String) { False }, TooLong),
    ])
  let assert Invalid(nel) = v("x")
  let assert [TooShort, TooLong] = non_empty_list.to_list(nel)
}

pub fn all_all_fail_test() {
  let v =
    validator.all([
      validator.predicate(fn(_: String) { False }, IsEmpty),
      validator.predicate(fn(_: String) { False }, TooShort),
      validator.predicate(fn(_: String) { False }, TooLong),
    ])
  let assert Invalid(nel) = v("x")
  let assert [IsEmpty, TooShort, TooLong] = non_empty_list.to_list(nel)
}

pub fn all_all_pass_test() {
  let v =
    validator.all([
      validator.predicate(fn(_: String) { True }, IsEmpty),
      validator.predicate(fn(_: String) { True }, TooShort),
    ])
  let assert Valid("x") = v("x")
}

// --- alt ---

pub fn alt_first_succeeds_skips_second_test() {
  let v =
    validator.predicate(fn(_: String) { True }, NotUuid)
    |> validator.alt(first: _, second: fn(_) {
      // nolint: avoid_panic -- verifies alt short-circuits after success
      panic as "alt must not evaluate second branch when first succeeds"
    })
  let assert Valid("test") = v("test")
}

pub fn alt_second_succeeds_test() {
  let v =
    validator.predicate(fn(_: String) { False }, NotUuid)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { True }, NotSlug),
    )
  let assert Valid("test") = v("test")
}

pub fn alt_both_fail_accumulates_test() {
  let v =
    validator.predicate(fn(_: String) { False }, NotUuid)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { False }, NotSlug),
    )
  let assert Invalid(nel) = v("test")
  let assert [NotUuid, NotSlug] = non_empty_list.to_list(nel)
}

pub fn alt_chained_three_first_wins_test() {
  let v =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { True }, TooShort),
    )
    |> validator.alt(first: _, second: fn(_) {
      // nolint: avoid_panic -- verifies later alt branches are skipped
      panic as "third alt branch should not run"
    })
  let assert Valid("x") = v("x")
}

pub fn alt_chained_three_all_fail_test() {
  let v =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { False }, TooShort),
    )
    |> validator.alt(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
  let assert Invalid(nel) = v("x")
  let assert [IsEmpty, TooShort, TooLong] = non_empty_list.to_list(nel)
}

// --- guard ---

pub fn guard_pre_fails_skips_main_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(pre: _, main: fn(_) {
      // nolint: avoid_panic -- verifies guard short-circuits on pre failure
      panic as "guard must not evaluate main when pre fails"
    })
  let assert Invalid(nel) = v("")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
}

pub fn guard_pre_passes_then_main_runs_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(
      pre: _,
      main: validator.predicate(fn(_) { False }, TooShort),
    )
  let assert Invalid(nel) = v("hello")
  let assert [TooShort] = non_empty_list.to_list(nel)
}

pub fn guard_both_pass_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(
      pre: _,
      main: validator.predicate(fn(s) { string.length(s) <= 10 }, TooLong),
    )
  let assert Valid("hello") = v("hello")
}

pub fn guard_does_not_accumulate_test() {
  // guard is short-circuit, NOT accumulation
  // when pre fails, we only see pre's error, not main's
  let v =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.guard(
      pre: _,
      main: validator.predicate(fn(_) { False }, TooShort),
    )
  let assert Invalid(nel) = v("x")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
}

pub fn guard_chained_test() {
  // guard(non_empty, guard(min_length, max_length))
  let v =
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
  let assert Invalid(nel) = v("")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
  let assert Invalid(nel2) = v("ab")
  let assert [TooShort] = non_empty_list.to_list(nel2)
  let assert Valid("abc") = v("abc")
}

// --- map_error ---

pub fn map_error_test() {
  let v =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.map_error(fn(e) { FieldError("name", e) })
  let assert Invalid(nel) = v("x")
  let assert [FieldError("name", TooShort)] = non_empty_list.to_list(nel)
}

pub fn map_error_valid_passes_through_test() {
  let v =
    validator.predicate(fn(_: String) { True }, TooShort)
    |> validator.map_error(fn(e) { FieldError("name", e) })
  let assert Valid("x") = v("x")
}

pub fn map_error_multiple_errors_test() {
  let v =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooLong),
    )
    |> validator.map_error(fn(e) { FieldError("field", e) })
  let assert Invalid(nel) = v("x")
  let assert [FieldError("field", TooShort), FieldError("field", TooLong)] =
    non_empty_list.to_list(nel)
}

// --- label ---

pub fn label_test() {
  let v =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.label("user.name", FieldError)
  let assert Invalid(nel) = v("x")
  let assert [FieldError("user.name", TooShort)] = non_empty_list.to_list(nel)
}

pub fn label_valid_passes_through_test() {
  let v =
    validator.predicate(fn(_: String) { True }, TooShort)
    |> validator.label("user.name", FieldError)
  let assert Valid("x") = v("x")
}

pub fn label_multiple_errors_test() {
  let v =
    validator.predicate(fn(_: String) { False }, IsEmpty)
    |> validator.both(
      first: _,
      second: validator.predicate(fn(_) { False }, TooShort),
    )
    |> validator.label("email", FieldError)
  let assert Invalid(nel) = v("x")
  let assert [FieldError("email", IsEmpty), FieldError("email", TooShort)] =
    non_empty_list.to_list(nel)
}

// --- composition: both + alt + guard ---

pub fn both_then_alt_test() {
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
  let v = validator.alt(first: short, second: long)

  let assert Valid("ab") = v("ab")
  let assert Valid("abcdefghijk") = v("abcdefghijk")
}

pub fn guard_then_both_test() {
  let v =
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
  let assert Invalid(nel) = v("")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
  let assert Valid("hello") = v("hello")
}

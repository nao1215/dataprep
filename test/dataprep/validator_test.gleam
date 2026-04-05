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

pub fn predicate_pass_test() {
  let v = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  let assert Valid(5) = v(5)
}

pub fn predicate_fail_test() {
  let v = validator.predicate(fn(n: Int) { n > 0 }, TooShort)
  let assert Invalid(_) = v(-1)
}

pub fn both_all_pass_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.both(validator.predicate(
      fn(s) { string.length(s) <= 10 },
      TooLong,
    ))
  let assert Valid("hello") = v("hello")
}

pub fn both_accumulates_errors_test() {
  let v1 = validator.predicate(fn(_: String) { False }, TooShort)
  let v2 = validator.predicate(fn(_: String) { False }, TooLong)
  let v = validator.both(v1, v2)
  let assert Invalid(nel) = v("x")
  let assert [TooShort, TooLong] = non_empty_list.to_list(nel)
}

pub fn all_empty_validators_test() {
  let v = validator.all([])
  let assert Valid("anything") = v("anything")
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

pub fn alt_first_succeeds_skips_second_test() {
  let v =
    validator.predicate(fn(_: String) { True }, NotUuid)
    |> validator.alt(fn(_) {
      panic as "alt must not evaluate second branch when first succeeds"
    })
  let assert Valid("test") = v("test")
}

pub fn alt_second_succeeds_test() {
  let v =
    validator.predicate(fn(_: String) { False }, NotUuid)
    |> validator.alt(validator.predicate(fn(_) { True }, NotSlug))
  let assert Valid("test") = v("test")
}

pub fn alt_both_fail_accumulates_test() {
  let v =
    validator.predicate(fn(_: String) { False }, NotUuid)
    |> validator.alt(validator.predicate(fn(_) { False }, NotSlug))
  let assert Invalid(nel) = v("test")
  let assert [NotUuid, NotSlug] = non_empty_list.to_list(nel)
}

pub fn guard_pre_fails_skips_main_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(fn(_) {
      panic as "guard must not evaluate main when pre fails"
    })
  let assert Invalid(nel) = v("")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
}

pub fn guard_pre_passes_then_main_runs_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(validator.predicate(fn(_) { False }, TooShort))
  let assert Invalid(nel) = v("hello")
  let assert [TooShort] = non_empty_list.to_list(nel)
}

pub fn guard_both_pass_test() {
  let v =
    validator.predicate(fn(s: String) { s != "" }, IsEmpty)
    |> validator.guard(validator.predicate(
      fn(s) { string.length(s) <= 10 },
      TooLong,
    ))
  let assert Valid("hello") = v("hello")
}

pub fn map_error_test() {
  let v =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.map_error(fn(e) { FieldError("name", e) })
  let assert Invalid(nel) = v("x")
  let assert [FieldError("name", TooShort)] = non_empty_list.to_list(nel)
}

pub fn label_test() {
  let v =
    validator.predicate(fn(_: String) { False }, TooShort)
    |> validator.label("user.name", FieldError)
  let assert Invalid(nel) = v("x")
  let assert [FieldError("user.name", TooShort)] = non_empty_list.to_list(nel)
}

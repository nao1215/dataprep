import dataprep/non_empty_list
import dataprep/prep
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator

type Err {
  IsEmpty
  TooShort(min: Int)
  TooLong(max: Int)
  TooSmall(min: Int)
  TooBig(max: Int)
  NotAllowed
  NotEqual
}

// --- not_empty ---

pub fn not_empty_pass_test() -> Nil {
  assert rules.not_empty(IsEmpty)("hello") == Valid("hello")
}

pub fn not_empty_fail_test() -> Nil {
  assert rules.not_empty(IsEmpty)("") == Invalid(non_empty_list.single(IsEmpty))
}

pub fn not_empty_whitespace_passes_test() -> Nil {
  assert rules.not_empty(IsEmpty)("   ") == Valid("   ")
}

pub fn not_empty_with_trim_rejects_whitespace_test() -> Nil {
  let clean = prep.trim()
  assert rules.not_empty(IsEmpty)(clean("   "))
    == Invalid(non_empty_list.single(IsEmpty))
}

pub fn not_empty_single_char_test() -> Nil {
  assert rules.not_empty(IsEmpty)(" ") == Valid(" ")
}

// --- min_length ---

pub fn min_length_pass_test() -> Nil {
  assert rules.min_length(minimum: 3, error: TooShort(3))("abc") == Valid("abc")
}

pub fn min_length_fail_test() -> Nil {
  assert rules.min_length(minimum: 3, error: TooShort(3))("ab")
    == Invalid(non_empty_list.single(TooShort(3)))
}

pub fn min_length_exact_boundary_test() -> Nil {
  assert rules.min_length(minimum: 3, error: TooShort(3))("abc") == Valid("abc")
  assert case rules.min_length(minimum: 3, error: TooShort(3))("ab") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn min_length_zero_test() -> Nil {
  assert rules.min_length(minimum: 0, error: TooShort(0))("") == Valid("")
}

pub fn min_length_empty_string_test() -> Nil {
  assert case rules.min_length(minimum: 1, error: TooShort(1))("") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- max_length ---

pub fn max_length_pass_test() -> Nil {
  assert rules.max_length(maximum: 5, error: TooLong(5))("abc") == Valid("abc")
}

pub fn max_length_fail_test() -> Nil {
  assert rules.max_length(maximum: 2, error: TooLong(2))("abc")
    == Invalid(non_empty_list.single(TooLong(2)))
}

pub fn max_length_exact_boundary_test() -> Nil {
  assert rules.max_length(maximum: 3, error: TooLong(3))("abc") == Valid("abc")
  assert case rules.max_length(maximum: 3, error: TooLong(3))("abcd") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn max_length_empty_string_test() -> Nil {
  assert rules.max_length(maximum: 0, error: TooLong(0))("") == Valid("")
}

// --- min_int ---

pub fn min_int_pass_test() -> Nil {
  assert rules.min_int(minimum: 0, error: TooSmall(0))(10) == Valid(10)
}

pub fn min_int_fail_test() -> Nil {
  assert rules.min_int(minimum: 0, error: TooSmall(0))(-1)
    == Invalid(non_empty_list.single(TooSmall(0)))
}

pub fn min_int_exact_boundary_test() -> Nil {
  assert rules.min_int(minimum: 0, error: TooSmall(0))(0) == Valid(0)
  assert case rules.min_int(minimum: 0, error: TooSmall(0))(-1) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn min_int_negative_boundary_test() -> Nil {
  assert rules.min_int(minimum: -10, error: TooSmall(-10))(-10) == Valid(-10)
  assert case rules.min_int(minimum: -10, error: TooSmall(-10))(-11) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- max_int ---

pub fn max_int_pass_test() -> Nil {
  assert rules.max_int(maximum: 10, error: TooBig(10))(5) == Valid(5)
}

pub fn max_int_fail_test() -> Nil {
  assert rules.max_int(maximum: 10, error: TooBig(10))(11)
    == Invalid(non_empty_list.single(TooBig(10)))
}

pub fn max_int_exact_boundary_test() -> Nil {
  assert rules.max_int(maximum: 10, error: TooBig(10))(10) == Valid(10)
  assert case rules.max_int(maximum: 10, error: TooBig(10))(11) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- one_of ---

pub fn one_of_pass_test() -> Nil {
  assert rules.one_of(allowed: ["a", "b", "c"], error: NotAllowed)("a")
    == Valid("a")
}

pub fn one_of_fail_test() -> Nil {
  assert rules.one_of(allowed: ["a", "b", "c"], error: NotAllowed)("d")
    == Invalid(non_empty_list.single(NotAllowed))
}

pub fn one_of_empty_list_always_fails_test() -> Nil {
  assert case rules.one_of(allowed: [], error: NotAllowed)("anything") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

pub fn one_of_int_test() -> Nil {
  assert rules.one_of(allowed: [1, 2, 3], error: NotAllowed)(1) == Valid(1)
  assert case rules.one_of(allowed: [1, 2, 3], error: NotAllowed)(4) {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- equals ---

pub fn equals_pass_test() -> Nil {
  assert rules.equals(expected: 42, error: NotEqual)(42) == Valid(42)
}

pub fn equals_fail_test() -> Nil {
  assert rules.equals(expected: 42, error: NotEqual)(99)
    == Invalid(non_empty_list.single(NotEqual))
}

pub fn equals_string_test() -> Nil {
  assert rules.equals(expected: "yes", error: NotEqual)("yes") == Valid("yes")
  assert case rules.equals(expected: "yes", error: NotEqual)("no") {
    Invalid(_) -> True
    Valid(_) -> False
  }
}

// --- rules combined with validator combinators ---

pub fn min_max_length_combined_test() -> Nil {
  let validator_under_test =
    rules.min_length(minimum: 3, error: TooShort(3))
    |> validator.both(
      first: _,
      second: rules.max_length(maximum: 10, error: TooLong(10)),
    )
  assert validator_under_test("hello") == Valid("hello")
  assert validator_under_test("ab")
    == Invalid(non_empty_list.single(TooShort(3)))
  assert validator_under_test("abcdefghijk")
    == Invalid(non_empty_list.single(TooLong(10)))
}

pub fn min_max_int_combined_test() -> Nil {
  let validator_under_test =
    rules.min_int(minimum: 0, error: TooSmall(0))
    |> validator.both(
      first: _,
      second: rules.max_int(maximum: 100, error: TooBig(100)),
    )
  assert validator_under_test(50) == Valid(50)
  assert validator_under_test(-1) == Invalid(non_empty_list.single(TooSmall(0)))
  assert validator_under_test(101)
    == Invalid(non_empty_list.single(TooBig(100)))
}

pub fn not_empty_guard_min_length_test() -> Nil {
  let validator_under_test =
    rules.not_empty(IsEmpty)
    |> validator.guard(
      pre: _,
      main: rules.min_length(minimum: 3, error: TooShort(3)),
    )
  assert validator_under_test("") == Invalid(non_empty_list.single(IsEmpty))
  assert validator_under_test("ab")
    == Invalid(non_empty_list.single(TooShort(3)))
  assert validator_under_test("abc") == Valid("abc")
}

import dataprep/non_empty_list
import dataprep/prep
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator

pub type Err {
  IsEmpty
  TooShort(min: Int)
  TooLong(max: Int)
  TooSmall(min: Int)
  TooBig(max: Int)
  NotAllowed
  NotEqual
}

// --- not_empty ---

pub fn not_empty_pass_test() {
  let assert Valid("hello") = rules.not_empty(IsEmpty)("hello")
}

pub fn not_empty_fail_test() {
  let assert Invalid(nel) = rules.not_empty(IsEmpty)("")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
}

pub fn not_empty_whitespace_passes_test() {
  let assert Valid("   ") = rules.not_empty(IsEmpty)("   ")
}

pub fn not_empty_with_trim_rejects_whitespace_test() {
  let clean = prep.trim()
  let assert Invalid(nel) = rules.not_empty(IsEmpty)(clean("   "))
  let assert [IsEmpty] = non_empty_list.to_list(nel)
}

pub fn not_empty_single_char_test() {
  let assert Valid(" ") = rules.not_empty(IsEmpty)(" ")
}

// --- min_length ---

pub fn min_length_pass_test() {
  let assert Valid("abc") =
    rules.min_length(minimum: 3, error: TooShort(3))("abc")
}

pub fn min_length_fail_test() {
  let assert Invalid(nel) =
    rules.min_length(minimum: 3, error: TooShort(3))("ab")
  let assert [TooShort(3)] = non_empty_list.to_list(nel)
}

pub fn min_length_exact_boundary_test() {
  let assert Valid("abc") =
    rules.min_length(minimum: 3, error: TooShort(3))("abc")
  let assert Invalid(_) = rules.min_length(minimum: 3, error: TooShort(3))("ab")
}

pub fn min_length_zero_test() {
  let assert Valid("") = rules.min_length(minimum: 0, error: TooShort(0))("")
}

pub fn min_length_empty_string_test() {
  let assert Invalid(_) = rules.min_length(minimum: 1, error: TooShort(1))("")
}

// --- max_length ---

pub fn max_length_pass_test() {
  let assert Valid("abc") =
    rules.max_length(maximum: 5, error: TooLong(5))("abc")
}

pub fn max_length_fail_test() {
  let assert Invalid(nel) =
    rules.max_length(maximum: 2, error: TooLong(2))("abc")
  let assert [TooLong(2)] = non_empty_list.to_list(nel)
}

pub fn max_length_exact_boundary_test() {
  let assert Valid("abc") =
    rules.max_length(maximum: 3, error: TooLong(3))("abc")
  let assert Invalid(_) =
    rules.max_length(maximum: 3, error: TooLong(3))("abcd")
}

pub fn max_length_empty_string_test() {
  let assert Valid("") = rules.max_length(maximum: 0, error: TooLong(0))("")
}

// --- min_int ---

pub fn min_int_pass_test() {
  let assert Valid(10) = rules.min_int(minimum: 0, error: TooSmall(0))(10)
}

pub fn min_int_fail_test() {
  let assert Invalid(nel) = rules.min_int(minimum: 0, error: TooSmall(0))(-1)
  let assert [TooSmall(0)] = non_empty_list.to_list(nel)
}

pub fn min_int_exact_boundary_test() {
  let assert Valid(0) = rules.min_int(minimum: 0, error: TooSmall(0))(0)
  let assert Invalid(_) = rules.min_int(minimum: 0, error: TooSmall(0))(-1)
}

pub fn min_int_negative_boundary_test() {
  let assert Valid(-10) = rules.min_int(minimum: -10, error: TooSmall(-10))(-10)
  let assert Invalid(_) = rules.min_int(minimum: -10, error: TooSmall(-10))(-11)
}

// --- max_int ---

pub fn max_int_pass_test() {
  let assert Valid(5) = rules.max_int(maximum: 10, error: TooBig(10))(5)
}

pub fn max_int_fail_test() {
  let assert Invalid(nel) = rules.max_int(maximum: 10, error: TooBig(10))(11)
  let assert [TooBig(10)] = non_empty_list.to_list(nel)
}

pub fn max_int_exact_boundary_test() {
  let assert Valid(10) = rules.max_int(maximum: 10, error: TooBig(10))(10)
  let assert Invalid(_) = rules.max_int(maximum: 10, error: TooBig(10))(11)
}

// --- one_of ---

pub fn one_of_pass_test() {
  let assert Valid("a") =
    rules.one_of(allowed: ["a", "b", "c"], error: NotAllowed)("a")
}

pub fn one_of_fail_test() {
  let assert Invalid(nel) =
    rules.one_of(allowed: ["a", "b", "c"], error: NotAllowed)("d")
  let assert [NotAllowed] = non_empty_list.to_list(nel)
}

pub fn one_of_empty_list_always_fails_test() {
  let assert Invalid(_) =
    rules.one_of(allowed: [], error: NotAllowed)("anything")
}

pub fn one_of_int_test() {
  let assert Valid(1) = rules.one_of(allowed: [1, 2, 3], error: NotAllowed)(1)
  let assert Invalid(_) = rules.one_of(allowed: [1, 2, 3], error: NotAllowed)(4)
}

// --- equals ---

pub fn equals_pass_test() {
  let assert Valid(42) = rules.equals(expected: 42, error: NotEqual)(42)
}

pub fn equals_fail_test() {
  let assert Invalid(nel) = rules.equals(expected: 42, error: NotEqual)(99)
  let assert [NotEqual] = non_empty_list.to_list(nel)
}

pub fn equals_string_test() {
  let assert Valid("yes") =
    rules.equals(expected: "yes", error: NotEqual)("yes")
  let assert Invalid(_) = rules.equals(expected: "yes", error: NotEqual)("no")
}

// --- rules combined with validator combinators ---

pub fn min_max_length_combined_test() {
  let v =
    rules.min_length(minimum: 3, error: TooShort(3))
    |> validator.both(
      first: _,
      second: rules.max_length(maximum: 10, error: TooLong(10)),
    )
  let assert Valid("hello") = v("hello")
  let assert Invalid(nel) = v("ab")
  let assert [TooShort(3)] = non_empty_list.to_list(nel)
  let assert Invalid(nel2) = v("abcdefghijk")
  let assert [TooLong(10)] = non_empty_list.to_list(nel2)
}

pub fn min_max_int_combined_test() {
  let v =
    rules.min_int(minimum: 0, error: TooSmall(0))
    |> validator.both(
      first: _,
      second: rules.max_int(maximum: 100, error: TooBig(100)),
    )
  let assert Valid(50) = v(50)
  let assert Invalid(nel) = v(-1)
  let assert [TooSmall(0)] = non_empty_list.to_list(nel)
  let assert Invalid(nel2) = v(101)
  let assert [TooBig(100)] = non_empty_list.to_list(nel2)
}

pub fn not_empty_guard_min_length_test() {
  let v =
    rules.not_empty(IsEmpty)
    |> validator.guard(
      pre: _,
      main: rules.min_length(minimum: 3, error: TooShort(3)),
    )
  let assert Invalid(nel) = v("")
  let assert [IsEmpty] = non_empty_list.to_list(nel)
  let assert Invalid(nel2) = v("ab")
  let assert [TooShort(3)] = non_empty_list.to_list(nel2)
  let assert Valid("abc") = v("abc")
}

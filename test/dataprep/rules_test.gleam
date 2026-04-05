import dataprep/non_empty_list
import dataprep/prep
import dataprep/rules
import dataprep/validated.{Invalid, Valid}

pub type Err {
  IsEmpty
  TooShort(min: Int)
  TooLong(max: Int)
  TooSmall(min: Int)
  TooBig(max: Int)
  NotAllowed
  NotEqual
}

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

pub fn min_length_pass_test() {
  let assert Valid("abc") = rules.min_length(3, TooShort(3))("abc")
}

pub fn min_length_fail_test() {
  let assert Invalid(nel) = rules.min_length(3, TooShort(3))("ab")
  let assert [TooShort(3)] = non_empty_list.to_list(nel)
}

pub fn max_length_pass_test() {
  let assert Valid("abc") = rules.max_length(5, TooLong(5))("abc")
}

pub fn max_length_fail_test() {
  let assert Invalid(nel) = rules.max_length(2, TooLong(2))("abc")
  let assert [TooLong(2)] = non_empty_list.to_list(nel)
}

pub fn min_int_pass_test() {
  let assert Valid(10) = rules.min_int(0, TooSmall(0))(10)
}

pub fn min_int_fail_test() {
  let assert Invalid(nel) = rules.min_int(0, TooSmall(0))(-1)
  let assert [TooSmall(0)] = non_empty_list.to_list(nel)
}

pub fn max_int_pass_test() {
  let assert Valid(5) = rules.max_int(10, TooBig(10))(5)
}

pub fn max_int_fail_test() {
  let assert Invalid(nel) = rules.max_int(10, TooBig(10))(11)
  let assert [TooBig(10)] = non_empty_list.to_list(nel)
}

pub fn one_of_pass_test() {
  let assert Valid("a") = rules.one_of(["a", "b", "c"], NotAllowed)("a")
}

pub fn one_of_fail_test() {
  let assert Invalid(nel) = rules.one_of(["a", "b", "c"], NotAllowed)("d")
  let assert [NotAllowed] = non_empty_list.to_list(nel)
}

pub fn equals_pass_test() {
  let assert Valid(42) = rules.equals(42, NotEqual)(42)
}

pub fn equals_fail_test() {
  let assert Invalid(nel) = rules.equals(42, NotEqual)(99)
  let assert [NotEqual] = non_empty_list.to_list(nel)
}

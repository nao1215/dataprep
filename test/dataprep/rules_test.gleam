import dataprep
import gleam/result
import gleam/string
import non_empty_list

type Err {
  IsEmpty
  TooShort(min: Int)
  TooLong(max: Int)
  TooSmall(min: Int)
  TooBig(max: Int)
  NotAllowed
}

// --- not_empty ---

pub fn not_empty_pass_test() -> Nil {
  assert dataprep.not_empty(IsEmpty)("hello") == Ok("hello")
}

pub fn not_empty_fail_test() -> Nil {
  assert dataprep.not_empty(IsEmpty)("")
    == Error(non_empty_list.single(IsEmpty))
}

pub fn not_empty_whitespace_passes_test() -> Nil {
  assert dataprep.not_empty(IsEmpty)("   ") == Ok("   ")
}

pub fn not_empty_with_trim_rejects_whitespace_test() -> Nil {
  assert dataprep.not_empty(IsEmpty)(string.trim("   "))
    == Error(non_empty_list.single(IsEmpty))
}

pub fn not_empty_single_char_test() -> Nil {
  assert dataprep.not_empty(IsEmpty)(" ") == Ok(" ")
}

// --- min_length ---

pub fn min_length_pass_test() -> Nil {
  assert dataprep.min_length(minimum: 3, error: TooShort(3))("abc") == Ok("abc")
}

pub fn min_length_fail_test() -> Nil {
  assert dataprep.min_length(minimum: 3, error: TooShort(3))("ab")
    == Error(non_empty_list.single(TooShort(3)))
}

pub fn min_length_exact_boundary_test() -> Nil {
  assert dataprep.min_length(minimum: 3, error: TooShort(3))("abc") == Ok("abc")
  assert result.is_error(dataprep.min_length(minimum: 3, error: TooShort(3))(
    "ab",
  ))
}

pub fn min_length_zero_test() -> Nil {
  assert dataprep.min_length(minimum: 0, error: TooShort(0))("") == Ok("")
}

pub fn min_length_empty_string_test() -> Nil {
  assert result.is_error(dataprep.min_length(minimum: 1, error: TooShort(1))(""))
}

// --- max_length ---

pub fn max_length_pass_test() -> Nil {
  assert dataprep.max_length(maximum: 5, error: TooLong(5))("abc") == Ok("abc")
}

pub fn max_length_fail_test() -> Nil {
  assert dataprep.max_length(maximum: 2, error: TooLong(2))("abc")
    == Error(non_empty_list.single(TooLong(2)))
}

pub fn max_length_exact_boundary_test() -> Nil {
  assert dataprep.max_length(maximum: 3, error: TooLong(3))("abc") == Ok("abc")
  assert result.is_error(dataprep.max_length(maximum: 3, error: TooLong(3))(
    "abcd",
  ))
}

pub fn max_length_empty_string_test() -> Nil {
  assert dataprep.max_length(maximum: 0, error: TooLong(0))("") == Ok("")
}

// --- min_int ---

pub fn min_int_pass_test() -> Nil {
  assert dataprep.min_int(minimum: 0, error: TooSmall(0))(10) == Ok(10)
}

pub fn min_int_fail_test() -> Nil {
  assert dataprep.min_int(minimum: 0, error: TooSmall(0))(-1)
    == Error(non_empty_list.single(TooSmall(0)))
}

pub fn min_int_exact_boundary_test() -> Nil {
  assert dataprep.min_int(minimum: 0, error: TooSmall(0))(0) == Ok(0)
  assert result.is_error(dataprep.min_int(minimum: 0, error: TooSmall(0))(-1))
}

pub fn min_int_negative_boundary_test() -> Nil {
  assert dataprep.min_int(minimum: -10, error: TooSmall(-10))(-10) == Ok(-10)
  assert result.is_error(dataprep.min_int(minimum: -10, error: TooSmall(-10))(
    -11,
  ))
}

// --- max_int ---

pub fn max_int_pass_test() -> Nil {
  assert dataprep.max_int(maximum: 10, error: TooBig(10))(5) == Ok(5)
}

pub fn max_int_fail_test() -> Nil {
  assert dataprep.max_int(maximum: 10, error: TooBig(10))(11)
    == Error(non_empty_list.single(TooBig(10)))
}

pub fn max_int_exact_boundary_test() -> Nil {
  assert dataprep.max_int(maximum: 10, error: TooBig(10))(10) == Ok(10)
  assert result.is_error(dataprep.max_int(maximum: 10, error: TooBig(10))(11))
}

// --- one_of ---

pub fn one_of_pass_test() -> Nil {
  assert dataprep.one_of(allowed: ["a", "b", "c"], error: NotAllowed)("a")
    == Ok("a")
}

pub fn one_of_fail_test() -> Nil {
  assert dataprep.one_of(allowed: ["a", "b", "c"], error: NotAllowed)("d")
    == Error(non_empty_list.single(NotAllowed))
}

// `dataprep.one_of(allowed: [], ...)` panics at construction time.
// Capturing the panic from Gleam would require an FFI shim per
// target, so the panic path is left out of the test suite.

pub fn one_of_int_test() -> Nil {
  assert dataprep.one_of(allowed: [1, 2, 3], error: NotAllowed)(1) == Ok(1)
  assert result.is_error(dataprep.one_of(allowed: [1, 2, 3], error: NotAllowed)(
    4,
  ))
}

// --- rules combined with validator combinators ---

pub fn min_max_length_combined_test() -> Nil {
  let validator_under_test =
    dataprep.min_length(minimum: 3, error: TooShort(3))
    |> dataprep.both(
      first: _,
      second: dataprep.max_length(maximum: 10, error: TooLong(10)),
    )
  assert validator_under_test("hello") == Ok("hello")
  assert validator_under_test("ab") == Error(non_empty_list.single(TooShort(3)))
  assert validator_under_test("abcdefghijk")
    == Error(non_empty_list.single(TooLong(10)))
}

pub fn min_max_int_combined_test() -> Nil {
  let validator_under_test =
    dataprep.min_int(minimum: 0, error: TooSmall(0))
    |> dataprep.both(
      first: _,
      second: dataprep.max_int(maximum: 100, error: TooBig(100)),
    )
  assert validator_under_test(50) == Ok(50)
  assert validator_under_test(-1) == Error(non_empty_list.single(TooSmall(0)))
  assert validator_under_test(101) == Error(non_empty_list.single(TooBig(100)))
}

pub fn not_empty_guard_min_length_test() -> Nil {
  let validator_under_test =
    dataprep.not_empty(IsEmpty)
    |> dataprep.and_then(
      first: _,
      then: dataprep.min_length(minimum: 3, error: TooShort(3)),
    )
  assert validator_under_test("") == Error(non_empty_list.single(IsEmpty))
  assert validator_under_test("ab") == Error(non_empty_list.single(TooShort(3)))
  assert validator_under_test("abc") == Ok("abc")
}

import dataprep/non_empty_list
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator

type Err {
  TooShort
  Indexed(index: Int, detail: Err)
}

// --- sequence ---

pub fn sequence_all_valid_test() -> Nil {
  assert validated.sequence([Valid(1), Valid(2), Valid(3)]) == Valid([1, 2, 3])
}

pub fn sequence_empty_list_test() -> Nil {
  assert validated.sequence([]) == Valid([])
}

pub fn sequence_accumulates_errors_test() -> Nil {
  assert validated.sequence([
      Valid(1),
      Invalid(non_empty_list.single("e1")),
      Valid(3),
      Invalid(non_empty_list.single("e2")),
    ])
    == Invalid(non_empty_list.NonEmptyList(first: "e1", rest: ["e2"]))
}

pub fn sequence_single_invalid_test() -> Nil {
  assert validated.sequence([Invalid(non_empty_list.single("err"))])
    == Invalid(non_empty_list.single("err"))
}

pub fn sequence_preserves_order_test() -> Nil {
  assert validated.sequence([Valid("a"), Valid("b"), Valid("c")])
    == Valid(["a", "b", "c"])
}

// --- traverse ---

pub fn traverse_all_pass_test() -> Nil {
  assert validated.traverse([1, 2, 3], fn(n) {
      case n > 0 {
        True -> Valid(n)
        False -> Invalid(non_empty_list.single("negative"))
      }
    })
    == Valid([1, 2, 3])
}

pub fn traverse_empty_list_test() -> Nil {
  assert validated.traverse([], fn(_) { Valid(1) }) == Valid([])
}

pub fn traverse_accumulates_errors_test() -> Nil {
  assert validated.traverse(["hello", "", "world", ""], fn(s) {
      rules.not_empty(TooShort)(s)
    })
    == Invalid(non_empty_list.NonEmptyList(first: TooShort, rest: [TooShort]))
}

pub fn traverse_with_transform_test() -> Nil {
  assert validated.traverse(["1", "2", "3"], fn(s) {
      case s {
        "1" -> Valid(1)
        "2" -> Valid(2)
        "3" -> Valid(3)
        _ -> Invalid(non_empty_list.single("bad"))
      }
    })
    == Valid([1, 2, 3])
}

// --- traverse_indexed ---

pub fn traverse_indexed_with_label_test() -> Nil {
  assert validated.traverse_indexed(["hello", "", "world"], fn(s, i) {
      rules.not_empty(TooShort)(s)
      |> validated.map_error(fn(e) { Indexed(i, e) })
    })
    == Invalid(non_empty_list.single(Indexed(1, TooShort)))
}

pub fn traverse_indexed_all_valid_test() -> Nil {
  assert validated.traverse_indexed(["a", "b", "c"], fn(s, _i) { Valid(s) })
    == Valid(["a", "b", "c"])
}

pub fn traverse_indexed_empty_test() -> Nil {
  assert validated.traverse_indexed([], fn(_s: String, _i) { Valid("x") })
    == Valid([])
}

// --- from_result_map ---

pub fn from_result_map_ok_test() -> Nil {
  assert validated.from_result_map(Ok(42), fn(_) { "err" }) == Valid(42)
}

pub fn from_result_map_error_test() -> Nil {
  assert validated.from_result_map(Error(Nil), fn(_) { "mapped" })
    == Invalid(non_empty_list.single("mapped"))
}

// --- each ---

pub fn each_all_pass_test() -> Nil {
  let check = validator.each(rules.not_empty(TooShort))
  assert check(["a", "b", "c"]) == Valid(["a", "b", "c"])
}

pub fn each_accumulates_test() -> Nil {
  let check = validator.each(rules.not_empty(TooShort))
  assert check(["a", "", "b", ""])
    == Invalid(non_empty_list.NonEmptyList(first: TooShort, rest: [TooShort]))
}

pub fn each_empty_list_test() -> Nil {
  let check = validator.each(rules.not_empty(TooShort))
  assert check([]) == Valid([])
}

// --- optional ---

pub fn optional_none_test() -> Nil {
  let check = validator.optional(rules.not_empty(TooShort))
  assert check(option.None) == Valid(option.None)
}

pub fn optional_some_valid_test() -> Nil {
  let check = validator.optional(rules.not_empty(TooShort))
  assert check(option.Some("hello")) == Valid(option.Some("hello"))
}

pub fn optional_some_invalid_test() -> Nil {
  let check = validator.optional(rules.not_empty(TooShort))
  assert check(option.Some("")) == Invalid(non_empty_list.single(TooShort))
}

import gleam/option

import dataprep/non_empty_list
import dataprep/rules
import dataprep/validated.{Invalid, Valid}
import dataprep/validator

pub type Err {
  TooShort
  Indexed(index: Int, detail: Err)
}

// --- sequence ---

pub fn sequence_all_valid_test() {
  let result = validated.sequence([Valid(1), Valid(2), Valid(3)])
  let assert Valid([1, 2, 3]) = result
}

pub fn sequence_empty_list_test() {
  let result = validated.sequence([])
  let assert Valid([]) = result
}

pub fn sequence_accumulates_errors_test() {
  let result =
    validated.sequence([
      Valid(1),
      Invalid(non_empty_list.single("e1")),
      Valid(3),
      Invalid(non_empty_list.single("e2")),
    ])
  let assert Invalid(nel) = result
  let assert ["e1", "e2"] = non_empty_list.to_list(nel)
}

pub fn sequence_single_invalid_test() {
  let result = validated.sequence([Invalid(non_empty_list.single("err"))])
  let assert Invalid(nel) = result
  let assert ["err"] = non_empty_list.to_list(nel)
}

pub fn sequence_preserves_order_test() {
  let result = validated.sequence([Valid("a"), Valid("b"), Valid("c")])
  let assert Valid(["a", "b", "c"]) = result
}

// --- traverse ---

pub fn traverse_all_pass_test() {
  let result =
    validated.traverse([1, 2, 3], fn(n) {
      case n > 0 {
        True -> Valid(n)
        False -> Invalid(non_empty_list.single("negative"))
      }
    })
  let assert Valid([1, 2, 3]) = result
}

pub fn traverse_empty_list_test() {
  let result = validated.traverse([], fn(_) { Valid(1) })
  let assert Valid([]) = result
}

pub fn traverse_accumulates_errors_test() {
  let result =
    validated.traverse(["hello", "", "world", ""], fn(s) {
      rules.not_empty(TooShort)(s)
    })
  let assert Invalid(nel) = result
  let assert [TooShort, TooShort] = non_empty_list.to_list(nel)
}

pub fn traverse_with_transform_test() {
  let result =
    validated.traverse(["1", "2", "3"], fn(s) {
      case s {
        "1" -> Valid(1)
        "2" -> Valid(2)
        "3" -> Valid(3)
        _ -> Invalid(non_empty_list.single("bad"))
      }
    })
  let assert Valid([1, 2, 3]) = result
}

// --- traverse_indexed ---

pub fn traverse_indexed_with_label_test() {
  let result =
    validated.traverse_indexed(["hello", "", "world"], fn(s, i) {
      rules.not_empty(TooShort)(s)
      |> validated.map_error(fn(e) { Indexed(i, e) })
    })
  let assert Invalid(nel) = result
  let assert [Indexed(1, TooShort)] = non_empty_list.to_list(nel)
}

pub fn traverse_indexed_all_valid_test() {
  let result =
    validated.traverse_indexed(["a", "b", "c"], fn(s, _i) { Valid(s) })
  let assert Valid(["a", "b", "c"]) = result
}

pub fn traverse_indexed_empty_test() {
  let result = validated.traverse_indexed([], fn(_s: String, _i) { Valid("x") })
  let assert Valid([]) = result
}

// --- from_result_map ---

pub fn from_result_map_ok_test() {
  let result = validated.from_result_map(Ok(42), fn(_) { "err" })
  let assert Valid(42) = result
}

pub fn from_result_map_error_test() {
  let result = validated.from_result_map(Error(Nil), fn(_) { "mapped" })
  let assert Invalid(nel) = result
  let assert ["mapped"] = non_empty_list.to_list(nel)
}

// --- each ---

pub fn each_all_pass_test() {
  let check = validator.each(rules.not_empty(TooShort))
  let assert Valid(["a", "b", "c"]) = check(["a", "b", "c"])
}

pub fn each_accumulates_test() {
  let check = validator.each(rules.not_empty(TooShort))
  let assert Invalid(nel) = check(["a", "", "b", ""])
  let assert [TooShort, TooShort] = non_empty_list.to_list(nel)
}

pub fn each_empty_list_test() {
  let check = validator.each(rules.not_empty(TooShort))
  let assert Valid([]) = check([])
}

// --- optional ---

pub fn optional_none_test() {
  let check = validator.optional(rules.not_empty(TooShort))
  let assert Valid(option.None) = check(option.None)
}

pub fn optional_some_valid_test() {
  let check = validator.optional(rules.not_empty(TooShort))
  let assert Valid(option.Some("hello")) = check(option.Some("hello"))
}

pub fn optional_some_invalid_test() {
  let check = validator.optional(rules.not_empty(TooShort))
  let assert Invalid(nel) = check(option.Some(""))
  let assert [TooShort] = non_empty_list.to_list(nel)
}

import gleam/option

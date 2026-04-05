import dataprep/non_empty_list.{NonEmptyList}
import dataprep/validated.{Invalid, Valid}
import gleam/int

// --- map ---

pub fn map_valid_test() {
  let result = Valid(2) |> validated.map(fn(x) { x * 3 })
  let assert Valid(6) = result
}

pub fn map_invalid_test() {
  let result =
    Invalid(non_empty_list.single("err")) |> validated.map(fn(x) { x * 3 })
  let assert Invalid(NonEmptyList(first: "err", rest: [])) = result
}

pub fn map_type_change_test() {
  let result = Valid(42) |> validated.map(int.to_string)
  let assert Valid("42") = result
}

// --- map_error ---

pub fn map_error_valid_test() {
  let result =
    Valid(42) |> validated.map_error(fn(e: String) { "wrapped: " <> e })
  let assert Valid(42) = result
}

pub fn map_error_invalid_test() {
  let result =
    Invalid(non_empty_list.single("bad"))
    |> validated.map_error(fn(e) { "wrapped: " <> e })
  let assert Invalid(NonEmptyList(first: "wrapped: bad", rest: [])) = result
}

pub fn map_error_multiple_errors_test() {
  let result =
    Invalid(NonEmptyList(first: "a", rest: ["b"]))
    |> validated.map_error(fn(e) { "x:" <> e })
  let assert Invalid(nel) = result
  let assert ["x:a", "x:b"] = non_empty_list.to_list(nel)
}

// --- and_then ---

pub fn and_then_valid_test() {
  let result =
    Valid(10)
    |> validated.and_then(fn(x) {
      case x > 5 {
        True -> Valid(x)
        False -> Invalid(non_empty_list.single("too small"))
      }
    })
  let assert Valid(10) = result
}

pub fn and_then_valid_to_invalid_test() {
  let result =
    Valid(3)
    |> validated.and_then(fn(x) {
      case x > 5 {
        True -> Valid(x)
        False -> Invalid(non_empty_list.single("too small"))
      }
    })
  let assert Invalid(NonEmptyList(first: "too small", rest: [])) = result
}

pub fn and_then_short_circuits_test() {
  let result =
    Invalid(non_empty_list.single("first"))
    |> validated.and_then(fn(_) {
      panic as "and_then must not call continuation on Invalid"
    })
  let assert Invalid(NonEmptyList(first: "first", rest: [])) = result
}

pub fn and_then_type_change_test() {
  let result =
    Valid("42")
    |> validated.and_then(fn(s) {
      case int.parse(s) {
        Ok(n) -> Valid(n)
        Error(_) -> Invalid(non_empty_list.single("not an int"))
      }
    })
  let assert Valid(42) = result
}

pub fn and_then_chained_test() {
  let result =
    Valid("10")
    |> validated.and_then(fn(s) {
      case int.parse(s) {
        Ok(n) -> Valid(n)
        Error(_) -> Invalid(non_empty_list.single("parse"))
      }
    })
    |> validated.and_then(fn(n) {
      case n > 0 {
        True -> Valid(n)
        False -> Invalid(non_empty_list.single("positive"))
      }
    })
  let assert Valid(10) = result
}

pub fn and_then_does_not_accumulate_test() {
  // and_then is monadic: first failure stops, second is not run
  let result =
    Valid("abc")
    |> validated.and_then(fn(_) {
      Invalid(non_empty_list.single("parse failed"))
    })
    |> validated.and_then(fn(_) {
      panic as "should not be called after first and_then fails"
    })
  let assert Invalid(NonEmptyList(first: "parse failed", rest: [])) = result
}

// --- from_result / to_result ---

pub fn from_result_ok_test() {
  let assert Valid(42) = validated.from_result(Ok(42))
}

pub fn from_result_error_test() {
  let assert Invalid(NonEmptyList(first: "err", rest: [])) =
    validated.from_result(Error("err"))
}

pub fn to_result_valid_test() {
  let assert Ok(42) = validated.to_result(Valid(42))
}

pub fn to_result_invalid_test() {
  let assert Error(["a", "b"]) =
    validated.to_result(Invalid(NonEmptyList(first: "a", rest: ["b"])))
}

pub fn from_result_to_result_roundtrip_ok_test() {
  let assert Ok(99) = Ok(99) |> validated.from_result |> validated.to_result
}

pub fn from_result_to_result_roundtrip_error_test() {
  let assert Error(["e"]) =
    Error("e") |> validated.from_result |> validated.to_result
}

// --- map2 ---

pub fn map2_all_valid_test() {
  let result = validated.map2(fn(a, b) { a + b }, Valid(1), Valid(2))
  let assert Valid(3) = result
}

pub fn map2_accumulates_errors_test() {
  let result =
    validated.map2(
      fn(a, b) { a + b },
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
    )
  let assert Invalid(nel) = result
  let assert ["e1", "e2"] = non_empty_list.to_list(nel)
}

pub fn map2_first_invalid_test() {
  let result =
    validated.map2(
      fn(a, b) { a + b },
      Invalid(non_empty_list.single("e1")),
      Valid(2),
    )
  let assert Invalid(NonEmptyList(first: "e1", rest: [])) = result
}

pub fn map2_second_invalid_test() {
  let result =
    validated.map2(
      fn(a, b) { a + b },
      Valid(1),
      Invalid(non_empty_list.single("e2")),
    )
  let assert Invalid(NonEmptyList(first: "e2", rest: [])) = result
}

pub fn map2_multiple_errors_per_branch_test() {
  let result =
    validated.map2(
      fn(a, b) { a + b },
      Invalid(NonEmptyList(first: "e1a", rest: ["e1b"])),
      Invalid(non_empty_list.single("e2")),
    )
  let assert Invalid(nel) = result
  let assert ["e1a", "e1b", "e2"] = non_empty_list.to_list(nel)
}

// --- map3 ---

pub type Triple {
  Triple(a: Int, b: Int, c: Int)
}

pub fn map3_all_valid_test() {
  let result = validated.map3(Triple, Valid(1), Valid(2), Valid(3))
  let assert Valid(Triple(1, 2, 3)) = result
}

pub fn map3_accumulates_errors_test() {
  let result =
    validated.map3(
      Triple,
      Invalid(non_empty_list.single("e1")),
      Valid(2),
      Invalid(non_empty_list.single("e3")),
    )
  let assert Invalid(nel) = result
  let assert ["e1", "e3"] = non_empty_list.to_list(nel)
}

pub fn map3_all_invalid_test() {
  let result =
    validated.map3(
      Triple,
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
      Invalid(non_empty_list.single("e3")),
    )
  let assert Invalid(nel) = result
  let assert ["e1", "e2", "e3"] = non_empty_list.to_list(nel)
}

pub fn map3_one_invalid_test() {
  let result =
    validated.map3(
      Triple,
      Valid(1),
      Invalid(non_empty_list.single("e2")),
      Valid(3),
    )
  let assert Invalid(NonEmptyList(first: "e2", rest: [])) = result
}

// --- map4 ---

pub type Quad {
  Quad(a: Int, b: Int, c: Int, d: Int)
}

pub fn map4_all_valid_test() {
  let result = validated.map4(Quad, Valid(1), Valid(2), Valid(3), Valid(4))
  let assert Valid(Quad(1, 2, 3, 4)) = result
}

pub fn map4_accumulates_errors_test() {
  let result =
    validated.map4(
      Quad,
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
      Invalid(non_empty_list.single("e3")),
      Invalid(non_empty_list.single("e4")),
    )
  let assert Invalid(nel) = result
  let assert ["e1", "e2", "e3", "e4"] = non_empty_list.to_list(nel)
}

pub fn map4_partial_invalid_test() {
  let result =
    validated.map4(
      Quad,
      Valid(1),
      Invalid(non_empty_list.single("e2")),
      Valid(3),
      Invalid(non_empty_list.single("e4")),
    )
  let assert Invalid(nel) = result
  let assert ["e2", "e4"] = non_empty_list.to_list(nel)
}

// --- map5 ---

pub type Quint {
  Quint(a: Int, b: Int, c: Int, d: Int, e: Int)
}

pub fn map5_all_valid_test() {
  let result =
    validated.map5(Quint, Valid(1), Valid(2), Valid(3), Valid(4), Valid(5))
  let assert Valid(Quint(1, 2, 3, 4, 5)) = result
}

pub fn map5_accumulates_errors_test() {
  let result =
    validated.map5(
      Quint,
      Invalid(non_empty_list.single("e1")),
      Valid(2),
      Invalid(non_empty_list.single("e3")),
      Valid(4),
      Invalid(non_empty_list.single("e5")),
    )
  let assert Invalid(nel) = result
  let assert ["e1", "e3", "e5"] = non_empty_list.to_list(nel)
}

pub fn map5_all_invalid_test() {
  let result =
    validated.map5(
      Quint,
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
      Invalid(non_empty_list.single("e3")),
      Invalid(non_empty_list.single("e4")),
      Invalid(non_empty_list.single("e5")),
    )
  let assert Invalid(nel) = result
  let assert ["e1", "e2", "e3", "e4", "e5"] = non_empty_list.to_list(nel)
}

pub fn map5_single_invalid_test() {
  let result =
    validated.map5(
      Quint,
      Valid(1),
      Valid(2),
      Valid(3),
      Invalid(non_empty_list.single("e4")),
      Valid(5),
    )
  let assert Invalid(NonEmptyList(first: "e4", rest: [])) = result
}

// --- error order preservation across mapN ---

pub fn map2_error_order_test() {
  let result =
    validated.map2(
      fn(a, b) { #(a, b) },
      Invalid(NonEmptyList(first: "first", rest: ["second"])),
      Invalid(non_empty_list.single("third")),
    )
  let assert Invalid(nel) = result
  let assert ["first", "second", "third"] = non_empty_list.to_list(nel)
}

pub fn map3_error_order_test() {
  let result =
    validated.map3(
      Triple,
      Invalid(non_empty_list.single("a")),
      Invalid(non_empty_list.single("b")),
      Invalid(non_empty_list.single("c")),
    )
  let assert Invalid(nel) = result
  let assert ["a", "b", "c"] = non_empty_list.to_list(nel)
}

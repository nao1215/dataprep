import dataprep/non_empty_list.{NonEmptyList}
import dataprep/validated.{Invalid, Valid}

pub fn map_valid_test() {
  let result = Valid(2) |> validated.map(fn(x) { x * 3 })
  let assert Valid(6) = result
}

pub fn map_invalid_test() {
  let result =
    Invalid(non_empty_list.single("err")) |> validated.map(fn(x) { x * 3 })
  let assert Invalid(NonEmptyList(first: "err", rest: [])) = result
}

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

pub fn and_then_short_circuits_test() {
  let result =
    Invalid(non_empty_list.single("first"))
    |> validated.and_then(fn(_) {
      panic as "and_then must not call continuation on Invalid"
    })
  let assert Invalid(NonEmptyList(first: "first", rest: [])) = result
}

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

pub fn map2_one_invalid_test() {
  let result =
    validated.map2(
      fn(a, b) { a + b },
      Valid(1),
      Invalid(non_empty_list.single("e2")),
    )
  let assert Invalid(NonEmptyList(first: "e2", rest: [])) = result
}

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

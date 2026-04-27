import dataprep/non_empty_list.{NonEmptyList}
import dataprep/validated.{Invalid, Valid}
import gleam/int

// --- fail ---

pub fn fail_returns_invalid_with_single_error_test() -> Nil {
  let result: validated.Validated(String, String) = validated.fail("oops")
  assert result == Invalid(NonEmptyList(first: "oops", rest: []))
}

pub fn fail_is_equivalent_to_manual_construction_test() -> Nil {
  assert validated.fail(42) == Invalid(non_empty_list.single(42))
}

// --- map ---

pub fn map_valid_test() -> Nil {
  assert Valid(2) |> validated.map(fn(x) { x * 3 }) == Valid(6)
}

pub fn map_invalid_test() -> Nil {
  assert Invalid(non_empty_list.single("err")) |> validated.map(fn(x) { x * 3 })
    == Invalid(NonEmptyList(first: "err", rest: []))
}

pub fn map_type_change_test() -> Nil {
  assert Valid(42) |> validated.map(int.to_string) == Valid("42")
}

// --- map_error ---

pub fn map_error_valid_test() -> Nil {
  assert Valid(42) |> validated.map_error(fn(e: String) { "wrapped: " <> e })
    == Valid(42)
}

pub fn map_error_invalid_test() -> Nil {
  assert Invalid(non_empty_list.single("bad"))
    |> validated.map_error(fn(e) { "wrapped: " <> e })
    == Invalid(NonEmptyList(first: "wrapped: bad", rest: []))
}

pub fn map_error_multiple_errors_test() -> Nil {
  assert Invalid(NonEmptyList(first: "a", rest: ["b"]))
    |> validated.map_error(fn(e) { "x:" <> e })
    == Invalid(NonEmptyList(first: "x:a", rest: ["x:b"]))
}

// --- and_then ---

pub fn and_then_valid_test() -> Nil {
  assert Valid(10)
    |> validated.and_then(fn(x) {
      case x > 5 {
        True -> Valid(x)
        False -> Invalid(non_empty_list.single("too small"))
      }
    })
    == Valid(10)
}

pub fn and_then_valid_to_invalid_test() -> Nil {
  assert Valid(3)
    |> validated.and_then(fn(x) {
      case x > 5 {
        True -> Valid(x)
        False -> Invalid(non_empty_list.single("too small"))
      }
    })
    == Invalid(NonEmptyList(first: "too small", rest: []))
}

pub fn and_then_short_circuits_test() -> Nil {
  assert Invalid(non_empty_list.single("first"))
    |> validated.and_then(fn(_) {
      // nolint: avoid_panic -- verifies and_then short-circuits on Invalid
      panic as "and_then must not call continuation on Invalid"
    })
    == Invalid(NonEmptyList(first: "first", rest: []))
}

pub fn and_then_type_change_test() -> Nil {
  assert Valid("42")
    |> validated.and_then(fn(s) {
      case int.parse(s) {
        Ok(n) -> Valid(n)
        Error(Nil) -> Invalid(non_empty_list.single("not an int"))
      }
    })
    == Valid(42)
}

pub fn and_then_chained_test() -> Nil {
  assert Valid("10")
    |> validated.and_then(fn(s) {
      case int.parse(s) {
        Ok(n) -> Valid(n)
        Error(Nil) -> Invalid(non_empty_list.single("parse"))
      }
    })
    |> validated.and_then(fn(n) {
      case n > 0 {
        True -> Valid(n)
        False -> Invalid(non_empty_list.single("positive"))
      }
    })
    == Valid(10)
}

pub fn and_then_does_not_accumulate_test() -> Nil {
  // and_then is monadic: first failure stops, second is not run
  assert Valid("abc")
    |> validated.and_then(fn(_) {
      Invalid(non_empty_list.single("parse failed"))
    })
    |> validated.and_then(fn(_) {
      // nolint: avoid_panic -- verifies later and_then stages are skipped
      panic as "should not be called after first and_then fails"
    })
    == Invalid(NonEmptyList(first: "parse failed", rest: []))
}

// --- from_result / to_result ---

pub fn from_result_ok_test() -> Nil {
  assert validated.from_result(Ok(42)) == Valid(42)
}

pub fn from_result_error_test() -> Nil {
  assert validated.from_result(Error("err"))
    == Invalid(NonEmptyList(first: "err", rest: []))
}

pub fn to_result_valid_test() -> Nil {
  assert validated.to_result(Valid(42)) == Ok(42)
}

pub fn to_result_invalid_test() -> Nil {
  assert validated.to_result(Invalid(NonEmptyList(first: "a", rest: ["b"])))
    == Error(["a", "b"])
}

pub fn from_result_to_result_roundtrip_ok_test() -> Nil {
  assert Ok(99) |> validated.from_result |> validated.to_result == Ok(99)
}

pub fn from_result_to_result_roundtrip_error_test() -> Nil {
  assert Error("e") |> validated.from_result |> validated.to_result
    == Error(["e"])
}

// --- map2 ---

pub fn map2_all_valid_test() -> Nil {
  assert validated.map2(fn(a, b) { a + b }, Valid(1), Valid(2)) == Valid(3)
}

pub fn map2_accumulates_errors_test() -> Nil {
  assert validated.map2(
      fn(a, b) { a + b },
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
    )
    == Invalid(NonEmptyList(first: "e1", rest: ["e2"]))
}

pub fn map2_first_invalid_test() -> Nil {
  assert validated.map2(
      fn(a, b) { a + b },
      Invalid(non_empty_list.single("e1")),
      Valid(2),
    )
    == Invalid(NonEmptyList(first: "e1", rest: []))
}

pub fn map2_second_invalid_test() -> Nil {
  assert validated.map2(
      fn(a, b) { a + b },
      Valid(1),
      Invalid(non_empty_list.single("e2")),
    )
    == Invalid(NonEmptyList(first: "e2", rest: []))
}

pub fn map2_multiple_errors_per_branch_test() -> Nil {
  assert validated.map2(
      fn(a, b) { a + b },
      Invalid(NonEmptyList(first: "e1a", rest: ["e1b"])),
      Invalid(non_empty_list.single("e2")),
    )
    == Invalid(NonEmptyList(first: "e1a", rest: ["e1b", "e2"]))
}

// --- map3 ---

type Triple {
  Triple(a: Int, b: Int, c: Int)
}

pub fn map3_all_valid_test() -> Nil {
  assert validated.map3(Triple, Valid(1), Valid(2), Valid(3))
    == Valid(Triple(1, 2, 3))
}

pub fn map3_accumulates_errors_test() -> Nil {
  assert validated.map3(
      Triple,
      Invalid(non_empty_list.single("e1")),
      Valid(2),
      Invalid(non_empty_list.single("e3")),
    )
    == Invalid(NonEmptyList(first: "e1", rest: ["e3"]))
}

pub fn map3_all_invalid_test() -> Nil {
  assert validated.map3(
      Triple,
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
      Invalid(non_empty_list.single("e3")),
    )
    == Invalid(NonEmptyList(first: "e1", rest: ["e2", "e3"]))
}

pub fn map3_one_invalid_test() -> Nil {
  assert validated.map3(
      Triple,
      Valid(1),
      Invalid(non_empty_list.single("e2")),
      Valid(3),
    )
    == Invalid(NonEmptyList(first: "e2", rest: []))
}

// --- map4 ---

type Quad {
  Quad(a: Int, b: Int, c: Int, d: Int)
}

pub fn map4_all_valid_test() -> Nil {
  assert validated.map4(Quad, Valid(1), Valid(2), Valid(3), Valid(4))
    == Valid(Quad(1, 2, 3, 4))
}

pub fn map4_accumulates_errors_test() -> Nil {
  assert validated.map4(
      Quad,
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
      Invalid(non_empty_list.single("e3")),
      Invalid(non_empty_list.single("e4")),
    )
    == Invalid(NonEmptyList(first: "e1", rest: ["e2", "e3", "e4"]))
}

pub fn map4_partial_invalid_test() -> Nil {
  assert validated.map4(
      Quad,
      Valid(1),
      Invalid(non_empty_list.single("e2")),
      Valid(3),
      Invalid(non_empty_list.single("e4")),
    )
    == Invalid(NonEmptyList(first: "e2", rest: ["e4"]))
}

// --- map5 ---

type Quint {
  Quint(a: Int, b: Int, c: Int, d: Int, e: Int)
}

pub fn map5_all_valid_test() -> Nil {
  assert validated.map5(Quint, Valid(1), Valid(2), Valid(3), Valid(4), Valid(5))
    == Valid(Quint(1, 2, 3, 4, 5))
}

pub fn map5_accumulates_errors_test() -> Nil {
  assert validated.map5(
      Quint,
      Invalid(non_empty_list.single("e1")),
      Valid(2),
      Invalid(non_empty_list.single("e3")),
      Valid(4),
      Invalid(non_empty_list.single("e5")),
    )
    == Invalid(NonEmptyList(first: "e1", rest: ["e3", "e5"]))
}

pub fn map5_all_invalid_test() -> Nil {
  assert validated.map5(
      Quint,
      Invalid(non_empty_list.single("e1")),
      Invalid(non_empty_list.single("e2")),
      Invalid(non_empty_list.single("e3")),
      Invalid(non_empty_list.single("e4")),
      Invalid(non_empty_list.single("e5")),
    )
    == Invalid(NonEmptyList(first: "e1", rest: ["e2", "e3", "e4", "e5"]))
}

pub fn map5_single_invalid_test() -> Nil {
  assert validated.map5(
      Quint,
      Valid(1),
      Valid(2),
      Valid(3),
      Invalid(non_empty_list.single("e4")),
      Valid(5),
    )
    == Invalid(NonEmptyList(first: "e4", rest: []))
}

// --- error order preservation across mapN ---

pub fn map2_error_order_test() -> Nil {
  assert validated.map2(
      fn(a, b) { #(a, b) },
      Invalid(NonEmptyList(first: "first", rest: ["second"])),
      Invalid(non_empty_list.single("third")),
    )
    == Invalid(NonEmptyList(first: "first", rest: ["second", "third"]))
}

pub fn map3_error_order_test() -> Nil {
  assert validated.map3(
      Triple,
      Invalid(non_empty_list.single("a")),
      Invalid(non_empty_list.single("b")),
      Invalid(non_empty_list.single("c")),
    )
    == Invalid(NonEmptyList(first: "a", rest: ["b", "c"]))
}

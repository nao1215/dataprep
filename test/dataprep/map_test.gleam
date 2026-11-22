import dataprep
import non_empty_list

// --- map2 ---

pub fn map2_all_valid_test() -> Nil {
  assert dataprep.map2(Ok(1), Ok(2), with: fn(a, b) { a + b }) == Ok(3)
}

pub fn map2_accumulates_errors_test() -> Nil {
  assert dataprep.map2(
      Error(non_empty_list.single("e1")),
      Error(non_empty_list.single("e2")),
      with: fn(a, b) { a + b },
    )
    == Error(non_empty_list.new("e1", ["e2"]))
}

pub fn map2_first_invalid_test() -> Nil {
  assert dataprep.map2(
      Error(non_empty_list.single("e1")),
      Ok(2),
      with: fn(a, b) { a + b },
    )
    == Error(non_empty_list.new("e1", []))
}

pub fn map2_second_invalid_test() -> Nil {
  assert dataprep.map2(
      Ok(1),
      Error(non_empty_list.single("e2")),
      with: fn(a, b) { a + b },
    )
    == Error(non_empty_list.new("e2", []))
}

pub fn map2_multiple_errors_per_branch_test() -> Nil {
  assert dataprep.map2(
      Error(non_empty_list.new("e1a", ["e1b"])),
      Error(non_empty_list.single("e2")),
      with: fn(a, b) { a + b },
    )
    == Error(non_empty_list.new("e1a", ["e1b", "e2"]))
}

// --- map3 ---

type Triple {
  Triple(a: Int, b: Int, c: Int)
}

pub fn map3_all_valid_test() -> Nil {
  assert dataprep.map3(Ok(1), Ok(2), Ok(3), with: Triple) == Ok(Triple(1, 2, 3))
}

pub fn map3_accumulates_errors_test() -> Nil {
  assert dataprep.map3(
      Error(non_empty_list.single("e1")),
      Ok(2),
      Error(non_empty_list.single("e3")),
      with: Triple,
    )
    == Error(non_empty_list.new("e1", ["e3"]))
}

pub fn map3_all_invalid_test() -> Nil {
  assert dataprep.map3(
      Error(non_empty_list.single("e1")),
      Error(non_empty_list.single("e2")),
      Error(non_empty_list.single("e3")),
      with: Triple,
    )
    == Error(non_empty_list.new("e1", ["e2", "e3"]))
}

pub fn map3_one_invalid_test() -> Nil {
  assert dataprep.map3(
      Ok(1),
      Error(non_empty_list.single("e2")),
      Ok(3),
      with: Triple,
    )
    == Error(non_empty_list.new("e2", []))
}

// --- map4 ---

type Quad {
  Quad(a: Int, b: Int, c: Int, d: Int)
}

pub fn map4_all_valid_test() -> Nil {
  assert dataprep.map4(Ok(1), Ok(2), Ok(3), Ok(4), with: Quad)
    == Ok(Quad(1, 2, 3, 4))
}

pub fn map4_accumulates_errors_test() -> Nil {
  assert dataprep.map4(
      Error(non_empty_list.single("e1")),
      Error(non_empty_list.single("e2")),
      Error(non_empty_list.single("e3")),
      Error(non_empty_list.single("e4")),
      with: Quad,
    )
    == Error(non_empty_list.new("e1", ["e2", "e3", "e4"]))
}

pub fn map4_partial_invalid_test() -> Nil {
  assert dataprep.map4(
      Ok(1),
      Error(non_empty_list.single("e2")),
      Ok(3),
      Error(non_empty_list.single("e4")),
      with: Quad,
    )
    == Error(non_empty_list.new("e2", ["e4"]))
}

// --- map5 ---

type Quint {
  Quint(a: Int, b: Int, c: Int, d: Int, e: Int)
}

pub fn map5_all_valid_test() -> Nil {
  assert dataprep.map5(Ok(1), Ok(2), Ok(3), Ok(4), Ok(5), with: Quint)
    == Ok(Quint(1, 2, 3, 4, 5))
}

pub fn map5_accumulates_errors_test() -> Nil {
  assert dataprep.map5(
      Error(non_empty_list.single("e1")),
      Ok(2),
      Error(non_empty_list.single("e3")),
      Ok(4),
      Error(non_empty_list.single("e5")),
      with: Quint,
    )
    == Error(non_empty_list.new("e1", ["e3", "e5"]))
}

pub fn map5_all_invalid_test() -> Nil {
  assert dataprep.map5(
      Error(non_empty_list.single("e1")),
      Error(non_empty_list.single("e2")),
      Error(non_empty_list.single("e3")),
      Error(non_empty_list.single("e4")),
      Error(non_empty_list.single("e5")),
      with: Quint,
    )
    == Error(non_empty_list.new("e1", ["e2", "e3", "e4", "e5"]))
}

pub fn map5_single_invalid_test() -> Nil {
  assert dataprep.map5(
      Ok(1),
      Ok(2),
      Ok(3),
      Error(non_empty_list.single("e4")),
      Ok(5),
      with: Quint,
    )
    == Error(non_empty_list.new("e4", []))
}

// --- error order preservation across mapN ---

pub fn map2_error_order_test() -> Nil {
  assert dataprep.map2(
      Error(non_empty_list.new("first", ["second"])),
      Error(non_empty_list.single("third")),
      with: fn(a, b) { #(a, b) },
    )
    == Error(non_empty_list.new("first", ["second", "third"]))
}

pub fn map3_error_order_test() -> Nil {
  assert dataprep.map3(
      Error(non_empty_list.single("a")),
      Error(non_empty_list.single("b")),
      Error(non_empty_list.single("c")),
      with: Triple,
    )
    == Error(non_empty_list.new("a", ["b", "c"]))
}

// --- mapN with the first result piped in ---

pub fn map2_pipes_first_result_test() -> Nil {
  assert Ok(1)
    |> dataprep.map2(Ok(2), with: fn(a, b) { a + b })
    == Ok(3)
}

pub fn map2_piped_accumulates_errors_test() -> Nil {
  assert Error(non_empty_list.single("a"))
    |> dataprep.map2(Error(non_empty_list.single("b")), with: fn(_, _) { Nil })
    == Error(non_empty_list.new("a", ["b"]))
}

pub fn map3_pipes_first_result_test() -> Nil {
  assert Ok(1)
    |> dataprep.map3(Ok(2), Ok(3), with: Triple)
    == Ok(Triple(1, 2, 3))
}

pub fn map3_piped_accumulates_errors_test() -> Nil {
  assert Error(non_empty_list.single("a"))
    |> dataprep.map3(Ok(2), Error(non_empty_list.single("c")), with: Triple)
    == Error(non_empty_list.new("a", ["c"]))
}

pub fn map4_pipes_first_result_test() -> Nil {
  assert Ok(1)
    |> dataprep.map4(Ok(2), Ok(3), Ok(4), with: Quad)
    == Ok(Quad(1, 2, 3, 4))
}

pub fn map4_piped_accumulates_errors_test() -> Nil {
  assert Error(non_empty_list.single("a"))
    |> dataprep.map4(
      Error(non_empty_list.single("b")),
      Ok(3),
      Error(non_empty_list.single("d")),
      with: Quad,
    )
    == Error(non_empty_list.new("a", ["b", "d"]))
}

pub fn map5_pipes_first_result_test() -> Nil {
  assert Ok(1)
    |> dataprep.map5(Ok(2), Ok(3), Ok(4), Ok(5), with: Quint)
    == Ok(Quint(1, 2, 3, 4, 5))
}

pub fn map5_piped_accumulates_errors_test() -> Nil {
  assert Error(non_empty_list.single("a"))
    |> dataprep.map5(
      Ok(2),
      Error(non_empty_list.single("c")),
      Ok(4),
      Error(non_empty_list.single("e")),
      with: Quint,
    )
    == Error(non_empty_list.new("a", ["c", "e"]))
}

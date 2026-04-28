import dataprep/helpers/nel
import dataprep/non_empty_list

// --- single ---

pub fn single_test() -> Nil {
  assert non_empty_list.single(1) == nel.make(first: 1, rest: [])
}

pub fn single_string_test() -> Nil {
  assert non_empty_list.single("a") |> non_empty_list.to_list == ["a"]
}

// --- cons ---

pub fn cons_test() -> Nil {
  assert non_empty_list.single(2) |> non_empty_list.cons(head: 1, tail: _)
    == nel.make(first: 1, rest: [2])
}

pub fn cons_multiple_test() -> Nil {
  assert non_empty_list.single(3)
    |> non_empty_list.cons(head: 2, tail: _)
    |> non_empty_list.cons(head: 1, tail: _)
    |> non_empty_list.to_list
    == [1, 2, 3]
}

// --- append ---

pub fn append_test() -> Nil {
  let left = nel.make(first: 1, rest: [2])
  let right = nel.make(first: 3, rest: [4])
  assert non_empty_list.append(left: left, right: right)
    == nel.make(first: 1, rest: [2, 3, 4])
}

pub fn append_single_to_single_test() -> Nil {
  assert non_empty_list.append(
      left: non_empty_list.single(1),
      right: non_empty_list.single(2),
    )
    |> non_empty_list.to_list
    == [1, 2]
}

pub fn append_preserves_order_test() -> Nil {
  let left = nel.make(first: "a", rest: ["b"])
  let right = nel.make(first: "c", rest: ["d"])
  assert non_empty_list.to_list(non_empty_list.append(left: left, right: right))
    == ["a", "b", "c", "d"]
}

// --- concat ---

pub fn concat_test() -> Nil {
  let first_group = nel.make(first: 1, rest: [2])
  let second_group = nel.make(first: 3, rest: [])
  let third_group = nel.make(first: 4, rest: [5])
  let groups = nel.make(first: first_group, rest: [second_group, third_group])
  assert non_empty_list.concat(groups) |> non_empty_list.to_list
    == [1, 2, 3, 4, 5]
}

pub fn concat_single_list_test() -> Nil {
  let inner = nel.make(first: 42, rest: [])
  let groups = nel.make(first: inner, rest: [])
  assert non_empty_list.concat(groups) |> non_empty_list.to_list == [42]
}

// --- map ---

pub fn map_test() -> Nil {
  let values = nel.make(first: 1, rest: [2, 3])
  assert non_empty_list.map(values, fn(x) { x * 2 }) |> non_empty_list.to_list
    == [2, 4, 6]
}

pub fn map_single_test() -> Nil {
  let value = non_empty_list.single(10)
  assert non_empty_list.map(value, fn(x) { x + 1 }) |> non_empty_list.to_list
    == [11]
}

pub fn map_type_change_test() -> Nil {
  let values = nel.make(first: 1, rest: [2, 3])
  assert non_empty_list.map(values, fn(x) { x > 1 }) |> non_empty_list.to_list
    == [False, True, True]
}

// --- flat_map ---

pub fn flat_map_test() -> Nil {
  let values = nel.make(first: 1, rest: [2])
  assert non_empty_list.flat_map(values, fn(x) {
      nel.make(first: x, rest: [x * 10])
    })
    |> non_empty_list.to_list
    == [1, 10, 2, 20]
}

pub fn flat_map_single_test() -> Nil {
  let value = non_empty_list.single(5)
  assert non_empty_list.flat_map(value, fn(x) {
      nel.make(first: x, rest: [x + 1])
    })
    |> non_empty_list.to_list
    == [5, 6]
}

// --- to_list ---

pub fn to_list_test() -> Nil {
  let values = nel.make(first: "a", rest: ["b", "c"])
  assert non_empty_list.to_list(values) == ["a", "b", "c"]
}

pub fn to_list_single_test() -> Nil {
  assert non_empty_list.single(42) |> non_empty_list.to_list == [42]
}

// --- from_list ---

pub fn from_list_empty_test() -> Nil {
  assert non_empty_list.from_list([]) == Error(Nil)
}

pub fn from_list_non_empty_test() -> Nil {
  assert non_empty_list.from_list([1, 2, 3])
    == Ok(nel.make(first: 1, rest: [2, 3]))
}

pub fn from_list_single_element_test() -> Nil {
  assert non_empty_list.from_list(["x"]) == Ok(nel.make(first: "x", rest: []))
}

// --- roundtrip ---

pub fn from_list_to_list_roundtrip_test() -> Nil {
  let original = [1, 2, 3, 4, 5]
  assert non_empty_list.from_list(original)
    == Ok(nel.make(first: 1, rest: [2, 3, 4, 5]))
}

// --- head ---

pub fn head_single_test() -> Nil {
  assert non_empty_list.single(1) |> non_empty_list.head == 1
}

pub fn head_after_cons_test() -> Nil {
  assert non_empty_list.single(2)
    |> non_empty_list.cons(head: 1, tail: _)
    |> non_empty_list.head
    == 1
}

pub fn head_multi_test() -> Nil {
  assert nel.make(first: "a", rest: ["b", "c"]) |> non_empty_list.head == "a"
}

// --- tail ---

pub fn tail_single_test() -> Nil {
  assert non_empty_list.single(1) |> non_empty_list.tail == []
}

pub fn tail_multi_test() -> Nil {
  assert nel.make(first: 1, rest: [2, 3]) |> non_empty_list.tail == [2, 3]
}

// --- length ---

pub fn length_single_test() -> Nil {
  assert non_empty_list.single(1) |> non_empty_list.length == 1
}

pub fn length_multi_test() -> Nil {
  assert nel.make(first: 1, rest: [2, 3, 4]) |> non_empty_list.length == 4
}

// --- fold ---

pub fn fold_sum_test() -> Nil {
  assert nel.make(first: 1, rest: [2, 3, 4])
    |> non_empty_list.fold(from: 0, with: fn(acc, item) { acc + item })
    == 10
}

pub fn fold_concat_test() -> Nil {
  assert nel.make(first: "a", rest: ["b", "c"])
    |> non_empty_list.fold(from: "", with: fn(acc, item) { acc <> item })
    == "abc"
}

pub fn fold_single_test() -> Nil {
  assert non_empty_list.single(5)
    |> non_empty_list.fold(from: 10, with: fn(acc, item) { acc + item })
    == 15
}

// --- reverse ---

pub fn reverse_single_test() -> Nil {
  assert non_empty_list.single(1)
    |> non_empty_list.reverse
    |> non_empty_list.to_list
    == [1]
}

pub fn reverse_multi_test() -> Nil {
  assert nel.make(first: 1, rest: [2, 3, 4])
    |> non_empty_list.reverse
    |> non_empty_list.to_list
    == [4, 3, 2, 1]
}

pub fn reverse_idempotent_test() -> Nil {
  let values = nel.make(first: 1, rest: [2, 3])
  assert values
    |> non_empty_list.reverse
    |> non_empty_list.reverse
    |> non_empty_list.to_list
    == [1, 2, 3]
}

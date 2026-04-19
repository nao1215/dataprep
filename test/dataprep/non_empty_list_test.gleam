import dataprep/non_empty_list.{NonEmptyList}

// --- single ---

pub fn single_test() -> Nil {
  assert non_empty_list.single(1) == NonEmptyList(first: 1, rest: [])
}

pub fn single_string_test() -> Nil {
  assert non_empty_list.single("a") |> non_empty_list.to_list == ["a"]
}

// --- cons ---

pub fn cons_test() -> Nil {
  assert non_empty_list.single(2) |> non_empty_list.cons(head: 1, tail: _)
    == NonEmptyList(first: 1, rest: [2])
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
  let left = NonEmptyList(first: 1, rest: [2])
  let right = NonEmptyList(first: 3, rest: [4])
  assert non_empty_list.append(left: left, right: right)
    == NonEmptyList(first: 1, rest: [2, 3, 4])
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
  let left = NonEmptyList(first: "a", rest: ["b"])
  let right = NonEmptyList(first: "c", rest: ["d"])
  assert non_empty_list.to_list(non_empty_list.append(left: left, right: right))
    == ["a", "b", "c", "d"]
}

// --- concat ---

pub fn concat_test() -> Nil {
  let first_group = NonEmptyList(first: 1, rest: [2])
  let second_group = NonEmptyList(first: 3, rest: [])
  let third_group = NonEmptyList(first: 4, rest: [5])
  let groups =
    NonEmptyList(first: first_group, rest: [second_group, third_group])
  assert non_empty_list.concat(groups) |> non_empty_list.to_list
    == [1, 2, 3, 4, 5]
}

pub fn concat_single_list_test() -> Nil {
  let inner = NonEmptyList(first: 42, rest: [])
  let groups = NonEmptyList(first: inner, rest: [])
  assert non_empty_list.concat(groups) |> non_empty_list.to_list == [42]
}

// --- map ---

pub fn map_test() -> Nil {
  let values = NonEmptyList(first: 1, rest: [2, 3])
  assert non_empty_list.map(values, fn(x) { x * 2 }) |> non_empty_list.to_list
    == [2, 4, 6]
}

pub fn map_single_test() -> Nil {
  let value = non_empty_list.single(10)
  assert non_empty_list.map(value, fn(x) { x + 1 }) |> non_empty_list.to_list
    == [11]
}

pub fn map_type_change_test() -> Nil {
  let values = NonEmptyList(first: 1, rest: [2, 3])
  assert non_empty_list.map(values, fn(x) { x > 1 }) |> non_empty_list.to_list
    == [False, True, True]
}

// --- flat_map ---

pub fn flat_map_test() -> Nil {
  let values = NonEmptyList(first: 1, rest: [2])
  assert non_empty_list.flat_map(values, fn(x) {
      NonEmptyList(first: x, rest: [x * 10])
    })
    |> non_empty_list.to_list
    == [1, 10, 2, 20]
}

pub fn flat_map_single_test() -> Nil {
  let value = non_empty_list.single(5)
  assert non_empty_list.flat_map(value, fn(x) {
      NonEmptyList(first: x, rest: [x + 1])
    })
    |> non_empty_list.to_list
    == [5, 6]
}

// --- to_list ---

pub fn to_list_test() -> Nil {
  let values = NonEmptyList(first: "a", rest: ["b", "c"])
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
    == Ok(NonEmptyList(first: 1, rest: [2, 3]))
}

pub fn from_list_single_element_test() -> Nil {
  assert non_empty_list.from_list(["x"])
    == Ok(NonEmptyList(first: "x", rest: []))
}

// --- roundtrip ---

pub fn from_list_to_list_roundtrip_test() -> Nil {
  let original = [1, 2, 3, 4, 5]
  assert non_empty_list.from_list(original)
    == Ok(NonEmptyList(first: 1, rest: [2, 3, 4, 5]))
}

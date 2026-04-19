import dataprep/non_empty_list.{NonEmptyList}

// --- single ---

pub fn single_test() {
  let nel = non_empty_list.single(1)
  let assert NonEmptyList(first: 1, rest: []) = nel
}

pub fn single_string_test() {
  let nel = non_empty_list.single("a")
  let assert ["a"] = non_empty_list.to_list(nel)
}

// --- cons ---

pub fn cons_test() {
  let nel = non_empty_list.single(2) |> non_empty_list.cons(head: 1, tail: _)
  let assert NonEmptyList(first: 1, rest: [2]) = nel
}

pub fn cons_multiple_test() {
  let nel =
    non_empty_list.single(3)
    |> non_empty_list.cons(head: 2, tail: _)
    |> non_empty_list.cons(head: 1, tail: _)
  let assert [1, 2, 3] = non_empty_list.to_list(nel)
}

// --- append ---

pub fn append_test() {
  let left = NonEmptyList(first: 1, rest: [2])
  let right = NonEmptyList(first: 3, rest: [4])
  let result = non_empty_list.append(left: left, right: right)
  let assert NonEmptyList(first: 1, rest: [2, 3, 4]) = result
}

pub fn append_single_to_single_test() {
  let result =
    non_empty_list.append(
      left: non_empty_list.single(1),
      right: non_empty_list.single(2),
    )
  let assert [1, 2] = non_empty_list.to_list(result)
}

pub fn append_preserves_order_test() {
  let left = NonEmptyList(first: "a", rest: ["b"])
  let right = NonEmptyList(first: "c", rest: ["d"])
  let assert ["a", "b", "c", "d"] =
    non_empty_list.to_list(non_empty_list.append(left: left, right: right))
}

// --- concat ---

pub fn concat_test() {
  let a = NonEmptyList(first: 1, rest: [2])
  let b = NonEmptyList(first: 3, rest: [])
  let c = NonEmptyList(first: 4, rest: [5])
  let lists = NonEmptyList(first: a, rest: [b, c])
  let result = non_empty_list.concat(lists)
  let assert [1, 2, 3, 4, 5] = non_empty_list.to_list(result)
}

pub fn concat_single_list_test() {
  let inner = NonEmptyList(first: 42, rest: [])
  let lists = NonEmptyList(first: inner, rest: [])
  let assert [42] = non_empty_list.to_list(non_empty_list.concat(lists))
}

// --- map ---

pub fn map_test() {
  let nel = NonEmptyList(first: 1, rest: [2, 3])
  let result = non_empty_list.map(nel, fn(x) { x * 2 })
  let assert [2, 4, 6] = non_empty_list.to_list(result)
}

pub fn map_single_test() {
  let nel = non_empty_list.single(10)
  let result = non_empty_list.map(nel, fn(x) { x + 1 })
  let assert [11] = non_empty_list.to_list(result)
}

pub fn map_type_change_test() {
  let nel = NonEmptyList(first: 1, rest: [2, 3])
  let result = non_empty_list.map(nel, fn(x) { x > 1 })
  let assert [False, True, True] = non_empty_list.to_list(result)
}

// --- flat_map ---

pub fn flat_map_test() {
  let nel = NonEmptyList(first: 1, rest: [2])
  let result =
    non_empty_list.flat_map(nel, fn(x) {
      NonEmptyList(first: x, rest: [x * 10])
    })
  let assert [1, 10, 2, 20] = non_empty_list.to_list(result)
}

pub fn flat_map_single_test() {
  let nel = non_empty_list.single(5)
  let result =
    non_empty_list.flat_map(nel, fn(x) { NonEmptyList(first: x, rest: [x + 1]) })
  let assert [5, 6] = non_empty_list.to_list(result)
}

// --- to_list ---

pub fn to_list_test() {
  let nel = NonEmptyList(first: "a", rest: ["b", "c"])
  let assert ["a", "b", "c"] = non_empty_list.to_list(nel)
}

pub fn to_list_single_test() {
  let assert [42] = non_empty_list.to_list(non_empty_list.single(42))
}

// --- from_list ---

pub fn from_list_empty_test() {
  let assert Error(Nil) = non_empty_list.from_list([])
}

pub fn from_list_non_empty_test() {
  let assert Ok(nel) = non_empty_list.from_list([1, 2, 3])
  let assert NonEmptyList(first: 1, rest: [2, 3]) = nel
}

pub fn from_list_single_element_test() {
  let assert Ok(nel) = non_empty_list.from_list(["x"])
  let assert NonEmptyList(first: "x", rest: []) = nel
}

// --- roundtrip ---

pub fn from_list_to_list_roundtrip_test() {
  let original = [1, 2, 3, 4, 5]
  let assert Ok(nel) = non_empty_list.from_list(original)
  let assert [1, 2, 3, 4, 5] = non_empty_list.to_list(nel)
}

import dataprep/non_empty_list.{NonEmptyList}

pub fn single_test() {
  let nel = non_empty_list.single(1)
  let assert NonEmptyList(first: 1, rest: []) = nel
}

pub fn cons_test() {
  let nel = non_empty_list.single(2) |> non_empty_list.cons(1, _)
  let assert NonEmptyList(first: 1, rest: [2]) = nel
}

pub fn append_test() {
  let left = NonEmptyList(first: 1, rest: [2])
  let right = NonEmptyList(first: 3, rest: [4])
  let result = non_empty_list.append(left, right)
  let assert NonEmptyList(first: 1, rest: [2, 3, 4]) = result
}

pub fn concat_test() {
  let a = NonEmptyList(first: 1, rest: [2])
  let b = NonEmptyList(first: 3, rest: [])
  let c = NonEmptyList(first: 4, rest: [5])
  let lists = NonEmptyList(first: a, rest: [b, c])
  let result = non_empty_list.concat(lists)
  let assert [1, 2, 3, 4, 5] = non_empty_list.to_list(result)
}

pub fn map_test() {
  let nel = NonEmptyList(first: 1, rest: [2, 3])
  let result = non_empty_list.map(nel, fn(x) { x * 2 })
  let assert [2, 4, 6] = non_empty_list.to_list(result)
}

pub fn flat_map_test() {
  let nel = NonEmptyList(first: 1, rest: [2])
  let result =
    non_empty_list.flat_map(nel, fn(x) {
      NonEmptyList(first: x, rest: [x * 10])
    })
  let assert [1, 10, 2, 20] = non_empty_list.to_list(result)
}

pub fn to_list_test() {
  let nel = NonEmptyList(first: "a", rest: ["b", "c"])
  let assert ["a", "b", "c"] = non_empty_list.to_list(nel)
}

pub fn from_list_empty_test() {
  let assert Error(Nil) = non_empty_list.from_list([])
}

pub fn from_list_non_empty_test() {
  let assert Ok(nel) = non_empty_list.from_list([1, 2, 3])
  let assert NonEmptyList(first: 1, rest: [2, 3]) = nel
}

/// NonEmptyList guarantees at least one element.
/// Used by Invalid to ensure every failure carries at least one error.
pub type NonEmptyList(a) {
  NonEmptyList(first: a, rest: List(a))
}

/// Create a NonEmptyList with a single element.
pub fn single(value: a) -> NonEmptyList(a) {
  NonEmptyList(first: value, rest: [])
}

/// Prepend an element to a NonEmptyList.
pub fn cons(head head: a, tail tail: NonEmptyList(a)) -> NonEmptyList(a) {
  NonEmptyList(first: head, rest: [tail.first, ..tail.rest])
}

/// Concatenate two NonEmptyLists.
pub fn append(
  left left: NonEmptyList(a),
  right right: NonEmptyList(a),
) -> NonEmptyList(a) {
  NonEmptyList(
    first: left.first,
    rest: list.append(left.rest, [right.first, ..right.rest]),
  )
}

/// Flatten a NonEmptyList of NonEmptyLists into a single NonEmptyList.
pub fn concat(lists: NonEmptyList(NonEmptyList(a))) -> NonEmptyList(a) {
  list.fold(over: lists.rest, from: lists.first, with: fn(acc, next) {
    append(left: acc, right: next)
  })
}

/// Transform every element.
pub fn map(nel: NonEmptyList(a), f: fn(a) -> b) -> NonEmptyList(b) {
  NonEmptyList(first: f(nel.first), rest: list.map(nel.rest, f))
}

/// Map then flatten.
pub fn flat_map(
  nel: NonEmptyList(a),
  f: fn(a) -> NonEmptyList(b),
) -> NonEmptyList(b) {
  concat(map(nel, f))
}

/// Convert to a plain List.
pub fn to_list(nel: NonEmptyList(a)) -> List(a) {
  [nel.first, ..nel.rest]
}

/// Try to create a NonEmptyList from a List.
/// Returns Error(Nil) if the list is empty.
pub fn from_list(l: List(a)) -> Result(NonEmptyList(a), Nil) {
  case l {
    [] -> Error(Nil)
    [first, ..rest] -> Ok(NonEmptyList(first: first, rest: rest))
  }
}

import gleam/list

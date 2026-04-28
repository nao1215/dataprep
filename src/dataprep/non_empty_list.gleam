import gleam/list

/// NonEmptyList guarantees at least one element.
/// Used by Invalid to ensure every failure carries at least one error.
///
/// The type is opaque: callers construct values via `single` / `cons` /
/// `from_list` and observe values via `head` / `tail` / `to_list` /
/// `fold` / `length` / `reverse`. Hiding the constructor lets the
/// internal representation evolve without a breaking release.
pub opaque type NonEmptyList(a) {
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

/// Return the first element. Total: a NonEmptyList always has one.
pub fn head(nel: NonEmptyList(a)) -> a {
  nel.first
}

/// Return everything after the first element as a plain List.
/// May be empty when the NonEmptyList holds a single element.
pub fn tail(nel: NonEmptyList(a)) -> List(a) {
  nel.rest
}

/// Return the number of elements. Always >= 1.
pub fn length(nel: NonEmptyList(a)) -> Int {
  list.length(to_list(nel))
}

/// Fold over every item from an initial accumulator.
pub fn fold(nel: NonEmptyList(a), from initial: b, with f: fn(b, a) -> b) -> b {
  list.fold(over: to_list(nel), from: initial, with: f)
}

/// Reverse the order of elements. The result is itself a NonEmptyList.
pub fn reverse(nel: NonEmptyList(a)) -> NonEmptyList(a) {
  list.fold(over: nel.rest, from: single(nel.first), with: fn(acc, item) {
    cons(head: item, tail: acc)
  })
}

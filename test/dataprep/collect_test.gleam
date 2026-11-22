import dataprep
import gleam/list
import gleam/option
import non_empty_list

type Err {
  TooShort
  Indexed(index: Int, detail: Err)
}

// --- collect ---

pub fn collect_all_valid_test() -> Nil {
  assert dataprep.collect([Ok(1), Ok(2), Ok(3)]) == Ok([1, 2, 3])
}

pub fn collect_empty_list_test() -> Nil {
  assert dataprep.collect([]) == Ok([])
}

pub fn collect_accumulates_errors_test() -> Nil {
  assert dataprep.collect([
      Ok(1),
      Error(non_empty_list.single("e1")),
      Ok(3),
      Error(non_empty_list.single("e2")),
    ])
    == Error(non_empty_list.new("e1", ["e2"]))
}

pub fn collect_single_invalid_test() -> Nil {
  assert dataprep.collect([Error(non_empty_list.single("err"))])
    == Error(non_empty_list.single("err"))
}

pub fn collect_preserves_order_test() -> Nil {
  assert dataprep.collect([Ok("a"), Ok("b"), Ok("c")]) == Ok(["a", "b", "c"])
}

// --- collect over list.map ---

pub fn collect_map_all_pass_test() -> Nil {
  assert dataprep.collect(
      list.map([1, 2, 3], fn(n) {
        case n > 0 {
          True -> Ok(n)
          False -> Error(non_empty_list.single("negative"))
        }
      }),
    )
    == Ok([1, 2, 3])
}

pub fn collect_map_empty_list_test() -> Nil {
  assert dataprep.collect(list.map([], fn(_) { Ok(1) })) == Ok([])
}

pub fn collect_map_accumulates_errors_test() -> Nil {
  assert dataprep.collect(
      list.map(["hello", "", "world", ""], fn(s) {
        dataprep.not_empty(TooShort)(s)
      }),
    )
    == Error(non_empty_list.new(TooShort, [TooShort]))
}

pub fn collect_map_with_transform_test() -> Nil {
  assert dataprep.collect(
      list.map(["1", "2", "3"], fn(s) {
        case s {
          "1" -> Ok(1)
          "2" -> Ok(2)
          "3" -> Ok(3)
          _ -> Error(non_empty_list.single("bad"))
        }
      }),
    )
    == Ok([1, 2, 3])
}

// --- collect over list.index_map ---

pub fn collect_index_map_with_label_test() -> Nil {
  assert dataprep.collect(
      list.index_map(["hello", "", "world"], fn(s, i) {
        dataprep.map_error(dataprep.not_empty(TooShort), with: fn(e) {
          Indexed(i, e)
        })(s)
      }),
    )
    == Error(non_empty_list.single(Indexed(1, TooShort)))
}

pub fn collect_index_map_all_valid_test() -> Nil {
  assert dataprep.collect(list.index_map(["a", "b", "c"], fn(s, _i) { Ok(s) }))
    == Ok(["a", "b", "c"])
}

pub fn collect_index_map_empty_test() -> Nil {
  assert dataprep.collect(list.index_map([], fn(_s: String, _i) { Ok("x") }))
    == Ok([])
}

// --- each ---

pub fn each_all_pass_test() -> Nil {
  let check = dataprep.each(dataprep.not_empty(TooShort))
  assert check(["a", "b", "c"]) == Ok(["a", "b", "c"])
}

pub fn each_accumulates_test() -> Nil {
  let check = dataprep.each(dataprep.not_empty(TooShort))
  assert check(["a", "", "b", ""])
    == Error(non_empty_list.new(TooShort, [TooShort]))
}

pub fn each_empty_list_test() -> Nil {
  let check = dataprep.each(dataprep.not_empty(TooShort))
  assert check([]) == Ok([])
}

// --- optional ---

pub fn optional_none_test() -> Nil {
  let check = dataprep.optional(dataprep.not_empty(TooShort))
  assert check(option.None) == Ok(option.None)
}

pub fn optional_some_valid_test() -> Nil {
  let check = dataprep.optional(dataprep.not_empty(TooShort))
  assert check(option.Some("hello")) == Ok(option.Some("hello"))
}

pub fn optional_some_invalid_test() -> Nil {
  let check = dataprep.optional(dataprep.not_empty(TooShort))
  assert check(option.Some("")) == Error(non_empty_list.single(TooShort))
}

// --- large inputs (stack safety on JavaScript) ---
//
// collect and each used list.fold_right,
// which recursed once per element and overflowed the JavaScript stack
// at about 10_000 elements.

const large_size = 100_000

fn indices(count: Int) -> List(Int) {
  list.index_map(list.repeat(Nil, count), fn(_, index) { index })
}

pub fn collect_large_list_test() -> Nil {
  let items = list.map(indices(large_size), fn(i) { i + 1 })
  assert dataprep.collect(list.map(items, Ok)) == Ok(items)
}

pub fn collect_map_large_list_test() -> Nil {
  let items = list.map(indices(large_size), fn(i) { i + 1 })
  assert dataprep.collect(list.map(items, fn(n) { Ok(n * 2) }))
    == Ok(list.map(items, fn(n) { n * 2 }))
}

pub fn collect_index_map_large_list_test() -> Nil {
  let items = list.repeat("x", large_size)
  assert dataprep.collect(list.index_map(items, fn(_, i) { Ok(i) }))
    == Ok(indices(large_size))
}

pub fn each_large_list_test() -> Nil {
  let items = list.repeat("long enough", large_size)
  let check = dataprep.each(dataprep.min_length(minimum: 3, error: TooShort))
  assert check(items) == Ok(items)
}

pub fn collect_map_large_list_accumulates_every_error_in_order_test() -> Nil {
  let items = indices(large_size)
  // nolint: assert_ok_pattern -- every even element fails by construction
  let assert Error(errors) =
    dataprep.collect(
      list.index_map(items, fn(n, i) {
        case n % 2 {
          0 -> Error(non_empty_list.single(Indexed(index: i, detail: TooShort)))
          _ -> Ok(n)
        }
      }),
    )
    as "every even element fails"
  assert non_empty_list.to_list(errors)
    == list.map(list.filter(items, fn(n) { n % 2 == 0 }), fn(i) {
      Indexed(index: i, detail: TooShort)
    })
}

pub fn collect_large_list_of_failures_test() -> Nil {
  let items = list.repeat(Error(non_empty_list.single(TooShort)), large_size)
  // nolint: assert_ok_pattern -- every element fails by construction
  let assert Error(errors) = dataprep.collect(items) as "all elements fail"
  assert non_empty_list.length(errors) == large_size
}

import dataprep
import gleam/list
import metamon
import metamon/generator
import metamon/generator/range
import non_empty_list.{type NonEmptyList}

// ---------- Normalising ----------

pub fn collapse_space_is_idempotent_test() -> Nil {
  let mr =
    metamon.idempotency_of(
      name: "collapse_space_idempotent",
      of: dataprep.collapse_space,
    )
  metamon.forall_morph(
    generator.string_ascii(range.constant(0, 16)),
    mr,
    dataprep.collapse_space,
  )
}

pub fn collapse_unicode_space_is_idempotent_test() -> Nil {
  let mr =
    metamon.idempotency_of(
      name: "collapse_unicode_space_idempotent",
      of: dataprep.collapse_unicode_space,
    )
  metamon.forall_morph(
    generator.string_ascii(range.constant(0, 16)),
    mr,
    dataprep.collapse_unicode_space,
  )
}

// ---------- Combining results ----------

pub fn map2_two_errors_concatenate_errors_test() -> Nil {
  metamon.forall(
    generator.tuple2(
      generator.string_ascii(range.constant(1, 4)),
      generator.string_ascii(range.constant(1, 4)),
    ),
    fn(pair) {
      let #(error_a, error_b) = pair
      let invalid_a: Result(Int, NonEmptyList(String)) =
        Error(non_empty_list.single(error_a))
      let invalid_b: Result(Int, NonEmptyList(String)) =
        Error(non_empty_list.single(error_b))
      let combined =
        dataprep.map2(invalid_a, invalid_b, with: fn(left, right) {
          left + right
        })
      case combined {
        Error(errors) -> non_empty_list.to_list(errors) == [error_a, error_b]
        Ok(_) -> False
      }
    },
  )
}

pub fn collect_empty_is_ok_empty_test() -> Nil {
  let result: Result(List(Int), NonEmptyList(String)) = dataprep.collect([])
  assert result == Ok([])
}

pub fn collect_preserves_all_ok_test() -> Nil {
  metamon.forall(
    generator.list_of(
      generator.int(range.constant(-100, 100)),
      range.constant(0, 6),
    ),
    fn(values) {
      let inputs: List(Result(Int, NonEmptyList(String))) = list.map(values, Ok)
      dataprep.collect(inputs) == Ok(values)
    },
  )
}

pub fn each_matches_map_then_collect_test() -> Nil {
  metamon.forall(
    generator.list_of(
      generator.int(range.constant(-50, 50)),
      range.constant(0, 4),
    ),
    fn(values) {
      let positive = dataprep.min_int(0, "negative")
      dataprep.each(positive)(values)
      == dataprep.collect(list.map(values, positive))
    },
  )
}

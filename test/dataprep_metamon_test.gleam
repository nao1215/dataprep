import dataprep
import gleam/list
import gleam/result
import metamon
import metamon/generator
import non_empty_list.{type NonEmptyList}

// ---------- Normalising ----------

pub fn collapse_space_is_idempotent_test() -> Nil {
  let mr =
    metamon.idempotency_of(
      name: "collapse_space_idempotent",
      of: dataprep.collapse_space,
    )
  metamon.forall_morph(
    generator.string(
      of: generator.Ascii,
      length: generator.range(from: 0, to: 16),
    ),
    [mr],
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
    generator.string_from(
      characters: generator.one_of([
        generator.character(of: generator.PrintableAscii),
        generator.element_of([
          "\u{0085}", "\u{00A0}", "\u{2003}", "\u{2028}", "\u{3000}", "\u{FEFF}",
          "\t", " ",
        ]),
      ]),
      length: generator.range(from: 0, to: 16),
    ),
    [mr],
    dataprep.collapse_unicode_space,
  )
}

// ---------- Combining results ----------

pub fn map2_two_errors_concatenate_errors_test() -> Nil {
  metamon.forall(
    generator.tuple2(
      generator.string(
        of: generator.Ascii,
        length: generator.range(from: 1, to: 4),
      ),
      generator.string(
        of: generator.Ascii,
        length: generator.range(from: 1, to: 4),
      ),
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
      assert result.map_error(combined, non_empty_list.to_list)
        == Error([error_a, error_b])
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
      generator.int(generator.range(from: -100, to: 100)),
      length: generator.range(from: 0, to: 6),
    ),
    fn(values) {
      let inputs: List(Result(Int, NonEmptyList(String))) = list.map(values, Ok)
      assert dataprep.collect(inputs) == Ok(values)
    },
  )
}

pub fn each_matches_map_then_collect_test() -> Nil {
  metamon.forall(
    generator.list_of(
      generator.int(generator.range(from: -50, to: 50)),
      length: generator.range(from: 0, to: 4),
    ),
    fn(values) {
      let positive = dataprep.min_int(0, "negative")
      assert dataprep.each(positive)(values)
        == dataprep.collect(list.map(values, positive))
    },
  )
}

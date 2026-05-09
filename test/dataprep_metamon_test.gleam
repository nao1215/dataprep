import dataprep/non_empty_list
import dataprep/prep
import dataprep/validated.{Invalid, Valid}
import gleam/list
import gleam/string
import metamon
import metamon/generator
import metamon/generator/range

// ---------- Prep ----------

pub fn prep_identity_is_left_neutral_test() -> Nil {
  metamon.forall(generator.string_ascii(range.constant(0, 16)), fn(input) {
    let pipeline = prep.then(first: prep.identity(), next: prep.trim())
    pipeline(input) == prep.trim()(input)
  })
}

pub fn prep_identity_is_right_neutral_test() -> Nil {
  metamon.forall(generator.string_ascii(range.constant(0, 16)), fn(input) {
    let pipeline = prep.then(first: prep.trim(), next: prep.identity())
    pipeline(input) == prep.trim()(input)
  })
}

pub fn prep_sequence_empty_is_identity_test() -> Nil {
  metamon.forall(generator.string_ascii(range.constant(0, 16)), fn(input) {
    prep.sequence([])(input) == input
  })
}

pub fn prep_then_is_associative_test() -> Nil {
  metamon.forall(generator.string_ascii(range.constant(0, 16)), fn(input) {
    let trim_step = prep.trim()
    let lower_step = prep.lowercase()
    let replace_step = prep.replace(target: " ", replacement: "_")
    let left_assoc =
      prep.then(
        first: prep.then(first: trim_step, next: lower_step),
        next: replace_step,
      )(input)
    let right_assoc =
      prep.then(
        first: trim_step,
        next: prep.then(first: lower_step, next: replace_step),
      )(input)
    left_assoc == right_assoc
  })
}

pub fn prep_trim_is_idempotent_test() -> Nil {
  let mr = metamon.idempotency_of(name: "prep_trim_idempotent", of: prep.trim())
  metamon.forall_morph(
    generator.string_ascii(range.constant(0, 16)),
    mr,
    prep.trim(),
  )
}

pub fn prep_lowercase_is_idempotent_test() -> Nil {
  let mr =
    metamon.idempotency_of(
      name: "prep_lowercase_idempotent",
      of: prep.lowercase(),
    )
  metamon.forall_morph(
    generator.string_ascii(range.constant(0, 16)),
    mr,
    prep.lowercase(),
  )
}

pub fn prep_uppercase_is_idempotent_test() -> Nil {
  let mr =
    metamon.idempotency_of(
      name: "prep_uppercase_idempotent",
      of: prep.uppercase(),
    )
  metamon.forall_morph(
    generator.string_ascii(range.constant(0, 16)),
    mr,
    prep.uppercase(),
  )
}

pub fn prep_run_equals_function_application_test() -> Nil {
  metamon.forall(generator.string_ascii(range.constant(0, 16)), fn(input) {
    let pipeline = prep.then(first: prep.trim(), next: prep.lowercase())
    prep.run(prep: pipeline, value: input) == pipeline(input)
  })
}

pub fn prep_compose_equals_then_test() -> Nil {
  metamon.forall(generator.string_ascii(range.constant(0, 16)), fn(input) {
    let via_then = prep.then(first: prep.trim(), next: prep.lowercase())
    let via_compose = prep.compose(first: prep.trim(), then: prep.lowercase())
    via_then(input) == via_compose(input)
  })
}

// ---------- NonEmptyList ----------

fn nel_int_generator() -> generator.Generator(non_empty_list.NonEmptyList(Int)) {
  generator.map2(
    generator.int(range.constant(-100, 100)),
    generator.list_of(
      generator.int(range.constant(-100, 100)),
      range.constant(0, 6),
    ),
    fn(head, tail) {
      list.fold(
        over: tail,
        from: non_empty_list.single(head),
        with: fn(acc, item) {
          non_empty_list.append(left: acc, right: non_empty_list.single(item))
        },
      )
    },
  )
}

pub fn nel_length_is_at_least_one_test() -> Nil {
  metamon.forall(nel_int_generator(), fn(nel) {
    non_empty_list.length(nel) >= 1
  })
}

pub fn nel_to_list_round_trips_test() -> Nil {
  metamon.forall(nel_int_generator(), fn(nel) {
    let original_list = non_empty_list.to_list(nel)
    case non_empty_list.from_list(original_list) {
      Ok(rebuilt) -> non_empty_list.to_list(rebuilt) == original_list
      Error(Nil) -> False
    }
  })
}

pub fn nel_reverse_is_involutive_test() -> Nil {
  metamon.forall(nel_int_generator(), fn(nel) {
    let twice = non_empty_list.reverse(non_empty_list.reverse(nel))
    non_empty_list.to_list(twice) == non_empty_list.to_list(nel)
  })
}

pub fn nel_reverse_preserves_length_test() -> Nil {
  metamon.forall(nel_int_generator(), fn(nel) {
    non_empty_list.length(non_empty_list.reverse(nel))
    == non_empty_list.length(nel)
  })
}

pub fn nel_append_lengths_add_test() -> Nil {
  metamon.forall(
    generator.tuple2(nel_int_generator(), nel_int_generator()),
    fn(pair) {
      let #(left, right) = pair
      non_empty_list.length(non_empty_list.append(left:, right:))
      == non_empty_list.length(left) + non_empty_list.length(right)
    },
  )
}

pub fn nel_append_preserves_to_list_concat_test() -> Nil {
  metamon.forall(
    generator.tuple2(nel_int_generator(), nel_int_generator()),
    fn(pair) {
      let #(left, right) = pair
      non_empty_list.to_list(non_empty_list.append(left:, right:))
      == list.append(
        non_empty_list.to_list(left),
        non_empty_list.to_list(right),
      )
    },
  )
}

pub fn nel_head_of_single_round_trips_test() -> Nil {
  metamon.forall(generator.int(range.constant(-100, 100)), fn(value) {
    non_empty_list.head(non_empty_list.single(value)) == value
  })
}

pub fn nel_from_list_empty_returns_error_test() -> Nil {
  assert non_empty_list.from_list([]) == Error(Nil)
}

pub fn nel_map_preserves_length_test() -> Nil {
  metamon.forall(nel_int_generator(), fn(nel) {
    non_empty_list.length(non_empty_list.map(nel, fn(item) { item * 2 }))
    == non_empty_list.length(nel)
  })
}

// ---------- Validated ----------

pub fn validated_from_result_ok_is_valid_test() -> Nil {
  metamon.forall(generator.int(range.constant(-100, 100)), fn(value) {
    validated.from_result(Ok(value)) == Valid(value)
  })
}

pub fn validated_from_result_error_round_trips_test() -> Nil {
  metamon.forall(generator.int(range.constant(-100, 100)), fn(error_value) {
    case validated.from_result(Error(error_value)) {
      Invalid(errors) -> non_empty_list.to_list(errors) == [error_value]
      Valid(_) -> False
    }
  })
}

pub fn validated_map_preserves_invalid_test() -> Nil {
  metamon.forall(generator.int(range.constant(-100, 100)), fn(error_value) {
    let invalid: validated.Validated(Int, Int) = validated.fail(error_value)
    let mapped = validated.map(invalid, fn(value) { value * 10 })
    mapped == invalid
  })
}

pub fn validated_map_error_preserves_valid_test() -> Nil {
  metamon.forall(generator.int(range.constant(-100, 100)), fn(value) {
    let valid_value: validated.Validated(Int, String) = Valid(value)
    validated.map_error(valid_value, fn(error) { error <> "!" }) == Valid(value)
  })
}

pub fn validated_to_result_round_trips_valid_test() -> Nil {
  metamon.forall(generator.int(range.constant(-100, 100)), fn(value) {
    validated.to_result(Valid(value)) == Ok(value)
  })
}

pub fn validated_map2_two_invalids_concatenate_errors_test() -> Nil {
  metamon.forall(
    generator.tuple2(
      generator.string_ascii(range.constant(1, 4)),
      generator.string_ascii(range.constant(1, 4)),
    ),
    fn(pair) {
      let #(error_a, error_b) = pair
      let invalid_a: validated.Validated(Int, String) = validated.fail(error_a)
      let invalid_b: validated.Validated(Int, String) = validated.fail(error_b)
      let combined =
        validated.map2(fn(left, right) { left + right }, invalid_a, invalid_b)
      case combined {
        Invalid(errors) -> non_empty_list.to_list(errors) == [error_a, error_b]
        Valid(_) -> False
      }
    },
  )
}

pub fn validated_sequence_empty_is_valid_empty_test() -> Nil {
  let result: validated.Validated(List(Int), String) = validated.sequence([])
  assert result == Valid([])
}

pub fn validated_sequence_preserves_all_valid_test() -> Nil {
  metamon.forall(
    generator.list_of(
      generator.int(range.constant(-100, 100)),
      range.constant(0, 6),
    ),
    fn(values) {
      let inputs: List(validated.Validated(Int, String)) =
        list.map(values, Valid)
      validated.sequence(inputs) == Valid(values)
    },
  )
}

pub fn validated_traverse_matches_map_then_sequence_test() -> Nil {
  metamon.forall(
    generator.list_of(
      generator.int(range.constant(-50, 50)),
      range.constant(0, 4),
    ),
    fn(values) {
      let mapper = fn(value: Int) -> validated.Validated(Int, String) {
        case value < 0 {
          True -> validated.fail("negative")
          False -> Valid(value * 2)
        }
      }
      validated.traverse(values, mapper)
      == validated.sequence(list.map(values, mapper))
    },
  )
}

// ---------- prep + string spec checks (smoke) ----------

pub fn prep_lowercase_then_uppercase_smoke_test() -> Nil {
  metamon.forall(generator.string_alpha(range.constant(0, 8)), fn(input) {
    let pipeline = prep.then(first: prep.lowercase(), next: prep.uppercase())
    pipeline(input) == string.uppercase(input)
  })
}

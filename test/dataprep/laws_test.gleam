// Behavioral laws for the validator and result combinators.
//
// These tests are written as data-driven law assertions: each test names
// a documented invariant (accumulation vs short-circuit, error order,
// etc.) and exercises it across multiple representative
// inputs. They are deliberately phrased so that a regression in
// short-circuit vs accumulation semantics fails on the law itself, not
// on a single arithmetic edge case.
//
// See `doc/laws.md` for the prose description of every law
// asserted here.

import dataprep
import gleam/list
import gleam/option
import non_empty_list.{type NonEmptyList}

type LawErr {
  E1
  E2
  E3
  E4
  Tag(Int)
}

// ---------------------------------------------------------------------------
// Validator combinator laws
// ---------------------------------------------------------------------------

// Law: a Validator preserves its input on success.
//   For all v and x: if v(x) returns Ok(y), then x == y.
pub fn law_validator_preserves_input_on_success_test() -> Nil {
  let pass_string = dataprep.predicate(fn(_: String) { True }, E1)
  list.each(["", "hello", "  spaces  ", "🌱 unicode"], fn(s) {
    assert pass_string(s) == Ok(s)
  })

  let pass_int = dataprep.predicate(fn(_: Int) { True }, E1)
  list.each([0, 1, -1, 9999, -9999], fn(n) {
    assert pass_int(n) == Ok(n)
  })
}

// Law: `both` accumulates errors from both sides in left-to-right order.
//   For all v1, v2 with v1(x)=Error(e1) and v2(x)=Error(e2):
//   both(v1, v2)(x) = Error(e1 ++ e2).
pub fn law_both_accumulates_in_order_test() -> Nil {
  let cases = [#(E1, E2), #(E2, E1), #(E3, E4), #(Tag(7), Tag(11))]
  list.each(cases, fn(pair) {
    let #(e1, e2) = pair
    let v1 = dataprep.predicate(fn(_: Int) { False }, e1)
    let v2 = dataprep.predicate(fn(_: Int) { False }, e2)
    assert dataprep.both(first: v1, second: v2)(0)
      == Error(non_empty_list.new(e1, [e2]))
  })
}

// Law: `both` is associative for accumulated errors.
//   both(both(v1, v2), v3)(x) and both(v1, both(v2, v3))(x) produce
//   the same error list when all three branches fail.
pub fn law_both_associative_test() -> Nil {
  let v1 = dataprep.predicate(fn(_: Int) { False }, E1)
  let v2 = dataprep.predicate(fn(_: Int) { False }, E2)
  let v3 = dataprep.predicate(fn(_: Int) { False }, E3)

  let left_grouped =
    dataprep.both(first: dataprep.both(first: v1, second: v2), second: v3)
  let right_grouped =
    dataprep.both(first: v1, second: dataprep.both(first: v2, second: v3))

  let expected = Error(non_empty_list.new(E1, [E2, E3]))
  assert left_grouped(0) == expected
  assert right_grouped(0) == expected
}

// Law: `all([])` is the identity element of accumulation.
//   For every input x: all([])(x) = Ok(x).
pub fn law_all_empty_is_identity_test() -> Nil {
  assert dataprep.all([])(42) == Ok(42)
  assert dataprep.all([])("x") == Ok("x")
  assert dataprep.all([])(option.None) == Ok(option.None)
}

// Law: `all` accumulates failures from every failing branch, in order.
//   Passing branches contribute no error.
pub fn law_all_accumulates_in_order_test() -> Nil {
  let v_fail_1 = dataprep.predicate(fn(_: Int) { False }, E1)
  let v_pass = dataprep.predicate(fn(_: Int) { True }, E2)
  let v_fail_3 = dataprep.predicate(fn(_: Int) { False }, E3)
  let v_fail_4 = dataprep.predicate(fn(_: Int) { False }, E4)

  assert dataprep.all([v_fail_1, v_pass, v_fail_3, v_fail_4])(0)
    == Error(non_empty_list.new(E1, [E3, E4]))
}

// Law: `alt` short-circuits on the first success.
//   If v1(x) = Ok(_), v2 is never evaluated.
pub fn law_alt_short_circuits_on_success_test() -> Nil {
  let pass = dataprep.predicate(fn(_: Int) { True }, E1)
  list.each([0, 1, -1, 99], fn(n) {
    let combined =
      pass
      |> dataprep.alt(first: _, second: fn(_) {
        // nolint: avoid_panic -- verifies alt short-circuits after success
        panic as "alt must not evaluate second branch when first succeeds"
      })
    assert combined(n) == Ok(n)
  })
}

// Law: `alt` accumulates errors from both branches when both fail,
// preserving left-to-right order.
pub fn law_alt_accumulates_on_full_failure_test() -> Nil {
  let v1 = dataprep.predicate(fn(_: Int) { False }, E1)
  let v2 = dataprep.predicate(fn(_: Int) { False }, E2)
  assert dataprep.alt(first: v1, second: v2)(0)
    == Error(non_empty_list.new(E1, [E2]))
}

// Law: `alt` recovers when only the first branch fails.
//   v1(x) = Error(_), v2(x) = Ok(y) -> alt(v1, v2)(x) = Ok(y).
pub fn law_alt_recovers_on_second_success_test() -> Nil {
  let v1 = dataprep.predicate(fn(_: Int) { False }, E1)
  let v2 = dataprep.predicate(fn(_: Int) { True }, E2)
  list.each([0, 1, -1, 99], fn(n) {
    assert dataprep.alt(first: v1, second: v2)(n) == Ok(n)
  })
}

// Law: `and_then` short-circuits when the prerequisite fails.
//   pre(x) = Error(e) -> main is never called, result = Error(e).
pub fn law_and_then_short_circuits_on_pre_failure_test() -> Nil {
  let failing_pre = dataprep.predicate(fn(_: Int) { False }, E1)
  let combined =
    failing_pre
    |> dataprep.and_then(first: _, then: fn(_) {
      // nolint: avoid_panic -- verifies and_then short-circuits on pre failure
      panic as "and_then must not evaluate main when pre fails"
    })
  assert combined(0) == Error(non_empty_list.single(E1))
}

// Law: `and_then` does NOT accumulate errors across pre and main.
//   When pre fails, only pre's errors surface, even if main would also
//   fail on the same input. This is what distinguishes and_then from
//   both / all.
pub fn law_and_then_does_not_accumulate_test() -> Nil {
  let pre = dataprep.predicate(fn(_: Int) { False }, E1)
  let main = dataprep.predicate(fn(_: Int) { False }, E2)
  // E2 must NOT appear: main is never called.
  assert dataprep.and_then(first: pre, then: main)(0)
    == Error(non_empty_list.single(E1))
}

// Law: `and_then` runs main when pre succeeds and forwards main's verdict.
pub fn law_and_then_runs_main_on_pre_success_test() -> Nil {
  let pre = dataprep.predicate(fn(_: Int) { True }, E1)

  let main_pass = dataprep.predicate(fn(_: Int) { True }, E2)
  assert dataprep.and_then(first: pre, then: main_pass)(7) == Ok(7)

  let main_fail = dataprep.predicate(fn(_: Int) { False }, E2)
  assert dataprep.and_then(first: pre, then: main_fail)(7)
    == Error(non_empty_list.single(E2))
}

// Law: `optional` short-circuits on None.
//   The inner validator is never called for None.
pub fn law_optional_preserves_none_test() -> Nil {
  let combined =
    dataprep.optional(fn(_: Int) {
      // nolint: avoid_panic -- verifies optional short-circuits for None
      panic as "optional must not call inner validator for None"
    })
  assert combined(option.None) == Ok(option.None)
}

// Law: `optional` runs the inner validator on Some, wrapping the
// successful value back as Some.
pub fn law_optional_runs_on_some_test() -> Nil {
  let pass = dataprep.predicate(fn(_: Int) { True }, E1)
  list.each([0, 1, -1, 99], fn(n) {
    assert dataprep.optional(pass)(option.Some(n)) == Ok(option.Some(n))
  })

  let fail = dataprep.predicate(fn(_: Int) { False }, E1)
  assert dataprep.optional(fail)(option.Some(42))
    == Error(non_empty_list.single(E1))
}

// Law: `each` accumulates errors from every failing element, in input
// order. An empty list is always Valid.
pub fn law_each_accumulates_per_element_test() -> Nil {
  let positive =
    dataprep.check(fn(n: Int) {
      case n > 0 {
        True -> Ok(Nil)
        False -> Error(Tag(n))
      }
    })

  // mixed pass/fail keeps only the failing tags, in order
  assert dataprep.each(positive)([1, -1, 2, -2, 3])
    == Error(non_empty_list.new(Tag(-1), [Tag(-2)]))
  // all pass
  assert dataprep.each(positive)([1, 2, 3]) == Ok([1, 2, 3])
  // empty list
  assert dataprep.each(positive)([]) == Ok([])
}

// Law: `each` composes with the other combinators over the same parent
// list (Issue #21). all([list_level_check, each(item_check)]) is the
// canonical "validate the list AND each element" pattern, and accumulates
// failures from both layers.
pub fn law_each_composes_with_all_test() -> Nil {
  let no_negatives =
    dataprep.predicate(fn(xs: List(Int)) { list.all(xs, fn(x) { x >= 0 }) }, E1)
  let positive = dataprep.predicate(fn(n: Int) { n > 0 }, E2)
  let combined = dataprep.all([no_negatives, dataprep.each(positive)])

  // [-1, 1]: list-level no_negatives fails (E1) AND each on -1 fails (E2)
  assert combined([-1, 1]) == Error(non_empty_list.new(E1, [E2]))
  // [0, 1]: list-level passes, each on 0 fails
  assert combined([0, 1]) == Error(non_empty_list.new(E2, []))
  // [1, 2, 3]: both layers pass
  assert combined([1, 2, 3]) == Ok([1, 2, 3])
}

// ---------------------------------------------------------------------------
// Result combining laws (mapN and collect)
// ---------------------------------------------------------------------------

// Law: `map2` accumulates errors from both branches in left-to-right
// order, and acts as a pure combiner when both branches succeed.
pub fn law_map2_accumulates_test() -> Nil {
  let combine = fn(a: Int, b: Int) { a + b }

  // both valid
  let valid_a: Result(Int, NonEmptyList(LawErr)) = Ok(1)
  let valid_b: Result(Int, NonEmptyList(LawErr)) = Ok(2)
  assert dataprep.map2(valid_a, valid_b, with: combine) == Ok(3)

  // left invalid, right valid -> only left's errors
  let e1 = non_empty_list.new(E1, [])
  assert dataprep.map2(Error(e1), valid_b, with: combine) == Error(e1)

  // left valid, right invalid -> only right's errors
  let e2 = non_empty_list.new(E2, [])
  assert dataprep.map2(valid_a, Error(e2), with: combine) == Error(e2)

  // both invalid -> left first, then right
  assert dataprep.map2(Error(e1), Error(e2), with: combine)
    == Error(non_empty_list.new(E1, [E2]))
}

// Law: `map3` preserves left-to-right error order across all three
// failing branches.
pub fn law_map3_preserves_error_order_test() -> Nil {
  let combine = fn(a: Int, b: Int, c: Int) { #(a, b, c) }
  let e1: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E1, []))
  let e2: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E2, []))
  let e3: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E3, []))
  assert dataprep.map3(e1, e2, e3, with: combine)
    == Error(non_empty_list.new(E1, [E2, E3]))
}

// Law: `map4` preserves left-to-right error order across four failing
// branches.
pub fn law_map4_preserves_error_order_test() -> Nil {
  let combine = fn(a: Int, b: Int, c: Int, d: Int) { #(a, b, c, d) }
  let e1: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E1, []))
  let e2: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E2, []))
  let e3: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E3, []))
  let e4: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E4, []))
  assert dataprep.map4(e1, e2, e3, e4, with: combine)
    == Error(non_empty_list.new(E1, [E2, E3, E4]))
}

// Law: `map5` preserves left-to-right error order with mid-stream Valid
// branches contributing no error.
pub fn law_map5_preserves_error_order_test() -> Nil {
  let combine = fn(a: Int, b: Int, c: Int, d: Int, e: Int) { #(a, b, c, d, e) }
  let v1: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E1, []))
  let v2: Result(Int, NonEmptyList(LawErr)) = Ok(0)
  let v3: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E3, []))
  let v4: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E4, []))
  let v5: Result(Int, NonEmptyList(LawErr)) =
    Error(non_empty_list.new(Tag(5), []))
  assert dataprep.map5(v1, v2, v3, v4, v5, with: combine)
    == Error(non_empty_list.new(E1, [E3, E4, Tag(5)]))
}

// Law: `collect` accumulates every per-element error in order.
pub fn law_sequence_accumulates_in_order_test() -> Nil {
  let v1: Result(Int, NonEmptyList(LawErr)) = Ok(1)
  let v2: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E1, []))
  let v3: Result(Int, NonEmptyList(LawErr)) = Ok(3)
  let v4: Result(Int, NonEmptyList(LawErr)) = Error(non_empty_list.new(E2, []))

  assert dataprep.collect([v1, v2, v3, v4])
    == Error(non_empty_list.new(E1, [E2]))
  assert dataprep.collect([v1, v3]) == Ok([1, 3])
  // empty input is Ok([])
  let empty: List(Result(Int, NonEmptyList(LawErr))) = []
  assert dataprep.collect(empty) == Ok([])
}

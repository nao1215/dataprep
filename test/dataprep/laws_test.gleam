// Behavioral laws for `validator` and `validated`.
//
// These tests are written as data-driven law assertions: each test names
// a documented invariant (accumulation vs short-circuit, error order,
// functor identity, etc.) and exercises it across multiple representative
// inputs. They are deliberately phrased so that a regression in
// short-circuit vs accumulation semantics fails on the law itself, not
// on a single arithmetic edge case.
//
// See `doc/laws.md` for the prose description of every law
// asserted here.

import dataprep/helpers/nel
import dataprep/non_empty_list
import dataprep/validated.{type Validated, Invalid, Valid}
import dataprep/validator
import gleam/list
import gleam/option

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
//   For all v and x: if v(x) returns Valid(y), then x == y.
pub fn law_validator_preserves_input_on_success_test() -> Nil {
  let pass_string = validator.predicate(fn(_: String) { True }, E1)
  list.each(["", "hello", "  spaces  ", "🌱 unicode"], fn(s) {
    assert pass_string(s) == Valid(s)
  })

  let pass_int = validator.predicate(fn(_: Int) { True }, E1)
  list.each([0, 1, -1, 9999, -9999], fn(n) {
    assert pass_int(n) == Valid(n)
  })
}

// Law: `both` accumulates errors from both sides in left-to-right order.
//   For all v1, v2 with v1(x)=Invalid(e1) and v2(x)=Invalid(e2):
//   both(v1, v2)(x) = Invalid(e1 ++ e2).
pub fn law_both_accumulates_in_order_test() -> Nil {
  let cases = [#(E1, E2), #(E2, E1), #(E3, E4), #(Tag(7), Tag(11))]
  list.each(cases, fn(pair) {
    let #(e1, e2) = pair
    let v1 = validator.predicate(fn(_: Int) { False }, e1)
    let v2 = validator.predicate(fn(_: Int) { False }, e2)
    assert validator.both(first: v1, second: v2)(0)
      == Invalid(nel.make(first: e1, rest: [e2]))
  })
}

// Law: `both` is associative for accumulated errors.
//   both(both(v1, v2), v3)(x) and both(v1, both(v2, v3))(x) produce
//   the same error list when all three branches fail.
pub fn law_both_associative_test() -> Nil {
  let v1 = validator.predicate(fn(_: Int) { False }, E1)
  let v2 = validator.predicate(fn(_: Int) { False }, E2)
  let v3 = validator.predicate(fn(_: Int) { False }, E3)

  let left_grouped =
    validator.both(first: validator.both(first: v1, second: v2), second: v3)
  let right_grouped =
    validator.both(first: v1, second: validator.both(first: v2, second: v3))

  let expected = Invalid(nel.make(first: E1, rest: [E2, E3]))
  assert left_grouped(0) == expected
  assert right_grouped(0) == expected
}

// Law: `all([])` is the identity element of accumulation.
//   For every input x: all([])(x) = Valid(x).
pub fn law_all_empty_is_identity_test() -> Nil {
  assert validator.all([])(42) == Valid(42)
  assert validator.all([])("x") == Valid("x")
  assert validator.all([])(option.None) == Valid(option.None)
}

// Law: `all` accumulates failures from every failing branch, in order.
//   Passing branches contribute no error.
pub fn law_all_accumulates_in_order_test() -> Nil {
  let v_fail_1 = validator.predicate(fn(_: Int) { False }, E1)
  let v_pass = validator.predicate(fn(_: Int) { True }, E2)
  let v_fail_3 = validator.predicate(fn(_: Int) { False }, E3)
  let v_fail_4 = validator.predicate(fn(_: Int) { False }, E4)

  assert validator.all([v_fail_1, v_pass, v_fail_3, v_fail_4])(0)
    == Invalid(nel.make(first: E1, rest: [E3, E4]))
}

// Law: `alt` short-circuits on the first success.
//   If v1(x) = Valid(_), v2 is never evaluated.
pub fn law_alt_short_circuits_on_success_test() -> Nil {
  let pass = validator.predicate(fn(_: Int) { True }, E1)
  list.each([0, 1, -1, 99], fn(n) {
    let combined =
      pass
      |> validator.alt(first: _, second: fn(_) {
        // nolint: avoid_panic -- verifies alt short-circuits after success
        panic as "alt must not evaluate second branch when first succeeds"
      })
    assert combined(n) == Valid(n)
  })
}

// Law: `alt` accumulates errors from both branches when both fail,
// preserving left-to-right order.
pub fn law_alt_accumulates_on_full_failure_test() -> Nil {
  let v1 = validator.predicate(fn(_: Int) { False }, E1)
  let v2 = validator.predicate(fn(_: Int) { False }, E2)
  assert validator.alt(first: v1, second: v2)(0)
    == Invalid(nel.make(first: E1, rest: [E2]))
}

// Law: `alt` recovers when only the first branch fails.
//   v1(x) = Invalid(_), v2(x) = Valid(y) -> alt(v1, v2)(x) = Valid(y).
pub fn law_alt_recovers_on_second_success_test() -> Nil {
  let v1 = validator.predicate(fn(_: Int) { False }, E1)
  let v2 = validator.predicate(fn(_: Int) { True }, E2)
  list.each([0, 1, -1, 99], fn(n) {
    assert validator.alt(first: v1, second: v2)(n) == Valid(n)
  })
}

// Law: `guard` short-circuits when the prerequisite fails.
//   pre(x) = Invalid(e) -> main is never called, result = Invalid(e).
pub fn law_guard_short_circuits_on_pre_failure_test() -> Nil {
  let failing_pre = validator.predicate(fn(_: Int) { False }, E1)
  let combined =
    failing_pre
    |> validator.guard(pre: _, main: fn(_) {
      // nolint: avoid_panic -- verifies guard short-circuits on pre failure
      panic as "guard must not evaluate main when pre fails"
    })
  assert combined(0) == Invalid(non_empty_list.single(E1))
}

// Law: `guard` does NOT accumulate errors across pre and main.
//   When pre fails, only pre's errors surface, even if main would also
//   fail on the same input. This is what distinguishes guard from
//   both / all.
pub fn law_guard_does_not_accumulate_test() -> Nil {
  let pre = validator.predicate(fn(_: Int) { False }, E1)
  let main = validator.predicate(fn(_: Int) { False }, E2)
  // E2 must NOT appear: main is never called.
  assert validator.guard(pre: pre, main: main)(0)
    == Invalid(non_empty_list.single(E1))
}

// Law: `guard` runs main when pre succeeds and forwards main's verdict.
pub fn law_guard_runs_main_on_pre_success_test() -> Nil {
  let pre = validator.predicate(fn(_: Int) { True }, E1)

  let main_pass = validator.predicate(fn(_: Int) { True }, E2)
  assert validator.guard(pre: pre, main: main_pass)(7) == Valid(7)

  let main_fail = validator.predicate(fn(_: Int) { False }, E2)
  assert validator.guard(pre: pre, main: main_fail)(7)
    == Invalid(non_empty_list.single(E2))
}

// Law: `optional` short-circuits on None.
//   The inner validator is never called for None.
pub fn law_optional_preserves_none_test() -> Nil {
  let combined =
    validator.optional(fn(_: Int) {
      // nolint: avoid_panic -- verifies optional short-circuits for None
      panic as "optional must not call inner validator for None"
    })
  assert combined(option.None) == Valid(option.None)
}

// Law: `optional` runs the inner validator on Some, wrapping the
// successful value back as Some.
pub fn law_optional_runs_on_some_test() -> Nil {
  let pass = validator.predicate(fn(_: Int) { True }, E1)
  list.each([0, 1, -1, 99], fn(n) {
    assert validator.optional(pass)(option.Some(n)) == Valid(option.Some(n))
  })

  let fail = validator.predicate(fn(_: Int) { False }, E1)
  assert validator.optional(fail)(option.Some(42))
    == Invalid(non_empty_list.single(E1))
}

// Law: `each` accumulates errors from every failing element, in input
// order. An empty list is always Valid.
pub fn law_each_accumulates_per_element_test() -> Nil {
  let positive =
    validator.check(fn(n: Int) {
      case n > 0 {
        True -> Ok(Nil)
        False -> Error(Tag(n))
      }
    })

  // mixed pass/fail keeps only the failing tags, in order
  assert validator.each(positive)([1, -1, 2, -2, 3])
    == Invalid(nel.make(first: Tag(-1), rest: [Tag(-2)]))
  // all pass
  assert validator.each(positive)([1, 2, 3]) == Valid([1, 2, 3])
  // empty list
  assert validator.each(positive)([]) == Valid([])
}

// Law: `each` composes with the other combinators over the same parent
// list (Issue #21). all([list_level_check, each(item_check)]) is the
// canonical "validate the list AND each element" pattern, and accumulates
// failures from both layers.
pub fn law_each_composes_with_all_test() -> Nil {
  let no_negatives =
    validator.predicate(
      fn(xs: List(Int)) { list.all(xs, fn(x) { x >= 0 }) },
      E1,
    )
  let positive = validator.predicate(fn(n: Int) { n > 0 }, E2)
  let combined = validator.all([no_negatives, validator.each(positive)])

  // [-1, 1]: list-level no_negatives fails (E1) AND each on -1 fails (E2)
  assert combined([-1, 1]) == Invalid(nel.make(first: E1, rest: [E2]))
  // [0, 1]: list-level passes, each on 0 fails
  assert combined([0, 1]) == Invalid(nel.make(first: E2, rest: []))
  // [1, 2, 3]: both layers pass
  assert combined([1, 2, 3]) == Valid([1, 2, 3])
}

// ---------------------------------------------------------------------------
// Validated laws (functor / monad-style and_then / applicative mapN)
// ---------------------------------------------------------------------------

// Functor identity law for `map`.
//   map(v, fn(x) { x }) == v
pub fn law_validated_map_identity_test() -> Nil {
  let id = fn(x: Int) { x }
  list.each([0, 1, -1, 99], fn(n) {
    assert validated.map(Valid(n), id) == Valid(n)
  })

  let errs = nel.make(first: E1, rest: [E2])
  let invalid: Validated(Int, LawErr) = Invalid(errs)
  assert validated.map(invalid, id) == invalid
}

// Functor composition law for `map`.
//   map(v, compose(outer, inner)) == map(map(v, inner), outer)
pub fn law_validated_map_composition_test() -> Nil {
  let outer = fn(n: Int) { n + 1 }
  let inner = fn(n: Int) { n * 2 }
  let composed = fn(n: Int) { outer(inner(n)) }

  list.each([0, 1, -1, 5, 99], fn(n) {
    let valid_n: Validated(Int, LawErr) = Valid(n)
    assert validated.map(valid_n, composed)
      == validated.map(validated.map(valid_n, inner), outer)
  })

  let errs = nel.make(first: E1, rest: [])
  let invalid: Validated(Int, LawErr) = Invalid(errs)
  assert validated.map(invalid, composed)
    == validated.map(validated.map(invalid, inner), outer)
}

// Law: `and_then` is short-circuit (monadic), NOT applicative.
//   and_then(Invalid(e), f) = Invalid(e); f is never called.
pub fn law_and_then_short_circuits_on_invalid_test() -> Nil {
  let errs = nel.make(first: E1, rest: [E2])
  let invalid: Validated(Int, LawErr) = Invalid(errs)
  let result =
    validated.and_then(invalid, fn(_) {
      // nolint: avoid_panic -- verifies and_then short-circuits on Invalid
      panic as "and_then must not call f on Invalid"
    })
  assert result == invalid
}

// Monadic left identity law for `and_then`.
//   and_then(Valid(a), continue) == continue(a)
pub fn law_and_then_left_identity_test() -> Nil {
  let continue = fn(n: Int) -> Validated(Int, LawErr) { Valid(n + 1) }
  list.each([0, 1, -1, 99], fn(n) {
    assert validated.and_then(Valid(n), continue) == continue(n)
  })
}

// Monadic right identity law for `and_then`.
//   and_then(Valid(a), Valid) == Valid(a)
pub fn law_and_then_right_identity_test() -> Nil {
  let pure = fn(n: Int) -> Validated(Int, LawErr) { Valid(n) }
  list.each([0, 1, -1, 99], fn(n) {
    assert validated.and_then(Valid(n), pure) == Valid(n)
  })
}

// Law: `map2` accumulates errors from both branches in left-to-right
// order, and acts as a pure combiner when both branches succeed.
pub fn law_map2_accumulates_test() -> Nil {
  let combine = fn(a: Int, b: Int) { a + b }

  // both valid
  let valid_a: Validated(Int, LawErr) = Valid(1)
  let valid_b: Validated(Int, LawErr) = Valid(2)
  assert validated.map2(combine, valid_a, valid_b) == Valid(3)

  // left invalid, right valid -> only left's errors
  let e1 = nel.make(first: E1, rest: [])
  assert validated.map2(combine, Invalid(e1), valid_b) == Invalid(e1)

  // left valid, right invalid -> only right's errors
  let e2 = nel.make(first: E2, rest: [])
  assert validated.map2(combine, valid_a, Invalid(e2)) == Invalid(e2)

  // both invalid -> left first, then right
  assert validated.map2(combine, Invalid(e1), Invalid(e2))
    == Invalid(nel.make(first: E1, rest: [E2]))
}

// Law: `map3` preserves left-to-right error order across all three
// failing branches.
pub fn law_map3_preserves_error_order_test() -> Nil {
  let combine = fn(a: Int, b: Int, c: Int) { #(a, b, c) }
  let e1: Validated(Int, LawErr) = Invalid(nel.make(first: E1, rest: []))
  let e2: Validated(Int, LawErr) = Invalid(nel.make(first: E2, rest: []))
  let e3: Validated(Int, LawErr) = Invalid(nel.make(first: E3, rest: []))
  assert validated.map3(combine, e1, e2, e3)
    == Invalid(nel.make(first: E1, rest: [E2, E3]))
}

// Law: `map4` preserves left-to-right error order across four failing
// branches.
pub fn law_map4_preserves_error_order_test() -> Nil {
  let combine = fn(a: Int, b: Int, c: Int, d: Int) { #(a, b, c, d) }
  let e1: Validated(Int, LawErr) = Invalid(nel.make(first: E1, rest: []))
  let e2: Validated(Int, LawErr) = Invalid(nel.make(first: E2, rest: []))
  let e3: Validated(Int, LawErr) = Invalid(nel.make(first: E3, rest: []))
  let e4: Validated(Int, LawErr) = Invalid(nel.make(first: E4, rest: []))
  assert validated.map4(combine, e1, e2, e3, e4)
    == Invalid(nel.make(first: E1, rest: [E2, E3, E4]))
}

// Law: `map5` preserves left-to-right error order with mid-stream Valid
// branches contributing no error.
pub fn law_map5_preserves_error_order_test() -> Nil {
  let combine = fn(a: Int, b: Int, c: Int, d: Int, e: Int) { #(a, b, c, d, e) }
  let v1: Validated(Int, LawErr) = Invalid(nel.make(first: E1, rest: []))
  let v2: Validated(Int, LawErr) = Valid(0)
  let v3: Validated(Int, LawErr) = Invalid(nel.make(first: E3, rest: []))
  let v4: Validated(Int, LawErr) = Invalid(nel.make(first: E4, rest: []))
  let v5: Validated(Int, LawErr) = Invalid(nel.make(first: Tag(5), rest: []))
  assert validated.map5(combine, v1, v2, v3, v4, v5)
    == Invalid(nel.make(first: E1, rest: [E3, E4, Tag(5)]))
}

// Law: `sequence` is the special case of `traverse` with the identity
// function, and accumulates every per-element error in order.
pub fn law_sequence_accumulates_in_order_test() -> Nil {
  let v1: Validated(Int, LawErr) = Valid(1)
  let v2: Validated(Int, LawErr) = Invalid(nel.make(first: E1, rest: []))
  let v3: Validated(Int, LawErr) = Valid(3)
  let v4: Validated(Int, LawErr) = Invalid(nel.make(first: E2, rest: []))

  assert validated.sequence([v1, v2, v3, v4])
    == Invalid(nel.make(first: E1, rest: [E2]))
  assert validated.sequence([v1, v3]) == Valid([1, 3])
  // empty input is Valid([])
  let empty: List(Validated(Int, LawErr)) = []
  assert validated.sequence(empty) == Valid([])
}

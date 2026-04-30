# Behavioral laws of `validator` and `validated`

This document is the prose counterpart to `test/dataprep/laws_test.gleam`.
Each law below is asserted by a test of the same name (`law_*_test`) so a
regression in accumulation vs short-circuit semantics fails on the law
itself, not on a single arithmetic edge case.

The tests are deliberately written without a property-based testing
dependency: they exercise each law over a small, hand-picked set of
representative inputs (zero, positive, negative, empty, mixed). This
keeps the test lane fast on both the Erlang and JavaScript targets and
matches the rest of the test suite's style.

## Why these laws matter

`dataprep` is a composable validation toolkit. Three behaviors must hold
across every release for downstream code to remain correct:

1. **Input preservation on success** — a `Validator` must never mutate
   its input. This is what lets users compose validators without
   threading values manually.
2. **Accumulation vs short-circuit must stay distinct.** Combinators are
   chosen on this basis: users reach for `both` / `all` / `each` / `mapN`
   when they want every error reported at once, and for `guard` / `alt` /
   `and_then` when they want the first failure to stop further work.
   Silently flipping any of these would corrupt every error report
   downstream.
3. **Error order is left-to-right.** Form UIs and API responses depend on
   this for stable rendering. The `mapN` family, `both`, `all`,
   `sequence`, and `traverse` all preserve input-order errors.

## Validator combinator laws

### Input preservation

If `v(x)` returns `Valid(y)`, then `x == y`. The combinators (`both`,
`all`, `alt`, `guard`, `optional`, `each`) all return the original input
on success rather than the inner result, because the inner result must
itself satisfy this law.

### `both` accumulates

For any `v1`, `v2` and any input `x`:

- if both fail, `both(v1, v2)(x) = Invalid(e1 ++ e2)` (left-to-right);
- if exactly one fails, `both(v1, v2)(x)` is the failing branch's `Invalid`;
- if both succeed, `both(v1, v2)(x) = Valid(x)`.

### `both` is associative for accumulation

`both(both(v1, v2), v3)(x)` and `both(v1, both(v2, v3))(x)` produce the
same accumulated error list when all three branches fail. This is what
allows the chained pipeline form (`v1 |> both(_, v2) |> both(_, v3)`) to
behave equivalently to `all([v1, v2, v3])`.

### `all([])` is the accumulation identity

For every input `x`: `all([])(x) = Valid(x)`. An empty validator list
contributes no constraints.

### `all` accumulates in order, ignoring passing branches

Failures from every failing branch are appended in input order; passing
branches contribute no error.

### `alt` short-circuits on success

If `v1(x) = Valid(_)`, `v2` is **never evaluated**. The test enforces this
with a `panic` sentinel as the second branch.

### `alt` accumulates only on full failure

If both `v1(x)` and `v2(x)` are `Invalid`, the result is
`Invalid(e1 ++ e2)`. If the first fails and the second succeeds, the
result is the second's `Valid`.

### `guard` short-circuits on prerequisite failure

If `pre(x) = Invalid(e)`, `main` is **never evaluated**. The result is
`Invalid(e)`. The test enforces this with a `panic` sentinel as `main`.

### `guard` does NOT accumulate

Even when `main(x)` would also fail, `guard(pre, main)(x)` only carries
`pre`'s errors when `pre` fails. This is what distinguishes `guard` from
`both` / `all` and is the reason to reach for `guard` when later checks
depend on earlier ones (e.g. "non-empty before regex match").

### `guard` runs main on prerequisite success

If `pre(x) = Valid(_)`, `guard(pre, main)(x) = main(x)` exactly.

### `optional` short-circuits on `None`

For any inner validator `v`: `optional(v)(None) = Valid(None)`. The inner
`v` is **never evaluated** for `None`. The test enforces this with a
`panic` sentinel as `v`.

### `optional` runs the inner validator on `Some`

For `Some(a)`: `optional(v)(Some(a))` equals the inner `v(a)` re-wrapped
in `Some` on success, or the inner `Invalid` propagated unchanged.

### `each` accumulates per-element errors in input order

For a list `xs` and validator `v`, `each(v)(xs)` accumulates an error for
every failing element, in the order the elements appear. An empty list
is always `Valid([])`.

### `each` composes with the other combinators (Issue #21)

`all([list_level_check, each(item_check)])` is the canonical "validate
the list AND each element" pattern. Because `each` returns a
`Validator(List(a), e)`, accumulation works across both the list-level
check and the per-element check in the same `all`.

## `Validated` laws

### Functor identity (`map`)

`map(v, fn(x) { x }) == v` for every `Validated` value `v`.

### Functor composition (`map`)

`map(v, compose(f, g)) == map(map(v, g), f)` for every `Validated` value
`v` and every pair of functions `f`, `g`.

### `and_then` is short-circuit (NOT applicative)

For every error value `e` and continuation `f`:
`and_then(Invalid(e), f) = Invalid(e)`, with `f` **never called**. This
is intentional — `and_then` is the sequential, monadic-style combinator
to use for "parse, then validate the parsed value". It does not
accumulate errors. Use `mapN` / `both` / `all` when accumulation is
desired.

### `and_then` left identity

`and_then(Valid(a), f) == f(a)` for every `a` and `f`.

### `and_then` right identity

`and_then(Valid(a), Valid) == Valid(a)` for every `a`. (Right identity is
asserted only on `Valid`; on `Invalid` the right identity holds trivially
by short-circuit.)

### `mapN` accumulates errors in left-to-right order

For every `mapN` (n in 2..5) and every assignment of `Valid` /
`Invalid` to its branches, the resulting `Invalid` (if any) carries
errors in input order, with passing branches contributing nothing. This
is what makes `mapN` the right tool for form-style validation, where the
field order in the error list mirrors the field order in the form.

### `sequence` accumulates per-element in input order

For a list of `Validated` values, `sequence` returns `Valid` only when
every element is `Valid`, and otherwise returns `Invalid` carrying every
per-element error in input order. The empty list is always `Valid([])`.
`traverse` is the special case of `sequence` precomposed with a function.

## Target matrix

These laws are part of the standard test suite (`gleam test` /
`just ci`) and therefore run on both the Erlang and JavaScript CI
targets. They use only `gleam_stdlib` types (`List`, `Option`, tuples)
and the project's own `non_empty_list`, so no target-specific behavior
is exercised.

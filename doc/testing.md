# Testing

`gleam test` runs everything below except the nightly job. CI runs it on the Erlang and JavaScript targets, on the Gleam floor and on the latest Gleam 1.x.

## Examples and unit tests

`test/dataprep/*_test.gleam` checks the functions of `dataprep` with fixed inputs and expected outputs, including the edge cases of `parse_float` (overflowing exponents, negative zero, the strict grammar), the whitespace sets of `collapse_space` and `collapse_unicode_space`, and the anchoring of `full_match`. `cookbook_test.gleam` builds small parsers from `dataprep` and the standard library, `integration_pipeline_test.gleam` validates a whole form, and `readme_test.gleam` runs the README examples.

## Laws

`test/dataprep/laws_test.gleam` asserts the combinator laws over several representative inputs: accumulation in `both`, `all` and `mapN`, short-circuit in `and_then`, and error order. A change that swaps accumulation for short-circuit fails on the law, not on one example.

## Generated properties

`test/dataprep_metamon_test.gleam` uses metamon for generated properties, such as `each` agreeing with `collect` over `list.map`, and `collapse_space` being idempotent.

## Nightly runs

`.github/workflows/nightly-property.yml` runs the whole suite ten times with `METAMON_RUNS_MULTIPLIER=10`, each pass with a new seed. A failure report prints its seed, so the case can be replayed and kept as a regression test.

## Coverage

`just coverage` (`gleam build --target erlang`, then `gleam run -m metamon/mutation -- coverage`) runs the tests on the Erlang target with every module under `src/` measured and writes `build/coverage/lcov.info`; `.github/workflows/coverage.yml` reports it with octocov on pull requests and main. The local run on 2026-11-28 reached 88.5% of the lines.

## Mutation testing

`gleam run -m metamon/mutation` changes one operator, `!` or boolean literal in `src/dataprep.gleam` at a time and runs `gleam test --target erlang` on each change. `.github/workflows/mutation.yml` mutates the module on every pull request that changes it and fails on a survivor that `doc/mutation/baseline.json` does not list; the weekly run does the same.

The first run (2026-11-27) scored 61.2%. Tests were then added for `(*ACCEPT)` inside a group, a lookahead, `(*pla:` and `(*atomic:`, and for a start verb with a 9 in its value, and the score rose to 79.1%. The 14 survivors left change nothing on Erlang: the grammar check of `parse_float` (8), whose rejects `float.parse` and the integer path reject again; the `\Q` and recursion flags of `full_match` at their start values (2), which only add `\E` or an unused copy that PCRE ignores; the group-or-verb test of `(*name:` (2), because a verb keeps its own `)`; the upper bound `Z` of start verb names (1), since no start verb has a `Z`; and the error offset of a wrapped pattern that cannot fail when the pattern compiles on its own (1). Several of them change the result on JavaScript, which the tests check on that target.

<!-- mutation:start -->
| Module | Killed | Lived | Timed out | Score |
|---|---:|---:|---:|---:|
| `dataprep` | 53 | 14 | 0 | 79.1% |
| all | 53 | 14 | 0 | 79.1% |
<!-- mutation:end -->

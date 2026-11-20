# Testing

`gleam test` runs everything below except the nightly job. CI runs it on the Erlang and JavaScript targets, on the Gleam floor and on the latest Gleam 1.x.

## Examples and unit tests

`test/dataprep/<module>_test.gleam` checks each module with fixed inputs and expected outputs, including the documented edge cases of `parse` (overflowing exponents and integer literals, signs, strict grammar). `cookbook_test.gleam` runs the recipes of `doc/recipes/custom_parsers.md`, and `integration_pipeline_test.gleam` runs the Prep then Validator pipeline of `doc/architecture.md`.

## Laws

`test/dataprep/laws_test.gleam` asserts every law in `doc/laws.md` over several representative inputs: accumulation in `both`, `all` and `mapN`, short-circuit in `and_then`, error order, and the functor laws of `Validated`. A change that swaps accumulation for short-circuit fails on the law, not on one example.

## Generated properties

`test/dataprep_metamon_test.gleam` uses metamon: Prep identity, associativity and idempotence (`trim`, `lowercase`, `uppercase`), NonEmptyList length, reverse and append, and `Validated` round trips through `Result`, `sequence` and `traverse`.

## Nightly runs

`.github/workflows/nightly-property.yml` runs the whole suite ten times with `METAMON_RUNS_MULTIPLIER=10`, each pass with a new seed. A failure report prints its seed, so the case can be replayed with `metamon.with_seed` and kept as a regression test.

## Mutation testing

There is no mutation testing tool for Gleam, so `gleam_mutate.py` (from the mutation-testing lab in nao1215/debimate) is run by hand on a copy of the project. It rewrites one operator or boolean result at a time (`==`/`!=`, `&&`/`||`, float comparisons, `-> True`/`-> False`, a dropped `!`) and runs `gleam test` on the Erlang target. The score is killed / (killed + lived).

| Date | Files | Killed | Lived | Score |
|---|---|---:|---:|---:|
| 2026-11-19 | every module under `src/` | 16 | 2 | 88.9% |

The first run scored 15/18. Treating every character as a digit in the plain-integer overflow guard went unnoticed, because no test passed a long literal that is not an integer; `float_accepts_long_decimal_literal_test` now does. The 2 survivors are in the same guards: on Erlang, the `int.parse` fallback already rejects a 309-digit integer, so turning the digit check off changes nothing there (on JavaScript, where `int.parse` returns Infinity, the guard is what rejects it), and an exponent that does not parse as an integer is rejected by the later parsers either way.

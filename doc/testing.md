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

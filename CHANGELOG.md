# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-04-05

### Added
- `dataprep/non_empty_list` module: `NonEmptyList(a)` type with `single`, `cons`, `append`, `concat`, `map`, `flat_map`, `to_list`, `from_list`
- `dataprep/validated` module: `Validated(a, e)` applicative functor with `map`, `map_error`, `and_then`, `from_result`, `to_result`, `map2`..`map5`
- `dataprep/prep` module: `Prep(a)` infallible transformations with `then`, `sequence`, `identity`, `trim`, `lowercase`, `uppercase`, `collapse_space`, `replace`, `default`
- `dataprep/validator` module: `Validator(a, e)` with `check`, `predicate`, `both`, `all`, `alt`, `guard`, `map_error`, `label`
- `dataprep/rules` module: built-in rules `not_empty`, `min_length`, `max_length`, `min_int`, `max_int`, `one_of`, `equals`
- Root module `dataprep` with type aliases for convenience re-exports
- GitHub Actions CI (format, lint, build, test)
- Dependabot configuration for hex and github-actions
- justfile with `ci`, `test`, `format`, `check`, `build`, `clean` tasks
- mise configuration for Gleam 1.15.2 and Erlang/OTP 28.4.1

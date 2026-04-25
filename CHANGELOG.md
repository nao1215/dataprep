# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-04-25

### Changed

- `parse.float` is no longer strictly bound to `gleam/float.parse`.
  It now also accepts integer literals (`"5"` → `5.0`), so the
  asymmetry with `parse.int` no longer surprises callers who pass a
  user-typed numeric value, and accepts scientific notation
  (`"1e3"`, `"1.5e-2"`, `"5E3"`). Inputs the bare stdlib already
  accepted continue to parse identically; the failure path is
  unchanged. (#6)

### Added

- `rules.matches_fully(pattern: regexp.Regexp, error)` and
  `rules.matches_fully_string(pattern: String, error)` rules that
  require the regex to match the **entire** input string. Unlike
  `matches` / `matches_string` (which inherit `regexp.check`'s
  substring semantics and would accept `"abc123def"` for a digit
  pattern), the `_fully` variants compare the matched span against
  the full input. The `matches` / `matches_string` docstrings were
  also rewritten to call out the substring footgun loudly. This is
  the validation-friendly default most callers actually wanted. (#7)
- `rules.matches_string(pattern: String, error)` convenience that
  compiles the pattern internally and panics on a malformed literal.
  Lets callers with strict glinter settings (`assert_ok_pattern =
  "error"`) use literal regex patterns without a `let assert
  Ok(_)` workaround. Dynamic patterns still flow through the
  existing `matches` + `regexp.from_string` pair so the compile
  error stays observable. (#5)
- README example demonstrating both `matches` (dynamic pattern,
  caller-handled `Result`) and `matches_string` (literal pattern)
  so first-time users see the compile step that the previous
  README hid.

## [0.2.0] - 2026-04-05

### Added
- `dataprep/rules`: `not_blank`, `matches` (pre-compiled `Regexp`), `length_between`, `min_float`, `max_float`, `non_negative_int`, `non_negative_float`
- `dataprep/validated`: `sequence`, `traverse`, `traverse_indexed`, `from_result_map`
- `dataprep/validator`: `each`, `optional`
- `dataprep/parse` module: `int`, `float` parse helpers for String to typed Validated
- Test suite expanded from 73 to 214 tests
- README examples: field validation with label, parse-then-validate, nested error labeling with map3
- Recipe documents: signup form, query params, CSV row (with batch via traverse_indexed), API payload (with each, optional, matches)
- GitHub Actions release workflow for automatic Hex publish on v* tag push
- SECURITY.md, CONTRIBUTING.md, CHANGELOG.md

### Changed
- `matches` now takes a pre-compiled `regexp.Regexp` instead of a pattern string to avoid runtime crashes on invalid patterns
- Recipes updated to use new APIs (parse helpers, not_blank, length_between, each, optional)
- README links use absolute GitHub URLs for HexDocs compatibility

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

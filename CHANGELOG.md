# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `dataprep/prep`: `prep.replace_checked(target:, replacement:) -> Result(Prep(String), PrepError)` is a `Result`-returning companion to `prep.replace` for callers whose `target` comes from runtime input (search fields, configuration, CSV) rather than a known-good literal. It returns `Error(EmptyTarget)` instead of panicking on an empty target, matching the `_checked` convention used elsewhere in the package. `prep.replace` is now defined in terms of `replace_checked` (panicking on `Error(EmptyTarget)`), so the checked and unchecked constructors cannot drift. The new `PrepError` type (variant `EmptyTarget`) names the failure. (#106)
- `dataprep/validated`: `validated.and_map(vf, va)` is an applicative-apply companion that lets the first `Validated` value flow into a pipe and chain to any number of further values — `v1 |> validated.map(curried) |> validated.and_map(v2) |> validated.and_map(v3)` — accumulating errors from every `Invalid` in the chain in left-to-right order. The existing `map2`..`map5` keep the function-first shape for direct calls and `combine2`..`combine5` cover the fixed-arity pipe shape; `and_map` fills the arbitrary-arity pipe gap that callers starting from the value-first `validated.map` expected. Re-verification follow-up to #83. (#107)

## [0.22.0] - 2026-05-20

### Changed

- `dataprep/prep`: `prep.replace(target: "", replacement: _)` now panics at construction time with `dataprep/prep.replace: target must be non-empty` instead of building a no-op transform. The underlying `gleam/string.replace` silently leaves the input untouched when the target is empty (the empty string matches at every position, which has no meaningful "replace once" interpretation), so the empty-target case used to hide caller typos like swapped argument labels. Guard at the call site when `target` comes from configuration or user input. **Breaking** for callers that relied on the silent no-op behaviour. (#99)
- `dataprep/rules`: `rules.min_length(minimum: m, error: e)` and `rules.max_length(maximum: m, error: e)` now panic at construction time when `m < 0` instead of silently returning a no-op (for `min_length`) or always-fail (for `max_length`) validator. `string.length` is always `>= 0`, so a negative bound produces a vacuously true / vacuously false predicate; the case is almost always a config or arithmetic bug and is surfaced as one. The panic message names the function and echoes the offending value (`dataprep/rules.min_length: minimum (-1) must be >= 0`). Zero remains a valid bound — `min_length(0)` accepts every input, `max_length(0)` accepts only the empty string. **Breaking** for callers that relied on the silent no-op / always-fail behaviour. (#98)
- `dataprep/rules`: `rules.length_between(minimum: m, maximum: n, error: e)` with `m > n` now panics at construction time with `dataprep/rules.length_between: minimum (m) must be <= maximum (n)` instead of silently returning an always-fail validator. An inverted `[min, max]` interval has no inhabitants, so any validator built from it would reject every input — that is a programmer error and is surfaced as one. Guard the bounds at the call site when `min`/`max` come from configuration or other dynamic input. **Breaking** for callers that relied on the silent always-fail behaviour. (#97)
- `dataprep/rules`: `rules.one_of(allowed: [], error: e)` now panics at construction time with `dataprep/rules.one_of: allowed list must be non-empty` instead of silently returning an always-fail validator. A set-membership check against the empty set has no inhabitants, so any validator built from `[]` would reject every input — that is a programmer error and is surfaced as one. Guard at the call site when the allowlist comes from configuration or other dynamic input (e.g., `case allowed { [] -> ...; [_, ..] -> rules.one_of(allowed, e) }`). **Breaking** for callers that relied on the silent always-fail behaviour. (#96)

### Removed

- `dataprep/rules`: `rules.matches_fully(pattern: regexp.Regexp, error: e)` is removed. The function took an already-compiled `Regexp` whose source pattern Gleam's `gleam/regexp` does not expose, which left no way to re-anchor the pattern as `^(?:...)$`; that prevented it from implementing Python `re.fullmatch` semantics for top-level alternation (`a|ab` against `"ab"` was rejected via leftmost-first matching). `rules.matches_fully_string(pattern: String, error: e)` and `rules.matches_fully_string_checked(pattern: String, error: e)` already compile the anchored pattern internally and behave correctly for all patterns; migrate by passing the pattern source string instead of a precompiled `Regexp`. **Breaking**. (#95)

## [0.21.0] - 2026-05-16

### Added

- `dataprep/validator`: `validator.also/2` as a pipe-friendly alias of `validator.both/2` for chains of three or more error-accumulating checks. Reads as "this check also has to pass" at every step, instead of `both` (which implies two things). Identical semantics — both functions accumulate errors the same way — so the choice is purely stylistic. The `both/2` doc-comment now also points readers at `validator.all([...])` for the list form once chains grow beyond a handful of checks. (#87)
- `dataprep/validator`: `validator.and_then/2` as the preferred name for the short-circuit prerequisite combinator. Reads as the `Result.try` / `Option.then` idiom callers already know from stdlib and removes the friction with `bool.guard` from gleam_stdlib (which is the opposite "shortcut on condition" idiom). Same semantics as the existing combinator: `pre` runs first; if `Valid`, `main` runs on the same input; otherwise only `pre`'s errors are returned. Errors are NOT accumulated. (#86)

### Deprecated

- `dataprep/validator`: `validator.guard/2` is now deprecated in favour of `validator.and_then/2`. The name collided with `bool.guard` from gleam_stdlib (which has the opposite "shortcut on condition" intuition), and first-time readers had to read the source to be sure which branch fired when. `guard` keeps working as a thin alias of `and_then` — the deprecation triggers a compiler warning at call sites so existing code can migrate at its own pace. (#86)

## [0.20.0] - 2026-05-12

### Added

- `validated.combine2`, `combine3`, `combine4`, `combine5`:
  pipe-friendly aliases of `map2..map5` that take the `Validated`
  receivers first and the combining function last via the `with`
  label. The applicative `mapN` form (function-first, mirroring
  Haskell-style `f <$> va <*> vb <*> ...`) stays for callers who
  prefer it, but multi-field validators built on this module can
  now flow through a single pipe — `validate_a(x) |>
  validated.combine4(validate_b(y), validate_c(z), validate_d(w),
  with: fn(a, b, c, d) { ... })`. (#83)

## [0.19.0] - 2026-05-11

### Fixed

- `parse.float` and `parse.float_strict` no longer panic with Erlang
  `badarg` on plain-digit inputs whose magnitude exceeds the IEEE 754
  double range (e.g. `"9"` repeated 309 times, or any decimal integer
  literal with more than 308 digits). Previously the call to
  `gleam/int.to_float` invoked the BEAM's `erlang:float/1` BIF, which
  raised at the runtime level and crashed the calling actor or HTTP
  handler. The function now funnels the overflow into the documented
  `Invalid` shape that its `Validated(Float, e)` return type already
  promises, consistently with the scientific-notation overflow path
  fixed in #77. (#80)

## [0.18.0] - 2026-05-11

### Fixed

- `parse.float` and `parse.float_strict` no longer panic with Erlang
  `Badarith` on scientific-notation inputs whose exponent overflows the
  IEEE 754 double range (e.g. `"1e309"`, `"1.5e3000"`, `"-1e309"`).
  Previously the call to `gleam/float.power` raised at the BEAM level
  and crashed the calling actor or HTTP handler; the function now
  funnels the overflow into the documented `Invalid` shape that its
  `Validated(Float, e)` return type already promises. The
  boundary-preserving input `"1e308"` continues to return
  `Valid(1.0e308)`, and the underflow case `"1e-3000"` keeps returning
  `Valid(0.0)` (the IEEE 754 underflow-to-zero behaviour is intentional
  per the asymmetry note in #77). (#77)

## [0.17.0] - 2026-05-10

### Fixed

- `parse.float_strict` now accepts standard scientific notation with an
  explicit `+` sign on the exponent (e.g. `"1.5e+2"`, `"5e+3"`,
  `"1.5E+10"`). Previously the strict-grammar regex only allowed an
  optional `-` on the exponent, so inputs that the lenient `parse.float`
  accepted — and that every standard float grammar (IEEE 754,
  ECMAScript, Python, Rust, Go) accepts — were incorrectly rejected.
  This restores the documented invariant that strict is a subset of
  lenient. (#74)

## [0.16.0] - 2026-05-11

### Documentation

- README now states the package's intentional **scope policy**: dataprep
  is a combinator toolkit, not a rule catalog. Domain-specific parsers
  (`email`, `url`, `uuid`, `iso_datetime`, `ipv4`, ...) are explicitly
  out of scope, with rationale. This surfaces the design statement
  previously documented only in `CLAUDE.md`. (#71)
- README adds a **"Building your own parser" cookbook** with four
  recipes (`positive_int`, `bounded_string`, `uuid_v4_lowercase`,
  `enum_of_strings_ci`) showing how `prep` + `rules` + `validator` +
  `parse` compose into the parsers callers commonly want. Every
  recipe is verified by the new `test/dataprep/cookbook_test.gleam`
  test module so future API changes will surface as test failures
  rather than stale docs. (#71)
- README adds a **"Out of scope, by design"** list naming
  `email`/`url`/`uri`, `iso_datetime`/time, `uuid`/`ulid`, JSON
  shape validation, and HTML/XML sanitisation as the categories
  the package will not absorb, with a one-line "why" per category. (#71)
- Modules table: `parse` now lists `float_strict` alongside `int` and
  `float`. The function existed in 0.15.0 but was missing from the
  table. (#71)

## [0.15.0] - 2026-05-09

### Added

- **`dataprep/parse`**: `parse.float_strict(raw, on_error)` is the
  strict counterpart of `parse.float`. The lenient variant delegates
  to `gleam/float.parse`, which silently truncates inputs like
  `"3,000"` to `3.0` (parse stops at the comma) — a 1000× wrong
  amount for users typing locale-formatted thousand-separated values
  in `de_DE` / `fr_FR` / `ja_JP`. The strict variant validates the
  input with a strict-float grammar
  (`-?(\d+|\d+\.\d+)([eE]-?\d+)?`) and rejects anything else
  (commas, spaces, trailing letters, leading dots, multiple dots).
  `parse.float` keeps its lenient shape for backward compatibility,
  with an updated doc-comment that warns about the locale-truncation
  footgun and points at `float_strict` for amount fields. (#67)
- Property-based and metamorphic tests using
  [metamon](https://github.com/nao1215/metamon) covering the public
  surface of `dataprep/prep`, `dataprep/non_empty_list`, and
  `dataprep/validated`. Lives in `test/dataprep_metamon_test.gleam`.
  Highlights: `prep.then` is associative and `prep.identity` is a
  two-sided neutral; `prep.sequence([])` is the identity prep;
  `prep.trim` / `prep.lowercase` / `prep.uppercase` are idempotent;
  `prep.compose` is byte-equivalent to `prep.then`; `NonEmptyList`
  satisfies `length >= 1`, `to_list` / `from_list` round-trip,
  `reverse` is involutive and length-preserving, `append` lengths
  add, `head ∘ single == id`; `Validated.from_result` round-trips on
  both arms, `Valid` survives `map_error` / `Invalid` survives `map`,
  `map2` on two `Invalid`s concatenates errors, `sequence` and
  `traverse` agree on the all-`Valid` path.

## [0.14.0] - 2026-05-08

### Added
- **validator**: `validator.required(error)` is a convenience for the
  canonical "this string field is required" check —
  `predicate(fn(s) { s != "" }, error)` spelt out as the intent rather
  than the implementation. Pairs naturally with `prep.trim()` upstream
  for the "required after trimming" posture. Scoped to `String` because
  "required for `Option(a)`" and "required for a list" are different
  shapes (use `optional/1` flipped or `predicate(fn(xs) { xs != [] })`,
  respectively). (#62)

- **prep**: `prep.compose(first:, then:)` is a labelled alias of
  `prep.then/2` exposed under the FP `compose` name. FP-leaning users
  coming from Haskell `(.)`, Elm `<<`, or lodash `_.flow` grep for
  `compose` first; the alias keeps the entry point discoverable via
  hexdocs / autocomplete without renaming or removing the existing
  `then/2`. Output is byte-identical to `then(first:, next:)`. The
  second label reads `then` (not `next`) to mirror the prose "first
  do f, *then* do g". (#61)

- **prep**: `prep.run(prep:, value:)` is a thin alias for the
  function-call form: `prep.run(p, value)` is identical to `p(value)`.
  `Prep(a)` is a `fn(a) -> a` type alias, so applying a built prep is
  just calling it like a function — but new users coming from a "build
  a transformer, apply later" mental model reach for `run`/`apply`
  first. `prep.run/2` exists as a discoverability hook (and as a
  pipe-friendly entry point for callers who thread the prep value
  through multiple call sites). Both forms compile to the same code;
  pick whichever reads better at the call site. (#60)

### Documentation
- **prep**: top-level `////` docstring now ships an "Applying a Prep"
  section that pins the type-alias trick (`Prep(a) = fn(a) -> a`),
  shows the function-call form, and points readers at `prep.run/2`
  for the named entry point. The split lets readers pick whichever
  form reads better at the call site without having to read the
  source to learn the type-alias contract. (#60)

## [0.13.0] - 2026-05-07

### Documentation

- **validator / prep**: pin the empty-list monoid identity in the
  docstrings of `validator.all/1` and `prep.sequence/1`. Both
  functions return the identity element when given `[]` (`Valid(a)`
  and `identity()` respectively); the docs now explain that this is
  a deliberate monoid law and recommend
  `validator.predicate(fn(_) { True }, _)` for callers who want an
  *explicit* pass-through validator. The existing
  `law_all_empty_is_identity_test` keeps the validator side under
  test; a new `law_prep_sequence_empty_is_identity_test` pins the
  prep side. (#57)

## [0.12.0] - 2026-05-07

### Documentation

- **architecture**: `doc/architecture.md` (new) — single page that
  resolves the recurring \"do I want a `Prep` or a `Validator`?\"
  decision. Covers the decision table, why the library splits total
  transformations from fallible checks, the canonical Prep →
  Validator pipeline recipe, the type-changing `parse` →
  `validated.and_then` bridge, and a worked end-to-end signup form.
  The `prep` and `validator` module docstrings now cross-link to it.
  The recipe is exercised by `test/integration_pipeline_test.gleam`
  so the snippet cannot drift out of sync. (#51)

### Added

- **prep**: `prep.default_when_blank(fallback)` falls back when the
  input is the literal empty string **or** whitespace-only (per
  `string.trim`). The existing `prep.default(fallback)` keeps its
  literal-empty-only contract; pick the right tool side-by-side via
  the new \"`default` vs `default_when_blank`\" README section. The
  documented `prep.trim() |> prep.then(prep.default(...))` composition
  is now exercised by `gleam test` so the example cannot rot. (#52)
- **prep**: `prep.collapse_unicode_space()` collapses runs of Unicode
  whitespace (`\s+` under the regex engine's full Unicode rule, so
  NO-BREAK SPACE, IDEOGRAPHIC SPACE, EN/EM spaces, etc. all match)
  into a single ASCII space. Reach for this when callers actually
  want the broader fold; the default `collapse_space` no longer does
  it. (#50)

### Changed

- **Breaking (prep)**: `prep.collapse_space()` now matches **ASCII
  whitespace only** (`[ \t\n\r\f\v]`). Previously it used `\s+`,
  which under the Erlang regex engine matches Unicode whitespace too
  and silently rewrote NO-BREAK SPACE (U+00A0) and IDEOGRAPHIC SPACE
  (U+3000) to a regular ASCII space — destructive in CJK contexts
  where `姓　名` (with U+3000 between names) would become `姓 名`
  with no warning. The Unicode-aware behaviour is still available as
  `prep.collapse_unicode_space()` for callers who need it. (#50)

### Fixed

- **rules**: `matches_fully_string` and `matches_fully_string_checked`
  now correctly accept inputs that match a non-leftmost branch of a
  top-level alternation. The pattern is anchored as `^(?:pattern)$`
  inside the helper before compilation, so e.g. `"a|ab"` against
  `"ab"` is now `Valid` (matching Python `re.fullmatch` semantics)
  instead of being rejected because `regexp.scan` chose the shorter
  `a` alternative. The compiled-regex variant `matches_fully` cannot
  be fixed in place — `Regexp` is opaque and the source pattern is
  unrecoverable — so its docstring now documents the alternation
  caveat and points callers at the `_string` / `_string_checked`
  variants. (#47)

## [0.10.0] - 2026-05-04

### Fixed

- **docs**: The README rule-composition snippet now imports
  `dataprep/validator` so the example actually compiles when copied
  into a project. The other onboarding snippets were re-checked for
  copy-paste completeness. (#43)

### Changed

- **validator**: `all` was refactored to a single `list.fold`
  accumulation, replacing the prior map / `filter_map` / fold pipeline.
  No behavior change — order of accumulated errors and the empty-list
  identity (`all([])` returns `Valid(input)`) are preserved. (#43)

## [0.9.0] - 2026-04-30

### Added

- **test**: A dedicated `laws_test` module pins the documented behavioral
  invariants of `validator` and `validated` (input preservation,
  accumulation vs short-circuit semantics across `both` / `all` / `alt` /
  `guard` / `each` / `optional`, functor identity & composition for
  `map`, monadic short-circuit and identity laws for `and_then`, and
  left-to-right error order across the `mapN` family). The tests use
  only `gleam_stdlib` types so they exercise both the Erlang and
  JavaScript CI lanes; `panic` sentinels enforce the short-circuit
  branches. A prose counterpart lives in `doc/laws.md`. (#32)

- **docs**: Two new first-party recipes — `doc/recipes/wisp_request.md`
  for a JSON-bodied Wisp handler that returns every field error at once,
  and `doc/recipes/lustre_form.md` for a Lustre form that validates on
  submit and renders per-field error messages inline. The Lustre recipe
  also documents how to share a single `dataprep` validator module
  between the BEAM server and the JavaScript browser. (#33)

## [0.8.0] - 2026-04-30

### Added

- **rules**: `matches_string_checked` and `matches_fully_string_checked`
  return `Result(Validator(String, e), RegexRuleError)` instead of
  panicking on a malformed pattern. Use these when the pattern comes
  from config or admin-supplied input — the panicking
  `matches_string` / `matches_fully_string` helpers stay available
  for hard-coded literal patterns. The `RegexRuleError.InvalidPattern`
  variant exposes both `reason` and `byte_index` so callers can
  surface meaningful diagnostics without depending on `gleam/regexp`
  directly. (#35)

### Changed

- **ci(javascript)**: The `Test (JavaScript)` workflow now runs against
  Node 18 in addition to Node 22, matching the documented minimum
  supported Node version in the README. Support-floor regressions are
  now visible in CI instead of relying on ad hoc user reports. (#36)

## [0.7.0] - 2026-04-28

### Added

- JavaScript target support. The `target = "erlang"` constraint has
  been dropped from `gleam.toml` so the package compiles for both
  Erlang and JavaScript. Enables sharing the same `Validator(a, e)`
  between Lustre client-side form validation and a server-side
  validator (e.g. wisp). The package contains zero FFI and zero
  target-specific code, so behavior is identical on both runtimes.
  CI now runs the test suite on both targets. (#25)

### Changed

- **non_empty_list (BREAKING)**: `NonEmptyList(a)` is now `pub opaque`.
  Direct constructor calls like `NonEmptyList(first: x, rest: [...])`
  and pattern matches on the `NonEmptyList` constructor no longer
  compile. Construct via `non_empty_list.single`,
  `non_empty_list.cons`, or `non_empty_list.from_list`; observe via
  `non_empty_list.head`, `non_empty_list.tail`,
  `non_empty_list.to_list`, or `non_empty_list.fold`. Hiding the
  representation lets the internal layout evolve without a future
  breaking change. (#26)

### Added

- `non_empty_list.head`, `non_empty_list.tail`, `non_empty_list.length`,
  `non_empty_list.fold`, and `non_empty_list.reverse` accessors so
  callers can observe a `NonEmptyList` without pattern matching.
  `head` is total, `tail` returns a plain `List(a)` (possibly empty),
  `length` is always `>= 1`, `fold` mirrors `gleam/list.fold` with
  `from:` / `with:` labels, and `reverse` returns a `NonEmptyList(a)`.
  (#26)
- Module-level docstring on `dataprep/validated` clarifying that
  `Validated(a, e)` is intentionally a transparent sum type and that
  pattern matching on `Valid` / `Invalid` is the supported call
  shape. (#26)

## [0.6.0] - 2026-04-28

### Changed

- **validator (BREAKING)**: `validator.each` and `validator.optional` now
  return `Validator(List(a), e)` and `Validator(Option(a), e)` respectively
  instead of the bare `fn(...) -> Validated(...)` arrows they exposed
  before. The implementations are unchanged (`each` already preserved
  its input list per the `Validator` invariant; `optional` already
  preserved its `Option`), but the explicit `Validator(_, _)` return
  type means both can now be dropped directly into `validator.all`,
  `validator.both`, `validator.alt`, and `validator.guard` over the
  same parent value — the seven-line bridge described in #21 (validate
  `length(list) <= 8` AND `each item satisfies X` over the same
  `List(String)`) collapses to a one-line `validator.all([...])`
  composition. Existing call sites that captured the bound function
  by its concrete type need no change because the alias resolves
  transparently; sites that named the type explicitly should switch
  to `Validator(List(a), e)` / `Validator(Option(a), e)`. (#21)

## [0.5.0] - 2026-04-27

### Documentation

- Document the vacuously-unsatisfiable edge cases on `rules.one_of` and
  `rules.length_between`. `rules.one_of([], error)` and
  `rules.length_between(min, max, error)` with `min > max` always return
  `Invalid(error)` for any input — the rule constructors stay pure (no
  panic, no API break) but the docstrings now flag these as programmer
  errors and recommend guarding the bounds at the call site when the
  allowlist or range comes from configuration. Add `length_between` test
  coverage including a `min > max` regression case so the documented
  behavior is pinned. (#18)

## [0.4.0] - 2026-04-27

### Added

- `validated.fail(error)` convenience function for constructing an `Invalid`
  result from a single error without importing `non_empty_list`. (#13)

### Documentation

- Clarify in README that rules return validator functions and must be composed
  with `validator.both`/`validator.guard`, not piped directly. (#14)

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

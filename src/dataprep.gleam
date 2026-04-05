/// dataprep: composable, type-driven preprocessing and validation combinators.
///
/// Four concepts, one pipeline:
///
///   Prep(a)          = fn(a) -> a               -- normalize (always succeeds)
///   Validator(a, e)  = fn(a) -> Validated(a, e) -- check (never transforms)
///   Validated(a, e)  = Valid(a) | Invalid(...)   -- result with error accumulation
///   NonEmptyList(e)  -- guarantees at least one error in Invalid
///
/// Modules:
///   dataprep/prep           -- Infallible transformations and composition
///   dataprep/validator      -- Checks, combinators (both, all, alt, guard)
///   dataprep/validated      -- Applicative error accumulation (map2..map5)
///   dataprep/non_empty_list -- At-least-one guarantee for error lists
///   dataprep/rules          -- Built-in validation rules
///   dataprep/parse          -- Parse helpers (String -> typed Validated)
import dataprep/non_empty_list
import dataprep/prep
import dataprep/validated
import dataprep/validator

/// Infallible transformation: fn(a) -> a. Always succeeds, never produces
/// errors. See `dataprep/prep` for composition (`then`, `sequence`) and
/// built-in preps (`trim`, `lowercase`, etc.).
pub type Prep(a) =
  prep.Prep(a)

/// Check without transformation: fn(a) -> Validated(a, e). If v(x) returns
/// Valid(y), then x == y. See `dataprep/validator` for builders (`check`,
/// `predicate`) and combinators (`both`, `all`, `alt`, `guard`).
pub type Validator(a, e) =
  validator.Validator(a, e)

/// Applicative result with error accumulation. Valid(a) on success,
/// Invalid(NonEmptyList(e)) on failure. See `dataprep/validated` for
/// `map`, `and_then`, and `map2`..`map5` for combining independent fields.
pub type Validated(a, e) =
  validated.Validated(a, e)

/// List guaranteed to have at least one element. Used by Invalid to
/// ensure every failure carries at least one error. See
/// `dataprep/non_empty_list` for construction and traversal.
pub type NonEmptyList(a) =
  non_empty_list.NonEmptyList(a)

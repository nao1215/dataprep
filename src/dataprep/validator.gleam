import dataprep/non_empty_list
import dataprep/validated.{type Validated, Invalid, Valid}
import gleam/list
import gleam/option

/// Validator(a, e) checks a value and either returns it unchanged
/// or produces errors. Key invariant: if v(x) returns Valid(y), then x == y.
pub type Validator(a, e) =
  fn(a) -> Validated(a, e)

/// Create a validator from a function that returns Ok(Nil) on success
/// or Error(e) on failure. Allows value-dependent error construction.
pub fn check(f: fn(a) -> Result(Nil, e)) -> Validator(a, e) {
  fn(a) {
    case f(a) {
      Ok(Nil) -> Valid(a)
      Error(e) -> Invalid(non_empty_list.single(e))
    }
  }
}

/// Convenience for the common case of a boolean test with a static error.
pub fn predicate(condition: fn(a) -> Bool, error: e) -> Validator(a, e) {
  check(fn(a) {
    case condition(a) {
      True -> Ok(Nil)
      False -> Error(error)
    }
  })
}

/// Run both validators on the same input. Accumulate all errors.
/// On success, return the (unchanged) input.
pub fn both(
  first v1: Validator(a, e),
  second v2: Validator(a, e),
) -> Validator(a, e) {
  fn(a) {
    case v1(a), v2(a) {
      Valid(_), Valid(_) -> Valid(a)
      Valid(_), Invalid(e2) -> Invalid(e2)
      Invalid(e1), Valid(_) -> Invalid(e1)
      Invalid(e1), Invalid(e2) ->
        Invalid(non_empty_list.append(left: e1, right: e2))
    }
  }
}

/// Run all validators on the same input. Accumulate all errors.
pub fn all(validators: List(Validator(a, e))) -> Validator(a, e) {
  fn(a) {
    list.fold(validators, Valid(a), fn(acc, v) {
      case acc, v(a) {
        Valid(_), result -> result
        Invalid(e1), Valid(_) -> Invalid(e1)
        Invalid(e1), Invalid(e2) ->
          Invalid(non_empty_list.append(left: e1, right: e2))
      }
    })
  }
}

/// Try alternatives in order. Use when the input can satisfy
/// different formats (e.g. UUID or slug).
///
/// Evaluation: v1 is tried first. If Valid, v2 is never called
/// (short-circuit). If v1 fails, v2 is tried. If both fail, errors
/// from both branches are accumulated.
///
/// The accumulated errors can be noisy for end-user display.
/// Use `map_error` to tag each branch before `alt`, then
/// post-process the error list before presenting to users.
pub fn alt(
  first v1: Validator(a, e),
  second v2: Validator(a, e),
) -> Validator(a, e) {
  fn(a) {
    case v1(a) {
      Valid(x) -> Valid(x)
      Invalid(e1) ->
        case v2(a) {
          Valid(x) -> Valid(x)
          Invalid(e2) -> Invalid(non_empty_list.append(left: e1, right: e2))
        }
    }
  }
}

/// Short-circuit prerequisite. Use when main is expensive or
/// semantically depends on pre passing (e.g. "non-empty" before
/// "regex match").
///
/// Evaluation: pre runs first. If Valid, main runs on the same
/// input. If pre fails, main is never called and only pre's errors
/// are returned. Errors are NOT accumulated across pre and main.
pub fn guard(
  pre pre: Validator(a, e),
  main main: Validator(a, e),
) -> Validator(a, e) {
  fn(a) {
    case pre(a) {
      Valid(_) -> main(a)
      Invalid(errs) -> Invalid(errs)
    }
  }
}

/// Transform the error type of a validator.
pub fn map_error(v: Validator(a, e1), f: fn(e1) -> e2) -> Validator(a, e2) {
  fn(a) {
    case v(a) {
      Valid(x) -> Valid(x)
      Invalid(errs) -> Invalid(non_empty_list.map(errs, f))
    }
  }
}

/// Attach structured context to all errors produced by a validator.
/// Shorthand for `map_error(v, fn(e) { wrap(ctx, e) })`.
///
/// Apply at module or field boundaries (once per field), not at
/// every individual rule. Deeply nested labels produce unreadable
/// error structures.
///
/// Example:
///
///   check_name |> validator.label("name", FieldError)
///   // wraps every error e as FieldError("name", e)
///
pub fn label(
  v: Validator(a, e1),
  ctx: ctx,
  wrap: fn(ctx, e1) -> e2,
) -> Validator(a, e2) {
  map_error(v, fn(e) { wrap(ctx, e) })
}

/// Validate each element of a list with the given validator.
/// All errors from all elements are accumulated.
/// Returns Valid with the unchanged list on success.
///
/// Issue #21: returns a `Validator(List(a), e)` so it composes
/// directly with `all`, `both`, `alt`, and `guard` over the same
/// parent list — e.g. `validator.all([length_check, validator.each(item_v)])`
/// validates "this list as a whole" AND "each item" without an
/// adapter. The Validator invariant (input value preserved on
/// Valid) holds because `validated.traverse` does not mutate the
/// input — it threads each element through `v` whose own invariant
/// preserves the value.
///
/// For index-aware validation, use `validated.traverse_indexed`
/// with `validator.label` to attach position info.
pub fn each(v: Validator(a, e)) -> Validator(List(a), e) {
  fn(items) { validated.traverse(items, v) }
}

/// Make a validator optional: if the value is None, it is always
/// Valid(None). If Some(a), run the inner validator and wrap the
/// result back in Some.
///
/// Issue #21: returns a `Validator(Option(a), e)` so it composes
/// with `all`, `both`, `alt`, and `guard` over the same optional
/// parent value (e.g. enforce "if present, satisfies X" alongside
/// other Optional-level rules).
pub fn optional(v: Validator(a, e)) -> Validator(option.Option(a), e) {
  fn(opt) {
    case opt {
      option.None -> Valid(option.None)
      option.Some(a) -> validated.map(v(a), option.Some)
    }
  }
}

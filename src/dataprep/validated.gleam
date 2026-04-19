import dataprep/non_empty_list
import gleam/list

/// Applicative functor for error accumulation.
pub type Validated(a, e) {
  Valid(a)
  Invalid(non_empty_list.NonEmptyList(e))
}

/// Transform the success value (functor map).
pub fn map(v: Validated(a, e), f: fn(a) -> b) -> Validated(b, e) {
  case v {
    Valid(a) -> Valid(f(a))
    Invalid(errs) -> Invalid(errs)
  }
}

/// Transform every error value.
pub fn map_error(v: Validated(a, e1), f: fn(e1) -> e2) -> Validated(a, e2) {
  case v {
    Valid(a) -> Valid(a)
    Invalid(errs) -> Invalid(non_empty_list.map(errs, f))
  }
}

/// Monadic bind. Sequential, short-circuits on error.
/// Use for dependent operations (e.g. parse then validate).
/// Does NOT accumulate errors -- that is intentional.
pub fn and_then(
  v: Validated(a, e),
  f: fn(a) -> Validated(b, e),
) -> Validated(b, e) {
  case v {
    Valid(a) -> f(a)
    Invalid(errs) -> Invalid(errs)
  }
}

/// Convert from Result.
pub fn from_result(r: Result(a, e)) -> Validated(a, e) {
  case r {
    Ok(a) -> Valid(a)
    Error(e) -> Invalid(non_empty_list.single(e))
  }
}

/// Convert from Result with a custom error mapper.
/// Useful for parsing where the original error type differs
/// from the validation error type.
///
/// Example:
///   int.parse(raw)
///   |> validated.from_result_map(fn(_) { NotAnInteger(raw) })
///
pub fn from_result_map(r: Result(a, err), f: fn(err) -> e) -> Validated(a, e) {
  case r {
    Ok(a) -> Valid(a)
    Error(err) -> Invalid(non_empty_list.single(f(err)))
  }
}

/// Convert to Result (collapses errors into a list).
pub fn to_result(v: Validated(a, e)) -> Result(a, List(e)) {
  case v {
    Valid(a) -> Ok(a)
    Invalid(errs) -> Error(non_empty_list.to_list(errs))
  }
}

/// Combine two Validated values, accumulating all errors.
pub fn map2(
  f: fn(a, b) -> c,
  va: Validated(a, e),
  vb: Validated(b, e),
) -> Validated(c, e) {
  case va, vb {
    Valid(a), Valid(b) -> Valid(f(a, b))
    Valid(_), Invalid(eb) -> Invalid(eb)
    Invalid(ea), Valid(_) -> Invalid(ea)
    Invalid(ea), Invalid(eb) ->
      Invalid(non_empty_list.append(left: ea, right: eb))
  }
}

/// Combine three Validated values, accumulating all errors.
pub fn map3(
  f: fn(a, b, c) -> d,
  va: Validated(a, e),
  vb: Validated(b, e),
  vc: Validated(c, e),
) -> Validated(d, e) {
  map2(fn(g, c) { g(c) }, map2(fn(a, b) { fn(c) { f(a, b, c) } }, va, vb), vc)
}

/// Combine four Validated values, accumulating all errors.
pub fn map4(
  f: fn(a, b, c, d) -> out,
  va: Validated(a, e),
  vb: Validated(b, e),
  vc: Validated(c, e),
  vd: Validated(d, e),
) -> Validated(out, e) {
  map2(
    fn(g, d) { g(d) },
    map3(fn(a, b, c) { fn(d) { f(a, b, c, d) } }, va, vb, vc),
    vd,
  )
}

/// Combine five Validated values, accumulating all errors.
pub fn map5(
  f: fn(a, b, c, d, e_) -> out,
  va: Validated(a, e),
  vb: Validated(b, e),
  vc: Validated(c, e),
  vd: Validated(d, e),
  ve: Validated(e_, e),
) -> Validated(out, e) {
  map2(
    fn(g, e_val) { g(e_val) },
    map4(fn(a, b, c, d) { fn(e_val) { f(a, b, c, d, e_val) } }, va, vb, vc, vd),
    ve,
  )
}

/// Combine a list of Validated values into a Validated list.
/// All errors from all elements are accumulated.
/// Returns Valid([]) for an empty input list.
pub fn sequence(vs: List(Validated(a, e))) -> Validated(List(a), e) {
  list.fold_right(vs, Valid([]), fn(acc, v) {
    map2(fn(head, tail) { [head, ..tail] }, v, acc)
  })
}

/// Apply a function that returns Validated to each element of a list,
/// then combine the results. All errors are accumulated.
///
/// Equivalent to `list.map(xs, f) |> validated.sequence` but avoids
/// building an intermediate list.
pub fn traverse(
  xs: List(a),
  f: fn(a) -> Validated(b, e),
) -> Validated(List(b), e) {
  list.fold_right(xs, Valid([]), fn(acc, x) {
    map2(fn(head, tail) { [head, ..tail] }, f(x), acc)
  })
}

/// Apply a function that returns Validated to each element with its
/// index. Useful for CSV rows, arrays, or any indexed collection
/// where the error needs to carry the position.
pub fn traverse_indexed(
  xs: List(a),
  f: fn(a, Int) -> Validated(b, e),
) -> Validated(List(b), e) {
  xs
  |> list.index_map(fn(x, i) { #(x, i) })
  |> list.fold_right(Valid([]), fn(acc, pair) {
    let #(x, i) = pair
    map2(fn(head, tail) { [head, ..tail] }, f(x, i), acc)
  })
}

//// Validate values and combine the results, keeping every error.
////
//// A `Validator(a, e)` checks a value and returns it unchanged on success.
//// On failure it returns at least one error, held in a `NonEmptyList` from
//// the `non_empty_list` package. Validators for one value are combined with
//// `both`, `all`, `alt` and `and_then`; results for different values are
//// combined with `map2` to `map5` and `collect`.
////
//// ```gleam
//// import dataprep
//// import gleam/string
////
//// pub type User {
////   User(name: String, age: Int)
//// }
////
//// pub fn validate(name: String, age: Int) {
////   let name = string.trim(name)
////   let check_name = dataprep.not_empty("name is required")
////   let check_age = dataprep.min_int(18, "must be an adult")
////   dataprep.map2(check_name(name), check_age(age), with: User)
//// }
//// ```
////

import gleam/string_tree

import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type CompileError, type Regexp}
import gleam/result
import gleam/string
import non_empty_list.{type NonEmptyList}

/// A check on a value of type `a` that fails with errors of type `e`.
///
/// A validator returns `Ok` holding the value it was given, unchanged, or
/// `Error` holding at least one error.
///
pub type Validator(a, e) =
  fn(a) -> Result(a, NonEmptyList(e))

// Building validators -------------------------------------------------------

/// Creates a validator from a function that returns `Ok(Nil)` when the value
/// is valid and `Error` with one error when it is not.
///
/// Use this when the error depends on the value.
///
/// ## Examples
///
/// ```gleam
/// let check = dataprep.check(fn(n) {
///   case n > 0 {
///     True -> Ok(Nil)
///     False -> Error("not positive: " <> int.to_string(n))
///   }
/// })
/// check(-1)
/// // -> Error(NonEmptyList("not positive: -1", []))
/// ```
///
pub fn check(f: fn(a) -> Result(Nil, e)) -> Validator(a, e) {
  fn(value) {
    case f(value) {
      Ok(Nil) -> Ok(value)
      Error(error) -> Error(non_empty_list.single(error))
    }
  }
}

/// Creates a validator that fails with `error` when `condition` returns
/// `False`.
///
/// ## Examples
///
/// ```gleam
/// let even = dataprep.predicate(int.is_even, otherwise: "odd")
/// even(4)
/// // -> Ok(4)
/// even(3)
/// // -> Error(NonEmptyList("odd", []))
/// ```
///
pub fn predicate(
  condition: fn(a) -> Bool,
  otherwise error: e,
) -> Validator(a, e) {
  check(fn(value) {
    case condition(value) {
      True -> Ok(Nil)
      False -> Error(error)
    }
  })
}

// Combining validators ------------------------------------------------------

/// Runs both validators on the same value and keeps the errors of both.
///
/// The errors of `first` come before the errors of `second`.
///
/// ## Examples
///
/// ```gleam
/// let check =
///   dataprep.min_length(3, "too short")
///   |> dataprep.both(dataprep.not_blank("blank"))
/// check(" ")
/// // -> Error(NonEmptyList("too short", ["blank"]))
/// ```
///
pub fn both(
  first first: Validator(a, e),
  second second: Validator(a, e),
) -> Validator(a, e) {
  fn(value) {
    case first(value), second(value) {
      Ok(_), Ok(_) -> Ok(value)
      Ok(_), Error(errors) | Error(errors), Ok(_) -> Error(errors)
      Error(first_errors), Error(second_errors) ->
        Error(non_empty_list.append(first_errors, second_errors))
    }
  }
}

/// Runs every validator on the same value and keeps all of their errors, in
/// list order.
///
/// `all([])` accepts every value.
///
/// ## Examples
///
/// ```gleam
/// let check =
///   dataprep.all([
///     dataprep.not_empty("required"),
///     dataprep.max_length(5, "too long"),
///   ])
/// check("")
/// // -> Error(NonEmptyList("required", []))
/// ```
///
pub fn all(validators: List(Validator(a, e))) -> Validator(a, e) {
  fn(value) {
    // Error groups are collected in reverse and joined once, so the cost
    // stays linear in the number of failing validators.
    let failures =
      list.fold(validators, [], fn(failures, validator) {
        case validator(value) {
          Ok(_) -> failures
          Error(errors) -> [errors, ..failures]
        }
      })
    case non_empty_list.from_list(list.reverse(failures)) {
      Error(Nil) -> Ok(value)
      Ok(groups) -> Error(non_empty_list.flatten(groups))
    }
  }
}

/// Tries `first`, and tries `second` only when `first` fails.
///
/// The value is accepted when either validator accepts it. When both fail,
/// the errors of `first` come before the errors of `second`.
///
/// ## Examples
///
/// ```gleam
/// let check =
///   dataprep.one_of(non_empty_list.single("auto"), "not auto")
///   |> dataprep.alt(dataprep.max_length(3, "too long"))
/// check("auto")
/// // -> Ok("auto")
/// check("manual")
/// // -> Error(NonEmptyList("not auto", ["too long"]))
/// ```
///
pub fn alt(
  first first: Validator(a, e),
  second second: Validator(a, e),
) -> Validator(a, e) {
  fn(value) {
    case first(value) {
      Ok(checked) -> Ok(checked)
      Error(first_errors) ->
        case second(value) {
          Ok(checked) -> Ok(checked)
          Error(second_errors) ->
            Error(non_empty_list.append(first_errors, second_errors))
        }
    }
  }
}

/// Runs `second` only when `first` accepts the value.
///
/// Unlike `both`, the errors are not combined: when `first` fails, only its
/// errors are returned. Use this when `second` is expensive or only makes
/// sense once `first` holds.
///
/// ## Examples
///
/// ```gleam
/// let check =
///   dataprep.not_empty("required")
///   |> dataprep.and_then(dataprep.min_length(3, "too short"))
/// check("")
/// // -> Error(NonEmptyList("required", []))
/// ```
///
pub fn and_then(
  first first: Validator(a, e),
  then second: Validator(a, e),
) -> Validator(a, e) {
  fn(value) {
    case first(value) {
      Ok(_) -> second(value)
      Error(errors) -> Error(errors)
    }
  }
}

/// Changes every error a validator returns with the given function.
///
/// Use it to tag the errors of a field with the field's name.
///
/// ## Examples
///
/// ```gleam
/// let check =
///   dataprep.not_empty("required")
///   |> dataprep.map_error(with: fn(error) { #("name", error) })
/// check("")
/// // -> Error(NonEmptyList(#("name", "required"), []))
/// ```
///
pub fn map_error(
  validator: Validator(a, e1),
  with f: fn(e1) -> e2,
) -> Validator(a, e2) {
  fn(value) { result.map_error(validator(value), non_empty_list.map(_, f)) }
}

/// Creates a validator that runs `validator` on every element of a list and
/// keeps the errors of every element, in list order.
///
/// ## Examples
///
/// ```gleam
/// let check = dataprep.each(dataprep.min_int(0, "negative"))
/// check([1, -2, -3])
/// // -> Error(NonEmptyList("negative", ["negative"]))
/// ```
///
pub fn each(validator: Validator(a, e)) -> Validator(List(a), e) {
  fn(items) { collect_loop(items, validator, [], []) }
}

/// Creates a validator that accepts `None` and runs `validator` on the value
/// inside `Some`.
///
/// ## Examples
///
/// ```gleam
/// let check = dataprep.optional(dataprep.min_int(0, "negative"))
/// check(None)
/// // -> Ok(None)
/// check(Some(-1))
/// // -> Error(NonEmptyList("negative", []))
/// ```
///
pub fn optional(validator: Validator(a, e)) -> Validator(Option(a), e) {
  fn(value) {
    case value {
      None -> Ok(None)
      Some(inner) -> result.map(validator(inner), Some)
    }
  }
}

// Combining results ---------------------------------------------------------

/// Combines two results with `f` when both are `Ok`, and keeps the errors of
/// both otherwise.
///
/// Use it to build a record from fields validated on their own. The errors of
/// `a` come before the errors of `b`.
///
/// ## Examples
///
/// ```gleam
/// dataprep.map2(check_name(""), check_age(10), with: User)
/// // -> Error(NonEmptyList("name is required", ["must be an adult"]))
/// ```
///
pub fn map2(
  a: Result(a, NonEmptyList(e)),
  b: Result(b, NonEmptyList(e)),
  with f: fn(a, b) -> c,
) -> Result(c, NonEmptyList(e)) {
  case a, b {
    Ok(a), Ok(b) -> Ok(f(a, b))
    Ok(_), Error(errors) | Error(errors), Ok(_) -> Error(errors)
    Error(a_errors), Error(b_errors) ->
      Error(non_empty_list.append(a_errors, b_errors))
  }
}

/// Combines three results with `f`, keeping the errors of all of them in
/// argument order. See `map2`.
///
pub fn map3(
  a: Result(a, NonEmptyList(e)),
  b: Result(b, NonEmptyList(e)),
  c: Result(c, NonEmptyList(e)),
  with f: fn(a, b, c) -> d,
) -> Result(d, NonEmptyList(e)) {
  map2(a, b, with: fn(a, b) { fn(c) { f(a, b, c) } })
  |> map2(c, with: apply)
}

/// Combines four results with `f`, keeping the errors of all of them in
/// argument order. See `map2`.
///
pub fn map4(
  a: Result(a, NonEmptyList(e)),
  b: Result(b, NonEmptyList(e)),
  c: Result(c, NonEmptyList(e)),
  d: Result(d, NonEmptyList(e)),
  with f: fn(a, b, c, d) -> g,
) -> Result(g, NonEmptyList(e)) {
  map3(a, b, c, with: fn(a, b, c) { fn(d) { f(a, b, c, d) } })
  |> map2(d, with: apply)
}

/// Combines five results with `f`, keeping the errors of all of them in
/// argument order. See `map2`.
///
pub fn map5(
  a: Result(a, NonEmptyList(e)),
  b: Result(b, NonEmptyList(e)),
  c: Result(c, NonEmptyList(e)),
  d: Result(d, NonEmptyList(e)),
  g: Result(g, NonEmptyList(e)),
  with f: fn(a, b, c, d, g) -> h,
) -> Result(h, NonEmptyList(e)) {
  map4(a, b, c, d, with: fn(a, b, c, d) { fn(g) { f(a, b, c, d, g) } })
  |> map2(g, with: apply)
}

fn apply(f: fn(a) -> b, value: a) -> b {
  f(value)
}

/// Turns a list of results into a result holding the list of values, or
/// holding the errors of every failed result in list order.
///
/// `collect([])` is `Ok([])`.
///
/// ## Examples
///
/// ```gleam
/// dataprep.collect([Ok(1), Ok(2)])
/// // -> Ok([1, 2])
/// ```
///
/// ```gleam
/// dataprep.collect([Ok(1), Error(non_empty_list.single("bad"))])
/// // -> Error(NonEmptyList("bad", []))
/// ```
///
pub fn collect(
  results: List(Result(a, NonEmptyList(e))),
) -> Result(List(a), NonEmptyList(e)) {
  collect_loop(results, fn(result) { result }, [], [])
}

// Tail-recursive so long lists do not overflow the JavaScript stack. Values
// and error groups are collected in reverse and joined once at the end, which
// keeps the whole walk linear.
fn collect_loop(
  items: List(a),
  f: fn(a) -> Result(b, NonEmptyList(e)),
  values: List(b),
  failures: List(NonEmptyList(e)),
) -> Result(List(b), NonEmptyList(e)) {
  case items {
    [] ->
      case non_empty_list.from_list(list.reverse(failures)) {
        Error(Nil) -> Ok(list.reverse(values))
        Ok(groups) -> Error(non_empty_list.flatten(groups))
      }
    [item, ..rest] ->
      case f(item) {
        Ok(value) -> collect_loop(rest, f, [value, ..values], failures)
        Error(errors) -> collect_loop(rest, f, values, [errors, ..failures])
      }
  }
}

// Rules ---------------------------------------------------------------------

/// Creates a validator that rejects the empty string.
///
/// A string of spaces is accepted; use `not_blank` to reject it too.
///
/// ## Examples
///
/// ```gleam
/// dataprep.not_empty("required")("")
/// // -> Error(NonEmptyList("required", []))
/// ```
///
pub fn not_empty(error: e) -> Validator(String, e) {
  predicate(fn(text) { text != "" }, otherwise: error)
}

/// Creates a validator that rejects a string that is empty or holds only
/// Unicode whitespace.
///
/// Unicode whitespace is the White_Space set that `collapse_unicode_space`
/// folds, so the no-break space U+00A0 and the ideographic space U+3000 count
/// as blank. This is wider than `string.trim`, which keeps both. The value is
/// returned unchanged; it is not trimmed.
///
/// ## Examples
///
/// ```gleam
/// dataprep.not_blank("required")(" \t\u{3000}")
/// // -> Error(NonEmptyList("required", []))
/// ```
///
pub fn not_blank(error: e) -> Validator(String, e) {
  predicate(
    fn(text) {
      !list.all(string.to_utf_codepoints(text), fn(codepoint) {
        is_unicode_whitespace(string.utf_codepoint_to_int(codepoint))
      })
    },
    otherwise: error,
  )
}

/// Creates a validator that rejects a string with fewer than `minimum`
/// graphemes.
///
/// ## Panics
///
/// Panics when `minimum` is negative.
///
/// ## Examples
///
/// ```gleam
/// dataprep.min_length(3, "too short")("ab")
/// // -> Error(NonEmptyList("too short", []))
/// ```
///
pub fn min_length(minimum min: Int, error error: e) -> Validator(String, e) {
  // A negative minimum would accept every input; that is a programmer error.
  use <- bool.lazy_guard(when: min < 0, return: fn() {
    let message =
      "dataprep.min_length: minimum (" <> int.to_string(min) <> ") must be >= 0"
    // nolint: avoid_panic -- negative minimum is a programmer error; an always-pass validator would silently accept every input
    panic as message
  })
  predicate(fn(text) { string.length(text) >= min }, otherwise: error)
}

/// Creates a validator that rejects a string with more than `maximum`
/// graphemes.
///
/// ## Panics
///
/// Panics when `maximum` is negative.
///
/// ## Examples
///
/// ```gleam
/// dataprep.max_length(3, "too long")("abcd")
/// // -> Error(NonEmptyList("too long", []))
/// ```
///
pub fn max_length(maximum max: Int, error error: e) -> Validator(String, e) {
  // A negative maximum would reject every input; that is a programmer error.
  use <- bool.lazy_guard(when: max < 0, return: fn() {
    let message =
      "dataprep.max_length: maximum (" <> int.to_string(max) <> ") must be >= 0"
    // nolint: avoid_panic -- negative maximum is a programmer error; an always-fail validator would silently reject every input
    panic as message
  })
  predicate(fn(text) { string.length(text) <= max }, otherwise: error)
}

/// Creates a validator that rejects an integer below `minimum`.
///
/// ## Examples
///
/// ```gleam
/// dataprep.min_int(0, "negative")(-1)
/// // -> Error(NonEmptyList("negative", []))
/// ```
///
pub fn min_int(minimum min: Int, error error: e) -> Validator(Int, e) {
  predicate(fn(n) { n >= min }, otherwise: error)
}

/// Creates a validator that rejects an integer above `maximum`.
///
/// ## Examples
///
/// ```gleam
/// dataprep.max_int(10, "too big")(11)
/// // -> Error(NonEmptyList("too big", []))
/// ```
///
pub fn max_int(maximum max: Int, error error: e) -> Validator(Int, e) {
  predicate(fn(n) { n <= max }, otherwise: error)
}

/// Creates a validator that rejects a float below `minimum`.
///
/// ## Examples
///
/// ```gleam
/// dataprep.min_float(0.0, "negative")(-0.5)
/// // -> Error(NonEmptyList("negative", []))
/// ```
///
pub fn min_float(minimum min: Float, error error: e) -> Validator(Float, e) {
  predicate(fn(x) { x >=. min }, otherwise: error)
}

/// Creates a validator that rejects a float above `maximum`.
///
/// ## Examples
///
/// ```gleam
/// dataprep.max_float(1.0, "too big")(1.5)
/// // -> Error(NonEmptyList("too big", []))
/// ```
///
pub fn max_float(maximum max: Float, error error: e) -> Validator(Float, e) {
  predicate(fn(x) { x <=. max }, otherwise: error)
}

/// Creates a validator that rejects a value not in `allowed`.
///
/// ## Examples
///
/// ```gleam
/// let colours = non_empty_list.new("red", ["green"])
/// dataprep.one_of(colours, "unknown colour")("blue")
/// // -> Error(NonEmptyList("unknown colour", []))
/// ```
///
pub fn one_of(
  allowed allowed: NonEmptyList(a),
  error error: e,
) -> Validator(a, e) {
  let allowed = non_empty_list.to_list(allowed)
  predicate(fn(value) { list.contains(allowed, value) }, otherwise: error)
}

/// Creates a validator that rejects a string in which `pattern` matches
/// nowhere.
///
/// A match anywhere in the string is enough, so `[0-9]+` accepts `"a1"`. Use
/// `full_match` to require the whole string to match. Erlang's `$` also
/// matches before a final newline, so `^...$` is not a full match there.
/// Classes such as `\d` and `\w` match non-ASCII digits and letters on Erlang
/// but only ASCII on JavaScript.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(digits) = regexp.from_string("[0-9]")
/// dataprep.matches(digits, "no digit")("abc")
/// // -> Error(NonEmptyList("no digit", []))
/// ```
///
pub fn matches(pattern re: Regexp, error error: e) -> Validator(String, e) {
  predicate(fn(text) { regexp.check(re, text) }, otherwise: error)
}

/// Compiles `pattern` and creates a validator that rejects a string the
/// pattern does not match from start to end.
///
/// Top-level alternation is matched as a whole: `"a|ab"` accepts `"ab"`. The
/// end of the match is the real end of the string on both targets, so `"foo"`
/// rejects `"foo\n"`.
///
/// Returns the compile error when `pattern` is not a valid regular
/// expression on the target. Erlang's PCRE accepts more than JavaScript does,
/// such as `(*UTF)`, `\Q...\E` and `(?x)` with `#` comments, and those
/// patterns work here too. Whole-pattern recursion `(?R)` recurses into the
/// pattern without the anchors, so `"a(?R)?b"` accepts `"ab"` and `"aabb"`,
/// and `(*ACCEPT)` outside a recursion or a lookaround ends the match only at
/// the end of the string, so `"a(*ACCEPT)b"` accepts `"a"` but not `"ab"`.
///
/// The pattern is passed to the target's engine as it is, so classes such as
/// `\d` and `\w` match non-ASCII digits and letters on Erlang but only ASCII
/// on JavaScript.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(slug) = dataprep.full_match("[a-z0-9-]+", "not a slug")
/// slug("my-post")
/// // -> Ok("my-post")
/// slug("my post")
/// // -> Error(NonEmptyList("not a slug", []))
/// ```
///
pub fn full_match(
  pattern pattern: String,
  error error: e,
) -> Result(Validator(String, e), CompileError) {
  // The pattern is compiled on its own first, so a pattern such as "a)|(b"
  // cannot close the wrapper group below and slip through.
  use _ <- result.try(regexp.from_string(pattern))
  // PCRE accepts verbs such as `(*UTF)` only at the very start, so they stay
  // in front of the anchor.
  let #(verbs, body) = split_leading_verbs(pattern, "")
  // A `\Q` quote left open would swallow the wrapper, so it is closed.
  let close_quote = case
    body
    |> string.to_utf_codepoints
    |> list.map(string.utf_codepoint_to_int)
    |> ends_inside_quote(quoted: False)
  {
    True -> "\\E"
    False -> ""
  }
  // In extended mode a `#` comment runs to the next newline and would
  // swallow the wrapper. `[\r\n]{0}` holds the newline of every convention
  // but `(*NUL)`, which gets a NUL as well, and matches nothing. After a
  // comment ends, what is left of it is whitespace, which extended mode
  // ignores, and a literal `]` repeated zero times. The NUL is added only
  // for `(*NUL)`: PCRE before OTP 28 ends the pattern at a NUL, and it has
  // no `(*NUL)` either.
  let newlines = case string.contains(verbs, "(*NUL)") {
    True -> "[\u{0}\r\n]{0}"
    False -> "[\r\n]{0}"
  }
  let #(body, recursion) = rewrite_whole_pattern_items(body)
  let body = body <> close_quote <> newlines
  // `(?R)` would recurse into the anchors as well, so it calls a copy of the
  // pattern defined after them. A subroutine call cannot replace the pattern
  // itself: PCRE before OTP 28 does not backtrack into one, and `"a|ab"`
  // would then reject `"ab"`. The copy repeats the pattern's named groups,
  // so `(?J)` allows duplicate names.
  let #(prefix, copy) = case recursion {
    True -> #(
      "(?J)^(?:",
      "(?(DEFINE)(?<" <> whole_pattern_group <> ">" <> body <> "))",
    )
    False -> #("^(?:", "")
  }
  let wrapped = verbs <> prefix <> body <> ")(?![\\s\\S])" <> copy
  // `(?![\s\S])` holds only at the real end of the input on both targets;
  // Erlang's `$` also matches before a trailing newline.
  use anchored <- result.map(
    regexp.from_string(wrapped)
    |> result.map_error(fn(wrapped_error) {
      // Point into the caller's pattern rather than the wrapped one.
      regexp.CompileError(
        error: wrapped_error.error,
        byte_index: int.clamp(
          wrapped_error.byte_index - string.byte_size(prefix),
          min: 0,
          max: string.byte_size(pattern),
        ),
      )
    }),
  )
  predicate(fn(text) { regexp.check(anchored, text) }, otherwise: error)
}

const whole_pattern_group: String = "dataprep_whole_pattern"

// Rewrites the items whose meaning depends on the whole pattern, and reports
// whether the pattern recurses into itself. `(?R)` and `(?0)` become calls to
// the copy of the pattern. `(*ACCEPT)` outside a lookaround keeps its meaning
// inside a recursion and, at the top level, succeeds only at the end of the
// input, where the full match would have ended. Escapes, `\Q...\E` quotes,
// character classes and `(?#...)` comments are copied unchanged. A `#`
// comment in extended mode is read as pattern text: an item in it is
// rewritten into another comment, and a bracket in it can hide a later item
// from the rewrite, which then keeps the meaning it had before.
fn rewrite_whole_pattern_items(pattern: String) -> #(String, Bool) {
  rewrite_loop(
    pattern,
    Rewrite(done: string_tree.new(), lookarounds: [], recursion: False),
  )
}

// The text rewritten so far, whether each open group is a lookaround,
// innermost first, and whether the pattern recurses into itself.
type Rewrite {
  Rewrite(
    done: string_tree.StringTree,
    lookarounds: List(Bool),
    recursion: Bool,
  )
}

fn emit(state: Rewrite, text: String) -> Rewrite {
  Rewrite(..state, done: string_tree.append(state.done, text))
}

fn open_group(state: Rewrite, text: String) -> Rewrite {
  Rewrite(..emit(state, text), lookarounds: [False, ..state.lookarounds])
}

fn open_lookaround(state: Rewrite, text: String) -> Rewrite {
  Rewrite(..emit(state, text), lookarounds: [True, ..state.lookarounds])
}

fn rewrite_loop(pattern: String, state: Rewrite) -> #(String, Bool) {
  case pattern {
    "" -> #(string_tree.to_string(state.done), state.recursion)
    "\\Q" <> rest -> {
      let #(quoted, rest) = take_through(rest, "\\E")
      rewrite_loop(rest, emit(state, "\\Q" <> quoted))
    }
    "\\" <> rest ->
      case string.pop_grapheme(rest) {
        Ok(#(escaped, rest)) -> rewrite_loop(rest, emit(state, "\\" <> escaped))
        Error(Nil) -> rewrite_loop("", emit(state, "\\"))
      }
    "[" <> rest -> {
      let #(class, rest) = take_class(rest)
      rewrite_loop(rest, emit(state, "[" <> class))
    }
    "(?#" <> rest -> {
      let #(comment, rest) = take_through(rest, ")")
      rewrite_loop(rest, emit(state, "(?#" <> comment))
    }
    "(?R)" <> rest | "(?0)" <> rest ->
      rewrite_loop(
        rest,
        Rewrite(
          ..emit(state, "(?&" <> whole_pattern_group <> ")"),
          recursion: True,
        ),
      )
    "(*ACCEPT" <> rest -> {
      let #(verb, rest) = take_through(rest, ")")
      let verb = "(*ACCEPT" <> verb
      case list.contains(state.lookarounds, True) {
        // In a lookaround it only ends the assertion.
        True -> rewrite_loop(rest, emit(state, verb))
        False ->
          rewrite_loop(
            rest,
            emit(state, "(?(R)" <> verb <> "|(?![\\s\\S])" <> verb <> ")"),
          )
      }
    }
    "(?=" <> rest -> rewrite_loop(rest, open_lookaround(state, "(?="))
    "(?!" <> rest -> rewrite_loop(rest, open_lookaround(state, "(?!"))
    "(?<=" <> rest -> rewrite_loop(rest, open_lookaround(state, "(?<="))
    "(?<!" <> rest -> rewrite_loop(rest, open_lookaround(state, "(?<!"))
    "(*" <> rest -> rewrite_star_item(rest, state)
    "(" <> rest -> rewrite_loop(rest, open_group(state, "("))
    ")" <> rest ->
      rewrite_loop(
        rest,
        Rewrite(
          ..emit(state, ")"),
          lookarounds: list.drop(state.lookarounds, 1),
        ),
      )
    _ ->
      case string.pop_grapheme(pattern) {
        Ok(#(first, rest)) -> rewrite_loop(rest, emit(state, first))
        Error(Nil) -> rewrite_loop("", state)
      }
  }
}

// After `(*`: a lowercase name with a colon opens a group, such as `(*pla:`
// or `(*atomic:`. Anything else is a verb such as `(*MARK:x)`, which is not a
// group.
fn rewrite_star_item(rest: String, state: Rewrite) -> #(String, Bool) {
  let group = case string.split_once(rest, on: ":") {
    Ok(#(name, after)) ->
      case
        name != ""
        && string.lowercase(name) == name
        && !string.contains(name, ")")
      {
        True -> Ok(#(name, after))
        False -> Error(Nil)
      }
    Error(Nil) -> Error(Nil)
  }
  case group {
    Ok(#(name, after)) -> {
      let opener = "(*" <> name <> ":"
      let state = case list.contains(lookaround_names, name) {
        True -> open_lookaround(state, opener)
        False -> open_group(state, opener)
      }
      rewrite_loop(after, state)
    }
    Error(Nil) -> {
      let #(verb, after) = take_through(rest, ")")
      rewrite_loop(after, emit(state, "(*" <> verb))
    }
  }
}

const lookaround_names: List(String) = [
  "pla", "plb", "nla", "nlb", "napla", "naplb", "positive_lookahead",
  "positive_lookbehind", "negative_lookahead", "negative_lookbehind",
  "non_atomic_positive_lookahead", "non_atomic_positive_lookbehind",
]

// The text up to and including the first `end`, and the rest. All of it when
// `end` does not occur.
fn take_through(text: String, end: String) -> #(String, String) {
  case string.split_once(text, on: end) {
    Ok(#(before, after)) -> #(before <> end, after)
    Error(Nil) -> #(text, "")
  }
}

// The rest of a character class after its `[`, through the `]` that closes
// it: a `]` right after `[` or `[^` is a literal, a backslash escapes the next
// character and `[:alpha:]` is a POSIX class.
fn take_class(text: String) -> #(String, String) {
  let #(start, rest) = case text {
    "^]" <> rest -> #("^]", rest)
    "]" <> rest -> #("]", rest)
    "^" <> rest -> #("^", rest)
    _ -> #("", text)
  }
  take_class_loop(rest, string_tree.from_string(start))
}

fn take_class_loop(
  text: String,
  done: string_tree.StringTree,
) -> #(String, String) {
  case text {
    "" -> #(string_tree.to_string(done), "")
    "]" <> rest -> #(string_tree.to_string(string_tree.append(done, "]")), rest)
    "[:" <> rest ->
      case string.split_once(rest, on: ":]") {
        Ok(#(name, after)) ->
          take_class_loop(after, string_tree.append(done, "[:" <> name <> ":]"))
        Error(Nil) -> take_class_loop(rest, string_tree.append(done, "[:"))
      }
    "\\" <> rest ->
      case string.pop_grapheme(rest) {
        Ok(#(escaped, rest)) ->
          take_class_loop(rest, string_tree.append(done, "\\" <> escaped))
        Error(Nil) -> #(
          string_tree.to_string(string_tree.append(done, "\\")),
          "",
        )
      }
    _ ->
      case string.pop_grapheme(text) {
        Ok(#(first, rest)) ->
          take_class_loop(rest, string_tree.append(done, first))
        Error(Nil) -> #(string_tree.to_string(done), "")
      }
  }
}

// Splits off the `(*NAME)` items at the start of a pattern that set options,
// such as `(*UTF)`, `(*CR)` and `(*LIMIT_MATCH=10)`. Backtracking verbs such
// as `(*FAIL)` are valid anywhere and stay in the body.
fn split_leading_verbs(pattern: String, verbs: String) -> #(String, String) {
  let split = case pattern {
    "(*" <> rest -> string.split_once(rest, on: ")")
    _ -> Error(Nil)
  }
  case split {
    Ok(#(name, body)) ->
      case is_start_verb(name) {
        True -> split_leading_verbs(body, verbs <> "(*" <> name <> ")")
        False -> #(verbs, pattern)
      }
    Error(Nil) -> #(verbs, pattern)
  }
}

fn is_start_verb(name: String) -> Bool {
  let backtracking = ["ACCEPT", "FAIL", "F", "COMMIT", "PRUNE", "SKIP", "THEN"]
  name != ""
  && !list.contains(backtracking, name)
  && list.all(string.to_utf_codepoints(name), fn(codepoint) {
    case string.utf_codepoint_to_int(codepoint) {
      // A-Z, 0-9, `_` and `=`.
      code if code >= 0x41 && code <= 0x5A -> True
      code if code >= 0x30 && code <= 0x39 -> True
      0x5F | 0x3D -> True
      _ -> False
    }
  })
}

// Whether a `\Q` quote is still open at the end of the pattern, read as a
// list of codepoints. Inside a quote only `\E` is special; outside it a
// backslash escapes the next character.
fn ends_inside_quote(codepoints: List(Int), quoted quoted: Bool) -> Bool {
  case codepoints, quoted {
    [], _ -> quoted
    [0x5C, 0x45, ..rest], True -> ends_inside_quote(rest, quoted: False)
    [_, ..rest], True -> ends_inside_quote(rest, quoted: True)
    [0x5C, 0x51, ..rest], False -> ends_inside_quote(rest, quoted: True)
    [0x5C, _, ..rest], False | [_, ..rest], False ->
      ends_inside_quote(rest, quoted: False)
  }
}

// Parsing and normalising ---------------------------------------------------

/// Parses a string as a float.
///
/// Accepts an optional leading `-`, digits, an optional fraction of a dot and
/// digits, and an optional exponent of `e` or `E`, an optional sign and
/// digits. Integers such as `"42"` are accepted. Anything else, including
/// commas, spaces, a leading `+` or a leading dot, is rejected, as is a value
/// too large for a finite float. Every zero parses as `0.0`.
///
/// ## Examples
///
/// ```gleam
/// dataprep.parse_float("1.5e-2")
/// // -> Ok(0.015)
/// ```
///
/// ```gleam
/// dataprep.parse_float("3,000")
/// // -> Error(Nil)
/// ```
///
pub fn parse_float(raw: String) -> Result(Float, Nil) {
  use <- bool.guard(when: !float_grammar_matches(raw), return: Error(Nil))
  case float.parse(raw) {
    Ok(value) -> finite(value)
    Error(Nil) ->
      case is_integer_literal(raw) {
        True -> parse_finite(raw <> ".0")
        False -> parse_scientific(raw)
      }
  }
}

// Grammar: `-?digits(.digits)?([eE][+-]?digits)?`, end to end.
fn float_grammar_matches(raw: String) -> Bool {
  let unsigned = case raw {
    "-" <> rest -> rest
    _ -> raw
  }
  case skip_digits(unsigned, seen: False) {
    Ok(rest) -> fraction_matches(rest)
    Error(Nil) -> False
  }
}

fn fraction_matches(rest: String) -> Bool {
  case rest {
    "." <> fraction ->
      case skip_digits(fraction, seen: False) {
        Ok(after) -> exponent_matches(after)
        Error(Nil) -> False
      }
    _ -> exponent_matches(rest)
  }
}

fn exponent_matches(rest: String) -> Bool {
  case rest {
    "" -> True
    "e" <> exponent | "E" <> exponent -> {
      let digits = case exponent {
        "+" <> unsigned | "-" <> unsigned -> unsigned
        _ -> exponent
      }
      skip_digits(digits, seen: False) == Ok("")
    }
    _ -> False
  }
}

// Drops leading ASCII digits. Fails when there is not at least one.
fn skip_digits(input: String, seen seen: Bool) -> Result(String, Nil) {
  case input {
    "0" <> rest
    | "1" <> rest
    | "2" <> rest
    | "3" <> rest
    | "4" <> rest
    | "5" <> rest
    | "6" <> rest
    | "7" <> rest
    | "8" <> rest
    | "9" <> rest -> skip_digits(rest, seen: True)
    _ if seen -> Ok(input)
    _ -> Error(Nil)
  }
}

// The largest finite IEEE 754 double.
const max_finite_float = 1.7976931348623157e308

// Every accepted shape is rewritten into the `digits.digits[e..]` form that
// `float.parse` reads on both targets, so the target's own correctly rounded
// parser does the work and nothing is multiplied here. On overflow Erlang's
// parser fails and JavaScript's returns Infinity; the magnitude check maps
// both to `Error(Nil)`.
fn parse_scientific(raw: String) -> Result(Float, Nil) {
  case string.split_once(string.lowercase(raw), on: "e") {
    Error(Nil) -> Error(Nil)
    Ok(#(mantissa, exponent)) ->
      case is_integer_literal(mantissa) {
        True -> parse_finite(mantissa <> ".0e" <> exponent)
        False -> Error(Nil)
      }
  }
}

// An optional `-` followed by ASCII digits. Checked by scanning instead of
// `int.parse`, which would build a bignum for a huge digit string.
fn is_integer_literal(raw: String) -> Bool {
  let digits = case raw {
    "-" <> rest -> rest
    _ -> raw
  }
  skip_digits(digits, seen: False) == Ok("")
}

fn parse_finite(raw: String) -> Result(Float, Nil) {
  result.try(float.parse(raw), finite)
}

fn finite(value: Float) -> Result(Float, Nil) {
  use <- bool.guard(
    when: float.absolute_value(value) >. max_finite_float,
    return: Error(Nil),
  )
  // Erlang keeps the sign of `-0.0`, which is not equal to `0.0` on OTP 27
  // and later; report every zero as `0.0`.
  case value == 0.0 || value == -0.0 {
    True -> Ok(0.0)
    False -> Ok(value)
  }
}

/// Replaces every run of ASCII whitespace with a single space.
///
/// ASCII whitespace is tab, line feed, vertical tab, form feed, carriage
/// return and space. Other whitespace, such as the ideographic space U+3000
/// between Japanese names, is kept; use `collapse_unicode_space` to fold it
/// too.
///
/// ## Examples
///
/// ```gleam
/// dataprep.collapse_space("a \t\n b")
/// // -> "a b"
/// ```
///
pub fn collapse_space(text: String) -> String {
  collapse_runs(text, of: is_ascii_whitespace)
}

/// Replaces every run of Unicode whitespace with a single ASCII space.
///
/// Unicode whitespace is the White_Space property, which includes the
/// no-break space U+00A0, the ideographic space U+3000 and the line and
/// paragraph separators. U+FEFF is not whitespace.
///
/// ## Examples
///
/// ```gleam
/// dataprep.collapse_unicode_space("姓\u{3000}\u{3000}名")
/// // -> "姓 名"
/// ```
///
pub fn collapse_unicode_space(text: String) -> String {
  collapse_runs(text, of: is_unicode_whitespace)
}

// Tab, line feed, vertical tab, form feed, carriage return, space.
fn is_ascii_whitespace(codepoint: Int) -> Bool {
  case codepoint {
    0x09 | 0x0A | 0x0B | 0x0C | 0x0D | 0x20 -> True
    _ -> False
  }
}

// The Unicode White_Space property. U+FEFF is not in it.
fn is_unicode_whitespace(codepoint: Int) -> Bool {
  case codepoint {
    0x85 | 0xA0 | 0x1680 | 0x2028 | 0x2029 | 0x202F | 0x205F | 0x3000 -> True
    _ ->
      is_ascii_whitespace(codepoint)
      || { codepoint >= 0x2000 && codepoint <= 0x200A }
  }
}

// One pass over the codepoints: characters that are not whitespace are
// gathered into words, and each run of whitespace becomes one space.
fn collapse_runs(text: String, of is_space: fn(Int) -> Bool) -> String {
  let #(tree, word, _) =
    list.fold(
      string.to_utf_codepoints(text),
      #(string_tree.new(), [], False),
      fn(state, codepoint) {
        let #(tree, word, in_run) = state
        case is_space(string.utf_codepoint_to_int(codepoint)), in_run {
          True, True -> #(tree, [], True)
          True, False -> #(
            tree |> flush_word(word) |> string_tree.append(" "),
            [],
            True,
          )
          False, _ -> #(tree, [codepoint, ..word], False)
        }
      },
    )
  tree |> flush_word(word) |> string_tree.to_string
}

fn flush_word(
  tree: string_tree.StringTree,
  reversed_word: List(UtfCodepoint),
) -> string_tree.StringTree {
  case reversed_word {
    [] -> tree
    _ ->
      string_tree.append(
        tree,
        string.from_utf_codepoints(list.reverse(reversed_word)),
      )
  }
}

# Recipe: Query Parameter Validation

Validate HTTP query parameters where values arrive as strings
and must be parsed into typed values before validation.
Uses `dataprep/parse` to eliminate manual `int.parse` boilerplate.

```gleam
import dataprep/parse
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator

pub type SearchQuery {
  SearchQuery(query: String, page: Int, per_page: Int)
}

pub type ParamError {
  Param(name: String, detail: ParamDetail)
}

pub type ParamDetail {
  Missing
  NotAnInteger(raw: String)
  TooSmall(min: Int)
  TooBig(max: Int)
}

// --- Field processors ---

fn validate_query(raw: String) -> Validated(String, ParamError) {
  let clean = prep.trim()
  let check =
    rules.not_blank(Missing)
    |> validator.label("q", Param)

  raw |> clean |> check
}

fn validate_page(raw: String) -> Validated(Int, ParamError) {
  parse.int(prep.trim()(raw), NotAnInteger)
  |> validated.map_error(fn(e) { Param("page", e) })
  |> validated.and_then(
    rules.min_int(1, TooSmall(1))
    |> validator.label("page", Param),
  )
}

fn validate_per_page(raw: String) -> Validated(Int, ParamError) {
  parse.int(prep.trim()(raw), NotAnInteger)
  |> validated.map_error(fn(e) { Param("per_page", e) })
  |> validated.and_then(
    rules.min_int(1, TooSmall(1))
    |> validator.both(rules.max_int(100, TooBig(100)))
    |> validator.label("per_page", Param),
  )
}

// --- Combine ---

pub fn validate_search(
  query: String,
  page: String,
  per_page: String,
) -> Validated(SearchQuery, ParamError) {
  validated.map3(
    SearchQuery,
    validate_query(query),
    validate_page(page),
    validate_per_page(per_page),
  )
}

// validate_search("", "abc", "200")
//   -> Invalid([
//        Param("q", Missing),
//        Param("page", NotAnInteger("abc")),
//        Param("per_page", TooBig(100)),
//      ])
//
// validate_search("gleam", "1", "25")
//   -> Valid(SearchQuery("gleam", 1, 25))
```

Key patterns used:
- `parse.int` instead of manual `int.parse |> result.map_error |> validated.from_result`
- `rules.not_blank` instead of `rules.not_empty` (rejects whitespace-only)
- `validated.and_then` to chain parsing (type-changing) with validation
- `validator.label` with a `Param` wrapper for structured errors
- `validated.map3` to combine independent fields

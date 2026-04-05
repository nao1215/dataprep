# Recipe: CSV Row Validation

Validate a row of CSV data where all values arrive as strings.
Demonstrates preprocessing, parsing, and multi-field accumulation.

```gleam
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator
import gleam/float
import gleam/int
import gleam/result

pub type Product {
  Product(name: String, quantity: Int, price: Float)
}

pub type RowError {
  Cell(column: String, detail: CellDetail)
}

pub type CellDetail {
  Empty
  TooLong(max: Int)
  NotAnInteger(raw: String)
  NotAFloat(raw: String)
  Negative
}

// --- Parse helpers ---

fn parse_int(raw: String, col: String) -> Validated(Int, RowError) {
  raw
  |> int.parse
  |> result.map_error(fn(_) { Cell(col, NotAnInteger(raw)) })
  |> validated.from_result
}

fn parse_float(raw: String, col: String) -> Validated(Float, RowError) {
  raw
  |> float.parse
  |> result.map_error(fn(_) { Cell(col, NotAFloat(raw)) })
  |> validated.from_result
}

// --- Field processors ---

fn validate_name(raw: String) -> Validated(String, RowError) {
  let clean = prep.trim()
  let check =
    rules.not_empty(Empty)
    |> validator.guard(rules.max_length(100, TooLong(100)))
    |> validator.label("name", Cell)

  raw |> clean |> check
}

fn validate_quantity(raw: String) -> Validated(Int, RowError) {
  let cleaned = prep.trim()(raw)
  parse_int(cleaned, "quantity")
  |> validated.and_then(
    rules.min_int(0, Negative)
    |> validator.label("quantity", Cell),
  )
}

fn validate_price(raw: String) -> Validated(Float, RowError) {
  let cleaned = prep.trim()(raw)
  parse_float(cleaned, "price")
  |> validated.and_then(
    validator.predicate(fn(x) { x >=. 0.0 }, Negative)
    |> validator.label("price", Cell),
  )
}

// --- Combine ---

pub fn validate_row(
  name: String,
  quantity: String,
  price: String,
) -> Validated(Product, RowError) {
  validated.map3(
    Product,
    validate_name(name),
    validate_quantity(quantity),
    validate_price(price),
  )
}

// validate_row("", "abc", "-1.5")
//   -> Invalid([
//        Cell("name", Empty),
//        Cell("quantity", NotAnInteger("abc")),
//        Cell("price", Negative),
//      ])
//
// validate_row("  Widget  ", "10", "29.99")
//   -> Valid(Product("Widget", 10, 29.99))
```

Key patterns used:
- `prep.trim()` applied inline before parsing
- `validated.from_result` to bridge `int.parse` / `float.parse`
- `validated.and_then` to chain parse-then-validate for each cell
- `validator.label` with `Cell` wrapper for column-level error context
- `validated.map3` to accumulate errors across all columns in a row

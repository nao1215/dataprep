# Recipe: CSV Row Validation

Validate a row of CSV data where all values arrive as strings.
Uses `dataprep/parse` for type conversion and `validated.traverse_indexed`
for batch row validation with row-level error context.

```gleam
import dataprep/parse
import dataprep/prep
import dataprep/rules
import dataprep/validated.{type Validated}
import dataprep/validator

pub type Product {
  Product(name: String, quantity: Int, price: Float)
}

pub type RowError {
  Cell(column: String, detail: CellDetail)
}

pub type BatchError {
  Row(index: Int, detail: RowError)
}

pub type CellDetail {
  Empty
  TooLong(max: Int)
  NotAnInteger(raw: String)
  NotAFloat(raw: String)
  Negative
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
  parse.int(prep.trim()(raw), NotAnInteger)
  |> validated.map_error(fn(e) { Cell("quantity", e) })
  |> validated.and_then(
    rules.non_negative_int(Negative)
    |> validator.label("quantity", Cell),
  )
}

fn validate_price(raw: String) -> Validated(Float, RowError) {
  parse.float(prep.trim()(raw), NotAFloat)
  |> validated.map_error(fn(e) { Cell("price", e) })
  |> validated.and_then(
    rules.non_negative_float(Negative)
    |> validator.label("price", Cell),
  )
}

// --- Single row ---

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

// --- Batch: validate multiple rows ---
// Uses traverse_indexed to attach row numbers to errors.

pub type RawRow {
  RawRow(name: String, quantity: String, price: String)
}

pub fn validate_rows(
  rows: List(RawRow),
) -> Validated(List(Product), BatchError) {
  validated.traverse_indexed(rows, fn(row, i) {
    validate_row(row.name, row.quantity, row.price)
    |> validated.map_error(fn(e) { Row(i, e) })
  })
}

// validate_rows([
//   RawRow("Widget", "10", "29.99"),
//   RawRow("", "abc", "-1.0"),
// ])
//   -> Invalid([
//        Row(1, Cell("name", Empty)),
//        Row(1, Cell("quantity", NotAnInteger("abc"))),
//        Row(1, Cell("price", Negative)),
//      ])
```

Key patterns used:
- `parse.int` / `parse.float` instead of manual boilerplate
- `rules.non_negative_int` / `rules.non_negative_float` for cleaner range checks
- `validated.traverse_indexed` for batch validation with row index in errors
- `validator.label` with `Cell` wrapper for column-level error context
- `validated.map3` to accumulate errors across all columns in a row

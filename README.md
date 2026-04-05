# dataprep

[![CI](https://github.com/nao1215/dataprep/actions/workflows/ci.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/dataprep)](https://hex.pm/packages/dataprep)


![dataprep_logo](./doc/img/dataprep-logo-small.png)

Composable, type-driven preprocessing and validation combinator library for Gleam.

dataprep is a combinator toolkit, not a rule catalog.

- Built-in and user-defined rules are identical in power.
- No domain-specific rules (email, URL, UUID). Write your own or use a dedicated package.
- No schema, no DSL, no reflection.
- Prep transforms. Validator checks. They do not mix.
- Errors are your types, not ours.

## Requirements

- Gleam 1.15 or later
- Erlang/OTP 27 or later

## Install

```sh
gleam add dataprep
```

## Quick start

```gleam
import dataprep/prep
import dataprep/validated.{type Validated}
import dataprep/rules

pub type User {
  User(name: String, age: Int)
}

pub type Err {
  NameEmpty
  AgeTooYoung
}

pub fn validate_user(name: String, age: Int) -> Validated(User, Err) {
  let clean = prep.trim() |> prep.then(prep.lowercase())
  let check_name = rules.not_empty(NameEmpty)
  let check_age = rules.min_int(0, AgeTooYoung)

  validated.map2(
    User,
    name |> clean |> check_name,
    check_age(age),
  )
}

// validate_user("  Alice ", 25)   -> Valid(User("alice", 25))
// validate_user("", -1)           -> Invalid([NameEmpty, AgeTooYoung])
```

## Modules

| Module | Responsibility |
|--------|---------------|
| `dataprep/prep` | Infallible transformations: `trim`, `lowercase`, `uppercase`, `collapse_space`, `replace`, `default`. Compose with `then` or `sequence`. |
| `dataprep/validator` | Checks without transformation: `check`, `predicate`, `both`, `all`, `alt`, `guard`, `map_error`, `label`. |
| `dataprep/validated` | Applicative error accumulation: `map`, `map_error`, `and_then`, `from_result`, `to_result`, `map2`..`map5`. |
| `dataprep/non_empty_list` | At-least-one guarantee for error lists: `single`, `cons`, `append`, `concat`, `map`, `flat_map`, `to_list`, `from_list`. |
| `dataprep/rules` | Built-in rules: `not_empty`, `min_length`, `max_length`, `min_int`, `max_int`, `one_of`, `equals`. |

## Composition overview

| Phase | Combinator | Errors | When to use |
|-------|-----------|--------|-------------|
| Prep | `prep.then` | (none) | Chain infallible transforms |
| Validate | `validator.both` / `all` | Accumulate all | Independent checks on same value |
| Validate | `validator.alt` | Accumulate on full failure | Accept alternative forms |
| Validate | `validator.guard` | Short-circuit | Skip if prerequisite fails |
| Combine | `validated.map2`..`map5` | Accumulate all | Build domain types from independent fields |
| Bridge | `validated.and_then` | Short-circuit | Parse then validate (type changes) |
| Bridge | `raw \|> prep \|> validator` | (prep has none) | Apply infallible transform before validation |

## Development

This project uses [mise](https://mise.jdx.dev/) to manage Gleam and Erlang versions, and [just](https://just.systems/) as a task runner.

```sh
mise install    # install Gleam and Erlang
just ci         # format check, typecheck, build, test
just test       # gleam test
just format     # gleam format
just check      # all checks without deps download
```

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

[MIT](LICENSE)

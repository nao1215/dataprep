# dataprep

[![CI](https://github.com/nao1215/dataprep/actions/workflows/ci.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/ci.yml)
[![Gitleaks](https://github.com/nao1215/dataprep/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/gitleaks.yml)
[![Trivy](https://github.com/nao1215/dataprep/actions/workflows/trivy.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/trivy.yml)
[![OSV-Scanner](https://github.com/nao1215/dataprep/actions/workflows/osv-scan.yml/badge.svg)](https://github.com/nao1215/dataprep/actions/workflows/osv-scan.yml)
[![Hex](https://img.shields.io/hexpm/v/dataprep)](https://hex.pm/packages/dataprep)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/dataprep/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/dataprep)](https://hex.pm/packages/dataprep)
[![License](https://img.shields.io/github/license/nao1215/dataprep)](https://github.com/nao1215/dataprep/blob/main/LICENSE)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/nao1215/dataprep/badge)](https://scorecard.dev/viewer/?uri=github.com/nao1215/dataprep)

![dataprep_logo](https://raw.githubusercontent.com/nao1215/dataprep/main/doc/img/dataprep-logo-small.png)

Composable validation for Gleam. A validator is a function from a value to `Result(value, NonEmptyList(error))`, errors are your own types, and independent checks report every failure at once. It runs on Erlang and JavaScript.

```sh
gleam add dataprep@0 non_empty_list@2
```

## Example

```gleam
import dataprep
import gleam/string
import non_empty_list.{type NonEmptyList}

pub type User {
  User(name: String, age: Int)
}

pub type FormError {
  NameMissing
  TooYoung(minimum: Int)
}

pub fn validate_user(
  name: String,
  age: Int,
) -> Result(User, NonEmptyList(FormError)) {
  let check_name = dataprep.not_blank(NameMissing)
  let check_age = dataprep.min_int(minimum: 18, error: TooYoung(18))
  dataprep.map2(check_name(string.trim(name)), check_age(age), with: User)
}

// validate_user("Ada", 36)
// -> Ok(User("Ada", 36))
// validate_user(" ", 12)
// -> Error(NonEmptyList(NameMissing, [TooYoung(18)]))
```

`map2` to `map5` combine independent results and keep every error. `both` and `all` run several validators on one value and also keep every error, while `and_then` stops at the first failure:

```gleam
pub type NameError {
  Empty
  TooLong
  NotASlug
}

pub fn validate_slug(raw: String) -> Result(String, NonEmptyList(NameError)) {
  let assert Ok(slug) = dataprep.full_match("[a-z0-9-]+", error: NotASlug)
  let check =
    dataprep.not_empty(Empty)
    |> dataprep.and_then(
      then: dataprep.all([
        dataprep.max_length(maximum: 32, error: TooLong),
        slug,
      ]),
    )
  check(raw)
}

// validate_slug("my-post")
// -> Ok("my-post")
// validate_slug("")
// -> Error(NonEmptyList(Empty, []))
```

Errors are built with the [`non_empty_list`](https://hexdocs.pm/non_empty_list/) package, so you can pattern match on `NonEmptyList(first:, rest:)` or turn them into a list with `non_empty_list.to_list`. Parsing and normalising are left to the standard library (`string.trim`, `int.parse`), plus `dataprep.parse_float` for strict decimal input and `collapse_space` / `collapse_unicode_space` for whitespace.

Further documentation can be found at <https://hexdocs.pm/dataprep>.

## Verifying releases

Each GitHub Release attaches the Hex package tarball (`dataprep-<version>.tar`),
`checksums.txt`, a cosign signature bundle (`checksums.txt.sigstore.json`) and
build provenance (`dataprep-<version>.intoto.jsonl`). Download the assets, then:

```sh
gh attestation verify dataprep-<version>.tar --repo nao1215/dataprep

cosign verify-blob \
  --bundle checksums.txt.sigstore.json \
  --certificate-identity-regexp '^https://github\.com/nao1215/dataprep/\.github/workflows/release\.yml@refs/tags/v' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  checksums.txt
sha256sum --check checksums.txt
```

## License

[MIT](https://github.com/nao1215/dataprep/blob/main/LICENSE)

//// The examples in README.md, kept here so they keep compiling and
//// keep giving the results the README shows.

import dataprep
import gleam/string
import non_empty_list.{type NonEmptyList, NonEmptyList}

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

pub fn readme_validate_user_test() -> Nil {
  assert validate_user("Ada", 36) == Ok(User("Ada", 36))
  assert validate_user(" ", 12)
    == Error(NonEmptyList(NameMissing, [TooYoung(18)]))
}

pub fn readme_validate_slug_test() -> Nil {
  assert validate_slug("my-post") == Ok("my-post")
  assert validate_slug("") == Error(NonEmptyList(Empty, []))
  assert validate_slug("My Post") == Error(NonEmptyList(NotASlug, []))
}

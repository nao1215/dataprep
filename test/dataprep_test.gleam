import dataprep.{type NonEmptyList, type Prep, type Validated, type Validator}
import dataprep/non_empty_list
import dataprep/prep
import dataprep/validated
import dataprep/validator
import gleeunit

fn api_type_aliases_compile() -> #(
  Prep(String),
  Validator(String, Nil),
  Validated(String, Nil),
  NonEmptyList(String),
) {
  #(
    prep.identity(),
    validator.predicate(fn(_: String) { True }, Nil),
    validated.Valid("ok"),
    non_empty_list.single("ok"),
  )
}

pub fn main() -> Nil {
  let #(prep_alias, validator_alias, validated_alias, non_empty_list_alias) =
    api_type_aliases_compile()
  let assert "ok" = prep_alias("ok")
  let assert validated.Valid("ok") = validator_alias("ok")
  let assert validated.Valid("ok") = validated_alias
  let assert ["ok"] = non_empty_list.to_list(non_empty_list_alias)
  gleeunit.main()
}

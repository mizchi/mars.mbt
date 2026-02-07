///|
test "jwt_extract_bearer_token_valid" {
  assert_eq(extract_bearer_token("Bearer abc"), Some("abc"))
}

///|
type ClaimsMap = Map[String, Json]

///|
test "jwt_extract_bearer_token_invalid" {
  assert_eq(extract_bearer_token("Basic abc"), None)
}

///|
test "jwt_extract_bearer_token_empty" {
  assert_eq(extract_bearer_token("Bearer "), None)
}

///|
test "jwt_decode_claims_from_string_map" {
  let result : Result[ClaimsMap, JwtClaimsError] = jwt_claims_decode_string(
    "{\"sub\":\"123\",\"exp\":2000}",
  )
  match result {
    Ok(obj) =>
      match obj.get("sub") {
        Some(String(value)) => assert_eq(value, "123")
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "jwt_decode_claims_from_string_invalid_json" {
  let result : Result[ClaimsMap, JwtClaimsError] = jwt_claims_decode_string("{")
  match result {
    Err(JwtClaimsError::InvalidJson) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "jwt_decode_claims_from_string_not_object" {
  let result : Result[ClaimsMap, JwtClaimsError] = jwt_claims_decode_string(
    "[1,2]",
  )
  match result {
    Err(JwtClaimsError::NotObject) => assert_true(true)
    _ => assert_true(false)
  }
}

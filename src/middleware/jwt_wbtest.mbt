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
test "jwt_verify_token_with_key_hs256" {
  let secret = @utf8.encode("secret")
  let sign_key = @jwt.SignKey::hs256(secret)
  let token = @jwt.sign("{\"sub\":\"123\",\"exp\":2000}", sign_key)
  let key = @jwt.Key::hs256(secret)
  let opts = @jwt.VerifyOptions::new(1000, clock_skew_sec=0, require_exp=true)
  let claims_json = verify_token_with_key(token, key, opts)
  let json = @json.parse(claims_json)
  guard json is Object(obj) else {
    assert_true(false)
    return
  }
  match obj.get("sub") {
    Some(String(value)) => assert_eq(value, "123")
    _ => assert_true(false)
  }
  match obj.get("exp") {
    Some(Number(value, ..)) => assert_eq(value.to_int(), 2000)
    _ => assert_true(false)
  }
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

///|
/// JWT verification options for middleware
pub(all) struct JwtOptions {
  clock_skew_sec : Int64
  require_exp : Bool
  issuer : String?
  audience : String?
  claims_key : String
  error_message : String
  error_status : Int
}

///|
/// Default JWT options
pub fn JwtOptions::default() -> JwtOptions {
  {
    clock_skew_sec: 0,
    require_exp: true,
    issuer: None,
    audience: None,
    claims_key: "jwt_claims",
    error_message: "Unauthorized",
    error_status: 401,
  }
}

///|
/// Errors when reading JWT claims from context
pub(all) enum JwtClaimsError {
  MissingClaims
  InvalidJson
  NotObject
  Decode(@json.JsonDecodeError)
} derive(Show)

///|
fn parse_claims_json_string(
  claims_json : String,
) -> Result[Json, JwtClaimsError] {
  let json = @json.parse(claims_json) catch {
    _ => return Err(JwtClaimsError::InvalidJson)
  }
  Ok(json)
}

///|
fn claims_json_from_ctx(
  ctx : @mars.Context,
  key : String,
) -> Result[Json, JwtClaimsError] {
  guard ctx.get(key) is Some(value) else {
    return Err(JwtClaimsError::MissingClaims)
  }
  parse_claims_json_string(value)
}

///|
fn claims_object_from_json(
  json : Json,
) -> Result[Map[String, Json], JwtClaimsError] {
  guard json is Object(obj) else { return Err(JwtClaimsError::NotObject) }
  Ok(obj)
}

///|
fn[T : @json.FromJson] decode_claims_from_json(
  json : Json,
) -> Result[T, JwtClaimsError] {
  guard json is Object(_) else { return Err(JwtClaimsError::NotObject) }
  let value : T = @json.from_json(json) catch {
    e => return Err(JwtClaimsError::Decode(e))
  }
  Ok(value)
}

///|
pub fn[T : @json.FromJson] jwt_claims_decode_string(
  claims_json : String,
) -> Result[T, JwtClaimsError] {
  match parse_claims_json_string(claims_json) {
    Ok(json) => decode_claims_from_json(json)
    Err(err) => Err(err)
  }
}

///|
/// Parse claims JSON stored in context
pub fn jwt_claims_json(
  ctx : @mars.Context,
  key? : String = "jwt_claims",
) -> Result[Json, JwtClaimsError] {
  claims_json_from_ctx(ctx, key)
}

///|
/// Parse claims as map stored in context
pub fn jwt_claims_map(
  ctx : @mars.Context,
  key? : String = "jwt_claims",
) -> Result[Map[String, Json], JwtClaimsError] {
  match claims_json_from_ctx(ctx, key) {
    Ok(json) => claims_object_from_json(json)
    Err(err) => Err(err)
  }
}

///|
/// Decode claims into a typed value
pub fn[T : @json.FromJson] jwt_claims_decode(
  ctx : @mars.Context,
  key? : String = "jwt_claims",
) -> Result[T, JwtClaimsError] {
  guard ctx.get(key) is Some(value) else {
    return Err(JwtClaimsError::MissingClaims)
  }
  jwt_claims_decode_string(value)
}

///|
fn extract_bearer_token(_auth : String) -> String? {
  if _auth.has_prefix("Bearer ") {
    let token = safe_substring_from(_auth, 7)
    if token == "" {
      None
    } else {
      Some(token)
    }
  } else {
    None
  }
}

///|
async fn respond_unauthorized(
  ctx : @mars.Context,
  options : JwtOptions,
) -> Unit {
  ctx.text(options.error_message, status=options.error_status)
}

///|
/// JWT verification is intentionally deferred.
/// This middleware currently always rejects requests.
pub fn[T] jwt_bearer_with_key(
  _key : T,
  _now : () -> Int64,
  options? : JwtOptions = JwtOptions::default(),
) -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    guard ctx.header("Authorization") is Some(auth) else {
      respond_unauthorized(ctx, options)
      return
    }
    guard extract_bearer_token(auth) is Some(_token) else {
      respond_unauthorized(ctx, options)
      return
    }
    respond_unauthorized(ctx, options)
  }
}

///|
/// JWT verification is intentionally deferred.
/// This middleware currently always rejects requests.
pub fn jwt_bearer_with_jwks(
  _url : String,
  _fetch : async (String) -> String,
  _now : () -> Int64,
  _ttl_sec : Int64,
  options? : JwtOptions = JwtOptions::default(),
) -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    guard ctx.header("Authorization") is Some(auth) else {
      respond_unauthorized(ctx, options)
      return
    }
    guard extract_bearer_token(auth) is Some(_token) else {
      respond_unauthorized(ctx, options)
      return
    }
    respond_unauthorized(ctx, options)
  }
}

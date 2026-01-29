///|
/// OAuth2 Helper Functions
/// For building authorization URLs and handling token exchange

///|
/// OAuth2 provider configuration
pub(all) struct OAuth2Config {
  client_id : String
  client_secret : String
  redirect_uri : String
  authorize_url : String
  token_url : String
  scopes : Array[String]
}

///|
/// OAuth2 token response
pub(all) struct OAuth2Token {
  access_token : String
  token_type : String
  expires_in : Int
  refresh_token : String
  scope : String
}

///|
/// OAuth2 error
pub(all) enum OAuth2Error {
  InvalidResponse(String)
  MissingField(String)
} derive(Show, Eq)

///|
/// URL encode a string for OAuth2
fn url_encode_oauth2(s : String) -> String {
  let result = StringBuilder::new()
  for c in s {
    if (c >= 'A' && c <= 'Z') ||
      (c >= 'a' && c <= 'z') ||
      (c >= '0' && c <= '9') ||
      c == '-' ||
      c == '_' ||
      c == '.' ||
      c == '~' {
      result.write_char(c)
    } else {
      let byte = c.to_int()
      result.write_char('%')
      result.write_char(hex_char(byte >> 4))
      result.write_char(hex_char(byte & 0x0F))
    }
  }
  result.to_string()
}

///|
/// Get hex character
fn hex_char(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('A'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
/// Build OAuth2 authorization URL
/// state parameter is REQUIRED for CSRF protection
pub fn oauth2_authorization_url(
  config : OAuth2Config,
  state : String,
) -> String {
  let scope = join_strings(config.scopes, " ")
  let url = StringBuilder::new()
  url.write_string(config.authorize_url)
  url.write_string("?client_id=")
  url.write_string(url_encode_oauth2(config.client_id))
  url.write_string("&redirect_uri=")
  url.write_string(url_encode_oauth2(config.redirect_uri))
  url.write_string("&response_type=code")
  if not(scope.is_empty()) {
    url.write_string("&scope=")
    url.write_string(url_encode_oauth2(scope))
  }
  // State is always included for CSRF protection
  url.write_string("&state=")
  url.write_string(url_encode_oauth2(state))
  url.to_string()
}

///|
/// Generate a secure random state for OAuth2 CSRF protection
pub fn oauth2_generate_state() -> String {
  let rng = @random.Rand::chacha8()
  let buf = StringBuilder::new()
  for i = 0; i < 16; i = i + 1 {
    let byte = rng.uint(limit=256).to_int()
    buf.write_char(hex_char(byte >> 4))
    buf.write_char(hex_char(byte & 0x0F))
  }
  buf.to_string()
}

///|
/// Build OAuth2 token request body (form-encoded)
pub fn oauth2_token_request_body(
  config : OAuth2Config,
  code : String,
) -> String {
  let body = StringBuilder::new()
  body.write_string("grant_type=authorization_code")
  body.write_string("&code=")
  body.write_string(url_encode_oauth2(code))
  body.write_string("&redirect_uri=")
  body.write_string(url_encode_oauth2(config.redirect_uri))
  body.write_string("&client_id=")
  body.write_string(url_encode_oauth2(config.client_id))
  body.write_string("&client_secret=")
  body.write_string(url_encode_oauth2(config.client_secret))
  body.to_string()
}

///|
/// Build OAuth2 refresh token request body
pub fn oauth2_refresh_request_body(
  config : OAuth2Config,
  refresh_token : String,
) -> String {
  let body = StringBuilder::new()
  body.write_string("grant_type=refresh_token")
  body.write_string("&refresh_token=")
  body.write_string(url_encode_oauth2(refresh_token))
  body.write_string("&client_id=")
  body.write_string(url_encode_oauth2(config.client_id))
  body.write_string("&client_secret=")
  body.write_string(url_encode_oauth2(config.client_secret))
  body.to_string()
}

///|
/// Parse OAuth2 token response JSON
pub fn oauth2_parse_token(
  json_str : String,
) -> Result[OAuth2Token, OAuth2Error] {
  let json = @json.parse(json_str) catch {
    _ => return Err(OAuth2Error::InvalidResponse("Invalid JSON"))
  }
  guard json is Object(obj) else {
    return Err(OAuth2Error::InvalidResponse("Expected JSON object"))
  }
  let access_token = match obj.get("access_token") {
    Some(String(s)) => s
    _ => return Err(OAuth2Error::MissingField("access_token"))
  }
  let token_type = match obj.get("token_type") {
    Some(String(s)) => s
    _ => "Bearer"
  }
  let expires_in = match obj.get("expires_in") {
    Some(Number(n, ..)) => n.to_int()
    _ => 3600
  }
  let refresh_token = match obj.get("refresh_token") {
    Some(String(s)) => s
    _ => ""
  }
  let scope = match obj.get("scope") {
    Some(String(s)) => s
    _ => ""
  }
  Ok({ access_token, token_type, expires_in, refresh_token, scope })
}

///|
/// Join strings with separator
fn join_strings(arr : Array[String], sep : String) -> String {
  if arr.is_empty() {
    return ""
  }
  let result = StringBuilder::new()
  for i, s in arr {
    if i > 0 {
      result.write_string(sep)
    }
    result.write_string(s)
  }
  result.to_string()
}

///|
/// Create GitHub OAuth2 config
pub fn oauth2_github(
  client_id : String,
  client_secret : String,
  redirect_uri : String,
  scopes? : Array[String] = ["read:user", "user:email"],
) -> OAuth2Config {
  {
    client_id,
    client_secret,
    redirect_uri,
    authorize_url: "https://github.com/login/oauth/authorize",
    token_url: "https://github.com/login/oauth/access_token",
    scopes,
  }
}

///|
/// Create Google OAuth2 config
pub fn oauth2_google(
  client_id : String,
  client_secret : String,
  redirect_uri : String,
  scopes? : Array[String] = ["openid", "profile", "email"],
) -> OAuth2Config {
  {
    client_id,
    client_secret,
    redirect_uri,
    authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
    token_url: "https://oauth2.googleapis.com/token",
    scopes,
  }
}

///|
/// Bearer token middleware - validates Authorization header
pub fn oauth2_bearer(validate : (String) -> Bool) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    guard ctx.header("Authorization") is Some(auth) else {
      ctx.text("Unauthorized", status=401)
      return
    }
    if not(auth.has_prefix("Bearer ")) {
      ctx.text("Unauthorized", status=401)
      return
    }
    let token = safe_substring_from(auth, 7)
    if not(validate(token)) {
      ctx.text("Unauthorized", status=401)
    }
  }
}

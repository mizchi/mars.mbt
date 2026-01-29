///|
/// Basic Auth Middleware
/// HTTP Basic Authentication

///|
/// Basic auth options
pub(all) struct BasicAuthOptions {
  /// Realm name shown in browser dialog
  realm : String
  /// Validator function (username, password) -> Bool
  validate : (String, String) -> Bool
}

///|
/// Constant-time string comparison for auth (timing-safe)
fn constant_time_compare_auth(a : String, b : String) -> Bool {
  let len_a = a.length()
  let len_b = b.length()
  let max_len = if len_a > len_b { len_a } else { len_b }
  let mut result = len_a ^ len_b
  for i = 0; i < max_len; i = i + 1 {
    let ca = if i < len_a { a[i].to_int() } else { 0 }
    let cb = if i < len_b { b[i].to_int() } else { 0 }
    result = result | (ca ^ cb)
  }
  result == 0
}

///|
/// Create basic auth options with simple username/password check
/// Uses constant-time comparison to prevent timing attacks
pub fn BasicAuthOptions::simple(
  username : String,
  password : String,
  realm? : String = "Restricted",
) -> BasicAuthOptions {
  {
    realm,
    validate: fn(u, p) {
      constant_time_compare_auth(u, username) &&
      constant_time_compare_auth(p, password)
    },
  }
}

///|
/// Create basic auth options with custom validator
pub fn BasicAuthOptions::custom(
  validate : (String, String) -> Bool,
  realm? : String = "Restricted",
) -> BasicAuthOptions {
  { realm, validate }
}

///|
/// Basic auth middleware
pub fn basic_auth(options : BasicAuthOptions) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    guard ctx.header("Authorization") is Some(auth) else {
      send_auth_required(ctx, options.realm)
      return
    }
    if not(auth.has_prefix("Basic ")) {
      send_auth_required(ctx, options.realm)
      return
    }
    let encoded = extract_after_prefix(auth, 7)
    guard decode_base64_credentials(encoded) is Some((username, password)) else {
      send_auth_required(ctx, options.realm)
      return
    }
    if not((options.validate)(username, password)) {
      send_auth_required(ctx, options.realm)
      return
    }
    // Store username in context for later use
    ctx.set("auth_user", username)
  }
}

///|
/// Send 401 response with WWW-Authenticate header
async fn send_auth_required(ctx : @flame.Context, realm : String) -> Unit {
  ctx.set_header("WWW-Authenticate", "Basic realm=\"\{realm}\"")
  ctx.text("Unauthorized", status=401)
}

///|
/// Extract substring after prefix
fn extract_after_prefix(s : String, start : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in s {
    if i >= start {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Decode Base64 credentials (username:password)
fn decode_base64_credentials(encoded : String) -> (String, String)? {
  let decoded = decode_base64_simple(encoded)
  let colon_pos = find_char_basic(decoded, ':')
  if colon_pos < 0 {
    return None
  }
  let username = extract_substring_basic(decoded, 0, colon_pos)
  let password = extract_substring_basic(
    decoded,
    colon_pos + 1,
    decoded.length(),
  )
  Some((username, password))
}

///|
/// Find character in string
fn find_char_basic(s : String, c : Char) -> Int {
  for i, ch in s {
    if ch == c {
      return i
    }
  }
  -1
}

///|
/// Extract substring
fn extract_substring_basic(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in s {
    if i >= start && i < end {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Simple Base64 decode (ASCII only)
fn decode_base64_simple(encoded : String) -> String {
  let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let buf = StringBuilder::new()
  let chars : Array[Char] = []
  for c in encoded {
    chars.push(c)
  }
  let mut i = 0
  while i + 3 < chars.length() {
    let a = base64_char_value(chars[i], table)
    let b = base64_char_value(chars[i + 1], table)
    let c = base64_char_value(chars[i + 2], table)
    let d = base64_char_value(chars[i + 3], table)
    if a >= 0 && b >= 0 {
      buf.write_char(((a << 2) | (b >> 4)).unsafe_to_char())
      if c >= 0 {
        buf.write_char((((b & 0x0F) << 4) | (c >> 2)).unsafe_to_char())
        if d >= 0 {
          buf.write_char((((c & 0x03) << 6) | d).unsafe_to_char())
        }
      }
    }
    i = i + 4
  }
  buf.to_string()
}

///|
/// Get Base64 character value
fn base64_char_value(c : Char, table : String) -> Int {
  if c == '=' {
    return -1
  }
  let mut i = 0
  for tc in table {
    if tc == c {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Get authenticated username from context
pub fn get_auth_user(ctx : @flame.Context) -> String? {
  ctx.get("auth_user")
}

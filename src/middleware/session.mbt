///|
/// Session Middleware
/// Signed cookie sessions with HMAC-SHA256 verification

///|
/// Session options
pub(all) struct SessionOptions {
  /// Secret key for signing cookies
  secret : String
  /// Cookie name (default: "session")
  cookie_name : String
  /// Max age in seconds (default: 86400 = 1 day)
  max_age : Int
  /// Use Secure flag (HTTPS only) - should be true in production
  secure : Bool
}

///|
/// Default session options (development mode - no Secure flag)
pub fn SessionOptions::default(secret : String) -> SessionOptions {
  { secret, cookie_name: "session", max_age: 86400, secure: false }
}

///|
/// Production session options (with Secure flag for HTTPS)
pub fn SessionOptions::production(secret : String) -> SessionOptions {
  { secret, cookie_name: "session", max_age: 86400, secure: true }
}

///|
/// In-memory session store
let session_store : Ref[Map[String, Map[String, String]]] = Ref::new({})

///|
/// Clear all sessions (for testing)
pub fn session_clear() -> Unit {
  session_store.val = {}
}

///|
/// Session data wrapper
pub(all) struct SessionData {
  priv id : String
}

///|
/// Get session value
pub fn SessionData::get(self : SessionData, key : String) -> String? {
  let store = session_store.val
  match store.get(self.id) {
    Some(data) => data.get(key)
    None => None
  }
}

///|
/// Set session value
pub fn SessionData::set(
  self : SessionData,
  key : String,
  value : String,
) -> Unit {
  let store = session_store.val
  let data = match store.get(self.id) {
    Some(d) => d
    None => {
      let d : Map[String, String] = {}
      store.set(self.id, d)
      d
    }
  }
  data.set(key, value)
}

///|
/// Delete session value
pub fn SessionData::delete(self : SessionData, key : String) -> Unit {
  let store = session_store.val
  match store.get(self.id) {
    Some(data) => data.remove(key)
    None => ()
  }
}

///|
/// Clear all session values
pub fn SessionData::clear_all(self : SessionData) -> Unit {
  let store = session_store.val
  store.remove(self.id)
}

///|
/// Sign a session ID with HMAC-SHA256
fn sign_session(session_id : String, secret : String) -> String {
  let signature = compute_hmac_sha256(secret, session_id)
  session_id + "." + signature
}

///|
/// Verify and extract session ID from signed cookie
fn verify_session(cookie_value : String, secret : String) -> String? {
  let dot_idx = find_dot(cookie_value)
  if dot_idx < 0 {
    return None
  }
  let session_id = safe_substring(cookie_value, 0, dot_idx)
  let signature = safe_substring_from(cookie_value, dot_idx + 1)
  let expected = compute_hmac_sha256(secret, session_id)
  if constant_time_compare_session(signature, expected) {
    Some(session_id)
  } else {
    None
  }
}

///|
/// Find dot in string
fn find_dot(s : String) -> Int {
  for i, c in s {
    if c == '.' {
      return i
    }
  }
  -1
}

///|
/// Constant-time string comparison (timing-safe, no length leak)
fn constant_time_compare_session(a : String, b : String) -> Bool {
  // Always iterate over the longer string to prevent timing leak
  let len_a = a.length()
  let len_b = b.length()
  let max_len = if len_a > len_b { len_a } else { len_b }
  // XOR the lengths - result will be non-zero if different
  let mut result = len_a ^ len_b
  // Compare all characters, using 0 for out-of-bounds
  for i = 0; i < max_len; i = i + 1 {
    let ca = if i < len_a { a[i].to_int() } else { 0 }
    let cb = if i < len_b { b[i].to_int() } else { 0 }
    result = result | (ca ^ cb)
  }
  result == 0
}

///|
/// Session counter for uniqueness
let session_counter : Ref[Int] = Ref::new(0)

///|
/// ChaCha8 CSPRNG for session ID generation
let session_rng : Ref[@random.Rand?] = Ref::new(None)

///|
/// Initialize session RNG with secret
fn ensure_session_rng(secret : String) -> @random.Rand {
  match session_rng.val {
    Some(rng) => rng
    None => {
      // Use secret as seed for reproducible but secure randomness
      let seed_bytes = string_to_bytes_session(secret)
      let rng = @random.Rand::chacha8(seed=seed_bytes)
      session_rng.val = Some(rng)
      rng
    }
  }
}

///|
/// Convert string to bytes for session
fn string_to_bytes_session(s : String) -> Bytes {
  let bytes = FixedArray::make(s.length(), b'\x00')
  for i, c in s {
    bytes[i] = c.to_int().to_byte()
  }
  Bytes::from_array(bytes)
}

///|
/// Hex characters for session ID
let session_hex_chars : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

///|
/// Generate cryptographically secure session ID
/// Uses ChaCha8 CSPRNG with counter to ensure uniqueness
fn generate_session_id_secure(secret : String) -> String {
  session_counter.val = session_counter.val + 1
  let rng = ensure_session_rng(secret)
  // Generate 16 random bytes (128-bit)
  let buf = StringBuilder::new()
  buf.write_string("sess_")
  for i = 0; i < 16; i = i + 1 {
    let byte = rng.uint(limit=256).reinterpret_as_int()
    buf.write_char(session_hex_chars[byte >> 4])
    buf.write_char(session_hex_chars[byte & 0x0F])
  }
  // Append counter for guaranteed uniqueness
  buf.write_char('_')
  buf.write_string(session_counter.val.to_string())
  buf.to_string()
}

///|
/// Parse Cookie header
fn parse_cookie(header : String, name : String) -> String? {
  let pairs = split_by_char_session(header, ';')
  for pair in pairs {
    let trimmed = safe_trim(pair)
    let eq_idx = find_eq(trimmed)
    if eq_idx >= 0 {
      let key = safe_substring(trimmed, 0, eq_idx)
      let value = safe_substring_from(trimmed, eq_idx + 1)
      if key == name {
        return Some(value)
      }
    }
  }
  None
}

///|
/// Split by char
fn split_by_char_session(s : String, sep : Char) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == sep {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  result.push(current.to_string())
  result
}

///|
/// Find equals sign
fn find_eq(s : String) -> Int {
  for i, c in s {
    if c == '=' {
      return i
    }
  }
  -1
}

///|
/// Build Set-Cookie header value
pub fn session_cookie_header(
  options : SessionOptions,
  session_id : String,
) -> String {
  let signed = sign_session(session_id, options.secret)
  let result = StringBuilder::new()
  result.write_string(options.cookie_name)
  result.write_string("=")
  result.write_string(signed)
  result.write_string("; Path=/; HttpOnly; SameSite=Lax")
  if options.secure {
    result.write_string("; Secure")
  }
  result.write_string("; Max-Age=")
  result.write_string(options.max_age.to_string())
  result.to_string()
}

///|
/// Build cookie header to destroy session
pub fn session_destroy(options : SessionOptions) -> String {
  let result = StringBuilder::new()
  result.write_string(options.cookie_name)
  result.write_string("=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0")
  result.to_string()
}

///|
/// Get or create session from context
pub fn get_session(
  ctx : @mars.Context,
  options : SessionOptions,
) -> SessionData {
  let cookie_header = ctx.header("Cookie").unwrap_or("")
  let session_id = match parse_cookie(cookie_header, options.cookie_name) {
    Some(cookie_value) =>
      match verify_session(cookie_value, options.secret) {
        Some(id) => id
        None => generate_session_id_secure(options.secret)
      }
    None => generate_session_id_secure(options.secret)
  }
  // Store session ID in context data for later use
  ctx.set("session_id", session_id)
  SessionData::{ id: session_id }
}

///|
/// Session middleware - sets up session and stores ID in context
pub fn session_middleware(options : SessionOptions) -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    let cookie_header = ctx.header("Cookie").unwrap_or("")
    let session_id = match parse_cookie(cookie_header, options.cookie_name) {
      Some(cookie_value) =>
        match verify_session(cookie_value, options.secret) {
          Some(id) => id
          None => generate_session_id_secure(options.secret)
        }
      None => generate_session_id_secure(options.secret)
    }
    ctx.set("session_id", session_id)
    // Note: Cookie should be set in response by the route handler
  }
}

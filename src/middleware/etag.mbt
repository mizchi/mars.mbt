///|
/// ETag Middleware
/// Generates and validates ETags for response caching

///|
/// ETag options
pub(all) struct ETagOptions {
  /// Use weak ETags (W/"...")
  weak : Bool
}

///|
/// Default ETag options
pub fn ETagOptions::default() -> ETagOptions {
  { weak: true }
}

///|
/// Strong ETag options
pub fn ETagOptions::strong() -> ETagOptions {
  { weak: false }
}

///|
/// Generate ETag from content using simple hash
pub fn generate_etag(content : String, weak : Bool) -> String {
  let hash = simple_hash(content)
  let hex = hash_to_hex(hash)
  if weak {
    "W/\"" + hex + "\""
  } else {
    "\"" + hex + "\""
  }
}

///|
/// Simple hash function for ETag generation
fn simple_hash(s : String) -> Int {
  let mut hash = 0
  for c in s {
    hash = ((hash << 5) - hash) + c.to_int()
    hash = hash & 0x7FFFFFFF // Keep positive
  }
  hash
}

///|
/// Hex characters for ETag
let etag_hex_chars : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

///|
/// Convert hash to hex string
fn hash_to_hex(hash : Int) -> String {
  let buf = StringBuilder::new()
  for i = 0; i < 8; i = i + 1 {
    let nibble = (hash >> (28 - i * 4)) & 0x0F
    buf.write_char(etag_hex_chars[nibble])
  }
  buf.to_string()
}

///|
/// Check if ETag matches If-None-Match header
pub fn etag_matches(etag : String, if_none_match : String) -> Bool {
  if if_none_match == "*" {
    return true
  }
  // Parse multiple ETags separated by comma
  let tags = split_etags(if_none_match)
  for tag in tags {
    let trimmed = trim_etag(tag)
    if compare_etags(etag, trimmed) {
      return true
    }
  }
  false
}

///|
/// Compare two ETags (handles weak comparison)
fn compare_etags(a : String, b : String) -> Bool {
  let a_val = strip_weak_prefix(a)
  let b_val = strip_weak_prefix(b)
  a_val == b_val
}

///|
/// Strip W/ prefix from weak ETag
fn strip_weak_prefix(etag : String) -> String {
  if etag.has_prefix("W/") {
    safe_substring_from(etag, 2)
  } else {
    etag
  }
}

///|
/// Split ETags by comma
fn split_etags(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut in_quotes = false
  for c in s {
    if c == '"' {
      in_quotes = not(in_quotes)
      current.write_char(c)
    } else if c == ',' && not(in_quotes) {
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
/// Trim whitespace from ETag
fn trim_etag(s : String) -> String {
  let buf = StringBuilder::new()
  let mut started = false
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  // Find start
  let mut start = 0
  while start < chars.length() && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  // Find end
  let mut end = chars.length()
  while end > start && (chars[end - 1] == ' ' || chars[end - 1] == '\t') {
    end = end - 1
  }
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// ETag response helper - sets ETag header and handles 304
pub fn set_etag(
  ctx : @flame.Context,
  content : String,
  options? : ETagOptions = ETagOptions::default(),
) -> Bool {
  let etag = generate_etag(content, options.weak)
  ctx.set_header("ETag", etag)
  // Check If-None-Match
  match ctx.header("If-None-Match") {
    Some(if_none_match) =>
      if etag_matches(etag, if_none_match) {
        true // Content not modified
      } else {
        false
      }
    None => false
  }
}

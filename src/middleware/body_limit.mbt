///|
/// Body Limit Middleware
/// Limit request body size to prevent DoS attacks

///|
/// Body limit options
pub(all) struct BodyLimitOptions {
  /// Maximum body size in bytes
  max_size : Int
  /// Error message when limit exceeded
  message : String
  /// Status code when limit exceeded
  status : Int
}

///|
/// Default body limit (1MB)
pub fn BodyLimitOptions::default() -> BodyLimitOptions {
  { max_size: 1048576, message: "Request body too large", status: 413 }
}

///|
/// Create body limit options with size in bytes
pub fn BodyLimitOptions::bytes(size : Int) -> BodyLimitOptions {
  { ..BodyLimitOptions::default(), max_size: size }
}

///|
/// Create body limit options with size in kilobytes
pub fn BodyLimitOptions::kb(size : Int) -> BodyLimitOptions {
  { ..BodyLimitOptions::default(), max_size: size * 1024 }
}

///|
/// Create body limit options with size in megabytes
pub fn BodyLimitOptions::mb(size : Int) -> BodyLimitOptions {
  { ..BodyLimitOptions::default(), max_size: size * 1024 * 1024 }
}

///|
/// Check Content-Length header against limit
pub fn check_content_length(content_length : String, max_size : Int) -> Bool {
  let length = parse_content_length(content_length)
  length <= max_size
}

///|
/// Parse Content-Length header value
fn parse_content_length(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
/// Body limit middleware
/// Checks Content-Length header and rejects oversized requests
pub fn body_limit(
  options? : BodyLimitOptions = BodyLimitOptions::default(),
) -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    // Check Content-Length header
    match ctx.header("Content-Length") {
      Some(length_str) => {
        let length = parse_content_length(length_str)
        if length > options.max_size {
          ctx.set_header("Connection", "close")
          ctx.text(options.message, status=options.status)
        }
      }
      None => ()
    }
  }
}

///|
/// Body limit middleware with size in bytes
pub fn body_limit_bytes(size : Int) -> @mars.Handler {
  body_limit(options=BodyLimitOptions::bytes(size))
}

///|
/// Body limit middleware with size in kilobytes
pub fn body_limit_kb(size : Int) -> @mars.Handler {
  body_limit(options=BodyLimitOptions::kb(size))
}

///|
/// Body limit middleware with size in megabytes
pub fn body_limit_mb(size : Int) -> @mars.Handler {
  body_limit(options=BodyLimitOptions::mb(size))
}

///|
/// Check if body size is within limit
pub fn is_within_limit(body : String, max_size : Int) -> Bool {
  body.length() <= max_size
}

///|
/// Format size for display
pub fn format_size(bytes : Int) -> String {
  if bytes >= 1048576 {
    let mb = bytes / 1048576
    mb.to_string() + " MB"
  } else if bytes >= 1024 {
    let kb = bytes / 1024
    kb.to_string() + " KB"
  } else {
    bytes.to_string() + " bytes"
  }
}

///|
/// Common size constants
pub fn size_1kb() -> Int {
  1024
}

///|
pub fn size_10kb() -> Int {
  10240
}

///|
pub fn size_100kb() -> Int {
  102400
}

///|
pub fn size_1mb() -> Int {
  1048576
}

///|
pub fn size_10mb() -> Int {
  10485760
}

///|
pub fn size_100mb() -> Int {
  104857600
}

///|
/// Compress Middleware
/// Content encoding negotiation and compression support
/// Note: Actual compression requires external library or reverse proxy

///|
/// Compression encoding types
pub(all) enum CompressionEncoding {
  Gzip
  Deflate
  Br // Brotli
  Identity // No compression
} derive(Show, Eq)

///|
/// Compression options
pub(all) struct CompressOptions {
  /// Minimum size to compress (bytes)
  threshold : Int
  /// Preferred encodings in order
  encodings : Array[CompressionEncoding]
}

///|
/// Default compression options
pub fn CompressOptions::default() -> CompressOptions {
  { threshold: 1024, encodings: [Gzip, Deflate, Br] }
}

///|
/// Gzip only
pub fn CompressOptions::gzip_only() -> CompressOptions {
  { threshold: 1024, encodings: [Gzip] }
}

///|
/// Parse Accept-Encoding header
pub fn parse_accept_encoding(header : String) -> Array[CompressionEncoding] {
  let result : Array[CompressionEncoding] = []
  let parts = split_accept_encoding(header)
  for part in parts {
    let encoding = trim_encoding(part)
    // Extract encoding name (before ;q=)
    let name = get_encoding_name(encoding)
    match name {
      "gzip" => result.push(Gzip)
      "deflate" => result.push(Deflate)
      "br" => result.push(Br)
      "identity" => result.push(Identity)
      _ => ()
    }
  }
  result
}

///|
/// Split Accept-Encoding by comma
fn split_accept_encoding(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == ',' {
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
/// Trim whitespace from encoding
fn trim_encoding(s : String) -> String {
  let buf = StringBuilder::new()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let mut start = 0
  while start < chars.length() && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
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
/// Get encoding name (before ;q= weight)
fn get_encoding_name(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if c == ';' {
      break
    }
    buf.write_char(c)
  }
  buf.to_string()
}

///|
/// Get Content-Encoding header value for encoding
pub fn encoding_to_header(encoding : CompressionEncoding) -> String {
  match encoding {
    Gzip => "gzip"
    Deflate => "deflate"
    Br => "br"
    Identity => "identity"
  }
}

///|
/// Negotiate best encoding between client and server
pub fn negotiate_encoding(
  accept : Array[CompressionEncoding],
  supported : Array[CompressionEncoding],
) -> CompressionEncoding {
  // Find first supported encoding that client accepts
  for enc in supported {
    for client_enc in accept {
      if enc == client_enc {
        return enc
      }
    }
  }
  Identity
}

///|
/// Check if content type should be compressed
pub fn should_compress_type(content_type : String) -> Bool {
  // Compress text-based content
  content_type.contains("text/") ||
  content_type.contains("application/json") ||
  content_type.contains("application/javascript") ||
  content_type.contains("application/xml") ||
  content_type.contains("image/svg+xml")
}

///|
/// Compress middleware - sets up encoding negotiation
/// Note: This middleware sets headers; actual compression
/// should be done by the response handler or reverse proxy
pub fn compress(
  options? : CompressOptions = CompressOptions::default(),
) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let accept_header = ctx.header("Accept-Encoding").unwrap_or("")
    if accept_header.is_empty() {
      return
    }
    let accepted = parse_accept_encoding(accept_header)
    let encoding = negotiate_encoding(accepted, options.encodings)
    // Store negotiated encoding in context for later use
    ctx.set("_compress_encoding", encoding_to_header(encoding))
    ctx.set("_compress_threshold", options.threshold.to_string())
    // Set Vary header to indicate content varies by Accept-Encoding
    ctx.set_header("Vary", "Accept-Encoding")
  }
}

///|
/// Get negotiated compression encoding from context
pub fn get_compression_encoding(ctx : @flame.Context) -> CompressionEncoding {
  match ctx.get("_compress_encoding") {
    Some("gzip") => Gzip
    Some("deflate") => Deflate
    Some("br") => Br
    _ => Identity
  }
}

///|
/// Set Content-Encoding header if compression was applied
pub fn set_content_encoding(
  ctx : @flame.Context,
  encoding : CompressionEncoding,
) -> Unit {
  if encoding != Identity {
    ctx.set_header("Content-Encoding", encoding_to_header(encoding))
  }
}

///|
/// Simple run-length encoding for demonstration
/// (Not a real compression algorithm, just for testing)
pub fn simple_compress(data : String) -> String {
  if data.length() < 4 {
    return data
  }
  let buf = StringBuilder::new()
  let chars : Array[Char] = []
  for c in data {
    chars.push(c)
  }
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let mut count = 1
    while i + count < chars.length() && chars[i + count] == c && count < 9 {
      count = count + 1
    }
    if count >= 3 {
      buf.write_char('#')
      buf.write_char(('0'.to_int() + count).unsafe_to_char())
      buf.write_char(c)
    } else {
      for j = 0; j < count; j = j + 1 {
        buf.write_char(c)
      }
    }
    i = i + count
  }
  buf.to_string()
}

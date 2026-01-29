///|
/// API Key Authentication Middleware
/// Authenticate requests using API keys in header or query parameter

///|
/// Where to look for API key
pub(all) enum ApiKeyLocation {
  /// Look in header (e.g., X-API-Key)
  Header(String)
  /// Look in query parameter (e.g., ?api_key=xxx)
  Query(String)
  /// Look in both header and query
  Both(String, String)
}

///|
/// API key validation result
pub(all) enum ApiKeyResult {
  /// Valid API key with optional metadata
  Valid(String)
  /// Invalid or missing API key
  Invalid
} derive(Show, Eq)

///|
/// API key options
pub(all) struct ApiKeyOptions {
  /// Where to look for API key
  location : ApiKeyLocation
  /// Validator function: (key) -> ApiKeyResult
  validate : (String) -> ApiKeyResult
  /// Error message for invalid key
  error_message : String
  /// Error status code
  error_status : Int
}

///|
/// Create API key options with simple key list
pub fn ApiKeyOptions::simple(
  keys : Array[String],
  location? : ApiKeyLocation = Header("X-API-Key"),
) -> ApiKeyOptions {
  {
    location,
    validate: fn(key) {
      for valid_key in keys {
        if constant_time_compare_api(key, valid_key) {
          return ApiKeyResult::Valid(key)
        }
      }
      ApiKeyResult::Invalid
    },
    error_message: "Invalid API key",
    error_status: 401,
  }
}

///|
/// Create API key options with custom validator
pub fn ApiKeyOptions::custom(
  validate : (String) -> ApiKeyResult,
  location? : ApiKeyLocation = Header("X-API-Key"),
) -> ApiKeyOptions {
  { location, validate, error_message: "Invalid API key", error_status: 401 }
}

///|
/// Constant-time string comparison for API keys
fn constant_time_compare_api(a : String, b : String) -> Bool {
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
/// Extract API key from request
fn extract_api_key(ctx : @flame.Context, location : ApiKeyLocation) -> String? {
  match location {
    Header(header_name) => ctx.header(header_name)
    Query(param_name) => ctx.query(param_name)
    Both(header_name, param_name) =>
      match ctx.header(header_name) {
        Some(key) => Some(key)
        None => ctx.query(param_name)
      }
  }
}

///|
/// API key authentication middleware
pub fn api_key_auth(options : ApiKeyOptions) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let key = match extract_api_key(ctx, options.location) {
      Some(k) => k
      None => {
        ctx.text(options.error_message, status=options.error_status)
        return
      }
    }
    match (options.validate)(key) {
      Valid(validated_key) =>
        // Store validated key in context
        ctx.set("api_key", validated_key)
      Invalid => ctx.text(options.error_message, status=options.error_status)
    }
  }
}

///|
/// Get authenticated API key from context
pub fn get_api_key(ctx : @flame.Context) -> String? {
  ctx.get("api_key")
}

///|
/// API key middleware with header location (convenience)
pub fn api_key_header(
  keys : Array[String],
  header_name? : String = "X-API-Key",
) -> @flame.Handler {
  api_key_auth(
    ApiKeyOptions::simple(keys, location=ApiKeyLocation::Header(header_name)),
  )
}

///|
/// API key middleware with query location (convenience)
pub fn api_key_query(
  keys : Array[String],
  param_name? : String = "api_key",
) -> @flame.Handler {
  api_key_auth(
    ApiKeyOptions::simple(keys, location=ApiKeyLocation::Query(param_name)),
  )
}

///|
/// API key middleware with both header and query (convenience)
pub fn api_key_both(
  keys : Array[String],
  header_name? : String = "X-API-Key",
  param_name? : String = "api_key",
) -> @flame.Handler {
  api_key_auth(
    ApiKeyOptions::simple(
      keys,
      location=ApiKeyLocation::Both(header_name, param_name),
    ),
  )
}

///|
/// Generate a random API key
pub fn generate_api_key(prefix? : String = "sk_") -> String {
  let rng = @random.Rand::chacha8()
  let buf = StringBuilder::new()
  buf.write_string(prefix)
  // Generate 32 random hex characters (128 bits)
  for i = 0; i < 32; i = i + 1 {
    let byte = rng.uint(limit=16).reinterpret_as_int()
    let c = if byte < 10 {
      ('0'.to_int() + byte).unsafe_to_char()
    } else {
      ('a'.to_int() + byte - 10).unsafe_to_char()
    }
    buf.write_char(c)
  }
  buf.to_string()
}

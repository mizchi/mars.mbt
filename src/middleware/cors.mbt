///|
/// CORS Middleware
/// Cross-Origin Resource Sharing support

///|
/// CORS options
pub(all) struct CorsOptions {
  /// Allowed origins (use "*" for all)
  origin : String
  /// Allowed methods
  methods : Array[String]
  /// Allowed headers
  allowed_headers : Array[String]
  /// Exposed headers
  exposed_headers : Array[String]
  /// Allow credentials
  credentials : Bool
  /// Max age for preflight cache (seconds)
  max_age : Int
}

///|
/// Default CORS options (allow all)
pub fn CorsOptions::default() -> CorsOptions {
  {
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowed_headers: ["Content-Type", "Authorization"],
    exposed_headers: [],
    credentials: false,
    max_age: 86400,
  }
}

///|
/// CORS options allowing specific origin
pub fn CorsOptions::allow_origin(origin : String) -> CorsOptions {
  { ..CorsOptions::default(), origin, }
}

///|
/// CORS options with credentials
pub fn CorsOptions::with_credentials(origin : String) -> CorsOptions {
  { ..CorsOptions::default(), origin, credentials: true }
}

///|
/// CORS middleware
/// WARNING: Using credentials=true with origin="*" is insecure and will be rejected
pub fn cors(options? : CorsOptions = CorsOptions::default()) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let request_origin = ctx.header("Origin").unwrap_or("")

    // Security check: reject dangerous combination
    if options.credentials && options.origin == "*" {
      // This is a security vulnerability - reject the request
      ctx.text(
        "CORS misconfiguration: credentials cannot be used with wildcard origin",
        status=500,
      )
      return
    }

    // Determine origin to use in response
    let response_origin = if options.origin == "*" {
      "*"
    } else {
      options.origin
    }

    // Only set CORS headers if origin matches or is wildcard
    if response_origin == "*" || response_origin == request_origin {
      ctx.set_header("Access-Control-Allow-Origin", response_origin)
      if options.credentials {
        ctx.set_header("Access-Control-Allow-Credentials", "true")
      }
      if not(options.exposed_headers.is_empty()) {
        ctx.set_header(
          "Access-Control-Expose-Headers",
          join_array(options.exposed_headers, ", "),
        )
      }

      // Handle preflight request
      if ctx.meth() == @http.RequestMethod::Options {
        ctx.set_header(
          "Access-Control-Allow-Methods",
          join_array(options.methods, ", "),
        )
        ctx.set_header(
          "Access-Control-Allow-Headers",
          join_array(options.allowed_headers, ", "),
        )
        ctx.set_header("Access-Control-Max-Age", options.max_age.to_string())
        ctx.text("", status=204)
      }
    }
  }
}

///|
/// Simple CORS middleware (allow all)
pub fn cors_allow_all() -> @flame.Handler {
  cors()
}

///|
/// Join array with separator
fn join_array(arr : Array[String], sep : String) -> String {
  if arr.is_empty() {
    return ""
  }
  let buf = StringBuilder::new()
  for i, s in arr {
    if i > 0 {
      buf.write_string(sep)
    }
    buf.write_string(s)
  }
  buf.to_string()
}

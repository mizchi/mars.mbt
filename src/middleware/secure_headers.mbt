///|
/// Secure Headers Middleware
/// Security-related HTTP headers

///|
/// Secure headers options
pub(all) struct SecureHeadersOptions {
  /// Strict-Transport-Security
  hsts : Bool
  hsts_max_age : Int
  hsts_include_subdomains : Bool
  /// X-Content-Type-Options
  no_sniff : Bool
  /// X-Frame-Options
  frame_options : String
  /// X-XSS-Protection
  xss_protection : Bool
  /// Content-Security-Policy
  csp : String
  /// Referrer-Policy
  referrer_policy : String
  /// Permissions-Policy
  permissions_policy : String
}

///|
/// Default secure headers (recommended settings)
pub fn SecureHeadersOptions::default() -> SecureHeadersOptions {
  {
    hsts: true,
    hsts_max_age: 31536000, // 1 year
    hsts_include_subdomains: true,
    no_sniff: true,
    frame_options: "SAMEORIGIN",
    xss_protection: true,
    csp: "",
    referrer_policy: "strict-origin-when-cross-origin",
    permissions_policy: "",
  }
}

///|
/// Minimal secure headers
pub fn SecureHeadersOptions::minimal() -> SecureHeadersOptions {
  {
    hsts: false,
    hsts_max_age: 0,
    hsts_include_subdomains: false,
    no_sniff: true,
    frame_options: "SAMEORIGIN",
    xss_protection: false,
    csp: "",
    referrer_policy: "",
    permissions_policy: "",
  }
}

///|
/// Strict secure headers
pub fn SecureHeadersOptions::strict() -> SecureHeadersOptions {
  {
    hsts: true,
    hsts_max_age: 63072000, // 2 years
    hsts_include_subdomains: true,
    no_sniff: true,
    frame_options: "DENY",
    xss_protection: true,
    csp: "default-src 'self'",
    referrer_policy: "no-referrer",
    permissions_policy: "geolocation=(), microphone=(), camera=()",
  }
}

///|
/// Secure headers middleware
pub fn secure_headers(
  options? : SecureHeadersOptions = SecureHeadersOptions::default(),
) -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    // HSTS
    if options.hsts {
      let mut hsts_value = "max-age=" + options.hsts_max_age.to_string()
      if options.hsts_include_subdomains {
        hsts_value = hsts_value + "; includeSubDomains"
      }
      ctx.set_header("Strict-Transport-Security", hsts_value)
    }
    // X-Content-Type-Options
    if options.no_sniff {
      ctx.set_header("X-Content-Type-Options", "nosniff")
    }
    // X-Frame-Options
    if not(options.frame_options.is_empty()) {
      ctx.set_header("X-Frame-Options", options.frame_options)
    }
    // X-XSS-Protection
    if options.xss_protection {
      ctx.set_header("X-XSS-Protection", "1; mode=block")
    }
    // Content-Security-Policy
    if not(options.csp.is_empty()) {
      ctx.set_header("Content-Security-Policy", options.csp)
    }
    // Referrer-Policy
    if not(options.referrer_policy.is_empty()) {
      ctx.set_header("Referrer-Policy", options.referrer_policy)
    }
    // Permissions-Policy
    if not(options.permissions_policy.is_empty()) {
      ctx.set_header("Permissions-Policy", options.permissions_policy)
    }
  }
}

///|
/// Shorthand for default secure headers
pub fn secure_headers_default() -> @mars.Handler {
  secure_headers()
}

///|
/// Shorthand for strict secure headers
pub fn secure_headers_strict() -> @mars.Handler {
  secure_headers(options=SecureHeadersOptions::strict())
}

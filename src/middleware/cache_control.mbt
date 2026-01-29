///|
/// Cache-Control Middleware
/// HTTP caching headers management

///|
/// Cache-Control options
pub(all) struct CacheOptions {
  /// Max age in seconds
  max_age : Int
  /// Shared max age (CDN) in seconds
  s_maxage : Int
  /// Public cache
  public_ : Bool
  /// Private cache only
  private_ : Bool
  /// No cache (must revalidate)
  no_cache : Bool
  /// No store (don't cache at all)
  no_store : Bool
  /// Must revalidate when stale
  must_revalidate : Bool
  /// Immutable content
  immutable : Bool
}

///|
/// No caching (for sensitive data)
pub fn CacheOptions::no_cache() -> CacheOptions {
  {
    max_age: 0,
    s_maxage: 0,
    public_: false,
    private_: true,
    no_cache: true,
    no_store: true,
    must_revalidate: true,
    immutable: false,
  }
}

///|
/// Public cache with max age
pub fn CacheOptions::public_(max_age : Int) -> CacheOptions {
  {
    max_age,
    s_maxage: 0,
    public_: true,
    private_: false,
    no_cache: false,
    no_store: false,
    must_revalidate: false,
    immutable: false,
  }
}

///|
/// Private cache with max age
pub fn CacheOptions::private_(max_age : Int) -> CacheOptions {
  {
    max_age,
    s_maxage: 0,
    public_: false,
    private_: true,
    no_cache: false,
    no_store: false,
    must_revalidate: false,
    immutable: false,
  }
}

///|
/// Immutable content (versioned assets)
pub fn CacheOptions::immutable(max_age : Int) -> CacheOptions {
  {
    max_age,
    s_maxage: 0,
    public_: true,
    private_: false,
    no_cache: false,
    no_store: false,
    must_revalidate: false,
    immutable: true,
  }
}

///|
/// CDN-optimized cache
pub fn CacheOptions::cdn(max_age : Int, s_maxage : Int) -> CacheOptions {
  {
    max_age,
    s_maxage,
    public_: true,
    private_: false,
    no_cache: false,
    no_store: false,
    must_revalidate: false,
    immutable: false,
  }
}

///|
/// Stale-while-revalidate pattern
pub fn CacheOptions::stale_while_revalidate(
  max_age : Int,
  stale_time : Int,
) -> CacheOptions {
  // Note: stale-while-revalidate requires custom header building
  {
    max_age,
    s_maxage: stale_time,
    public_: true,
    private_: false,
    no_cache: false,
    no_store: false,
    must_revalidate: false,
    immutable: false,
  }
}

///|
/// Build Cache-Control header value
pub fn build_cache_control(options : CacheOptions) -> String {
  let parts : Array[String] = []
  if options.no_store {
    parts.push("no-store")
  }
  if options.no_cache {
    parts.push("no-cache")
  }
  if options.private_ {
    parts.push("private")
  } else if options.public_ {
    parts.push("public")
  }
  if options.max_age > 0 {
    parts.push("max-age=" + options.max_age.to_string())
  }
  if options.s_maxage > 0 {
    parts.push("s-maxage=" + options.s_maxage.to_string())
  }
  if options.must_revalidate {
    parts.push("must-revalidate")
  }
  if options.immutable {
    parts.push("immutable")
  }
  join_cache_parts(parts)
}

///|
/// Join cache control parts
fn join_cache_parts(parts : Array[String]) -> String {
  if parts.is_empty() {
    return ""
  }
  let buf = StringBuilder::new()
  for i, part in parts {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(part)
  }
  buf.to_string()
}

///|
/// Cache-Control middleware
pub fn cache_control(options : CacheOptions) -> @mars.Handler {
  async fn(ctx : @mars.Context) {
    let header = build_cache_control(options)
    if not(header.is_empty()) {
      ctx.set_header("Cache-Control", header)
    }
    // Set Pragma for HTTP/1.0 compatibility
    if options.no_cache || options.no_store {
      ctx.set_header("Pragma", "no-cache")
    }
  }
}

///|
/// No-cache middleware (for API responses, sensitive data)
pub fn no_cache_middleware() -> @mars.Handler {
  cache_control(CacheOptions::no_cache())
}

///|
/// Set cache headers on context
pub fn set_cache_headers(ctx : @mars.Context, options : CacheOptions) -> Unit {
  let header = build_cache_control(options)
  if not(header.is_empty()) {
    ctx.set_header("Cache-Control", header)
  }
  if options.no_cache || options.no_store {
    ctx.set_header("Pragma", "no-cache")
  }
}

///|
/// Common cache presets
pub fn cache_1_minute() -> CacheOptions {
  CacheOptions::public_(60)
}

///|
pub fn cache_1_hour() -> CacheOptions {
  CacheOptions::public_(3600)
}

///|
pub fn cache_1_day() -> CacheOptions {
  CacheOptions::public_(86400)
}

///|
pub fn cache_1_week() -> CacheOptions {
  CacheOptions::public_(604800)
}

///|
pub fn cache_1_year() -> CacheOptions {
  CacheOptions::immutable(31536000)
}

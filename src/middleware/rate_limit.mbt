///|
/// Rate Limiting Middleware
/// Uses fixed window algorithm with in-memory storage

///|
/// Rate limit entry
priv struct RateLimitEntry {
  count : Int
  window : Int
}

///|
/// Rate limit options
pub(all) struct RateLimitOptions {
  /// Maximum requests per window
  limit : Int
  /// Window size in ticks (use rate_limit_tick to advance)
  window_size : Int
}

///|
/// Default rate limit options (100 requests per window)
pub fn RateLimitOptions::default() -> RateLimitOptions {
  { limit: 100, window_size: 1 }
}

///|
/// In-memory rate limit storage
let rate_limit_store : Ref[Map[String, RateLimitEntry]] = Ref::new({})

///|
/// Current window counter
let rate_limit_window : Ref[Int] = Ref::new(0)

///|
/// Clear rate limit storage (for testing)
pub fn rate_limit_clear() -> Unit {
  rate_limit_store.val = {}
  rate_limit_window.val = 0
}

///|
/// Advance rate limit window (for testing or scheduled cleanup)
pub fn rate_limit_tick() -> Unit {
  rate_limit_window.val = rate_limit_window.val + 1
}

///|
/// Get current rate limit info for a key
pub fn rate_limit_info(key : String) -> (Int, Int, Bool) {
  let store = rate_limit_store.val
  let current_window = rate_limit_window.val
  match store.get(key) {
    Some(entry) =>
      if entry.window == current_window {
        (entry.count, 100, false)
      } else {
        (0, 100, false)
      }
    None => (0, 100, false)
  }
}

///|
/// Rate limit middleware with custom key extractor
pub fn rate_limit(
  key_extractor : (@flame.Context) -> String,
  options? : RateLimitOptions = RateLimitOptions::default(),
) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let key = key_extractor(ctx)
    let store = rate_limit_store.val
    let current_window = rate_limit_window.val
    let entry = match store.get(key) {
      Some(entry) =>
        if entry.window == current_window {
          { count: entry.count + 1, window: current_window }
        } else {
          { count: 1, window: current_window }
        }
      None => { count: 1, window: current_window }
    }
    store.set(key, entry)
    if entry.count > options.limit {
      ctx.text("Rate limit exceeded", status=429)
    }
  }
}

///|
/// Rate limit by IP address (INSECURE: trusts all proxies)
/// Use rate_limit_by_ip_secure for production
pub fn rate_limit_by_ip(
  options? : RateLimitOptions = RateLimitOptions::default(),
) -> @flame.Handler {
  rate_limit(
    fn(ctx) {
      match ctx.header("X-Forwarded-For") {
        Some(v) => {
          // Get first IP in chain
          let comma_idx = find_comma(v)
          if comma_idx >= 0 {
            safe_substring_rate(v, 0, comma_idx)
          } else {
            v
          }
        }
        None =>
          match ctx.header("X-Real-IP") {
            Some(v) => v
            None => "unknown"
          }
      }
    },
    options~,
  )
}

///|
/// Find comma in string
fn find_comma(s : String) -> Int {
  for i, c in s {
    if c == ',' {
      return i
    }
  }
  -1
}

///|
/// Safe substring for rate limit
fn safe_substring_rate(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i, c in s {
    if i >= start && i < end {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Rate limit by authorization header
pub fn rate_limit_by_auth(
  options? : RateLimitOptions = RateLimitOptions::default(),
) -> @flame.Handler {
  rate_limit(
    fn(ctx) { ctx.header("Authorization").unwrap_or("anonymous") },
    options~,
  )
}

///|
/// Rate limit by IP address with trusted proxy validation (SECURE)
/// Only trusts X-Forwarded-For from configured trusted proxies
pub fn rate_limit_by_ip_secure(
  trusted_proxies : TrustedProxyConfig,
  options? : RateLimitOptions = RateLimitOptions::default(),
) -> @flame.Handler {
  rate_limit(
    fn(ctx) { get_client_ip_for_rate_limit(ctx, trusted_proxies) },
    options~,
  )
}

///|
/// Get client IP for rate limiting with trusted proxy validation
fn get_client_ip_for_rate_limit(
  ctx : @flame.Context,
  trusted_proxies : TrustedProxyConfig,
) -> String {
  if not(trusted_proxies.enabled) {
    return "unknown"
  }
  let header = match ctx.header("X-Forwarded-For") {
    Some(v) => v
    None =>
      match ctx.header("X-Real-IP") {
        Some(v) => v
        None => return "unknown"
      }
  }
  // Parse IPs from header
  let ips = split_ips(header)
  // Walk from right to left, find first untrusted IP
  for i = ips.length() - 1; i >= 0; i = i - 1 {
    let ip = trim_ip(ips[i])
    if not(is_trusted_proxy_rate(ip, trusted_proxies)) {
      return ip
    }
  }
  if ips.length() > 0 {
    trim_ip(ips[0])
  } else {
    "unknown"
  }
}

///|
/// Split IPs by comma
fn split_ips(header : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in header {
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
/// Trim whitespace from IP
fn trim_ip(s : String) -> String {
  let buf = StringBuilder::new()
  let mut started = false
  let mut end_pos = 0
  for c in s {
    if c != ' ' && c != '\t' {
      if not(started) {
        started = true
      }
      buf.write_char(c)
      end_pos = buf.to_string().length()
    } else if started {
      buf.write_char(c)
    }
  }
  // Trim trailing
  let result = buf.to_string()
  safe_substring_rate(result, 0, end_pos)
}

///|
/// Check if IP is trusted proxy for rate limit
fn is_trusted_proxy_rate(ip : String, config : TrustedProxyConfig) -> Bool {
  for proxy in config.proxies {
    if ip_matches_pattern_rate(ip, proxy) {
      return true
    }
  }
  false
}

///|
/// Check if IP matches pattern for rate limit
fn ip_matches_pattern_rate(ip : String, pattern : String) -> Bool {
  if pattern.contains("/") {
    ip_matches_cidr_rate(ip, pattern)
  } else if pattern.contains("*") {
    ip_matches_wildcard_rate(ip, pattern)
  } else {
    ip == pattern
  }
}

///|
/// CIDR matching for rate limit
fn ip_matches_cidr_rate(ip : String, cidr : String) -> Bool {
  let slash_idx = find_slash(cidr)
  if slash_idx < 0 {
    return false
  }
  let network = safe_substring_rate(cidr, 0, slash_idx)
  let prefix_str = safe_substring_from_rate(cidr, slash_idx + 1)
  let prefix = parse_int_rate(prefix_str)
  let network_parts = split_by_dot(network)
  let ip_parts = split_by_dot(ip)
  if network_parts.length() != 4 || ip_parts.length() != 4 {
    return false
  }
  let parts_to_check = prefix / 8
  for i = 0; i < parts_to_check && i < 4; i = i + 1 {
    if network_parts[i] != ip_parts[i] {
      return false
    }
  }
  true
}

///|
/// Wildcard matching for rate limit
fn ip_matches_wildcard_rate(ip : String, pattern : String) -> Bool {
  let ip_parts = split_by_dot(ip)
  let pattern_parts = split_by_dot(pattern)
  if ip_parts.length() != pattern_parts.length() {
    return false
  }
  for i, ip_part in ip_parts {
    if pattern_parts[i] != "*" && ip_part != pattern_parts[i] {
      return false
    }
  }
  true
}

///|
fn find_slash(s : String) -> Int {
  for i, c in s {
    if c == '/' {
      return i
    }
  }
  -1
}

///|
fn safe_substring_from_rate(s : String, start : Int) -> String {
  let buf = StringBuilder::new()
  for i, c in s {
    if i >= start {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
fn parse_int_rate(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
fn split_by_dot(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == '.' {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  result.push(current.to_string())
  result
}

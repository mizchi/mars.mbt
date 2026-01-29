///|
/// IP Filter Middleware
/// Supports exact match, wildcard (192.168.1.*), and CIDR (10.0.0.0/8)

///|
/// Trusted proxy configuration
pub(all) struct TrustedProxyConfig {
  /// List of trusted proxy IPs or CIDR ranges
  proxies : Array[String]
  /// Whether trust is enabled (if false, always use direct connection IP)
  enabled : Bool
}

///|
/// Default: trust no proxies (most secure)
pub fn TrustedProxyConfig::none() -> TrustedProxyConfig {
  { proxies: [], enabled: false }
}

///|
/// Trust localhost proxies only
pub fn TrustedProxyConfig::localhost() -> TrustedProxyConfig {
  { proxies: ["127.0.0.1", "::1"], enabled: true }
}

///|
/// Trust specific proxy IPs
pub fn TrustedProxyConfig::trust(proxies : Array[String]) -> TrustedProxyConfig {
  { proxies, enabled: true }
}

///|
/// Trust all proxies (INSECURE - only for development)
pub fn TrustedProxyConfig::trust_all() -> TrustedProxyConfig {
  { proxies: ["0.0.0.0/0"], enabled: true }
}

///|
/// Check if an IP is a trusted proxy
fn is_trusted_proxy(ip : String, config : TrustedProxyConfig) -> Bool {
  if not(config.enabled) {
    return false
  }
  for proxy in config.proxies {
    if ip_matches_pattern(ip, proxy) {
      return true
    }
  }
  false
}

///|
/// IP filter options
pub(all) struct IpFilterOptions {
  /// List of IP patterns to allow (whitelist mode) or deny (blacklist mode)
  ips : Array[String]
  /// Header to extract IP from (default: X-Forwarded-For)
  ip_header : String
  /// Whether to use whitelist (true) or blacklist (false) mode
  whitelist : Bool
  /// Trusted proxy configuration
  trusted_proxies : TrustedProxyConfig
}

///|
/// Check if IP matches a pattern
fn ip_matches_pattern(ip : String, pattern : String) -> Bool {
  // CIDR notation
  if pattern.contains("/") {
    ip_matches_cidr(ip, pattern)
  } else if pattern.contains("*") {
    // Wildcard pattern
    ip_matches_wildcard(ip, pattern)
  } else {
    // Exact match
    ip == pattern
  }
}

///|
/// Check if IP matches wildcard pattern (e.g., 192.168.1.*)
fn ip_matches_wildcard(ip : String, pattern : String) -> Bool {
  let ip_parts = split_ip(ip)
  let pattern_parts = split_ip(pattern)
  if ip_parts.length() != pattern_parts.length() {
    return false
  }
  for i, ip_part in ip_parts {
    let pattern_part = pattern_parts[i]
    if pattern_part != "*" && ip_part != pattern_part {
      return false
    }
  }
  true
}

///|
/// Split IP address into parts
fn split_ip(ip : String) -> Array[String] {
  let parts : Array[String] = []
  let current = StringBuilder::new()
  for c in ip {
    if c == '.' {
      parts.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  parts.push(current.to_string())
  parts
}

///|
/// Check if IP matches CIDR notation (simplified: /8, /16, /24, /32)
fn ip_matches_cidr(ip : String, cidr : String) -> Bool {
  let slash_idx = find_char(cidr, '/')
  if slash_idx < 0 {
    return false
  }
  let network = safe_substring(cidr, 0, slash_idx)
  let prefix_str = safe_substring_from(cidr, slash_idx + 1)
  let prefix = match parse_int(prefix_str) {
    Some(v) => v
    None => 32
  }
  let network_parts = split_ip(network)
  let ip_parts = split_ip(ip)
  if network_parts.length() != 4 || ip_parts.length() != 4 {
    return false
  }
  // Simplified: only check based on prefix length
  let parts_to_check = prefix / 8
  for i = 0; i < parts_to_check && i < 4; i = i + 1 {
    if network_parts[i] != ip_parts[i] {
      return false
    }
  }
  true
}

///|
/// Find character index in string
fn find_char(s : String, c : Char) -> Int {
  for i, ch in s {
    if ch == c {
      return i
    }
  }
  -1
}

///|
/// Parse integer from string
fn parse_int(s : String) -> Int? {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  Some(result)
}

///|
/// Check if IP matches any pattern in the list
fn ip_matches_any(ip : String, patterns : Array[String]) -> Bool {
  for pattern in patterns {
    if ip_matches_pattern(ip, pattern) {
      return true
    }
  }
  false
}

///|
/// Get client IP from context with trusted proxy validation
fn get_client_ip_secure(
  ctx : @flame.Context,
  header : String,
  trusted_proxies : TrustedProxyConfig,
) -> String {
  // If no trusted proxies configured, return unknown (safest default)
  if not(trusted_proxies.enabled) {
    return "unknown"
  }
  let ip_header = match ctx.header(header) {
    Some(v) => v
    None =>
      match ctx.header("X-Real-IP") {
        Some(v) => v
        None => return "unknown"
      }
  }
  // X-Forwarded-For format: client, proxy1, proxy2, ...
  // We need to find the rightmost IP that is not a trusted proxy
  let ips = split_ip_header(ip_header)
  // Walk from right to left, stop at first untrusted IP
  for i = ips.length() - 1; i >= 0; i = i - 1 {
    let ip = safe_trim(ips[i])
    if not(is_trusted_proxy(ip, trusted_proxies)) {
      return ip
    }
  }
  // All IPs are trusted proxies, return the leftmost (original client)
  if ips.length() > 0 {
    safe_trim(ips[0])
  } else {
    "unknown"
  }
}

///|
/// Split IP header by comma
fn split_ip_header(header : String) -> Array[String] {
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
/// IP filter middleware
pub fn ip_filter(options : IpFilterOptions) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let ip = get_client_ip_secure(
      ctx,
      options.ip_header,
      options.trusted_proxies,
    )
    let matches = ip_matches_any(ip, options.ips)
    if options.whitelist {
      // Whitelist mode: block if NOT in list
      if not(matches) {
        ctx.text("Forbidden", status=403)
      }
      // Blacklist mode: block if in list
    } else if matches {
      ctx.text("Forbidden", status=403)
    }
  }
}

///|
/// IP whitelist middleware
pub fn ip_whitelist(
  ips : Array[String],
  ip_header? : String = "X-Forwarded-For",
  trusted_proxies? : TrustedProxyConfig = TrustedProxyConfig::none(),
) -> @flame.Handler {
  ip_filter({ ips, ip_header, whitelist: true, trusted_proxies })
}

///|
/// IP blacklist middleware
pub fn ip_blacklist(
  ips : Array[String],
  ip_header? : String = "X-Forwarded-For",
  trusted_proxies? : TrustedProxyConfig = TrustedProxyConfig::none(),
) -> @flame.Handler {
  ip_filter({ ips, ip_header, whitelist: false, trusted_proxies })
}

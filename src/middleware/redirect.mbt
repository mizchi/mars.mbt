///|
/// Redirect Middleware
/// HTTP redirect helpers and middleware

///|
/// Redirect status codes
pub(all) enum RedirectStatus {
  /// 301 Moved Permanently
  MovedPermanently
  /// 302 Found (temporary)
  Found
  /// 303 See Other
  SeeOther
  /// 307 Temporary Redirect
  TemporaryRedirect
  /// 308 Permanent Redirect
  PermanentRedirect
}

///|
/// Get status code for redirect type
pub fn RedirectStatus::to_code(self : RedirectStatus) -> Int {
  match self {
    MovedPermanently => 301
    Found => 302
    SeeOther => 303
    TemporaryRedirect => 307
    PermanentRedirect => 308
  }
}

///|
/// Redirect rule
pub(all) struct RedirectRule {
  /// Source path pattern
  from : String
  /// Destination URL or path
  to : String
  /// Redirect status
  status : RedirectStatus
}

///|
/// Create permanent redirect rule (301)
pub fn RedirectRule::permanent(from : String, to : String) -> RedirectRule {
  { from, to, status: MovedPermanently }
}

///|
/// Create temporary redirect rule (302)
pub fn RedirectRule::temporary(from : String, to : String) -> RedirectRule {
  { from, to, status: Found }
}

///|
/// Redirect options
pub(all) struct RedirectOptions {
  /// Redirect rules
  rules : Array[RedirectRule]
}

///|
/// Check if path matches pattern (supports * wildcard)
fn path_matches_redirect(path : String, pattern : String) -> Bool {
  if pattern == path {
    return true
  }
  // Check for wildcard at end
  if ends_with_wildcard(pattern) {
    let prefix = safe_substring(pattern, 0, pattern.length() - 1)
    return path.has_prefix(prefix)
  }
  false
}

///|
/// Check if pattern ends with *
fn ends_with_wildcard(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  chars[chars.length() - 1] == '*'
}

///|
/// Apply redirect transformation
fn apply_redirect_transform(
  path : String,
  from : String,
  to : String,
) -> String {
  if ends_with_wildcard(from) {
    // Extract the matched suffix and append to destination
    let prefix = safe_substring(from, 0, from.length() - 1)
    let suffix = safe_substring_from(path, prefix.length())
    if ends_with_wildcard(to) {
      safe_substring(to, 0, to.length() - 1) + suffix
    } else {
      to + suffix
    }
  } else {
    to
  }
}

///|
/// Redirect middleware with rules
pub fn redirect_rules(options : RedirectOptions) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let path = ctx.path()
    for rule in options.rules {
      if path_matches_redirect(path, rule.from) {
        let destination = apply_redirect_transform(path, rule.from, rule.to)
        ctx.set_header("Location", destination)
        ctx.text("", status=rule.status.to_code())
        return
      }
    }
  }
}

///|
/// Simple redirect handler
pub async fn redirect(
  ctx : @flame.Context,
  url : String,
  status? : RedirectStatus = Found,
) -> Unit {
  ctx.set_header("Location", url)
  ctx.text("", status=status.to_code())
}

///|
/// Permanent redirect (301)
pub async fn redirect_permanent(ctx : @flame.Context, url : String) -> Unit {
  redirect(ctx, url, status=MovedPermanently)
}

///|
/// Temporary redirect (302)
pub async fn redirect_temporary(ctx : @flame.Context, url : String) -> Unit {
  redirect(ctx, url, status=Found)
}

///|
/// HTTPS redirect middleware
pub fn https_redirect() -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    // Check X-Forwarded-Proto header
    let proto = ctx.header("X-Forwarded-Proto").unwrap_or("http")
    if proto == "http" {
      let host = ctx.header("Host").unwrap_or("")
      let path = ctx.path()
      let url = "https://" + host + path
      ctx.set_header("Location", url)
      ctx.text("", status=301)
    }
  }
}

///|
/// WWW redirect middleware (add or remove www)
pub fn www_redirect(add_www : Bool) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let host = ctx.header("Host").unwrap_or("")
    if host.is_empty() {
      return
    }
    let has_www = host.has_prefix("www.")
    if add_www && not(has_www) {
      let path = ctx.path()
      let url = "https://www." + host + path
      ctx.set_header("Location", url)
      ctx.text("", status=301)
    } else if not(add_www) && has_www {
      let path = ctx.path()
      let new_host = safe_substring_from(host, 4)
      let url = "https://" + new_host + path
      ctx.set_header("Location", url)
      ctx.text("", status=301)
    }
  }
}

///|
/// Domain redirect middleware
pub fn domain_redirect(
  from_domain : String,
  to_domain : String,
) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let host = ctx.header("Host").unwrap_or("")
    if host == from_domain || host.has_prefix(from_domain + ":") {
      let path = ctx.path()
      let url = "https://" + to_domain + path
      ctx.set_header("Location", url)
      ctx.text("", status=301)
    }
  }
}

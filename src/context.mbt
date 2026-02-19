///|
/// HTTP Context for request/response handling
pub(all) struct Context {
  /// The incoming HTTP request
  request : @http.Request
  /// URL parameters extracted from route matching
  params : @router.Params
  /// Platform-specific context data
  priv platform : PlatformContext
  /// Custom data storage (string only, legacy)
  priv data : Map[String, String]
  /// Typed variables storage
  vars : Variables
  /// Execution context for background tasks (trait object)
  exec_ctx : &ExecCtx
  /// Environment bindings (trait object)
  priv env : &Env
  /// Cached request body (lazy loaded)
  priv mut cached_body : String?
  /// Cached query parameters (lazy loaded)
  priv mut cached_query : Map[String, String]?
  /// Cached cookies (lazy loaded)
  priv mut cached_cookies : Map[String, String]?
  /// Response headers to send
  priv response_headers : Map[String, String]
  /// Response status (set before sending)
  priv mut status : Int
  /// Whether response has been sent
  priv mut response_sent : Bool
}

///|
/// Get a URL parameter by name
pub fn Context::param(self : Context, name : String) -> String? {
  self.params.get(name)
}

///|
/// Get request path
pub fn Context::path(self : Context) -> String {
  self.request.path
}

///|
/// Get request method
pub fn Context::meth(self : Context) -> @http.RequestMethod {
  self.request.meth
}

///|
/// Get raw HTTP request
pub fn Context::request(self : Context) -> @http.Request {
  self.request
}

///|
/// Get a request header
pub fn Context::header(self : Context, name : String) -> String? {
  self.request.headers.get(name)
}

///|
/// Set custom data
pub fn Context::set(self : Context, key : String, value : String) -> Unit {
  self.data.set(key, value)
}

///|
/// Get custom data
pub fn Context::get(self : Context, key : String) -> String? {
  self.data.get(key)
}

///|
/// Get environment variable
pub fn Context::env_var(self : Context, name : String) -> String? {
  self.env.get_var(name)
}

///|
/// Get environment binding as JSON
pub fn Context::env_binding(self : Context, name : String) -> Json? {
  self.env.get_binding(name)
}

///|
/// Schedule a background task (like Cloudflare's waitUntil)
pub fn Context::wait_until(
  self : Context,
  task : async () -> Unit,
  name? : String = "background",
) -> Unit {
  self.exec_ctx.wait_until(task, name~)
}

///|
/// Set response status code
pub fn Context::set_status(self : Context, status : Int) -> Unit {
  self.status = status
}

///|
/// Set a response header
pub fn Context::set_header(
  self : Context,
  name : String,
  value : String,
) -> Unit {
  self.response_headers.set(name, value)
}

///|
/// Parse request body as JSON
pub async fn Context::body_json(self : Context) -> Json? {
  let body = self.body()
  let result = @json.parse(body) catch { _ => return None }
  Some(result)
}

///|
/// Get a query parameter by name
pub fn Context::query(self : Context, name : String) -> String? {
  let query_map = match self.cached_query {
    Some(q) => q
    None => {
      let q = parse_query_string(self.request.path)
      self.cached_query = Some(q)
      q
    }
  }
  query_map.get(name)
}

///|
/// Get all query parameters
pub fn Context::queries(self : Context) -> Map[String, String] {
  match self.cached_query {
    Some(q) => q
    None => {
      let q = parse_query_string(self.request.path)
      self.cached_query = Some(q)
      q
    }
  }
}

///|
/// Get a cookie by name
pub fn Context::cookie(self : Context, name : String) -> String? {
  let cookies = match self.cached_cookies {
    Some(c) => c
    None => {
      let c = parse_cookies(self.request.headers.get("Cookie").unwrap_or(""))
      self.cached_cookies = Some(c)
      c
    }
  }
  cookies.get(name)
}

///|
/// Get all cookies
pub fn Context::cookies(self : Context) -> Map[String, String] {
  match self.cached_cookies {
    Some(c) => c
    None => {
      let c = parse_cookies(self.request.headers.get("Cookie").unwrap_or(""))
      self.cached_cookies = Some(c)
      c
    }
  }
}

///|
/// Set a cookie
pub fn Context::set_cookie(
  self : Context,
  name : String,
  value : String,
  max_age? : Int = 86400,
  path? : String = "/",
  http_only? : Bool = true,
  same_site? : String = "Lax",
) -> Unit {
  let cookie = build_set_cookie(
    name,
    value,
    max_age~,
    path~,
    http_only~,
    same_site~,
  )
  self.response_headers.set("Set-Cookie", cookie)
}

///|
/// Delete a cookie
pub fn Context::delete_cookie(self : Context, name : String) -> Unit {
  let cookie = "\{name}=; Path=/; Max-Age=0; HttpOnly"
  self.response_headers.set("Set-Cookie", cookie)
}

///|
/// Parse query string from path
fn parse_query_string(path : String) -> Map[String, String] {
  let result : Map[String, String] = {}
  // Find query string start
  let query_start = find_char(path, '?')
  if query_start < 0 || query_start + 1 >= path.length() {
    return result
  }
  // Extract query string
  let query = substring_from(path, query_start + 1)
  // Parse key=value pairs
  let pairs = split_by_char(query, '&')
  for pair in pairs {
    let eq_pos = find_char(pair, '=')
    if eq_pos >= 0 {
      let key = url_decode(substring(pair, 0, eq_pos))
      let value = url_decode(substring_from(pair, eq_pos + 1))
      result.set(key, value)
    }
  }
  result
}

///|
/// Parse cookies from Cookie header
fn parse_cookies(header : String) -> Map[String, String] {
  let result : Map[String, String] = {}
  let pairs = split_by_char(header, ';')
  for pair in pairs {
    let trimmed = trim(pair)
    let eq_pos = find_char(trimmed, '=')
    if eq_pos >= 0 {
      let key = substring(trimmed, 0, eq_pos)
      let value = substring_from(trimmed, eq_pos + 1)
      result.set(key, value)
    }
  }
  result
}

///|
/// Build Set-Cookie header value
fn build_set_cookie(
  name : String,
  value : String,
  max_age~ : Int,
  path~ : String,
  http_only~ : Bool,
  same_site~ : String,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(name)
  buf.write_char('=')
  buf.write_string(value)
  buf.write_string("; Path=")
  buf.write_string(path)
  buf.write_string("; Max-Age=")
  buf.write_string(max_age.to_string())
  if http_only {
    buf.write_string("; HttpOnly")
  }
  buf.write_string("; SameSite=")
  buf.write_string(same_site)
  buf.to_string()
}

///|
/// Merge response headers
/// base: user-set headers (via set_header), these take precedence
/// extra: default headers, only applied if not already set
fn merge_headers(
  base : Map[String, String],
  extra : Map[String, String],
) -> Map[String, String] {
  let result : Map[String, String] = {}
  // First, add defaults
  for key, value in extra {
    result.set(key, value)
  }
  // Then, add user-set headers (overriding defaults)
  for key, value in base {
    result.set(key, value)
  }
  result
}

///|
/// Check if response has been sent
pub fn Context::is_response_sent(self : Context) -> Bool {
  self.response_sent
}

///|
/// HTTP Context for request/response handling
pub(all) struct Context {
  /// The incoming HTTP request
  request : @http.Request
  /// URL parameters extracted from route matching
  params : @router.Params
  /// The server connection for sending responses
  priv conn : @http.ServerConnection
  /// Request body reader
  priv body_reader : &@async_io.Reader
  /// Custom data storage (string only, legacy)
  priv data : Map[String, String]
  /// Typed variables storage
  vars : Variables
  /// Execution context for background tasks
  execution_ctx : ExecutionContext
  /// Environment bindings (platform-specific)
  priv env_bindings : MapEnv
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
/// Create a new Context
pub fn Context::new(
  request : @http.Request,
  params : @router.Params,
  conn : @http.ServerConnection,
  body_reader : &@async_io.Reader,
) -> Context {
  {
    request,
    params,
    conn,
    body_reader,
    data: Map::new(),
    vars: Variables::new(),
    execution_ctx: ExecutionContext::new(),
    env_bindings: MapEnv::new(),
    cached_body: None,
    cached_query: None,
    cached_cookies: None,
    response_headers: {},
    status: 200,
    response_sent: false,
  }
}

///|
/// Create a new Context with environment bindings
pub fn Context::with_env(
  request : @http.Request,
  params : @router.Params,
  conn : @http.ServerConnection,
  body_reader : &@async_io.Reader,
  env : MapEnv,
) -> Context {
  {
    request,
    params,
    conn,
    body_reader,
    data: Map::new(),
    vars: Variables::new(),
    execution_ctx: ExecutionContext::new(),
    env_bindings: env,
    cached_body: None,
    cached_query: None,
    cached_cookies: None,
    response_headers: {},
    status: 200,
    response_sent: false,
  }
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
  self.env_bindings.get_var(name)
}

///|
/// Get environment binding as JSON
pub fn Context::env_binding(self : Context, name : String) -> Json? {
  self.env_bindings.get_binding(name)
}

///|
/// Schedule a background task (like Cloudflare's waitUntil)
pub fn Context::wait_until(
  self : Context,
  task : async () -> Unit,
  name? : String = "background",
) -> Unit {
  self.execution_ctx.wait_until(task, name~)
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
/// Read request body as string
pub async fn Context::body(self : Context) -> String {
  match self.cached_body {
    Some(body) => body
    None => {
      let body = read_body_as_string(self.body_reader)
      self.cached_body = Some(body)
      body
    }
  }
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
/// Read body from reader as string
async fn read_body_as_string(reader : &@async_io.Reader) -> String {
  let buf = StringBuilder::new()
  let chunk = FixedArray::make(4096, b'\x00')
  for {
    let n = reader.read(chunk) catch { _ => break }
    if n == 0 {
      break
    }
    for i = 0; i < n; i = i + 1 {
      buf.write_char(chunk[i].to_int().unsafe_to_char())
    }
  }
  buf.to_string()
}

///|
/// Parse query string from path
fn parse_query_string(path : String) -> Map[String, String] {
  let result : Map[String, String] = {}
  // Find query string start
  let mut query_start = -1
  for i, c in path {
    if c == '?' {
      query_start = i + 1
      break
    }
  }
  if query_start < 0 || query_start >= path.length() {
    return result
  }
  // Extract query string
  let query = extract_substring(path, query_start, path.length())
  // Parse key=value pairs
  let pairs = split_string(query, '&')
  for pair in pairs {
    let eq_pos = find_char_in_string(pair, '=')
    if eq_pos >= 0 {
      let key = url_decode(extract_substring(pair, 0, eq_pos))
      let value = url_decode(extract_substring(pair, eq_pos + 1, pair.length()))
      result.set(key, value)
    }
  }
  result
}

///|
/// Parse cookies from Cookie header
fn parse_cookies(header : String) -> Map[String, String] {
  let result : Map[String, String] = {}
  let pairs = split_string(header, ';')
  for pair in pairs {
    let trimmed = trim_string(pair)
    let eq_pos = find_char_in_string(trimmed, '=')
    if eq_pos >= 0 {
      let key = extract_substring(trimmed, 0, eq_pos)
      let value = extract_substring(trimmed, eq_pos + 1, trimmed.length())
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
/// Extract substring
fn extract_substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in s {
    if i >= start && i < end {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Split string by character
fn split_string(s : String, sep : Char) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == sep {
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
/// Find character in string
fn find_char_in_string(s : String, c : Char) -> Int {
  for i, ch in s {
    if ch == c {
      return i
    }
  }
  -1
}

///|
/// Trim whitespace from string
fn trim_string(s : String) -> String {
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
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// URL decode a string
fn url_decode(s : String) -> String {
  let buf = StringBuilder::new()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '%' && i + 2 < chars.length() {
      let high = hex_to_int(chars[i + 1])
      let low = hex_to_int(chars[i + 2])
      if high >= 0 && low >= 0 {
        buf.write_char(((high << 4) | low).unsafe_to_char())
        i = i + 3
        continue
      }
    } else if c == '+' {
      buf.write_char(' ')
      i = i + 1
      continue
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
/// Convert hex character to int
fn hex_to_int(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// Send a text response
pub async fn Context::text(
  self : Context,
  body : String,
  status? : Int,
) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/plain; charset=utf-8",
  })
  self.conn.send_response(
    status,
    reason_for_status(status),
    extra_headers=headers,
  )
  self.conn.write(@encoding.encode(@encoding.UTF8, body))
  self.conn.end_response()
  self.response_sent = true
}

///|
/// Send a JSON response
pub async fn Context::json(self : Context, data : Json, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "application/json",
  })
  self.conn.send_response(
    status,
    reason_for_status(status),
    extra_headers=headers,
  )
  self.conn.write(@encoding.encode(@encoding.UTF8, data.stringify()))
  self.conn.end_response()
  self.response_sent = true
}

///|
/// Send an HTML response
pub async fn Context::html(
  self : Context,
  body : String,
  status? : Int,
) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/html; charset=utf-8",
  })
  self.conn.send_response(
    status,
    reason_for_status(status),
    extra_headers=headers,
  )
  self.conn.write(@encoding.encode(@encoding.UTF8, body))
  self.conn.end_response()
  self.response_sent = true
}

///|
/// Send a redirect response
pub async fn Context::redirect(self : Context, url : String) -> Unit {
  let headers = merge_headers(self.response_headers, { "Location": url })
  self.conn.send_response(302, "Found", extra_headers=headers)
  self.conn.end_response()
  self.response_sent = true
}

///|
/// Merge response headers
fn merge_headers(
  base : Map[String, String],
  extra : Map[String, String],
) -> Map[String, String] {
  let result : Map[String, String] = {}
  for key, value in base {
    result.set(key, value)
  }
  for key, value in extra {
    result.set(key, value)
  }
  result
}

///|
/// Send a 404 Not Found response
pub async fn Context::not_found(self : Context) -> Unit {
  self.text("Not Found", status=404)
}

///|
/// Start an SSE response (sets headers, does not close connection)
pub async fn Context::sse_start(self : Context) -> Unit {
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  })
  self.conn.send_response(200, "OK", extra_headers=headers)
  self.response_sent = true
}

///|
/// Write raw data to the response (for SSE streaming)
pub async fn Context::write_raw(self : Context, data : String) -> Unit {
  self.conn.write(@encoding.encode(@encoding.UTF8, data))
  self.conn.flush()
}

///|
/// End the response (for SSE streaming)
pub async fn Context::end_response(self : Context) -> Unit {
  self.conn.end_response()
}

///|
/// Check if response has been sent
pub fn Context::is_response_sent(self : Context) -> Bool {
  self.response_sent
}

///|
/// Get HTTP status reason phrase
fn reason_for_status(status : Int) -> String {
  match status {
    200 => "OK"
    201 => "Created"
    204 => "No Content"
    301 => "Moved Permanently"
    302 => "Found"
    304 => "Not Modified"
    400 => "Bad Request"
    401 => "Unauthorized"
    403 => "Forbidden"
    404 => "Not Found"
    405 => "Method Not Allowed"
    500 => "Internal Server Error"
    502 => "Bad Gateway"
    503 => "Service Unavailable"
    _ => "Unknown"
  }
}

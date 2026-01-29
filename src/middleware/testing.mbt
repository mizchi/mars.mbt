///|
/// Testing Utilities
/// Mock context and test client for handler testing

///|
/// Mock request builder
pub(all) struct MockRequest {
  meth : String
  path : String
  headers : Map[String, String]
  mut body : String
  query : Map[String, String]
}

///|
/// Create a new mock request
pub fn MockRequest::new(meth : String, path : String) -> MockRequest {
  { meth, path, headers: {}, body: "", query: {} }
}

///|
/// GET request
pub fn MockRequest::get(path : String) -> MockRequest {
  MockRequest::new("GET", path)
}

///|
/// POST request
pub fn MockRequest::post(path : String) -> MockRequest {
  MockRequest::new("POST", path)
}

///|
/// PUT request
pub fn MockRequest::put(path : String) -> MockRequest {
  MockRequest::new("PUT", path)
}

///|
/// DELETE request
pub fn MockRequest::delete(path : String) -> MockRequest {
  MockRequest::new("DELETE", path)
}

///|
/// Set header
pub fn MockRequest::header(
  self : MockRequest,
  name : String,
  value : String,
) -> MockRequest {
  self.headers.set(name, value)
  self
}

///|
/// Set body
pub fn MockRequest::with_body(self : MockRequest, body : String) -> MockRequest {
  self.body = body
  self
}

///|
/// Set JSON body
pub fn MockRequest::json(self : MockRequest, data : Json) -> MockRequest {
  self.body = data.stringify()
  self.headers.set("Content-Type", "application/json")
  self
}

///|
/// Set form body
pub fn MockRequest::form(
  self : MockRequest,
  data : Map[String, String],
) -> MockRequest {
  let buf = StringBuilder::new()
  let mut first = true
  for key, value in data {
    if not(first) {
      buf.write_char('&')
    }
    first = false
    buf.write_string(url_encode_test(key))
    buf.write_char('=')
    buf.write_string(url_encode_test(value))
  }
  self.body = buf.to_string()
  self.headers.set("Content-Type", "application/x-www-form-urlencoded")
  self
}

///|
/// Set query parameter
pub fn MockRequest::query(
  self : MockRequest,
  name : String,
  value : String,
) -> MockRequest {
  self.query.set(name, value)
  self
}

///|
/// Set authorization header
pub fn MockRequest::auth(self : MockRequest, token : String) -> MockRequest {
  self.headers.set("Authorization", "Bearer " + token)
  self
}

///|
/// Set basic auth
pub fn MockRequest::basic_auth(
  self : MockRequest,
  username : String,
  password : String,
) -> MockRequest {
  let credentials = username + ":" + password
  let encoded = base64_encode_test(credentials)
  self.headers.set("Authorization", "Basic " + encoded)
  self
}

///|
/// Mock response
pub(all) struct MockResponse {
  mut status : Int
  mut headers : Map[String, String]
  mut body : String
  mut sent : Bool
}

///|
/// Create empty mock response
pub fn MockResponse::new() -> MockResponse {
  { status: 200, headers: {}, body: "", sent: false }
}

///|
/// Check if response was sent
pub fn MockResponse::is_sent(self : MockResponse) -> Bool {
  self.sent
}

///|
/// Get status code
pub fn MockResponse::get_status(self : MockResponse) -> Int {
  self.status
}

///|
/// Get header
pub fn MockResponse::get_header(self : MockResponse, name : String) -> String? {
  self.headers.get(name)
}

///|
/// Get body as string
pub fn MockResponse::get_body(self : MockResponse) -> String {
  self.body
}

///|
/// Parse body as JSON
pub fn MockResponse::json(self : MockResponse) -> Json? {
  let result = @json.parse(self.body) catch { _ => return None }
  Some(result)
}

///|
/// Mock context for testing
pub(all) struct MockContext {
  request : MockRequest
  response : MockResponse
  data : Map[String, String]
  params : Map[String, String]
}

///|
/// Create mock context from request
pub fn MockContext::from_request(request : MockRequest) -> MockContext {
  { request, response: MockResponse::new(), data: {}, params: {} }
}

///|
/// Set URL parameter
pub fn MockContext::set_param(
  self : MockContext,
  name : String,
  value : String,
) -> MockContext {
  self.params.set(name, value)
  self
}

///|
/// Get URL parameter
pub fn MockContext::param(self : MockContext, name : String) -> String? {
  self.params.get(name)
}

///|
/// Get path
pub fn MockContext::path(self : MockContext) -> String {
  self.request.path
}

///|
/// Get method
pub fn MockContext::meth(self : MockContext) -> String {
  self.request.meth
}

///|
/// Get header
pub fn MockContext::header(self : MockContext, name : String) -> String? {
  self.request.headers.get(name)
}

///|
/// Get body
pub fn MockContext::body(self : MockContext) -> String {
  self.request.body
}

///|
/// Get query parameter
pub fn MockContext::query(self : MockContext, name : String) -> String? {
  self.request.query.get(name)
}

///|
/// Set custom data
pub fn MockContext::set(
  self : MockContext,
  key : String,
  value : String,
) -> Unit {
  self.data.set(key, value)
}

///|
/// Get custom data
pub fn MockContext::get(self : MockContext, key : String) -> String? {
  self.data.get(key)
}

///|
/// Set response header
pub fn MockContext::set_header(
  self : MockContext,
  name : String,
  value : String,
) -> Unit {
  self.response.headers.set(name, value)
}

///|
/// Set response status
pub fn MockContext::set_status(self : MockContext, status : Int) -> Unit {
  self.response.status = status
}

///|
/// Send text response
pub fn MockContext::text(
  self : MockContext,
  body : String,
  status? : Int = 200,
) -> Unit {
  self.response.status = status
  self.response.body = body
  self.response.headers.set("Content-Type", "text/plain; charset=utf-8")
  self.response.sent = true
}

///|
/// Send JSON response
pub fn MockContext::json_response(
  self : MockContext,
  data : Json,
  status? : Int = 200,
) -> Unit {
  self.response.status = status
  self.response.body = data.stringify()
  self.response.headers.set("Content-Type", "application/json")
  self.response.sent = true
}

///|
/// Check if response sent
pub fn MockContext::is_response_sent(self : MockContext) -> Bool {
  self.response.sent
}

///|
/// Get response
pub fn MockContext::get_response(self : MockContext) -> MockResponse {
  self.response
}

///|
/// URL encode for testing
fn url_encode_test(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    if (c >= 'A' && c <= 'Z') ||
      (c >= 'a' && c <= 'z') ||
      (c >= '0' && c <= '9') ||
      c == '-' ||
      c == '_' ||
      c == '.' ||
      c == '~' {
      buf.write_char(c)
    } else if c == ' ' {
      buf.write_char('+')
    } else {
      let byte = c.to_int()
      buf.write_char('%')
      buf.write_char(hex_char_test(byte >> 4))
      buf.write_char(hex_char_test(byte & 0x0F))
    }
  }
  buf.to_string()
}

///|
/// Hex char for testing
fn hex_char_test(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('A'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
/// Simple Base64 encode for testing
fn base64_encode_test(s : String) -> String {
  let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let table_chars : Array[Char] = []
  for c in table {
    table_chars.push(c)
  }
  let bytes : Array[Int] = []
  for c in s {
    bytes.push(c.to_int())
  }
  let buf = StringBuilder::new()
  let mut i = 0
  while i < bytes.length() {
    let b1 = bytes[i]
    let b2 = if i + 1 < bytes.length() { bytes[i + 1] } else { 0 }
    let b3 = if i + 2 < bytes.length() { bytes[i + 2] } else { 0 }
    buf.write_char(table_chars[b1 >> 2])
    buf.write_char(table_chars[((b1 & 0x03) << 4) | (b2 >> 4)])
    if i + 1 < bytes.length() {
      buf.write_char(table_chars[((b2 & 0x0F) << 2) | (b3 >> 6)])
    } else {
      buf.write_char('=')
    }
    if i + 2 < bytes.length() {
      buf.write_char(table_chars[b3 & 0x3F])
    } else {
      buf.write_char('=')
    }
    i = i + 3
  }
  buf.to_string()
}

///|
/// Test assertion helper
pub fn assert_status(response : MockResponse, expected : Int) -> Bool {
  response.status == expected
}

///|
/// Assert response contains text
pub fn assert_body_contains(response : MockResponse, text : String) -> Bool {
  response.body.contains(text)
}

///|
/// Assert header exists
pub fn assert_header(
  response : MockResponse,
  name : String,
  expected : String,
) -> Bool {
  match response.headers.get(name) {
    Some(v) => v == expected
    None => false
  }
}

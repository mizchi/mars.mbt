///|
/// HTTP Context for request/response handling
pub(all) struct Context {
  /// The incoming HTTP request
  request : @http.Request
  /// URL parameters extracted from route matching
  params : @router.Params
  /// The server connection for sending responses
  priv conn : @http.ServerConnection
  /// Custom data storage
  priv data : Map[String, String]
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
) -> Context {
  { request, params, conn, data: Map::new(), status: 200, response_sent: false }
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
/// Set response status code
pub fn Context::set_status(self : Context, status : Int) -> Unit {
  self.status = status
}

///|
/// Send a text response
pub async fn Context::text(
  self : Context,
  body : String,
  status? : Int,
) -> Unit {
  let status = status.unwrap_or(self.status)
  self.conn.send_response(status, reason_for_status(status))
  self.conn.write(@encoding.encode(@encoding.UTF8, body))
  self.conn.end_response()
  self.response_sent = true
}

///|
/// Send a JSON response
pub async fn Context::json(self : Context, data : Json, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  self.conn.send_response(status, reason_for_status(status), extra_headers={
    "Content-Type": "application/json",
  })
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
  self.conn.send_response(status, reason_for_status(status), extra_headers={
    "Content-Type": "text/html; charset=utf-8",
  })
  self.conn.write(@encoding.encode(@encoding.UTF8, body))
  self.conn.end_response()
  self.response_sent = true
}

///|
/// Send a redirect response
pub async fn Context::redirect(self : Context, url : String) -> Unit {
  self.conn.send_response(302, "Found", extra_headers={ "Location": url })
  self.conn.end_response()
  self.response_sent = true
}

///|
/// Send a 404 Not Found response
pub async fn Context::not_found(self : Context) -> Unit {
  self.text("Not Found", status=404)
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

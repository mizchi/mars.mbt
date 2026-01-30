///|
/// Native platform-specific context data
pub(all) struct PlatformContext {
  /// The server connection for sending responses
  conn : @http.ServerConnection
  /// Request body reader
  body_reader : &@async_io.Reader
}

///|
/// Create a new PlatformContext for native
pub fn PlatformContext::new(
  conn : @http.ServerConnection,
  body_reader : &@async_io.Reader,
) -> PlatformContext {
  { conn, body_reader }
}

///|
/// Create a new Context (native-specific constructor)
pub fn Context::new(
  request : @http.Request,
  params : @router.Params,
  conn : @http.ServerConnection,
  body_reader : &@async_io.Reader,
) -> Context {
  let exec_ctx = ExecutionContext::new()
  let env = EmptyEnv::new()
  {
    request,
    params,
    platform: PlatformContext::new(conn, body_reader),
    data: Map::new(),
    vars: Variables::new(),
    exec_ctx,
    env,
    cached_body: None,
    cached_query: None,
    cached_cookies: None,
    response_headers: {},
    status: 200,
    response_sent: false,
  }
}

///|
/// Create a new Context with environment and execution context (native-specific)
pub fn[E : Env, C : ExecCtx] Context::with_env(
  request : @http.Request,
  params : @router.Params,
  conn : @http.ServerConnection,
  body_reader : &@async_io.Reader,
  env : E,
  exec_ctx : C,
) -> Context {
  {
    request,
    params,
    platform: PlatformContext::new(conn, body_reader),
    data: Map::new(),
    vars: Variables::new(),
    exec_ctx,
    env,
    cached_body: None,
    cached_query: None,
    cached_cookies: None,
    response_headers: {},
    status: 200,
    response_sent: false,
  }
}

///|
/// Read body from reader as string (native implementation)
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
/// Read request body as string (native implementation)
pub async fn Context::body(self : Context) -> String {
  match self.cached_body {
    Some(body) => body
    None => {
      let body = read_body_as_string(self.platform.body_reader)
      self.cached_body = Some(body)
      body
    }
  }
}

///|
/// Send a text response (native implementation)
pub async fn Context::text(
  self : Context,
  body : String,
  status? : Int,
) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/plain; charset=utf-8",
  })
  self.platform.conn.send_response(
    status,
    reason_for_status(status),
    extra_headers=headers,
  )
  self.platform.conn.write(@encoding.encode(@encoding.UTF8, body))
  self.platform.conn.end_response()
  self.response_sent = true
}

///|
/// Send a JSON response (native implementation)
pub async fn Context::json(self : Context, data : Json, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "application/json",
  })
  self.platform.conn.send_response(
    status,
    reason_for_status(status),
    extra_headers=headers,
  )
  self.platform.conn.write(@encoding.encode(@encoding.UTF8, data.stringify()))
  self.platform.conn.end_response()
  self.response_sent = true
}

///|
/// Send an HTML response (native implementation)
pub async fn Context::html(
  self : Context,
  body : String,
  status? : Int,
) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/html; charset=utf-8",
  })
  self.platform.conn.send_response(
    status,
    reason_for_status(status),
    extra_headers=headers,
  )
  self.platform.conn.write(@encoding.encode(@encoding.UTF8, body))
  self.platform.conn.end_response()
  self.response_sent = true
}

///|
/// Send a redirect response (native implementation)
pub async fn Context::redirect(self : Context, url : String) -> Unit {
  let headers = merge_headers(self.response_headers, { "Location": url })
  self.platform.conn.send_response(302, "Found", extra_headers=headers)
  self.platform.conn.end_response()
  self.response_sent = true
}

///|
/// Send a 404 Not Found response (native implementation)
pub async fn Context::not_found(self : Context) -> Unit {
  self.text("Not Found", status=404)
}

///|
/// Start an SSE response (native implementation)
pub async fn Context::sse_start(self : Context) -> Unit {
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  })
  self.platform.conn.send_response(200, "OK", extra_headers=headers)
  self.response_sent = true
}

///|
/// Write raw data to the response (native implementation)
pub async fn Context::write_raw(self : Context, data : String) -> Unit {
  self.platform.conn.write(@encoding.encode(@encoding.UTF8, data))
  self.platform.conn.flush()
}

///|
/// End the response (native implementation)
pub async fn Context::end_response(self : Context) -> Unit {
  self.platform.conn.end_response()
}

///|
/// Get server connection (native only)
pub fn Context::conn(self : Context) -> @http.ServerConnection {
  self.platform.conn
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

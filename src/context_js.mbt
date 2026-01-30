///|
/// JavaScript Request FFI type
pub(all) type JsRequest

///|
/// JavaScript Response FFI type
pub(all) type JsResponse

///|
/// JavaScript Headers FFI type
type JsHeaders

///|
/// Get request method from JsRequest
extern "js" fn js_request_method(req : JsRequest) -> String =
  #| (req) => req.method

///|
/// Get request URL from JsRequest
extern "js" fn js_request_url(req : JsRequest) -> String =
  #| (req) => req.url

///|
/// Get request body as text from JsRequest
extern "js" fn js_request_text(req : JsRequest) -> @js_async.Promise[String] =
  #| (req) => req.text()

///|
/// Get request headers from JsRequest
extern "js" fn js_request_headers(req : JsRequest) -> JsHeaders =
  #| (req) => req.headers

///|
/// Get header value from JsHeaders
extern "js" fn js_headers_get(headers : JsHeaders, name : String) -> String? =
  #| (headers, name) => headers.get(name)

///|
/// Create a new JsResponse
extern "js" fn js_response_new(
  body : String,
  status : Int,
  headers : Json,
) -> JsResponse =
  #| (body, status, headers) => new Response(body, { status, headers })

///|
/// JavaScript platform-specific context data
pub(all) struct PlatformContext {
  /// Original JavaScript request
  js_request : JsRequest
  /// JavaScript headers
  js_headers : JsHeaders
  /// Response resolver callback
  response_resolve : (JsResponse) -> Unit
}

///|
/// Create a new PlatformContext for JS
pub fn PlatformContext::new(
  js_request : JsRequest,
  response_resolve : (JsResponse) -> Unit,
) -> PlatformContext {
  { js_request, js_headers: js_request_headers(js_request), response_resolve }
}

///|
/// Create a new Context (JS-specific constructor)
pub fn Context::new_js(
  request : @http.Request,
  params : @router.Params,
  js_request : JsRequest,
  response_resolve : (JsResponse) -> Unit,
) -> Context {
  {
    request,
    params,
    platform: PlatformContext::new(js_request, response_resolve),
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
/// Create a new Context with environment bindings (JS-specific constructor)
pub fn Context::with_env_js(
  request : @http.Request,
  params : @router.Params,
  js_request : JsRequest,
  response_resolve : (JsResponse) -> Unit,
  env : MapEnv,
) -> Context {
  {
    request,
    params,
    platform: PlatformContext::new(js_request, response_resolve),
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
/// Read request body as string (JS implementation)
pub async fn Context::body(self : Context) -> String {
  match self.cached_body {
    Some(body) => body
    None => {
      let body = js_request_text(self.platform.js_request).wait()
      self.cached_body = Some(body)
      body
    }
  }
}

///|
/// Build response headers as JSON for JS Response constructor
fn build_js_headers(headers : Map[String, String]) -> Json {
  let obj : Map[String, Json] = {}
  for key, value in headers {
    obj.set(key, Json::string(value))
  }
  Json::object(obj)
}

///|
/// Send response via JS callback
fn send_js_response(
  resolve : (JsResponse) -> Unit,
  body : String,
  status : Int,
  headers : Map[String, String],
) -> Unit {
  let response = js_response_new(body, status, build_js_headers(headers))
  resolve(response)
}

///|
/// Send a text response (JS implementation)
pub fn Context::text(self : Context, body : String, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/plain; charset=utf-8",
  })
  send_js_response(self.platform.response_resolve, body, status, headers)
  self.response_sent = true
}

///|
/// Send a JSON response (JS implementation)
pub fn Context::json(self : Context, data : Json, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "application/json",
  })
  send_js_response(
    self.platform.response_resolve,
    data.stringify(),
    status,
    headers,
  )
  self.response_sent = true
}

///|
/// Send an HTML response (JS implementation)
pub fn Context::html(self : Context, body : String, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/html; charset=utf-8",
  })
  send_js_response(self.platform.response_resolve, body, status, headers)
  self.response_sent = true
}

///|
/// Send a redirect response (JS implementation)
pub fn Context::redirect(self : Context, url : String) -> Unit {
  let headers = merge_headers(self.response_headers, { "Location": url })
  send_js_response(self.platform.response_resolve, "", 302, headers)
  self.response_sent = true
}

///|
/// Send a 404 Not Found response (JS implementation)
pub fn Context::not_found(self : Context) -> Unit {
  self.text("Not Found", status=404)
}

///|
/// Start an SSE response - not fully supported in JS fetch handler
/// For full SSE support, consider using native or specialized streaming
pub fn Context::sse_start(self : Context) -> Unit {
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  })
  // Note: Full SSE streaming requires ReadableStream in JS
  // This is a simplified implementation
  send_js_response(self.platform.response_resolve, "", 200, headers)
  self.response_sent = true
}

///|
/// Write raw data - limited support in JS fetch handler
pub fn Context::write_raw(self : Context, _data : String) -> Unit {
  // Note: Streaming writes require ReadableStream in JS
  // This is a no-op in the simplified fetch handler
  let _ = self
  ()
}

///|
/// End the response - no-op in JS fetch handler
pub fn Context::end_response(self : Context) -> Unit {
  // Response is already sent via Promise resolution
  let _ = self
  ()
}

///|
/// Convert JS method string to @http.RequestMethod
pub fn js_method_to_request_method(meth : String) -> @http.RequestMethod {
  match meth {
    "GET" => @http.RequestMethod::Get
    "POST" => @http.RequestMethod::Post
    "PUT" => @http.RequestMethod::Put
    "DELETE" => @http.RequestMethod::Delete
    "PATCH" => @http.RequestMethod::Patch
    "HEAD" => @http.RequestMethod::Head
    "OPTIONS" => @http.RequestMethod::Options
    "CONNECT" => @http.RequestMethod::Connect
    "TRACE" => @http.RequestMethod::Trace
    _ => @http.RequestMethod::Get
  }
}

///|
/// Parse path from URL string
fn parse_path_from_url(url : String) -> String {
  // Find protocol end (://)
  let mut start = 0
  let chars : Array[Char] = []
  for c in url {
    chars.push(c)
  }
  // Skip protocol
  for i = 0; i < chars.length() - 2; i = i + 1 {
    if chars[i] == ':' && chars[i + 1] == '/' && chars[i + 2] == '/' {
      start = i + 3
      break
    }
  }
  // Find host end (first / after protocol)
  for i = start; i < chars.length(); i = i + 1 {
    if chars[i] == '/' {
      // Return from this / to end
      let buf = StringBuilder::new()
      for j = i; j < chars.length(); j = j + 1 {
        buf.write_char(chars[j])
      }
      return buf.to_string()
    }
  }
  "/"
}

///|
/// Parse headers from JsHeaders to Map
fn parse_js_headers(js_headers : JsHeaders) -> Map[String, String] {
  let headers : Map[String, String] = {}
  // Common headers to check
  let common_headers = [
    "Content-Type", "Accept", "Authorization", "Cookie", "User-Agent", "Host", "Origin",
    "Referer", "X-Requested-With", "Content-Length",
  ]
  for name in common_headers {
    match js_headers_get(js_headers, name) {
      Some(value) => headers.set(name, value)
      None => ()
    }
  }
  headers
}

///|
/// Create @http.Request from JsRequest
pub fn js_request_to_http_request(js_req : JsRequest) -> @http.Request {
  let meth = js_method_to_request_method(js_request_method(js_req))
  let url = js_request_url(js_req)
  let path = parse_path_from_url(url)
  let headers = parse_js_headers(js_request_headers(js_req))
  { meth, path, headers }
}

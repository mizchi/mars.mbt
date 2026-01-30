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
/// JavaScript ExecutionContext FFI type (Cloudflare Workers)
pub(all) type JsExecCtx

///|
/// Call waitUntil on JS ExecutionContext
extern "js" fn js_exec_ctx_wait_until(
  ctx : JsExecCtx,
  promise : @js_async.Promise[Unit],
) -> Unit =
  #| (ctx, promise) => ctx.waitUntil(promise)

///|
/// Implement ExecCtx trait for JsExecCtx
pub impl ExecCtx for JsExecCtx with wait_until(self, task, name~) {
  // Convert MoonBit async function to JS Promise
  let _ = name
  let promise = @js_async.Promise::from_async(task)
  js_exec_ctx_wait_until(self, promise)
}

///|
/// JavaScript Env FFI type (Cloudflare Workers bindings)
pub(all) type JsEnv

///|
/// Get environment variable from JS Env
extern "js" fn js_env_get_var(env : JsEnv, name : String) -> String? =
  #| (env, name) => {
  #|   const value = env[name];
  #|   return typeof value === 'string' ? value : undefined;
  #| }

///|
/// Get binding from JS Env as JSON string
extern "js" fn js_env_get_binding_json(env : JsEnv, name : String) -> String? =
  #| (env, name) => {
  #|   const value = env[name];
  #|   if (value === undefined) return undefined;
  #|   // For simple values, return as JSON
  #|   // For complex objects (KV, D1, etc.), return type info
  #|   if (typeof value === 'object' && value !== null) {
  #|     if (value.constructor && value.constructor.name) {
  #|       return JSON.stringify({ _type: value.constructor.name });
  #|     }
  #|   }
  #|   return JSON.stringify(value);
  #| }

///|
/// Implement Env trait for JsEnv
pub impl Env for JsEnv with get_var(self, name) {
  js_env_get_var(self, name)
}

///|
pub impl Env for JsEnv with get_binding(self, name) {
  match js_env_get_binding_json(self, name) {
    Some(json_str) => @json.parse(json_str) |> Result::ok
    None => None
  }
}

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
/// Returns undefined for None (headers.get returns null which MoonBit may not handle correctly)
extern "js" fn js_headers_get(headers : JsHeaders, name : String) -> String? =
  #| (headers, name) => {
  #|   const value = headers.get(name);
  #|   return value === null ? undefined : value;
  #| }

///|
/// Create a new JsResponse with headers object
/// Headers are passed as MoonBit Map and converted to JS object in FFI
extern "js" fn js_response_new(
  body : String,
  status : Int,
  headers : Map[String, String],
) -> JsResponse =
  #| (body, status, headers) => {
  #|   // Convert MoonBit Map to plain JS object for Response headers
  #|   // MoonBit Map structure: { head: node, entries: [...] }
  #|   // where each node has: { key, value, next }
  #|   const headerObj = {};
  #|   let curr = headers.head;
  #|   while (curr !== undefined && curr !== -1) {
  #|     headerObj[curr.key] = curr.value;
  #|     curr = curr.next;
  #|   }
  #|   return new Response(body, { status, headers: headerObj });
  #| }

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
  let exec_ctx = ExecutionContext::new()
  let env = EmptyEnv::new()
  {
    request,
    params,
    platform: PlatformContext::new(js_request, response_resolve),
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
/// Create a new Context with environment and execution context (JS-specific)
pub fn[E : Env, C : ExecCtx] Context::with_env_js(
  request : @http.Request,
  params : @router.Params,
  js_request : JsRequest,
  response_resolve : (JsResponse) -> Unit,
  env : E,
  exec_ctx : C,
) -> Context {
  {
    request,
    params,
    platform: PlatformContext::new(js_request, response_resolve),
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
/// Get any request header by name (directly from JS Headers API)
/// This is useful for custom headers not in the common headers list
pub fn Context::raw_header(self : Context, name : String) -> String? {
  js_headers_get(self.platform.js_headers, name)
}

// Note: build_js_headers removed - headers are now passed directly to FFI
// The js_response_new FFI handles Map[String, String] -> JS object conversion

///|
/// Send response via JS callback
fn send_js_response(
  resolve : (JsResponse) -> Unit,
  body : String,
  status : Int,
  headers : Map[String, String],
) -> Unit {
  let response = js_response_new(body, status, headers)
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
/// Unknown methods are logged (if debug enabled) and default to GET
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
    _ => {
      if is_debug() {
        println(
          "[mars] Warning: Unknown HTTP method '\{meth}', treating as GET",
        )
      }
      @http.RequestMethod::Get
    }
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
/// Note: Use ctx.raw_header() for headers not in this list
fn parse_js_headers(js_headers : JsHeaders) -> Map[String, String] {
  let headers : Map[String, String] = {}
  // Common headers to check
  // For custom headers, use ctx.raw_header("X-Custom-Header")
  let common_headers = [
    // Standard request headers
    "Content-Type", "Accept", "Authorization", "Cookie", "User-Agent", "Host", "Origin",
    "Referer", "Content-Length",
    // CORS headers
     "Access-Control-Request-Method", "Access-Control-Request-Headers",
    // Proxy headers
     "X-Forwarded-For", "X-Forwarded-Proto", "X-Forwarded-Host", "X-Real-IP",
    // Cache headers
     "If-None-Match", "If-Modified-Since", "Cache-Control",
    // Fetch Metadata headers for CSRF protection
     "Sec-Fetch-Site", "Sec-Fetch-Mode", "Sec-Fetch-Dest",
    // Common custom headers
     "X-Requested-With", "X-Request-ID", "X-Correlation-ID",
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

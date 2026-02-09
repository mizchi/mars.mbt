///|
/// Runtime response state for wasm handlers
pub(all) struct WasmResponseState {
  mut status : Int
  mut headers : Map[String, String]
  mut body : String
  mut sent : Bool
}

///|
pub fn WasmResponseState::new() -> WasmResponseState {
  { status: 200, headers: {}, body: "", sent: false }
}

///|
/// Wasm platform-specific context data
pub(all) struct PlatformContext {
  request_body : String
  state : Ref[WasmResponseState]
}

///|
pub fn PlatformContext::new(
  request_body : String,
  state : Ref[WasmResponseState],
) -> PlatformContext {
  { request_body, state }
}

///|
/// Keep Context::body async-compatible in wasm target
async fn wasm_async_checkpoint() -> Unit {
  ignore(@async.with_timeout_opt(1, async fn() { () }))
}

///|
/// Create a new Context (wasm-specific constructor)
pub fn Context::new(
  request : @http.Request,
  params : @router.Params,
  request_body : String,
  state : Ref[WasmResponseState],
) -> Context {
  let exec_ctx = ExecutionContext::new()
  let env = EmptyEnv::new()
  {
    request,
    params,
    platform: PlatformContext::new(request_body, state),
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
/// Create a new Context with environment and execution context (wasm-specific)
pub fn[E : Env, C : ExecCtx] Context::with_env(
  request : @http.Request,
  params : @router.Params,
  request_body : String,
  state : Ref[WasmResponseState],
  env : E,
  exec_ctx : C,
) -> Context {
  {
    request,
    params,
    platform: PlatformContext::new(request_body, state),
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
fn set_wasm_response(
  ctx : Context,
  status : Int,
  headers : Map[String, String],
  body : String,
) -> Unit {
  ctx.status = status
  ctx.platform.state.val.status = status
  ctx.platform.state.val.headers = headers
  ctx.platform.state.val.body = body
  ctx.platform.state.val.sent = true
  ctx.response_sent = true
}

///|
/// Read request body as string (wasm implementation)
pub async fn Context::body(self : Context) -> String {
  wasm_async_checkpoint()
  match self.cached_body {
    Some(body) => body
    None => {
      let body = self.platform.request_body
      self.cached_body = Some(body)
      body
    }
  }
}

///|
/// Send a text response (wasm implementation)
pub fn Context::text(self : Context, body : String, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/plain; charset=utf-8",
  })
  set_wasm_response(self, status, headers, body)
}

///|
/// Send a JSON response (wasm implementation)
pub fn Context::json(self : Context, data : Json, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "application/json",
  })
  set_wasm_response(self, status, headers, data.stringify())
}

///|
/// Send an HTML response (wasm implementation)
pub fn Context::html(self : Context, body : String, status? : Int) -> Unit {
  let status = status.unwrap_or(self.status)
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/html; charset=utf-8",
  })
  set_wasm_response(self, status, headers, body)
}

///|
/// Send a redirect response (wasm implementation)
pub fn Context::redirect(self : Context, url : String) -> Unit {
  let headers = merge_headers(self.response_headers, { "Location": url })
  set_wasm_response(self, 302, headers, "")
}

///|
/// Send a 404 Not Found response (wasm implementation)
pub fn Context::not_found(self : Context) -> Unit {
  self.text("Not Found", status=404)
}

///|
/// Start an SSE response (wasm implementation)
pub fn Context::sse_start(self : Context) -> Unit {
  let headers = merge_headers(self.response_headers, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  })
  self.platform.state.val.status = self.status
  self.platform.state.val.headers = headers
  self.platform.state.val.body = ""
  self.platform.state.val.sent = true
  self.response_sent = true
}

///|
/// Write raw data to the response (wasm implementation)
pub fn Context::write_raw(self : Context, data : String) -> Unit {
  if not(self.platform.state.val.sent) {
    self.platform.state.val.status = self.status
    self.platform.state.val.headers = self.response_headers
    self.platform.state.val.body = ""
    self.platform.state.val.sent = true
    self.response_sent = true
  }
  self.platform.state.val.body = self.platform.state.val.body + data
}

///|
/// End the response (wasm implementation)
pub fn Context::end_response(self : Context) -> Unit {
  if not(self.platform.state.val.sent) {
    self.platform.state.val.status = self.status
    self.platform.state.val.headers = self.response_headers
    self.platform.state.val.body = ""
  }
  self.platform.state.val.sent = true
  self.response_sent = true
}

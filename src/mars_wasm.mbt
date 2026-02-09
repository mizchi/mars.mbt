///|
/// Request payload for wasm runtime handlers
pub(all) struct WasmRequest {
  request : @http.Request
  body : String
}

///|
pub fn WasmRequest::new(
  request : @http.Request,
  body? : String = "",
) -> WasmRequest {
  { request, body }
}

///|
/// Response value produced by wasm runtime handlers
pub(all) struct WasmResponse {
  status : Int
  headers : Map[String, String]
  body : String
} derive(Show, Eq)

///|
fn request_method_to_method(meth : @http.RequestMethod) -> @router.Method {
  match meth {
    Get => @router.Method::Get
    Post => @router.Method::Post
    Put => @router.Method::Put
    Delete => @router.Method::Delete
    Patch => @router.Method::Patch
    Head => @router.Method::Head
    Options => @router.Method::Options
    Connect => @router.Method::Connect
    Trace => @router.Method::Trace
  }
}

///|
fn build_not_found_headers() -> Map[String, String] {
  { "Content-Type": "text/plain; charset=utf-8" }
}

///|
fn build_error_headers() -> Map[String, String] {
  { "Content-Type": "text/plain; charset=utf-8" }
}

///|
fn build_wasm_response(
  status : Int,
  body : String,
  headers : Map[String, String],
) -> WasmResponse {
  { status, headers, body }
}

///|
pub type AppHandler = async (WasmRequest) -> WasmResponse

///|
/// Convert Server app to a platform handler function (wasm runtime)
pub fn Server::to_handler(self : Server) -> AppHandler {
  self.to_handler_with_env(EmptyEnv::new(), ExecutionContext::new())
}

///|
/// Convert Server app to a platform handler function with environment and execution context (wasm runtime)
pub fn[E : Env, C : ExecCtx] Server::to_handler_with_env(
  self : Server,
  env : E,
  exec_ctx : C,
) -> AppHandler {
  async fn(input) {
    let request = input.request
    let meth = request_method_to_method(request.meth)
    let state : Ref[WasmResponseState] = { val: WasmResponseState::new() }
    let dispatch_result = self.match_and_dispatch(meth, request.path, fn(
      params,
    ) {
      Context::with_env(request, params, input.body, state, env, exec_ctx)
    })
    let dispatch = match dispatch_result {
      RequestDispatchResult::NotFound =>
        return build_wasm_response(404, "Not Found", build_not_found_headers())
      RequestDispatchResult::Dispatched(d) => d
    }
    match dispatch_fallback_status(dispatch) {
      Some(500) =>
        return build_wasm_response(
          500,
          "Internal Server Error",
          build_error_headers(),
        )
      Some(404) => ()
      _ => ()
    }
    if state.val.sent {
      build_wasm_response(state.val.status, state.val.body, state.val.headers)
    } else {
      build_wasm_response(404, "Not Found", build_not_found_headers())
    }
  }
}

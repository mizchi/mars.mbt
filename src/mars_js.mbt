///|
/// Convert JS method string to @router.Method
/// Unknown methods are logged (if debug enabled) and default to GET
fn js_method_to_router_method(meth : String) -> @router.Method {
  match meth {
    "GET" => @router.Method::Get
    "POST" => @router.Method::Post
    "PUT" => @router.Method::Put
    "DELETE" => @router.Method::Delete
    "PATCH" => @router.Method::Patch
    "HEAD" => @router.Method::Head
    "OPTIONS" => @router.Method::Options
    "CONNECT" => @router.Method::Connect
    "TRACE" => @router.Method::Trace
    "QUERY" => @router.Method::Query
    _ => {
      if is_debug() {
        println(
          "[mars] Warning: Unknown HTTP method '\{meth}' for routing, treating as GET",
        )
      }
      @router.Method::Get
    }
  }
}

///|
/// Build default headers for not found responses
fn build_not_found_headers() -> Map[String, String] {
  { "Content-Type": "text/plain" }
}

///|
/// Build default headers for error responses
fn build_error_headers() -> Map[String, String] {
  { "Content-Type": "text/plain" }
}

///|
pub type AppHandler = (JsRequest) -> @js_async.Promise[JsResponse]

///|
/// Convert Server app to a platform handler function
pub fn Server::to_handler(self : Server) -> AppHandler {
  self.to_handler_with_env(EmptyEnv::new(), ExecutionContext::new())
}

///|
/// FFI to trigger coroutine scheduler
/// moonbitlang/async's Promise::from_async doesn't reschedule after spawn,
/// so we need to manually trigger it for JS target
extern "js" fn ffi_reschedule() -> Unit =
  #| () => {
  #|   // Use moonbitlang/async's event_loop reschedule for proper coroutine context
  #|   moonbitlang$async$internal$event_loop$$reschedule();
  #| }

///|
/// Convert Server app to a platform handler function with environment and execution context
pub fn[E : Env, C : ExecCtx] Server::to_handler_with_env(
  self : Server,
  env : E,
  exec_ctx : C,
) -> AppHandler {
  fn(js_request : JsRequest) -> @js_async.Promise[JsResponse] {
    // Create async handler using Promise::from_async
    let promise = @js_async.Promise::from_async(async fn() -> JsResponse {
      // Convert JsRequest to @http.Request
      let request = js_request_to_http_request(js_request)
      let meth_str = js_request_method(js_request)
      let meth = js_method_to_router_method(meth_str)

      // We need to capture the response in a ref
      let response_ref : Ref[JsResponse?] = { val: None }
      let resolve = fn(resp : JsResponse) { response_ref.val = Some(resp) }
      let dispatch_result = self.match_and_dispatch(meth, request.path, fn(
        params,
      ) {
        Context::with_env_js(
          request, params, js_request, resolve, env, exec_ctx,
        )
      })
      let dispatch = match dispatch_result {
        RequestDispatchResult::NotFound =>
          return js_response_new("Not Found", 404, build_not_found_headers())
        RequestDispatchResult::Dispatched(d) => d
      }
      match dispatch_fallback_status(dispatch) {
        Some(500) =>
          return js_response_new(
            "Internal Server Error",
            500,
            build_error_headers(),
          )
        Some(404) => ()
        _ => ()
      }

      // Return response resolved by Context, or fallback when not sent.
      match response_ref.val {
        Some(resp) => resp
        None =>
          if dispatch.response_sent {
            js_response_new("Internal Server Error", 500, build_error_headers())
          } else {
            js_response_new("Not Found", 404, build_not_found_headers())
          }
      }
    })
    // Trigger coroutine scheduler for JS target
    ffi_reschedule()
    promise
  }
}

///|
/// Convert Server app to a fetch handler function
/// Kept for backward compatibility
pub fn Server::to_fetch_handler(
  self : Server,
) -> (JsRequest) -> @js_async.Promise[JsResponse] {
  self.to_handler()
}

///|
/// Convert Server app to a fetch handler function with environment and execution context
/// Kept for backward compatibility
pub fn[E : Env, C : ExecCtx] Server::to_fetch_handler_with_env(
  self : Server,
  env : E,
  exec_ctx : C,
) -> (JsRequest) -> @js_async.Promise[JsResponse] {
  self.to_handler_with_env(env, exec_ctx)
}

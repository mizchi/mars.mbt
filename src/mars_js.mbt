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
/// Convert Server app to a fetch handler function
/// Returns a function that takes JsRequest and returns Promise[JsResponse]
pub fn Server::to_fetch_handler(
  self : Server,
) -> (JsRequest) -> @js_async.Promise[JsResponse] {
  self.to_fetch_handler_with_env(EmptyEnv::new(), ExecutionContext::new())
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
/// Convert Server app to a fetch handler function with environment and execution context
pub fn[E : Env, C : ExecCtx] Server::to_fetch_handler_with_env(
  self : Server,
  env : E,
  exec_ctx : C,
) -> (JsRequest) -> @js_async.Promise[JsResponse] {
  fn(js_request : JsRequest) -> @js_async.Promise[JsResponse] {
    // Create async handler using Promise::from_async
    let promise = @js_async.Promise::from_async(async fn() -> JsResponse {
      // Convert JsRequest to @http.Request
      let request = js_request_to_http_request(js_request)
      let meth_str = js_request_method(js_request)
      let meth = js_method_to_router_method(meth_str)

      // Match route
      let matched = self.match_first_handler(meth, request.path)
      let (@router.HandlerId(id), params) = match matched {
        Some(v) => v
        None =>
          return js_response_new("Not Found", 404, build_not_found_headers())
      }

      // We need to capture the response in a ref
      let response_ref : Ref[JsResponse?] = { val: None }
      let resolve = fn(resp : JsResponse) { response_ref.val = Some(resp) }
      let ctx = Context::with_env_js(
        request, params, js_request, resolve, env, exec_ctx,
      )
      let dispatch = self.dispatch_to_context(ctx, id)
      if dispatch.handler_error && not(dispatch.response_sent) {
        return js_response_new(
          "Internal Server Error",
          500,
          build_error_headers(),
        )
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

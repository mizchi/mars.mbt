///|
/// Convert JS method string to @router.Method
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
    _ => @router.Method::Get
  }
}

///|
/// Build response headers as JSON for JS Response constructor
fn build_not_found_headers() -> Json {
  let obj : Map[String, Json] = {}
  obj.set("Content-Type", Json::string("text/plain"))
  Json::object(obj)
}

///|
/// Build response headers as JSON for JS Response constructor
fn build_error_headers() -> Json {
  let obj : Map[String, Json] = {}
  obj.set("Content-Type", Json::string("text/plain"))
  Json::object(obj)
}

///|
/// Convert Mars app to a fetch handler function
/// Returns a function that takes JsRequest and returns Promise[JsResponse]
pub fn Mars::to_fetch_handler(
  self : Mars,
) -> (JsRequest) -> @js_async.Promise[JsResponse] {
  self.to_fetch_handler_with_env(MapEnv::new())
}

///|
/// Convert Mars app to a fetch handler function with environment
pub fn Mars::to_fetch_handler_with_env(
  self : Mars,
  env : MapEnv,
) -> (JsRequest) -> @js_async.Promise[JsResponse] {
  fn(js_request : JsRequest) -> @js_async.Promise[JsResponse] {
    // Create async handler using Promise::from_async
    @js_async.Promise::from_async(async fn() -> JsResponse {
      // Convert JsRequest to @http.Request
      let request = js_request_to_http_request(js_request)
      let meth_str = js_request_method(js_request)
      let meth = js_method_to_router_method(meth_str)

      // Match route
      let result = self.router.match_(meth, request.path)
      if result.handlers.is_empty() {
        // No matching route - 404
        return js_response_new("Not Found", 404, build_not_found_headers())
      }

      // Get first matching handler
      let (@router.HandlerId(id), params) = result.handlers[0]

      // We need to capture the response in a ref
      let response_ref : Ref[JsResponse?] = { val: None }
      let resolve = fn(resp : JsResponse) { response_ref.val = Some(resp) }
      let ctx = Context::with_env_js(request, params, js_request, resolve, env)

      // Run middlewares first
      for middleware in self.middlewares {
        if ctx.is_response_sent() {
          break
        }
        let Handler(mw) = middleware
        mw(ctx) catch {
          e => {
            println("Middleware error: \{e}")
            break
          }
        }
      }

      // Then run the route handler
      if not(ctx.is_response_sent()) && id < self.handlers.length() {
        let Handler(h) = self.handlers[id]
        h(ctx) catch {
          e => {
            println("Handler error: \{e}")
            if not(ctx.is_response_sent()) {
              return js_response_new(
                "Internal Server Error",
                500,
                build_error_headers(),
              )
            }
          }
        }
      }

      // Return the response
      match response_ref.val {
        Some(resp) => resp
        None =>
          // If no response sent, send 404
          js_response_new("Not Found", 404, build_not_found_headers())
      }
    })
  }
}

///|
/// Convert @http.RequestMethod to @router.Method
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
pub type AppHandler = async (
  @http.Request,
  &@async_io.Reader,
  @http.ServerConnection,
) -> Unit

///|
/// Convert Server app to a platform handler function (native only)
pub fn Server::to_handler(self : Server) -> AppHandler {
  self.to_handler_with_env(EmptyEnv::new(), ExecutionContext::new())
}

///|
/// Convert Server app to a platform handler function with environment and execution context (native only)
pub fn[E : Env, C : ExecCtx] Server::to_handler_with_env(
  self : Server,
  env : E,
  exec_ctx : C,
) -> AppHandler {
  async fn(request, body, conn) {
    let meth = request_method_to_method(request.meth)
    match
      self.match_and_dispatch(meth, request.path, fn(params) {
        Context::with_env(request, params, conn, body, env, exec_ctx)
      }) {
      RequestDispatchResult::NotFound => {
        conn.send_response(404, "Not Found")
        conn.end_response()
      }
      RequestDispatchResult::Dispatched(dispatch) =>
        match dispatch_fallback_status(dispatch) {
          Some(500) => {
            conn.send_response(500, "Internal Server Error")
            conn.end_response()
          }
          Some(404) => {
            conn.send_response(404, "Not Found")
            conn.end_response()
          }
          _ => ()
        }
    }

    // Run background tasks after response is sent
    // Note: exec_ctx is a trait object, so we need to check if it's ExecutionContext
    // For now, background tasks are handled by the ExecCtx implementation
  }
}

///|
/// Start the HTTP server (native only)
pub async fn Server::serve(self : Server, addr : @socket.Addr) -> Unit {
  self.serve_with_env(addr, EmptyEnv::new(), ExecutionContext::new())
}

///|
/// Start the HTTP server with environment and execution context (native only)
pub async fn[E : Env, C : ExecCtx] Server::serve_with_env(
  self : Server,
  addr : @socket.Addr,
  env : E,
  exec_ctx : C,
) -> Unit {
  let server = @http.Server::new(addr)
  let handler = self.to_handler_with_env(env, exec_ctx)
  server.run_forever(handler)
}

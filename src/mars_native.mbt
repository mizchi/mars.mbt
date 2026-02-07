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
  server.run_forever(fn(request, body, conn) {
    let meth = request_method_to_method(request.meth)
    match self.match_first_handler(meth, request.path) {
      None => {
        conn.send_response(404, "Not Found")
        conn.end_response()
      }
      Some((@router.HandlerId(id), params)) => {
        let ctx = Context::with_env(request, params, conn, body, env, exec_ctx)
        let dispatch = self.dispatch_to_context(ctx, id)
        if dispatch.handler_error && not(dispatch.response_sent) {
          conn.send_response(500, "Internal Server Error")
          conn.end_response()
        } else if not(dispatch.response_sent) {
          conn.send_response(404, "Not Found")
          conn.end_response()
        }
      }
    }

    // Run background tasks after response is sent
    // Note: exec_ctx is a trait object, so we need to check if it's ExecutionContext
    // For now, background tasks are handled by the ExecCtx implementation
  })
}

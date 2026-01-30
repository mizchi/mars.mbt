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
pub async fn Mars::serve(self : Mars, addr : @socket.Addr) -> Unit {
  self.serve_with_env(addr, MapEnv::new())
}

///|
/// Start the HTTP server with environment bindings (native only)
pub async fn Mars::serve_with_env(
  self : Mars,
  addr : @socket.Addr,
  env : MapEnv,
) -> Unit {
  let server = @http.Server::new(addr)
  server.run_forever(fn(request, body, conn) {
    let meth = request_method_to_method(request.meth)
    let result = self.router.match_(meth, request.path)
    if result.handlers.is_empty() {
      // No matching route - 404
      conn.send_response(404, "Not Found")
      conn.end_response()
    } else {
      // Get first matching handler
      let (@router.HandlerId(id), params) = result.handlers[0]
      let ctx = Context::with_env(request, params, conn, body, env)

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
              conn.send_response(500, "Internal Server Error")
              conn.end_response()
            }
          }
        }
      }

      // If no response sent, send 404
      if not(ctx.is_response_sent()) {
        conn.send_response(404, "Not Found")
        conn.end_response()
      }

      // Run background tasks after response is sent
      if ctx.execution_ctx.pending_count() > 0 {
        ctx.execution_ctx.run_tasks() catch {
          e => println("Background tasks error: \{e}")
        }
      }
    }
  })
}

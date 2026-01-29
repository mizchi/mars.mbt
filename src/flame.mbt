///|
/// Flame HTTP Framework
/// A Hono-inspired HTTP framework for MoonBit
pub(all) struct Flame {
  router : @trie.TrieRouter
  handlers : Array[Handler]
  middlewares : Array[Handler]
}

///|
/// Create a new Flame application
pub fn Flame::new() -> Flame {
  { router: @trie.TrieRouter::new(), handlers: [], middlewares: [] }
}

///|
/// Add a middleware to the application
pub fn Flame::use_(self : Flame, handler : Handler) -> Flame {
  self.middlewares.push(handler)
  self
}

///|
/// Register a GET route
pub fn Flame::get(self : Flame, path : String, handler : Handler) -> Flame {
  self.add_route(@router.Method::Get, path, handler)
}

///|
/// Register a POST route
pub fn Flame::post(self : Flame, path : String, handler : Handler) -> Flame {
  self.add_route(@router.Method::Post, path, handler)
}

///|
/// Register a PUT route
pub fn Flame::put(self : Flame, path : String, handler : Handler) -> Flame {
  self.add_route(@router.Method::Put, path, handler)
}

///|
/// Register a DELETE route
pub fn Flame::delete(self : Flame, path : String, handler : Handler) -> Flame {
  self.add_route(@router.Method::Delete, path, handler)
}

///|
/// Register a PATCH route
pub fn Flame::patch(self : Flame, path : String, handler : Handler) -> Flame {
  self.add_route(@router.Method::Patch, path, handler)
}

///|
/// Register a route for all HTTP methods
pub fn Flame::all(self : Flame, path : String, handler : Handler) -> Flame {
  self.add_route(@router.Method::All, path, handler)
}

///|
/// Internal: Add a route with method
fn Flame::add_route(
  self : Flame,
  meth : @router.Method,
  path : String,
  handler : Handler,
) -> Flame {
  let @router.HandlerId(id) = self.router.add(meth, path)
  // Ensure handlers array is large enough
  while self.handlers.length() <= id {
    // Placeholder handler
    self.handlers.push(async fn(_ctx) { () })
  }
  self.handlers[id] = handler
  self
}

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
/// Start the HTTP server
pub async fn Flame::serve(self : Flame, addr : @socket.Addr) -> Unit {
  self.serve_with_env(addr, MapEnv::new())
}

///|
/// Start the HTTP server with environment bindings
pub async fn Flame::serve_with_env(
  self : Flame,
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

///|
/// Helper to create a Handler from an async function
pub fn handler(f : async (Context) -> Unit raise Error) -> Handler {
  Handler(f)
}

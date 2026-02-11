///|
/// Global debug mode flag
/// When enabled, logs warnings for unknown HTTP methods, etc.
let debug_enabled : Ref[Bool] = { val: false }

///|
/// Enable or disable debug mode globally
pub fn set_debug(enabled : Bool) -> Unit {
  debug_enabled.val = enabled
}

///|
/// Check if debug mode is enabled
pub fn is_debug() -> Bool {
  debug_enabled.val
}

///|
/// Server HTTP Framework
/// A Hono-inspired HTTP framework for MoonBit
pub(all) struct Server {
  router : @trie.TrieRouter
  handlers : Array[Handler]
  middlewares : Array[Handler]
  /// Registered routes for mount support
  routes : Array[(@router.Method, String, Int)]
}

///|
priv struct DispatchResult {
  response_sent : Bool
  handler_error : Bool
}

///|
priv enum RequestDispatchResult {
  NotFound
  Dispatched(DispatchResult)
}

///|
/// Create a new Server application
pub fn Server::new() -> Server {
  { router: @trie.TrieRouter::new(), handlers: [], middlewares: [], routes: [] }
}

///|
/// Create a new Server application with debug mode enabled
pub fn Server::new_debug() -> Server {
  set_debug(true)
  Server::new()
}

///|
/// Add a middleware to the application
pub fn Server::middleware(self : Server, handler : Handler) -> Unit {
  self.middlewares.push(handler)
}

///|
/// Register a GET route
pub fn Server::get(self : Server, path : String, handler : Handler) -> Unit {
  self.add_route(@router.Method::Get, path, handler)
}

///|
/// Register a POST route
pub fn Server::post(self : Server, path : String, handler : Handler) -> Unit {
  self.add_route(@router.Method::Post, path, handler)
}

///|
/// Register a PUT route
pub fn Server::put(self : Server, path : String, handler : Handler) -> Unit {
  self.add_route(@router.Method::Put, path, handler)
}

///|
/// Register a DELETE route
pub fn Server::delete(self : Server, path : String, handler : Handler) -> Unit {
  self.add_route(@router.Method::Delete, path, handler)
}

///|
/// Register a PATCH route
pub fn Server::patch(self : Server, path : String, handler : Handler) -> Unit {
  self.add_route(@router.Method::Patch, path, handler)
}

///|
/// Register a QUERY route (RFC 9110)
pub fn Server::query(self : Server, path : String, handler : Handler) -> Unit {
  self.add_route(@router.Method::Query, path, handler)
}

///|
/// Register a route for all HTTP methods
pub fn Server::all(self : Server, path : String, handler : Handler) -> Unit {
  self.add_route(@router.Method::All, path, handler)
}

///|
/// Internal: Add a route with method
fn Server::add_route(
  self : Server,
  meth : @router.Method,
  path : String,
  handler : Handler,
) -> Unit {
  let @router.HandlerId(id) = self.router.add(meth, path)
  // Ensure handlers array is large enough
  while self.handlers.length() <= id {
    // Placeholder handler
    self.handlers.push(fn(_ctx) { () })
  }
  self.handlers[id] = handler
  // Record route for mount support
  self.routes.push((meth, path, id))
}

///|
fn Server::match_first_handler(
  self : Server,
  meth : @router.Method,
  path : String,
) -> (@router.HandlerId, @router.Params)? {
  let result = self.router.match_(meth, path)
  result.handlers.get(0)
}

///|
async fn Server::dispatch_to_context(
  self : Server,
  ctx : Context,
  handler_id : Int,
) -> DispatchResult {
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
  let mut handler_error = false
  if not(ctx.is_response_sent()) && handler_id < self.handlers.length() {
    let Handler(h) = self.handlers[handler_id]
    h(ctx) catch {
      e => {
        println("Handler error: \{e}")
        handler_error = true
      }
    }
  }
  { response_sent: ctx.is_response_sent(), handler_error }
}

///|
async fn Server::match_and_dispatch(
  self : Server,
  meth : @router.Method,
  path : String,
  create_context : (@router.Params) -> Context,
) -> RequestDispatchResult {
  let (@router.HandlerId(id), params) = match
    self.match_first_handler(meth, path) {
    Some(v) => v
    None => return RequestDispatchResult::NotFound
  }
  let ctx = create_context(params)
  RequestDispatchResult::Dispatched(self.dispatch_to_context(ctx, id))
}

///|
fn dispatch_fallback_status(dispatch : DispatchResult) -> Int? {
  if dispatch.handler_error && not(dispatch.response_sent) {
    Some(500)
  } else if not(dispatch.response_sent) {
    Some(404)
  } else {
    None
  }
}

///|
/// Mount a sub-application at the given prefix
pub fn Server::mount(self : Server, prefix : String, sub : Server) -> Unit {
  // Wrap sub handlers with sub's middlewares
  for route in sub.routes {
    let (meth, path, handler_idx) = route
    let full_path = join_mount_paths(prefix, path)
    let handler = sub.handlers[handler_idx]
    // Wrap with sub's middlewares
    let wrapped = wrap_with_middlewares(handler, sub.middlewares)
    self.add_route(meth, full_path, wrapped)
  }
}

///|
/// Join mount prefix and path
fn join_mount_paths(prefix : String, path : String) -> String {
  // Remove trailing slash from prefix
  let prefix_clean = if prefix.length() > 1 && prefix.has_suffix("/") {
    let chars : Array[Char] = []
    for c in prefix {
      chars.push(c)
    }
    let buf = StringBuilder::new()
    for i = 0; i < chars.length() - 1; i = i + 1 {
      buf.write_char(chars[i])
    }
    buf.to_string()
  } else {
    prefix
  }
  // Ensure path starts with /
  if path.length() == 0 || not(path.has_prefix("/")) {
    "\{prefix_clean}/\{path}"
  } else {
    "\{prefix_clean}\{path}"
  }
}

///|
/// Wrap handler with middlewares (compose)
fn wrap_with_middlewares(
  handler : Handler,
  middlewares : Array[Handler],
) -> Handler {
  if middlewares.is_empty() {
    return handler
  }
  // Compose middlewares with handler
  let Handler(h) = handler
  let mut current : async (Context) -> Unit raise Error = h
  // Apply middlewares in reverse order
  for i = middlewares.length() - 1; i >= 0; i = i - 1 {
    let Handler(mw) = middlewares[i]
    let next = current
    current = async fn(ctx) {
      mw(ctx)
      next(ctx)
    }
  }
  Handler(current)
}

///|
/// Helper to create a Handler from an async function
pub fn handler(f : async (Context) -> Unit raise Error) -> Handler {
  Handler(f)
}

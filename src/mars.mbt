///|
/// Mars HTTP Framework
/// A Hono-inspired HTTP framework for MoonBit
pub(all) struct Mars {
  router : @trie.TrieRouter
  handlers : Array[Handler]
  middlewares : Array[Handler]
}

///|
/// Create a new Mars application
pub fn Mars::new() -> Mars {
  { router: @trie.TrieRouter::new(), handlers: [], middlewares: [] }
}

///|
/// Add a middleware to the application
pub fn Mars::use_(self : Mars, handler : Handler) -> Mars {
  self.middlewares.push(handler)
  self
}

///|
/// Register a GET route
pub fn Mars::get(self : Mars, path : String, handler : Handler) -> Mars {
  self.add_route(@router.Method::Get, path, handler)
}

///|
/// Register a POST route
pub fn Mars::post(self : Mars, path : String, handler : Handler) -> Mars {
  self.add_route(@router.Method::Post, path, handler)
}

///|
/// Register a PUT route
pub fn Mars::put(self : Mars, path : String, handler : Handler) -> Mars {
  self.add_route(@router.Method::Put, path, handler)
}

///|
/// Register a DELETE route
pub fn Mars::delete(self : Mars, path : String, handler : Handler) -> Mars {
  self.add_route(@router.Method::Delete, path, handler)
}

///|
/// Register a PATCH route
pub fn Mars::patch(self : Mars, path : String, handler : Handler) -> Mars {
  self.add_route(@router.Method::Patch, path, handler)
}

///|
/// Register a QUERY route (RFC 9110)
pub fn Mars::query(self : Mars, path : String, handler : Handler) -> Mars {
  self.add_route(@router.Method::Query, path, handler)
}

///|
/// Register a route for all HTTP methods
pub fn Mars::all(self : Mars, path : String, handler : Handler) -> Mars {
  self.add_route(@router.Method::All, path, handler)
}

///|
/// Internal: Add a route with method
fn Mars::add_route(
  self : Mars,
  meth : @router.Method,
  path : String,
  handler : Handler,
) -> Mars {
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
/// Helper to create a Handler from an async function
pub fn handler(f : async (Context) -> Unit raise Error) -> Handler {
  Handler(f)
}

///|
pub(all) struct RouteResponse {
  status : Int
  body : String
} derive(Debug, Eq)

///|
pub impl Show for RouteResponse with output(self, logger) {
  logger.write_string("{status: ")
  logger.write_string(self.status.to_string())
  logger.write_string(", body: \"")
  logger.write_string(self.body)
  logger.write_string("\"}")
}

///|
fn build_router() -> @trie.TrieRouter {
  let router = @trie.TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/")
  let _ = router.add(@router.Method::Get, "/users/:id")
  let _ = router.add(@router.Method::Get, "/files/*")
  let _ = router.add(@router.Method::Get, "/health")
  router
}

///|
pub fn route(method_name : String, path : String) -> RouteResponse {
  let meth = match @router.Method::from_string(method_name) {
    Some(m) => m
    None => @router.Method::Get
  }
  let router = build_router()
  let matched = router.match_(meth, path)
  if matched.is_empty() {
    return { status: 404, body: "not found: " + path }
  }
  let (handler_id, params) = matched.handlers[0]
  let @router.HandlerId(id) = handler_id
  match id {
    1 => { status: 200, body: "mars-router: top" }
    2 => {
      let user_id = match params.get("id") {
        Some(v) => v
        None => "unknown"
      }
      { status: 200, body: "mars-router: user=" + user_id }
    }
    3 => { status: 200, body: "mars-router: wildcard=" + path }
    4 => { status: 200, body: "ok" }
    _ => { status: 500, body: "unexpected handler id" }
  }
}

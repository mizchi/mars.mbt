///|
/// TrieRouter - A trie-based HTTP router
pub(all) struct TrieRouter {
  root : Node
  mut order : Int
}

///|
/// Create a new TrieRouter
pub fn TrieRouter::new() -> TrieRouter {
  { root: Node::new(), order: 0 }
}

///|
/// Get the router name
pub fn TrieRouter::name(_self : TrieRouter) -> String {
  "TrieRouter"
}

///|
/// Add a route to the router
pub fn TrieRouter::add(
  self : TrieRouter,
  meth : @router.Method,
  path : String,
) -> @router.HandlerId {
  self.order = self.order + 1
  let meth_str = meth.to_string()
  let handler_id = self.order

  // Handle optional parameters
  match check_optional_parameter(path) {
    Some(paths) =>
      for p in paths {
        let _ = self.root.insert(meth_str, p, handler_id, self.order)
      }
    None => {
      let _ = self.root.insert(meth_str, path, handler_id, self.order)
    }
  }
  @router.HandlerId(handler_id)
}

///|
/// Match a request path against registered routes
pub fn TrieRouter::match_(
  self : TrieRouter,
  meth : @router.Method,
  path : String,
) -> @router.MatchResult[@router.HandlerId] {
  let meth_str = meth.to_string()
  let results = self.root.search(meth_str, path)
  let handlers : Array[(@router.HandlerId, @router.Params)] = []
  for r in results {
    handlers.push((@router.HandlerId(r.handler_id), r.params))
  }
  { handlers, }
}

///|
/// Implement Router trait for TrieRouter
pub impl @router.Router for TrieRouter with name(self) {
  self.name()
}

///|
pub impl @router.Router for TrieRouter with add(self, meth, path) {
  self.add(meth, path)
}

///|
pub impl @router.Router for TrieRouter with match_(self, meth, path) {
  self.match_(meth, path)
}

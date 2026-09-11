///|
pub fn new_router() -> @trie.TrieRouter {
  @trie.TrieRouter::new()
}

///|
pub fn add_route(
  router : @trie.TrieRouter,
  meth : String,
  path : String,
) -> Int {
  let @router.HandlerId(id) = router.add(
    @router.Method::from_string(meth).unwrap(),
    path,
  )
  id
}

///|
pub fn match_count(
  router : @trie.TrieRouter,
  meth : String,
  path : String,
) -> Int {
  router.match_(@router.Method::from_string(meth).unwrap(), path).handlers.length()
}

///|
pub fn match_json(
  router : @trie.TrieRouter,
  meth : String,
  path : String,
) -> String {
  router.match_(@router.Method::from_string(meth).unwrap(), path).handlers
  .map(fn(entry) {
    let (@router.HandlerId(id), params) = entry
    ToJson::to_json((id, params.to_map()))
  })
  .to_json()
  .stringify()
}

///|
pub fn new_app(middleware : Bool) -> @mars.AppHandler {
  let app = @mars.Server::new()
  if middleware {
    app.middleware(fn(ctx) { ctx.set_header("x-bench", "1") })
  }
  app.get("/api/users/:id", fn(ctx) { ctx.text(ctx.param("id").unwrap()) })
  app.to_handler()
}

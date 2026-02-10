///|
/// Benchmarks for TrieRouter

///|
test "bench: add static route" (b : @bench.T) {
  let router = TrieRouter::new()
  b.bench(fn() { ignore(router.add(@router.Method::Get, "/api/users")) })
}

///|
test "bench: add dynamic route" (b : @bench.T) {
  let router = TrieRouter::new()
  b.bench(fn() { ignore(router.add(@router.Method::Get, "/api/users/:id")) })
}

///|
test "bench: add wildcard route" (b : @bench.T) {
  let router = TrieRouter::new()
  b.bench(fn() { ignore(router.add(@router.Method::Get, "/api/*")) })
}

///|
test "bench: add regex route" (b : @bench.T) {
  let router = TrieRouter::new()
  b.bench(fn() {
    ignore(router.add(@router.Method::Get, "/api/users/:id{[0-9]+}"))
  })
}

///|
test "bench: match static route (short)" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/")
  let _ = router.add(@router.Method::Get, "/api")
  let _ = router.add(@router.Method::Get, "/api/users")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/api")) })
}

///|
test "bench: match static route (long)" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/v1/users/profile/settings")
  b.bench(fn() {
    ignore(router.match_(@router.Method::Get, "/api/v1/users/profile/settings"))
  })
}

///|
test "bench: match dynamic route (:id)" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/users/:id")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/api/users/123")) })
}

///|
test "bench: match nested dynamic routes" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/users/:user_id/posts/:post_id")
  b.bench(fn() {
    ignore(router.match_(@router.Method::Get, "/api/users/123/posts/456"))
  })
}

///|
test "bench: match wildcard route" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/*")
  b.bench(fn() {
    ignore(router.match_(@router.Method::Get, "/api/users/123/posts"))
  })
}

///|
test "bench: match regex route" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/users/:id{[0-9]+}")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/api/users/123")) })
}

///|
test "bench: match regex route (UUID)" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(
    @router.Method::Get,
    "/api/items/:uuid{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}",
  )
  b.bench(fn() {
    ignore(
      router.match_(
        @router.Method::Get,
        "/api/items/550e8400-e29b-41d4-a716-446655440000",
      ),
    )
  })
}

///|
test "bench: multi-match (middleware pattern)" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::All, "*")
  let _ = router.add(@router.Method::Get, "/api/*")
  let _ = router.add(@router.Method::Get, "/api/users")
  let _ = router.add(@router.Method::Get, "/api/users/:id")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/api/users/123")) })
}

///|
test "bench: no match" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/users")
  let _ = router.add(@router.Method::Get, "/api/posts")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/not/found")) })
}

///|
test "bench: large router (100 routes) static match" (b : @bench.T) {
  let router = TrieRouter::new()
  for i in 0..<100 {
    let _ = router.add(@router.Method::Get, "/api/resource" + i.to_string())
  }
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/api/resource50")) })
}

///|
test "bench: large router (100 routes) dynamic match" (b : @bench.T) {
  let router = TrieRouter::new()
  for i in 0..<100 {
    let _ = router.add(
      @router.Method::Get,
      "/api/resource" + i.to_string() + "/:id",
    )
  }
  b.bench(fn() {
    ignore(router.match_(@router.Method::Get, "/api/resource50/123"))
  })
}

///|
test "bench: mixed routes priority" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/users/profile")
  let _ = router.add(@router.Method::Get, "/users/:id")
  let _ = router.add(@router.Method::Get, "/users/:id/settings")
  let _ = router.add(@router.Method::Get, "/users/*")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/users/profile")) })
}

///|
test "bench: optional parameter" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/items/:id?")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/api/items")) })
}

///|
test "bench: optional parameter with value" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/items/:id?")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/api/items/123")) })
}

///|
test "bench: deep nesting (5 levels)" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/a/b/c/d/e")
  let _ = router.add(@router.Method::Get, "/a/b/c/d/:e")
  let _ = router.add(@router.Method::Get, "/a/b/c/:d/:e")
  let _ = router.add(@router.Method::Get, "/a/b/:c/:d/:e")
  let _ = router.add(@router.Method::Get, "/a/:b/:c/:d/:e")
  b.bench(fn() { ignore(router.match_(@router.Method::Get, "/a/b/c/d/e")) })
}

///|
test "bench: ALL method matching" (b : @bench.T) {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::All, "/api/users")
  b.bench(fn() { ignore(router.match_(@router.Method::Post, "/api/users")) })
}

///|
test "bench: router creation" (b : @bench.T) {
  b.bench(fn() { ignore(TrieRouter::new()) })
}

///|
test "bench: typical REST API setup" (b : @bench.T) {
  b.bench(fn() {
    let router = TrieRouter::new()
    let _ = router.add(@router.Method::Get, "/api/users")
    let _ = router.add(@router.Method::Post, "/api/users")
    let _ = router.add(@router.Method::Get, "/api/users/:id")
    let _ = router.add(@router.Method::Put, "/api/users/:id")
    let _ = router.add(@router.Method::Delete, "/api/users/:id")
    let _ = router.add(@router.Method::Get, "/api/posts")
    let _ = router.add(@router.Method::Post, "/api/posts")
    let _ = router.add(@router.Method::Get, "/api/posts/:id")
    let _ = router.add(@router.Method::Put, "/api/posts/:id")
    let _ = router.add(@router.Method::Delete, "/api/posts/:id")
    b.keep(router)
  })
}

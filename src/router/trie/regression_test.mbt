///|
test "terminal wildcard still matches when the same node has children" {
  let router = TrieRouter::new()
  let fallback = router.add(@router.Get, "/files/*")
  let nested = router.add(@router.Get, "/files/*/meta")
  for path in ["/files/a/b", "/files/a/meta"] {
    let result = router.match_(@router.Get, path)
    assert_eq(result.handlers[0].0, fallback)
    if path == "/files/a/meta" {
      assert_eq(result.handlers.length(), 2)
      assert_eq(result.handlers[1].0, nested)
    } else {
      assert_eq(result.handlers.length(), 1)
    }
  }
}

///|
test "regex parameter followed by wildcard matches empty suffix" {
  let router = TrieRouter::new()
  let id = router.add(@router.Get, "/users/:id{[0-9]+}/*")
  let result = router.match_(@router.Get, "/users/123")
  assert_eq(result.handlers.length(), 1)
  assert_eq(result.handlers[0].0, id)
  assert_eq(result.handlers[0].1.get("id"), Some("123"))
}

///|
test "literal pattern tokens in a request do not visit dynamic children twice" {
  let router = TrieRouter::new()
  let id = router.add(@router.Get, "/users/:id")
  let result = router.match_(@router.Get, "/users/:id")
  assert_eq(result.handlers.length(), 1)
  assert_eq(result.handlers[0].0, id)
  assert_eq(result.handlers[0].1.get("id"), Some(":id"))
  let wildcard = TrieRouter::new()
  ignore(wildcard.add(@router.Get, "/files/*"))
  assert_eq(wildcard.match_(@router.Get, "/files/*").handlers.length(), 1)
}

///|
test "parameters are isolated across branches handlers and requests" {
  let router = TrieRouter::new()
  ignore(router.add(@router.Get, "/:id/:id"))
  ignore(router.add(@router.Get, "/:id/:other"))
  ignore(router.add(@router.All, "/:id/:other"))
  ignore(router.add(@router.Get, "/:first/:second"))
  let result = router.match_(@router.Get, "/a/b")
  assert_eq(result.handlers.length(), 4)
  assert_eq(result.handlers[0].1.get("id"), Some("b"))
  assert_eq(result.handlers[1].1.get("id"), Some("a"))
  assert_eq(result.handlers[1].1.get("other"), Some("b"))
  assert_eq(result.handlers[3].1.get("id"), None)
  result.handlers[1].1.set("other", "changed")
  assert_eq(result.handlers[2].1.get("other"), Some("b"))
  assert_eq(
    router.match_(@router.Get, "/c/d").handlers[1].1.get("id"),
    Some("c"),
  )
  assert_eq(result.handlers[0].1.get("id"), Some("b"))
}

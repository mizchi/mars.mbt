///|
test "split_path basic" {
  inspect(split_path("/hello/world"), content="[\"hello\", \"world\"]")
  inspect(split_path("/"), content="[]")
  inspect(split_path("/api/users/123"), content="[\"api\", \"users\", \"123\"]")
  inspect(split_path("hello/world"), content="[\"hello\", \"world\"]")
}

///|
test "split_routing_path with groups" {
  inspect(split_routing_path("/users/:id"), content="[\"users\", \":id\"]")
  inspect(
    split_routing_path("/users/:id{[0-9]+}"),
    content="[\"users\", \":id{[0-9]+}\"]",
  )
}

///|
test "get_pattern wildcard" {
  inspect(get_pattern("*"), content="Some(Wildcard)")
}

///|
test "get_pattern param" {
  inspect(get_pattern(":id"), content="Some(Param(id))")
  inspect(get_pattern(":name"), content="Some(Param(name))")
}

///|
test "get_pattern param with regex" {
  inspect(
    get_pattern(":id{[0-9]+}"),
    content="Some(ParamWithRegex(id, [0-9]+))",
  )
}

///|
test "get_pattern static segment" {
  inspect(get_pattern("hello"), content="None")
  inspect(get_pattern("users"), content="None")
}

///|
test "check_optional_parameter" {
  inspect(
    check_optional_parameter("/api/animals/:type?"),
    content="Some([\"/api/animals\", \"/api/animals/:type\"])",
  )
  inspect(check_optional_parameter("/api/animals"), content="None")
  inspect(check_optional_parameter("/users/:id"), content="None")
}

///|
test "check_optional_parameter root" {
  inspect(
    check_optional_parameter("/:type?"),
    content="Some([\"/\", \"/:type\"])",
  )
}

///|
test "Node::insert and search static" {
  let node = Node::new()
  let _ = node.insert("GET", "/hello", 1, 1)
  let _ = node.insert("GET", "/hello/world", 2, 2)
  let results = node.search("GET", "/hello")
  assert_eq(results.length(), 1)
  assert_eq(results[0].handler_id, 1)
}

///|
test "Node::insert and search with param" {
  let node = Node::new()
  let _ = node.insert("GET", "/users/:id", 1, 1)
  let results = node.search("GET", "/users/123")
  assert_eq(results.length(), 1)
  assert_eq(results[0].handler_id, 1)
  inspect(results[0].params.get("id"), content="Some(\"123\")")
}

///|
test "Node::insert and search with wildcard" {
  let node = Node::new()
  let _ = node.insert("GET", "/files/*", 1, 1)
  let results = node.search("GET", "/files/path/to/file.txt")
  assert_eq(results.length(), 1)
  assert_eq(results[0].handler_id, 1)
}

///|
test "Node::insert and search ALL method" {
  let node = Node::new()
  let _ = node.insert("ALL", "/api", 1, 1)
  let results = node.search("GET", "/api")
  assert_eq(results.length(), 1)
  assert_eq(results[0].handler_id, 1)
}

///|
test "Node::insert multiple methods" {
  let node = Node::new()
  let _ = node.insert("GET", "/users", 1, 1)
  let _ = node.insert("POST", "/users", 2, 2)
  let get_results = node.search("GET", "/users")
  let post_results = node.search("POST", "/users")
  assert_eq(get_results.length(), 1)
  assert_eq(get_results[0].handler_id, 1)
  assert_eq(post_results.length(), 1)
  assert_eq(post_results[0].handler_id, 2)
}

///|
test "TrieRouter basic usage" {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/")
  let _ = router.add(@router.Method::Get, "/users")
  let _ = router.add(@router.Method::Get, "/users/:id")
  let result = router.match_(@router.Method::Get, "/users/123")
  assert_eq(result.handlers.length(), 1)
  let (handler_id, params) = result.handlers[0]
  let @router.HandlerId(id) = handler_id
  assert_eq(id, 3)
  inspect(params.get("id"), content="Some(\"123\")")
}

///|
test "TrieRouter multiple routes" {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/users")
  let _ = router.add(@router.Method::Post, "/api/users")
  let _ = router.add(@router.Method::Get, "/api/users/:id")
  let get_result = router.match_(@router.Method::Get, "/api/users")
  let post_result = router.match_(@router.Method::Post, "/api/users")
  assert_eq(get_result.handlers.length(), 1)
  assert_eq(post_result.handlers.length(), 1)
  let (@router.HandlerId(get_id), _) = get_result.handlers[0]
  let (@router.HandlerId(post_id), _) = post_result.handlers[0]
  assert_eq(get_id, 1)
  assert_eq(post_id, 2)
}

///|
test "TrieRouter optional parameter" {
  let router = TrieRouter::new()
  let _ = router.add(@router.Method::Get, "/api/animals/:type?")
  let result1 = router.match_(@router.Method::Get, "/api/animals")
  let result2 = router.match_(@router.Method::Get, "/api/animals/dog")
  assert_eq(result1.handlers.length(), 1)
  assert_eq(result2.handlers.length(), 1)
}

///|
test "Server new creates empty app" {
  let app = Server::new()
  inspect(app.handlers.length(), content="0")
  inspect(app.middlewares.length(), content="0")
}

///|
test "Server get registers route" {
  let app = Server::new()
  app.get("/", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Server post registers route" {
  let app = Server::new()
  app.post("/users", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Server put registers route" {
  let app = Server::new()
  app.put("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Server delete registers route" {
  let app = Server::new()
  app.delete("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Server patch registers route" {
  let app = Server::new()
  app.patch("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Server query registers route" {
  let app = Server::new()
  app.query("/search", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Server all registers route for all methods" {
  let app = Server::new()
  app.all("/health", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Server middleware adds middleware" {
  let app = Server::new()
  app.middleware(async fn(_ctx) { () })
  inspect(app.middlewares.length(), content="1")
}

///|
test "Server multiple middlewares" {
  let app = Server::new()
  app
  ..middleware(async fn(_ctx) { () })
  ..middleware(async fn(_ctx) { () })
  ..middleware(async fn(_ctx) { () })
  inspect(app.middlewares.length(), content="3")
}

///|
test "Server chained routes" {
  let app = Server::new()
  app
  ..get("/", async fn(_ctx) { () })
  ..post("/users", async fn(_ctx) { () })
  ..get("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() >= 3, content="true")
}

///|
test "handler helper creates Handler" {
  let h = handler(async fn(_ctx) { () })
  // Just verify it compiles and can be created
  let Handler(_) = h

}

///|
test "Server mount sub-app" {
  let api = Server::new()
  api
  ..get("/users", async fn(_ctx) { () })
  ..post("/users", async fn(_ctx) { () })
  let app = Server::new()
  app.mount("/api", api)
  // Should have 2 routes mounted
  inspect(app.routes.length(), content="2")
}

///|
test "Server mount preserves route info" {
  let api = Server::new()
  api.get("/items", async fn(_ctx) { () })
  let app = Server::new()
  app.mount("/v1", api)
  // Check route was registered with prefix
  let (_, path, _) = app.routes[0]
  inspect(path, content="/v1/items")
}

///|
test "join_mount_paths basic" {
  inspect(join_mount_paths("/api", "/users"), content="/api/users")
  inspect(join_mount_paths("/api/", "/users"), content="/api/users")
  inspect(join_mount_paths("/api", "users"), content="/api/users")
  inspect(join_mount_paths("", "/users"), content="/users")
}

///|
test "debug mode default is false" {
  inspect(is_debug(), content="false")
}

///|
test "set_debug enables debug mode" {
  set_debug(true)
  inspect(is_debug(), content="true")
  // Reset to default
  set_debug(false)
  inspect(is_debug(), content="false")
}

///|
test "Server::new_debug enables debug mode" {
  set_debug(false) // Ensure clean state
  let _ = Server::new_debug()
  inspect(is_debug(), content="true")
  // Reset
  set_debug(false)
}

///|
test "Server::match_first_handler returns None when no route matched" {
  let app = Server::new()
  app.get("/users/:id", async fn(_ctx) { () })
  inspect(
    app.match_first_handler(@router.Method::Get, "/health"),
    content="None",
  )
}

///|
test "Server::match_first_handler returns first handler and params" {
  let app = Server::new()
  app.get("/users/:id", async fn(_ctx) { () })
  let result = app.match_first_handler(@router.Method::Get, "/users/42")
  match result {
    Some((@router.HandlerId(_), params)) =>
      inspect(params.get("id"), content="Some(\"42\")")
    None => inspect("missing", content="found")
  }
}

///|
test "dispatch_fallback_status chooses 500 on handler error without response" {
  let status = dispatch_fallback_status({
    response_sent: false,
    handler_error: true,
  })
  inspect(status, content="Some(500)")
}

///|
test "dispatch_fallback_status chooses 404 on unsent response" {
  let status = dispatch_fallback_status({
    response_sent: false,
    handler_error: false,
  })
  inspect(status, content="Some(404)")
}

///|
test "dispatch_fallback_status returns None when response already sent" {
  let status = dispatch_fallback_status({
    response_sent: true,
    handler_error: true,
  })
  inspect(status, content="None")
}

///|
test "Server::to_handler is available on all targets" {
  let app = Server::new()
  let _ = app.to_handler()

}

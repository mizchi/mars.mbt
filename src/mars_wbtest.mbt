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

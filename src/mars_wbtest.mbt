///|
test "Mars new creates empty app" {
  let app = Mars::new()
  inspect(app.handlers.length(), content="0")
  inspect(app.middlewares.length(), content="0")
}

///|
test "Mars get registers route" {
  let app = Mars::new()
  let _ = app.get("/", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Mars post registers route" {
  let app = Mars::new()
  let _ = app.post("/users", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Mars put registers route" {
  let app = Mars::new()
  let _ = app.put("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Mars delete registers route" {
  let app = Mars::new()
  let _ = app.delete("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Mars patch registers route" {
  let app = Mars::new()
  let _ = app.patch("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Mars query registers route" {
  let app = Mars::new()
  let _ = app.query("/search", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Mars all registers route for all methods" {
  let app = Mars::new()
  let _ = app.all("/health", async fn(_ctx) { () })
  inspect(app.handlers.length() > 0, content="true")
}

///|
test "Mars use_ adds middleware" {
  let app = Mars::new()
  let _ = app.use_(async fn(_ctx) { () })
  inspect(app.middlewares.length(), content="1")
}

///|
test "Mars multiple middlewares" {
  let app = Mars::new()
  let _ = app
    .use_(async fn(_ctx) { () })
    .use_(async fn(_ctx) { () })
    .use_(async fn(_ctx) { () })
  inspect(app.middlewares.length(), content="3")
}

///|
test "Mars chained routes" {
  let app = Mars::new()
  let _ = app
    .get("/", async fn(_ctx) { () })
    .post("/users", async fn(_ctx) { () })
    .get("/users/:id", async fn(_ctx) { () })
  inspect(app.handlers.length() >= 3, content="true")
}

///|
test "request_method_to_method Get" {
  let result = request_method_to_method(@http.RequestMethod::Get)
  inspect(result, content="GET")
}

///|
test "request_method_to_method Post" {
  let result = request_method_to_method(@http.RequestMethod::Post)
  inspect(result, content="POST")
}

///|
test "request_method_to_method Put" {
  let result = request_method_to_method(@http.RequestMethod::Put)
  inspect(result, content="PUT")
}

///|
test "request_method_to_method Delete" {
  let result = request_method_to_method(@http.RequestMethod::Delete)
  inspect(result, content="DELETE")
}

///|
test "request_method_to_method Patch" {
  let result = request_method_to_method(@http.RequestMethod::Patch)
  inspect(result, content="PATCH")
}

///|
test "request_method_to_method Head" {
  let result = request_method_to_method(@http.RequestMethod::Head)
  inspect(result, content="HEAD")
}

///|
test "request_method_to_method Options" {
  let result = request_method_to_method(@http.RequestMethod::Options)
  inspect(result, content="OPTIONS")
}

///|
test "request_method_to_method Connect" {
  let result = request_method_to_method(@http.RequestMethod::Connect)
  inspect(result, content="CONNECT")
}

///|
test "request_method_to_method Trace" {
  let result = request_method_to_method(@http.RequestMethod::Trace)
  inspect(result, content="TRACE")
}

///|
test "handler helper creates Handler" {
  let h = handler(async fn(_ctx) { () })
  // Just verify it compiles and can be created
  let Handler(_) = h

}

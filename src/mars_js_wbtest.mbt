///|
extern "js" fn test_request(path : String) -> JsRequest =
  #| path => new Request("http://localhost" + path)

///|
extern "js" fn test_status(response : JsResponse) -> Int =
  #| response => response.status

///|
async test "middleware errors stop dispatch with an internal error" {
  let app = Server::new()
  let called = Ref::new(false)
  app.middleware(_ctx => fail("middleware failed"))
  app.get("/", fn(ctx) {
    called.val = true
    ctx.text("should not run")
  })
  let response = app.to_handler()(test_request("/")).wait()
  assert_eq(test_status(response), 500)
  assert_false(called.val)
}

///|
async test "mounted middleware responses stop subsequent middleware and handler" {
  let sub = Server::new()
  let called = Ref::new(0)
  sub.middleware(fn(ctx) { ctx.text("unauthorized", status=401) })
  sub.middleware(fn(_ctx) { called.val += 1 })
  sub.get("/users", fn(ctx) {
    called.val += 1
    ctx.text("should not run")
  })
  let app = Server::new()
  app.mount("/api", sub)
  let response = app.to_handler()(test_request("/api/users")).wait()
  assert_eq(test_status(response), 401)
  assert_eq(called.val, 0)
}

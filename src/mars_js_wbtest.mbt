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

///|
extern "js" fn test_request_headers() -> JsRequest =
  #| () => new Request("http://localhost/api/users/123?q=1", { headers: {
  #|   "authorization": "Bearer test", "content-type": "application/json",
  #|   "x-forwarded-for": "192.0.2.1", "sec-fetch-site": "same-origin",
  #|   "x-correlation-id": "trace", "x-custom": "raw-only"
  #| } })

///|
test "request header conversion preserves common header names" {
  let request = js_request_to_http_request(test_request_headers())
  assert_eq(request.path, "/api/users/123?q=1")
  assert_eq(request.headers.length(), 5)
  assert_eq(request.headers.get("Authorization"), Some("Bearer test"))
  assert_eq(request.headers.get("Content-Type"), Some("application/json"))
  assert_eq(request.headers.get("X-Forwarded-For"), Some("192.0.2.1"))
  assert_eq(request.headers.get("Sec-Fetch-Site"), Some("same-origin"))
  assert_eq(request.headers.get("X-Correlation-ID"), Some("trace"))
  assert_eq(request.headers.get("X-Custom"), None)
  assert_eq(
    js_headers_get(js_request_headers(test_request_headers()), "x-custom"),
    Some("raw-only"),
  )
  assert_true(js_request_to_http_request(test_request("/")).headers.is_empty())
}

///|
test "URL path slicing retains query and Unicode" {
  assert_eq(
    parse_path_from_url("https://example.com/api/日本語?q=😀"),
    "/api/日本語?q=😀",
  )
  assert_eq(parse_path_from_url("https://example.com"), "/")
  assert_eq(parse_path_from_url("https://example.com/"), "/")
  assert_eq(parse_path_from_url("/api/users?q=1"), "/api/users?q=1")
}

///|
fn make_context_with_state() -> (Context, Ref[WasmResponseState]) {
  let request : @http.Request = {
    meth: @http.RequestMethod::Get,
    path: "/",
    headers: {},
  }
  let params = @router.Params::new()
  let env = EmptyEnv::new()
  let exec_ctx = ExecutionContext::new()
  let state : Ref[WasmResponseState] = { val: WasmResponseState::new() }
  (Context::with_env(request, params, "body", state, env, exec_ctx), state)
}

///|
test "WasmRequest new stores request and body" {
  let request : @http.Request = {
    meth: @http.RequestMethod::Post,
    path: "/echo",
    headers: { "Content-Type": "text/plain" },
  }
  let input = WasmRequest::new(request, body="hello")
  inspect(input.request.path, content="/echo")
  inspect(input.body, content="hello")
}

///|
test "Context text writes wasm response state" {
  let (ctx, state) = make_context_with_state()
  ctx.set_header("X-Test", "1")
  ctx.text("ok")
  inspect(ctx.is_response_sent(), content="true")
  inspect(state.val.sent, content="true")
  inspect(state.val.status, content="200")
  inspect(state.val.body, content="ok")
  inspect(
    state.val.headers.get("Content-Type"),
    content="Some(\"text/plain; charset=utf-8\")",
  )
  inspect(state.val.headers.get("X-Test"), content="Some(\"1\")")
}

///|
test "Context json and html set content type" {
  let (ctx_json, state_json) = make_context_with_state()
  ctx_json.json({ "ok": true }, status=201)
  inspect(state_json.val.status, content="201")
  inspect(
    state_json.val.headers.get("Content-Type"),
    content="Some(\"application/json\")",
  )
  let (ctx_html, state_html) = make_context_with_state()
  ctx_html.html("<h1>ok</h1>")
  inspect(state_html.val.status, content="200")
  inspect(
    state_html.val.headers.get("Content-Type"),
    content="Some(\"text/html; charset=utf-8\")",
  )
}

///|
test "Context redirect and not_found update status" {
  let (ctx_redirect, state_redirect) = make_context_with_state()
  ctx_redirect.redirect("/next")
  inspect(state_redirect.val.status, content="302")
  inspect(state_redirect.val.headers.get("Location"), content="Some(\"/next\")")
  let (ctx_not_found, state_not_found) = make_context_with_state()
  ctx_not_found.not_found()
  inspect(state_not_found.val.status, content="404")
  inspect(state_not_found.val.body, content="Not Found")
}

///|
test "Context sse_start and write_raw append body" {
  let (ctx, state) = make_context_with_state()
  ctx.sse_start()
  ctx.write_raw("data: one\n\n")
  ctx.write_raw("data: two\n\n")
  ctx.end_response()
  let expected =
    #|data: one
    #|
    #|data: two
    #|
    #|
  inspect(state.val.status, content="200")
  inspect(state.val.sent, content="true")
  inspect(state.val.body, content=expected)
  inspect(
    state.val.headers.get("Content-Type"),
    content="Some(\"text/event-stream\")",
  )
}

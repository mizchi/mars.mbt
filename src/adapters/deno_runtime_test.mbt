///|
test "deno handler is available on js target" {
  let app = @mars.Server::new()
  let _deno : @mars.AppHandler = deno_handler(app)

}

///|
test "deno handler_with_env is available on js target" {
  let env = @mars.EmptyEnv::new()
  let exec_ctx = @mars.ExecutionContext::new()
  let app = @mars.Server::new()
  let _deno : @mars.AppHandler = deno_handler_with_env(app, env, exec_ctx)

}

///|
test "deno runtime marker" {
  inspect(deno_runtime(), content="Deno")
}

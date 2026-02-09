///|
test "bun handler is available on js target" {
  let app = @mars.Server::new()
  let _bun : @mars.AppHandler = bun_handler(app)

}

///|
test "bun handler_with_env is available on js target" {
  let env = @mars.EmptyEnv::new()
  let exec_ctx = @mars.ExecutionContext::new()
  let app = @mars.Server::new()
  let _bun : @mars.AppHandler = bun_handler_with_env(app, env, exec_ctx)

}

///|
test "bun runtime marker" {
  inspect(bun_runtime(), content="Bun")
}

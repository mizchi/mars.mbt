///|
test "node deno bun handlers are available on js target" {
  let app1 = @mars.Server::new()
  let app2 = @mars.Server::new()
  let app3 = @mars.Server::new()
  let _node : @mars.AppHandler = node_handler(app1)
  let _deno : @mars.AppHandler = deno_handler(app2)
  let _bun : @mars.AppHandler = bun_handler(app3)

}

///|
test "node deno bun handler_with_env are available on js target" {
  let env = @mars.EmptyEnv::new()
  let exec_ctx = @mars.ExecutionContext::new()
  let app1 = @mars.Server::new()
  let app2 = @mars.Server::new()
  let app3 = @mars.Server::new()
  let _node : @mars.AppHandler = node_handler_with_env(app1, env, exec_ctx)
  let _deno : @mars.AppHandler = deno_handler_with_env(app2, env, exec_ctx)
  let _bun : @mars.AppHandler = bun_handler_with_env(app3, env, exec_ctx)

}

///|
test "runtime markers for js adapters" {
  inspect(node_runtime(), content="Node")
  inspect(deno_runtime(), content="Deno")
  inspect(bun_runtime(), content="Bun")
}

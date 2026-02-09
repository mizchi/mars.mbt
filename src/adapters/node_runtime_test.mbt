///|
test "node handler is available on js target" {
  let app = @mars.Server::new()
  let _node : @mars.AppHandler = node_handler(app)

}

///|
test "node handler_with_env is available on js target" {
  let env = @mars.EmptyEnv::new()
  let exec_ctx = @mars.ExecutionContext::new()
  let app = @mars.Server::new()
  let _node : @mars.AppHandler = node_handler_with_env(app, env, exec_ctx)

}

///|
test "node runtime marker" {
  inspect(node_runtime(), content="Node")
}

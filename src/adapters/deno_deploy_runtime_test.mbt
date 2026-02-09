///|
test "deno_deploy handler is available on js target" {
  let app = @mars.Server::new()
  let _deno_deploy : @mars.AppHandler = deno_deploy_handler(app)

}

///|
test "deno_deploy handler_with_env is available on js target" {
  let env = @mars.EmptyEnv::new()
  let exec_ctx = @mars.ExecutionContext::new()
  let app = @mars.Server::new()
  let _deno_deploy : @mars.AppHandler = deno_deploy_handler_with_env(
    app, env, exec_ctx,
  )

}

///|
test "deno_deploy runtime marker" {
  inspect(deno_deploy_runtime(), content="DenoDeploy")
}

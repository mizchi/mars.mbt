///|
pub fn deno_deploy_handler(app : @mars.Server) -> @mars.AppHandler {
  app.to_handler()
}

///|
pub fn[E : @mars.Env, C : @mars.ExecCtx] deno_deploy_handler_with_env(
  app : @mars.Server,
  env : E,
  exec_ctx : C,
) -> @mars.AppHandler {
  app.to_handler_with_env(env, exec_ctx)
}

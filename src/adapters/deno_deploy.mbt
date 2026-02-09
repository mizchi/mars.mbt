///|
pub fn deno_deploy_runtime() -> RuntimeTarget {
  RuntimeTarget::DenoDeploy
}

///|
pub fn deno_deploy_handler(app : @mars.Server) -> @mars.AppHandler {
  @deno_adapters.deno_deploy_handler(app)
}

///|
pub fn[E : @mars.Env, C : @mars.ExecCtx] deno_deploy_handler_with_env(
  app : @mars.Server,
  env : E,
  exec_ctx : C,
) -> @mars.AppHandler {
  @deno_adapters.deno_deploy_handler_with_env(app, env, exec_ctx)
}

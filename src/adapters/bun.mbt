///|
pub fn bun_runtime() -> RuntimeTarget {
  RuntimeTarget::Bun
}

///|
pub fn bun_handler(app : @mars.Server) -> @mars.AppHandler {
  app.to_handler()
}

///|
pub fn[E : @mars.Env, C : @mars.ExecCtx] bun_handler_with_env(
  app : @mars.Server,
  env : E,
  exec_ctx : C,
) -> @mars.AppHandler {
  app.to_handler_with_env(env, exec_ctx)
}

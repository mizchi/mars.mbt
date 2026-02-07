///|
/// WASM Component adapter configuration placeholder
pub(all) struct WasmComponentConfig {
  component : String
  world : String
  export_name : String
}

///|
pub fn WasmComponentConfig::default() -> WasmComponentConfig {
  {
    component: "mars-component",
    world: "http-component",
    export_name: "handle",
  }
}

///|
pub(all) struct WasmComponentAdapter {
  app : @mars.Server
  config : WasmComponentConfig
}

///|
pub fn wasm_component_adapter(
  app : @mars.Server,
  config? : WasmComponentConfig = WasmComponentConfig::default(),
) -> WasmComponentAdapter {
  { app, config }
}

///|
pub fn wasm_component_runtime() -> RuntimeTarget {
  RuntimeTarget::WasmComponent
}

///|
pub fn wasm_component_handler(app : @mars.Server) -> @mars.AppHandler {
  app.to_handler()
}

///|
pub fn[E : @mars.Env, C : @mars.ExecCtx] wasm_component_handler_with_env(
  app : @mars.Server,
  env : E,
  exec_ctx : C,
) -> @mars.AppHandler {
  app.to_handler_with_env(env, exec_ctx)
}

///|
pub fn WasmComponentAdapter::binding_hint(
  self : WasmComponentAdapter,
) -> String {
  "component=\{self.config.component} world=\{self.config.world} export=\{self.config.export_name}"
}

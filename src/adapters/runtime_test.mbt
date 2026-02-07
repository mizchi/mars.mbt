///|
test "RuntimeTarget id mapping" {
  inspect(RuntimeTarget::Node.id(), content="node")
  inspect(RuntimeTarget::Deno.id(), content="deno")
  inspect(RuntimeTarget::Bun.id(), content="bun")
  inspect(RuntimeTarget::Cloudflare.id(), content="cloudflare")
  inspect(RuntimeTarget::SpinWagi.id(), content="spin-wagi")
  inspect(RuntimeTarget::WasmComponent.id(), content="wasm-component")
}

///|
test "RuntimeTarget category helpers" {
  inspect(RuntimeTarget::Node.is_js_runtime(), content="true")
  inspect(RuntimeTarget::Cloudflare.is_js_runtime(), content="true")
  inspect(RuntimeTarget::SpinWagi.is_js_runtime(), content="false")
  inspect(RuntimeTarget::WasmComponent.is_js_runtime(), content="false")
  inspect(RuntimeTarget::Node.is_wasm_runtime(), content="false")
  inspect(RuntimeTarget::Cloudflare.is_wasm_runtime(), content="true")
  inspect(RuntimeTarget::SpinWagi.is_wasm_runtime(), content="true")
  inspect(RuntimeTarget::WasmComponent.is_wasm_runtime(), content="true")
}

///|
test "runtime marker functions" {
  inspect(cloudflare_runtime(), content="Cloudflare")
  inspect(spin_wagi_runtime(), content="SpinWagi")
  inspect(wasm_component_runtime(), content="WasmComponent")
}

///|
test "spin_wagi adapter default config and hint" {
  let app = @mars.Server::new()
  let adapter = spin_wagi_adapter(app)
  inspect(adapter.config.component, content="mars-app")
  inspect(adapter.config.route, content="/...")
  inspect(adapter.config.executor, content="wagi")
  inspect(
    adapter.manifest_hint(),
    content="[component.mars-app] route=\"/...\" executor=\"wagi\"",
  )
}

///|
test "wasm component adapter default config and hint" {
  let app = @mars.Server::new()
  let adapter = wasm_component_adapter(app)
  inspect(adapter.config.component, content="mars-component")
  inspect(adapter.config.world, content="http-component")
  inspect(adapter.config.export_name, content="handle")
  inspect(
    adapter.binding_hint(),
    content="component=mars-component world=http-component export=handle",
  )
}

///|
test "spin_wagi and wasm_component handlers are available" {
  let app1 = @mars.Server::new()
  let app2 = @mars.Server::new()
  let _spin : @mars.AppHandler = spin_wagi_handler(app1)
  let _wasm_cm : @mars.AppHandler = wasm_component_handler(app2)

}

///|
test "spin_wagi and wasm_component handler_with_env are available" {
  let env = @mars.EmptyEnv::new()
  let exec_ctx = @mars.ExecutionContext::new()
  let app1 = @mars.Server::new()
  let app2 = @mars.Server::new()
  let _spin : @mars.AppHandler = spin_wagi_handler_with_env(app1, env, exec_ctx)
  let _wasm_cm : @mars.AppHandler = wasm_component_handler_with_env(
    app2, env, exec_ctx,
  )

}

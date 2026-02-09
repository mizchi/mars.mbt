///|
/// Target runtimes for platform adapters
pub(all) enum RuntimeTarget {
  Node
  Deno
  DenoDeploy
  Bun
  Cloudflare
  SpinWagi
  WasmComponent
} derive(Show, Eq)

///|
pub fn RuntimeTarget::id(self : RuntimeTarget) -> String {
  match self {
    Node => "node"
    Deno => "deno"
    DenoDeploy => "deno-deploy"
    Bun => "bun"
    Cloudflare => "cloudflare"
    SpinWagi => "spin-wagi"
    WasmComponent => "wasm-component"
  }
}

///|
pub fn RuntimeTarget::is_js_runtime(self : RuntimeTarget) -> Bool {
  match self {
    Node | Deno | DenoDeploy | Bun | Cloudflare => true
    _ => false
  }
}

///|
pub fn RuntimeTarget::is_wasm_runtime(self : RuntimeTarget) -> Bool {
  match self {
    Cloudflare | SpinWagi | WasmComponent => true
    _ => false
  }
}

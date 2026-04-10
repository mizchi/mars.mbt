///|
/// Target runtimes for platform adapters
pub(all) enum RuntimeTarget {
  Node
  Deno
  Bun
  Cloudflare
  SpinWagi
  WasmComponent
} derive(Debug, Eq)

///|
pub impl Show for RuntimeTarget with output(self, logger) {
  match self {
    Node => logger.write_string("Node")
    Deno => logger.write_string("Deno")
    Bun => logger.write_string("Bun")
    Cloudflare => logger.write_string("Cloudflare")
    SpinWagi => logger.write_string("SpinWagi")
    WasmComponent => logger.write_string("WasmComponent")
  }
}

///|
pub fn RuntimeTarget::id(self : RuntimeTarget) -> String {
  match self {
    Node => "node"
    Deno => "deno"
    Bun => "bun"
    Cloudflare => "cloudflare"
    SpinWagi => "spin-wagi"
    WasmComponent => "wasm-component"
  }
}

///|
pub fn RuntimeTarget::is_js_runtime(self : RuntimeTarget) -> Bool {
  match self {
    Node | Deno | Bun | Cloudflare => true
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

///|
/// Environment Bindings
/// Platform-agnostic interface for environment variables and bindings

///|
/// Environment trait for platform-specific bindings
/// Implement this trait for your platform (Cloudflare, Deno, etc.)
pub(open) trait Env {
  /// Get an environment variable
  get_var(Self, String) -> String?
  /// Get a binding by name (KV, D1, R2, etc.)
  get_binding(Self, String) -> Json?
}

///|
/// Execution context trait for background tasks
/// Similar to Cloudflare Workers ExecutionContext
pub(open) trait ExecCtx {
  /// Schedule a background task to run after response is sent
  wait_until(Self, async () -> Unit, name~ : String) -> Unit
}

///|
/// Empty environment (no bindings)
pub(all) struct EmptyEnv {}

///|
pub fn EmptyEnv::new() -> EmptyEnv {
  EmptyEnv::{  }
}

///|
pub impl Env for EmptyEnv with get_var(_self, _name) {
  None
}

///|
pub impl Env for EmptyEnv with get_binding(_self, _name) {
  None
}

///|
/// Map-based environment (for testing and simple use cases)
pub(all) struct MapEnv {
  vars : Map[String, String]
  bindings : Map[String, Json]
}

///|
pub fn MapEnv::new() -> MapEnv {
  { vars: {}, bindings: {} }
}

///|
pub fn MapEnv::with_var(self : MapEnv, name : String, value : String) -> MapEnv {
  self.vars.set(name, value)
  self
}

///|
pub fn MapEnv::with_binding(
  self : MapEnv,
  name : String,
  value : Json,
) -> MapEnv {
  self.bindings.set(name, value)
  self
}

///|
pub impl Env for MapEnv with get_var(self, name) {
  self.vars.get(name)
}

///|
pub impl Env for MapEnv with get_binding(self, name) {
  self.bindings.get(name)
}

///|
/// Trait for types that can be stored in Variables
pub(open) trait Var {
  to_json(Self) -> Json
  from_json(Json) -> Self?
}

///|
pub impl Var for String with to_json(self) {
  Json::string(self)
}

///|
pub impl Var for String with from_json(json) {
  match json {
    String(s) => Some(s)
    _ => None
  }
}

///|
pub impl Var for Double with to_json(self) {
  Json::number(self)
}

///|
pub impl Var for Double with from_json(json) {
  match json {
    Number(n, ..) => Some(n)
    _ => None
  }
}

///|
pub impl Var for Bool with to_json(self) {
  Json::boolean(self)
}

///|
pub impl Var for Bool with from_json(json) {
  match json {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
pub impl Var for Json with to_json(self) {
  self
}

///|
pub impl Var for Json with from_json(json) {
  Some(json)
}

///|
/// Typed variables storage
/// Uses Json for flexible storage with runtime type checking
pub(all) struct Variables {
  data : Map[String, Json]
}

///|
pub fn Variables::new() -> Variables {
  { data: {} }
}

///|
/// Set a variable (trait-based)
pub fn[V : Var] Variables::set(
  self : Variables,
  key : String,
  value : V,
) -> Unit {
  self.data.set(key, value.to_json())
}

///|
/// Get a variable as Json for pattern matching
pub fn Variables::get(self : Variables, key : String) -> Json? {
  self.data.get(key)
}

///|
/// Check if variable exists
pub fn Variables::has(self : Variables, key : String) -> Bool {
  self.data.contains(key)
}

///|
/// Remove a variable
pub fn Variables::remove(self : Variables, key : String) -> Unit {
  self.data.remove(key)
}

///|
/// Get all keys
pub fn Variables::keys(self : Variables) -> Array[String] {
  let result : Array[String] = []
  for key, _ in self.data {
    result.push(key)
  }
  result
}

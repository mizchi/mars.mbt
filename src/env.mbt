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
/// Set a string variable
pub fn Variables::set_string(
  self : Variables,
  key : String,
  value : String,
) -> Unit {
  self.data.set(key, Json::string(value))
}

///|
/// Get a string variable
pub fn Variables::get_string(self : Variables, key : String) -> String? {
  match self.data.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
/// Set a number variable
pub fn Variables::set_number(
  self : Variables,
  key : String,
  value : Double,
) -> Unit {
  self.data.set(key, Json::number(value))
}

///|
/// Get a number variable
pub fn Variables::get_number(self : Variables, key : String) -> Double? {
  match self.data.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
/// Set a boolean variable
pub fn Variables::set_bool(
  self : Variables,
  key : String,
  value : Bool,
) -> Unit {
  self.data.set(key, Json::boolean(value))
}

///|
/// Get a boolean variable
pub fn Variables::get_bool(self : Variables, key : String) -> Bool? {
  match self.data.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
/// Set a JSON variable
pub fn Variables::set_json(
  self : Variables,
  key : String,
  value : Json,
) -> Unit {
  self.data.set(key, value)
}

///|
/// Get a JSON variable
pub fn Variables::get_json(self : Variables, key : String) -> Json? {
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

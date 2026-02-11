///|
test "MapEnv creation and variables" {
  let env = MapEnv::new()
    .with_var("API_KEY", "secret123")
    .with_var("ENV", "production")
  inspect(env.get_var("API_KEY"), content="Some(\"secret123\")")
  inspect(env.get_var("ENV"), content="Some(\"production\")")
  inspect(env.get_var("MISSING"), content="None")
}

///|
test "MapEnv bindings" {
  let env = MapEnv::new()
    .with_binding("KV", Json::object({ "type": "kv-namespace" }))
    .with_binding("D1", Json::object({ "type": "d1-database" }))
  let expected_kv = "Some(Object({\"type\": String(\"kv-namespace\")}))"
  let expected_d1 = "Some(Object({\"type\": String(\"d1-database\")}))"
  inspect(env.get_binding("KV"), content=expected_kv)
  inspect(env.get_binding("D1"), content=expected_d1)
  inspect(env.get_binding("MISSING"), content="None")
}

///|
test "EmptyEnv returns None for everything" {
  let env = EmptyEnv::new()
  inspect(env.get_var("ANY"), content="None")
  inspect(env.get_binding("ANY"), content="None")
}

///|
test "Variables string operations" {
  let vars = Variables::new()
  vars.set("name", "Alice")
  vars.set("city", "Tokyo")
  let name = match vars.get("name") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let city = match vars.get("city") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let missing = vars.get("missing")
  inspect(name, content="Some(\"Alice\")")
  inspect(city, content="Some(\"Tokyo\")")
  inspect(missing, content="None")
}

///|
test "Variables number operations" {
  let vars = Variables::new()
  vars.set("count", 42.0)
  vars.set("price", 19.99)
  let count = match vars.get("count") {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
  let price = match vars.get("price") {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
  let missing = vars.get("missing")
  inspect(count, content="Some(42)")
  inspect(price, content="Some(19.99)")
  inspect(missing, content="None")
}

///|
test "Variables bool operations" {
  let vars = Variables::new()
  vars.set("active", true)
  vars.set("deleted", false)
  let active = match vars.get("active") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  let deleted = match vars.get("deleted") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  let missing = vars.get("missing")
  inspect(active, content="Some(true)")
  inspect(deleted, content="Some(false)")
  inspect(missing, content="None")
}

///|
test "Variables json operations" {
  let vars = Variables::new()
  vars.set("config", Json::object({ "debug": true, "level": 5 }))
  inspect(vars.get("config") is Some(_), content="true")
  inspect(vars.get("missing") is None, content="true")
}

///|
test "Variables has and remove" {
  let vars = Variables::new()
  vars.set("key", "value")
  inspect(vars.has("key"), content="true")
  inspect(vars.has("missing"), content="false")
  vars.remove("key")
  inspect(vars.has("key"), content="false")
}

///|
test "Variables keys" {
  let vars = Variables::new()
  vars.set("a", "1")
  vars.set("b", "2")
  vars.set("c", "3")
  let keys = vars.keys()
  inspect(keys.length(), content="3")
}

///|
test "Variables type mismatch returns None" {
  let vars = Variables::new()
  vars.set("name", "Alice")
  vars.set("count", 42.0)
  // Accessing wrong type via pattern match returns None
  let wrong_double = match vars.get("name") {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
  let wrong_string = match vars.get("count") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let wrong_bool = match vars.get("name") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  inspect(wrong_double, content="None")
  inspect(wrong_string, content="None")
  inspect(wrong_bool, content="None")
}

///|
test "ExecutionContext implements ExecCtx trait" {
  let exec_ctx : &ExecCtx = ExecutionContext::new()
  // Can call wait_until via trait
  exec_ctx.wait_until(fn() { () }, name="test-task")
  // Verify task was added (need to cast back to check)
  let ctx = ExecutionContext::new()
  ctx.wait_until(fn() { () }, name="via-trait")
  inspect(ctx.pending_count(), content="1")
}

///|
/// Custom ExecCtx implementation for testing
struct TestExecCtx {
  mut task_count : Int
}

///|
fn TestExecCtx::new() -> TestExecCtx {
  { task_count: 0 }
}

///|
impl ExecCtx for TestExecCtx with wait_until(self, _task, name~) {
  let _ = name
  self.task_count = self.task_count + 1
}

///|
test "Custom ExecCtx implementation" {
  let ctx = TestExecCtx::new()
  inspect(ctx.task_count, content="0")
  ctx.wait_until(fn() { () }, name="task1")
  inspect(ctx.task_count, content="1")
  ctx.wait_until(fn() { () }, name="task2")
  inspect(ctx.task_count, content="2")
}

///|
test "ExecCtx trait polymorphism" {
  fn add_task(ctx : &ExecCtx) -> Unit {
    ctx.wait_until(fn() { () }, name="polymorphic")
  }

  // Works with ExecutionContext
  let exec_ctx = ExecutionContext::new()
  add_task(exec_ctx)
  inspect(exec_ctx.pending_count(), content="1")

  // Works with custom implementation
  let test_ctx = TestExecCtx::new()
  add_task(test_ctx)
  inspect(test_ctx.task_count, content="1")
}

///|
/// Custom Env implementation for testing
struct TestEnv {
  prefix : String
}

///|
fn TestEnv::new(prefix : String) -> TestEnv {
  { prefix, }
}

///|
impl Env for TestEnv with get_var(self, name) {
  Some("\{self.prefix}_\{name}")
}

///|
impl Env for TestEnv with get_binding(self, name) {
  Some(Json::object({ "name": name, "prefix": self.prefix }))
}

///|
test "Custom Env implementation" {
  let env = TestEnv::new("TEST")
  inspect(env.get_var("KEY"), content="Some(\"TEST_KEY\")")
  inspect(
    env.get_binding("DB"),
    content="Some(Object({\"name\": String(\"DB\"), \"prefix\": String(\"TEST\")}))",
  )
}

///|
test "Env trait polymorphism" {
  fn get_api_key(env : &Env) -> String? {
    env.get_var("API_KEY")
  }

  // Works with MapEnv
  let map_env = MapEnv::new().with_var("API_KEY", "secret")
  inspect(get_api_key(map_env), content="Some(\"secret\")")

  // Works with EmptyEnv
  let empty_env = EmptyEnv::new()
  inspect(get_api_key(empty_env), content="None")

  // Works with custom implementation
  let test_env = TestEnv::new("PREFIX")
  inspect(get_api_key(test_env), content="Some(\"PREFIX_API_KEY\")")
}

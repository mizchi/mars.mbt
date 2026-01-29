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
  vars.set_string("name", "Alice")
  vars.set_string("city", "Tokyo")
  inspect(vars.get_string("name"), content="Some(\"Alice\")")
  inspect(vars.get_string("city"), content="Some(\"Tokyo\")")
  inspect(vars.get_string("missing"), content="None")
}

///|
test "Variables number operations" {
  let vars = Variables::new()
  vars.set_number("count", 42.0)
  vars.set_number("price", 19.99)
  inspect(vars.get_number("count"), content="Some(42)")
  inspect(vars.get_number("price"), content="Some(19.99)")
  inspect(vars.get_number("missing"), content="None")
}

///|
test "Variables bool operations" {
  let vars = Variables::new()
  vars.set_bool("active", true)
  vars.set_bool("deleted", false)
  inspect(vars.get_bool("active"), content="Some(true)")
  inspect(vars.get_bool("deleted"), content="Some(false)")
  inspect(vars.get_bool("missing"), content="None")
}

///|
test "Variables json operations" {
  let vars = Variables::new()
  vars.set_json("config", Json::object({ "debug": true, "level": 5 }))
  inspect(vars.get_json("config") is Some(_), content="true")
  inspect(vars.get_json("missing") is None, content="true")
}

///|
test "Variables has and remove" {
  let vars = Variables::new()
  vars.set_string("key", "value")
  inspect(vars.has("key"), content="true")
  inspect(vars.has("missing"), content="false")
  vars.remove("key")
  inspect(vars.has("key"), content="false")
}

///|
test "Variables keys" {
  let vars = Variables::new()
  vars.set_string("a", "1")
  vars.set_string("b", "2")
  vars.set_string("c", "3")
  let keys = vars.keys()
  inspect(keys.length(), content="3")
}

///|
test "Variables type mismatch returns None" {
  let vars = Variables::new()
  vars.set_string("name", "Alice")
  vars.set_number("count", 42.0)
  // Accessing wrong type returns None
  inspect(vars.get_number("name"), content="None")
  inspect(vars.get_string("count"), content="None")
  inspect(vars.get_bool("name"), content="None")
}

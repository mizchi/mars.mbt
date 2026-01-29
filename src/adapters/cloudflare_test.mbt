///|
test "KVNamespace basic operations" {
  let kv = KVNamespace::new("MY_KV")
  inspect(kv.name, content="MY_KV")
}

///|
test "D1Database creation" {
  let db = D1Database::new("MY_DB")
  inspect(db.name, content="MY_DB")
}

///|
test "R2Bucket creation" {
  let bucket = R2Bucket::new("MY_BUCKET")
  inspect(bucket.name, content="MY_BUCKET")
}

///|
test "CloudflareEnv creation" {
  let env = CloudflareEnv::new()
  inspect(env.get_var("ANY"), content="None")
  inspect(env.get_kv("ANY") is None, content="true")
  inspect(env.get_d1("ANY") is None, content="true")
  inspect(env.get_r2("ANY") is None, content="true")
}

///|
test "CloudflareEnv with_var" {
  let env = CloudflareEnv::new()
    .with_var("API_KEY", "secret")
    .with_var("ENV", "production")
  inspect(env.get_var("API_KEY"), content="Some(\"secret\")")
  inspect(env.get_var("ENV"), content="Some(\"production\")")
  inspect(env.get_var("MISSING"), content="None")
}

///|
test "CloudflareEnv with_kv" {
  let kv = KVNamespace::new("CACHE")
  let env = CloudflareEnv::new().with_kv("CACHE", kv)
  inspect(env.get_kv("CACHE") is Some(_), content="true")
  inspect(env.get_kv("OTHER") is None, content="true")
}

///|
test "CloudflareEnv with_d1" {
  let db = D1Database::new("USERS")
  let env = CloudflareEnv::new().with_d1("USERS", db)
  inspect(env.get_d1("USERS") is Some(_), content="true")
  inspect(env.get_d1("OTHER") is None, content="true")
}

///|
test "CloudflareEnv with_r2" {
  let bucket = R2Bucket::new("UPLOADS")
  let env = CloudflareEnv::new().with_r2("UPLOADS", bucket)
  inspect(env.get_r2("UPLOADS") is Some(_), content="true")
  inspect(env.get_r2("OTHER") is None, content="true")
}

///|
test "CloudflareEnv to_map_env converts vars" {
  let cf_env = CloudflareEnv::new()
    .with_var("SECRET", "value123")
    .with_var("MODE", "dev")
  let map_env = cf_env.to_map_env()
  inspect(map_env.get_var("SECRET"), content="Some(\"value123\")")
  inspect(map_env.get_var("MODE"), content="Some(\"dev\")")
}

///|
test "CloudflareEnv to_map_env includes bindings info" {
  let cf_env = CloudflareEnv::new()
    .with_kv("CACHE", KVNamespace::new("CACHE"))
    .with_d1("DB", D1Database::new("DB"))
    .with_r2("BUCKET", R2Bucket::new("BUCKET"))
  let map_env = cf_env.to_map_env()
  let expected_kv = "Some(String(\"KVNamespace\"))"
  let expected_d1 = "Some(String(\"D1Database\"))"
  let expected_r2 = "Some(String(\"R2Bucket\"))"
  inspect(map_env.get_binding("kv:CACHE"), content=expected_kv)
  inspect(map_env.get_binding("d1:DB"), content=expected_d1)
  inspect(map_env.get_binding("r2:BUCKET"), content=expected_r2)
}

///|
test "CloudflareEnv chained builder pattern" {
  let env = CloudflareEnv::new()
    .with_var("KEY", "value")
    .with_kv("KV", KVNamespace::new("KV"))
    .with_d1("D1", D1Database::new("D1"))
    .with_r2("R2", R2Bucket::new("R2"))
  inspect(env.get_var("KEY"), content="Some(\"value\")")
  inspect(env.get_kv("KV") is Some(_), content="true")
  inspect(env.get_d1("D1") is Some(_), content="true")
  inspect(env.get_r2("R2") is Some(_), content="true")
}

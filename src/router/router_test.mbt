///|
test "Method::to_string" {
  inspect(Method::Get.to_string(), content="GET")
  inspect(Method::Post.to_string(), content="POST")
  inspect(Method::Query.to_string(), content="QUERY")
  inspect(Method::All.to_string(), content="ALL")
}

///|
test "Method::from_string" {
  inspect(Method::from_string("GET"), content="Some(GET)")
  inspect(Method::from_string("POST"), content="Some(POST)")
  inspect(Method::from_string("QUERY"), content="Some(QUERY)")
  inspect(Method::from_string("INVALID"), content="None")
}

///|
test "Params basic operations" {
  let params = Params::new()
  assert_true(params.is_empty())
  params.set("id", "123")
  assert_false(params.is_empty())
  inspect(params.get("id"), content="Some(\"123\")")
  inspect(params.get("unknown"), content="None")
}

///|
test "MatchResult::empty" {
  let result : MatchResult[Int] = MatchResult::empty()
  assert_true(result.is_empty())
}

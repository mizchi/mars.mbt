///|
test "extract_path_params empty" {
  let params = extract_path_params("/users")
  inspect(params.length(), content="0")
}

///|
test "extract_path_params single" {
  let params = extract_path_params("/users/:id")
  inspect(params.length(), content="1")
  inspect(params[0].name, content="id")
  inspect(params[0].position, content="1")
}

///|
test "extract_path_params multiple" {
  let params = extract_path_params("/users/:user_id/posts/:post_id")
  inspect(params.length(), content="2")
  inspect(params[0].name, content="user_id")
  inspect(params[1].name, content="post_id")
}

///|
test "RouteSpec::get" {
  let route = RouteSpec::get("/users", "get_users", "Array[User]")
  inspect(route.http_method, content="GET")
  inspect(route.path, content="/users")
  inspect(route.input_type, content="None")
  inspect(route.output_type, content="Array[User]")
  inspect(route.name, content="get_users")
}

///|
test "RouteSpec::post" {
  let route = RouteSpec::post("/users", "create_user", "CreateUserInput", "User")
  inspect(route.http_method, content="POST")
  inspect(route.input_type, content="Some(\"CreateUserInput\")")
  inspect(route.output_type, content="User")
}

///|
test "RouteSpec::delete" {
  let route = RouteSpec::delete("/users/:id", "delete_user", "Unit")
  inspect(route.http_method, content="DELETE")
  inspect(route.path, content="/users/:id")
}

///|
test "RouteSpec::query" {
  let route = RouteSpec::query("/search", "search", "SearchQuery", "SearchResult")
  inspect(route.http_method, content="QUERY")
  inspect(route.input_type, content="Some(\"SearchQuery\")")
}

///|
test "ClientOptions::default" {
  let opts = ClientOptions::default()
  inspect(opts.name, content="ApiClient")
  inspect(opts.base_url_field, content="base_url")
  inspect(opts.async_functions, content="true")
}

///|
test "ClientOptions::new" {
  let opts = ClientOptions::new("MyClient")
  inspect(opts.name, content="MyClient")
}

///|
test "validate_routes valid" {
  let routes = [
    RouteSpec::get("/users", "get_users", "Array[User]"),
    RouteSpec::post("/users", "create_user", "CreateUserInput", "User"),
  ]
  let errors = validate_routes(routes)
  inspect(errors.length(), content="0")
}

///|
test "validate_routes invalid method" {
  let routes = [
    {
      http_method: "INVALID",
      path: "/users",
      input_type: None,
      output_type: "Unit",
      name: "test",
      description: None,
    },
  ]
  let errors = validate_routes(routes)
  inspect(errors.length() > 0, content="true")
}

///|
test "validate_routes path without slash" {
  let routes = [
    {
      http_method: "GET",
      path: "users",
      input_type: None,
      output_type: "Unit",
      name: "test",
      description: None,
    },
  ]
  let errors = validate_routes(routes)
  inspect(errors.length() > 0, content="true")
}

///|
test "generate_client basic" {
  let routes = [RouteSpec::get("/health", "health", "String")]
  let code = generate_client(routes)
  inspect(code.contains("struct ApiClient"), content="true")
  inspect(code.contains("fn ApiClient::new"), content="true")
  inspect(code.contains("fn ApiClient::health"), content="true")
}

///|
test "generate_client with path params" {
  let routes = [RouteSpec::get("/users/:id", "get_user", "User")]
  let code = generate_client(routes)
  inspect(code.contains("id : String"), content="true")
}

///|
test "generate_client with body" {
  let routes = [RouteSpec::post("/users", "create_user", "CreateUserInput", "User")]
  let code = generate_client(routes)
  inspect(code.contains("body : CreateUserInput"), content="true")
}

///|
test "generate_client custom options" {
  let routes = [RouteSpec::get("/", "root", "String")]
  let opts = ClientOptions::new("MyApi")
  let code = generate_client(routes, options=opts)
  inspect(code.contains("struct MyApi"), content="true")
  inspect(code.contains("fn MyApi::new"), content="true")
}

///|
test "generate_types_doc" {
  let routes = [
    RouteSpec::post("/users", "create_user", "CreateUserInput", "User"),
    RouteSpec::get("/users/:id", "get_user", "User"),
  ]
  let doc = generate_types_doc(routes)
  inspect(doc.contains("CreateUserInput"), content="true")
  inspect(doc.contains("User"), content="true")
}

///|
test "split_path basic" {
  let segments = split_path("/users/123/posts")
  inspect(segments.length(), content="3")
  inspect(segments[0], content="users")
  inspect(segments[1], content="123")
  inspect(segments[2], content="posts")
}

///|
test "split_path with params" {
  let segments = split_path("/users/:id")
  inspect(segments.length(), content="2")
  inspect(segments[0], content="users")
  inspect(segments[1], content=":id")
}

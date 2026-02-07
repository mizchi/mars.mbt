///|
test "route: top path" {
  let res = route("GET", "/")
  inspect(res, content="{status: 200, body: \"mars-router: top\"}")
}

///|
test "route: param path" {
  let res = route("GET", "/users/42")
  inspect(res, content="{status: 200, body: \"mars-router: user=42\"}")
}

///|
test "route: wildcard path" {
  let res = route("GET", "/files/a/b/c")
  inspect(
    res,
    content="{status: 200, body: \"mars-router: wildcard=/files/a/b/c\"}",
  )
}

///|
test "route: not found" {
  let res = route("GET", "/missing")
  inspect(res, content="{status: 404, body: \"not found: /missing\"}")
}

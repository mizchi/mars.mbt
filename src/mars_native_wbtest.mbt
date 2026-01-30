///|
test "request_method_to_method Get" {
  let result = request_method_to_method(@http.RequestMethod::Get)
  inspect(result, content="GET")
}

///|
test "request_method_to_method Post" {
  let result = request_method_to_method(@http.RequestMethod::Post)
  inspect(result, content="POST")
}

///|
test "request_method_to_method Put" {
  let result = request_method_to_method(@http.RequestMethod::Put)
  inspect(result, content="PUT")
}

///|
test "request_method_to_method Delete" {
  let result = request_method_to_method(@http.RequestMethod::Delete)
  inspect(result, content="DELETE")
}

///|
test "request_method_to_method Patch" {
  let result = request_method_to_method(@http.RequestMethod::Patch)
  inspect(result, content="PATCH")
}

///|
test "request_method_to_method Head" {
  let result = request_method_to_method(@http.RequestMethod::Head)
  inspect(result, content="HEAD")
}

///|
test "request_method_to_method Options" {
  let result = request_method_to_method(@http.RequestMethod::Options)
  inspect(result, content="OPTIONS")
}

///|
test "request_method_to_method Connect" {
  let result = request_method_to_method(@http.RequestMethod::Connect)
  inspect(result, content="CONNECT")
}

///|
test "request_method_to_method Trace" {
  let result = request_method_to_method(@http.RequestMethod::Trace)
  inspect(result, content="TRACE")
}

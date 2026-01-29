///|
/// Route specification for code generation
pub(all) struct RouteSpec {
  /// HTTP method (GET, POST, PUT, DELETE, PATCH, QUERY)
  http_method : String
  /// URL path pattern (e.g., "/users/:id")
  path : String
  /// Request body type name (for POST/PUT/PATCH)
  input_type : String?
  /// Response type name
  output_type : String
  /// Generated function name
  name : String
  /// Optional description for documentation
  description : String?
} derive(Show)

///|
/// Create a GET route spec
pub fn RouteSpec::get(
  path : String,
  name : String,
  output_type : String,
  description? : String,
) -> RouteSpec {
  {
    http_method: "GET",
    path,
    input_type: None,
    output_type,
    name,
    description,
  }
}

///|
/// Create a POST route spec
pub fn RouteSpec::post(
  path : String,
  name : String,
  input_type : String,
  output_type : String,
  description? : String,
) -> RouteSpec {
  {
    http_method: "POST",
    path,
    input_type: Some(input_type),
    output_type,
    name,
    description,
  }
}

///|
/// Create a PUT route spec
pub fn RouteSpec::put(
  path : String,
  name : String,
  input_type : String,
  output_type : String,
  description? : String,
) -> RouteSpec {
  {
    http_method: "PUT",
    path,
    input_type: Some(input_type),
    output_type,
    name,
    description,
  }
}

///|
/// Create a DELETE route spec
pub fn RouteSpec::delete(
  path : String,
  name : String,
  output_type : String,
  description? : String,
) -> RouteSpec {
  {
    http_method: "DELETE",
    path,
    input_type: None,
    output_type,
    name,
    description,
  }
}

///|
/// Create a PATCH route spec
pub fn RouteSpec::patch(
  path : String,
  name : String,
  input_type : String,
  output_type : String,
  description? : String,
) -> RouteSpec {
  {
    http_method: "PATCH",
    path,
    input_type: Some(input_type),
    output_type,
    name,
    description,
  }
}

///|
/// Create a QUERY route spec
pub fn RouteSpec::query(
  path : String,
  name : String,
  input_type : String,
  output_type : String,
  description? : String,
) -> RouteSpec {
  {
    http_method: "QUERY",
    path,
    input_type: Some(input_type),
    output_type,
    name,
    description,
  }
}

///|
/// Client generation options
pub(all) struct ClientOptions {
  /// Client struct name
  name : String
  /// Base URL field name
  base_url_field : String
  /// Whether to generate async functions
  async_functions : Bool
  /// Package prefix for imports
  package_prefix : String?
} derive(Show)

///|
/// Default client options
pub fn ClientOptions::default() -> ClientOptions {
  {
    name: "ApiClient",
    base_url_field: "base_url",
    async_functions: true,
    package_prefix: None,
  }
}

///|
/// Create custom client options
pub fn ClientOptions::new(name : String) -> ClientOptions {
  { ..ClientOptions::default(), name }
}

///|
/// Path parameter extracted from route path
pub(all) struct PathParam {
  name : String
  position : Int
} derive(Show)

///|
/// Extract path parameters from a route path
/// e.g., "/users/:id/posts/:post_id" -> [("id", 1), ("post_id", 3)]
pub fn extract_path_params(path : String) -> Array[PathParam] {
  let params : Array[PathParam] = []
  let segments = split_path(path)
  for i, segment in segments {
    if segment.length() > 0 && segment[0] == ':' {
      let name = substring(segment, 1, segment.length())
      params.push({ name, position: i })
    }
  }
  params
}

///|
/// Split path into segments
fn split_path(path : String) -> Array[String] {
  let segments : Array[String] = []
  let buf = StringBuilder::new()
  for c in path {
    if c == '/' {
      if buf.to_string().length() > 0 {
        segments.push(buf.to_string())
        buf.reset()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    segments.push(buf.to_string())
  }
  segments
}

///|
/// Extract substring
fn substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in s {
    if i >= start && i < end {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

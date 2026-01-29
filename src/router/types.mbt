///|
/// URL path parameters extracted from route matching
pub(all) struct Params {
  priv data : Map[String, String]
}

///|
/// Create a new empty Params
pub fn Params::new() -> Params {
  { data: Map::new() }
}

///|
/// Create a new Params with an additional key-value pair
/// More efficient than clone + set when adding a single param
pub fn Params::with_param(
  self : Params,
  key : String,
  value : String,
) -> Params {
  let new_data : Map[String, String] = Map::new()
  self.data.each(fn(k, v) { new_data.set(k, v) })
  new_data.set(key, value)
  { data: new_data }
}

///|
/// Get a parameter value by key
pub fn Params::get(self : Params, key : String) -> String? {
  self.data.get(key)
}

///|
/// Set a parameter value
pub fn Params::set(self : Params, key : String, value : String) -> Unit {
  self.data.set(key, value)
}

///|
/// Check if params is empty
pub fn Params::is_empty(self : Params) -> Bool {
  self.data.is_empty()
}

///|
/// Get the underlying map
pub fn Params::to_map(self : Params) -> Map[String, String] {
  self.data
}

///|
/// Clone params
pub fn Params::clone(self : Params) -> Params {
  let new_data : Map[String, String] = Map::new()
  self.data.each(fn(k, v) { new_data.set(k, v) })
  { data: new_data }
}

///|
pub impl Show for Params with output(self, logger) {
  logger.write_string("Params(")
  logger.write_object(self.data)
  logger.write_string(")")
}

///|
/// Result of route matching
pub(all) struct MatchResult[H] {
  /// Array of matched handlers with their extracted params
  handlers : Array[(H, Params)]
}

///|
/// Create an empty match result
pub fn[H] MatchResult::empty() -> MatchResult[H] {
  { handlers: [] }
}

///|
/// Check if match result has any handlers
pub fn[H] MatchResult::is_empty(self : MatchResult[H]) -> Bool {
  self.handlers.is_empty()
}

///|
/// HTTP method type
pub(all) enum Method {
  Get
  Post
  Put
  Delete
  Patch
  Head
  Options
  Connect
  Trace
  Query
  All
} derive(Eq, Hash)

///|
pub impl Show for Method with output(self, logger) {
  let s = match self {
    Get => "GET"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Patch => "PATCH"
    Head => "HEAD"
    Options => "OPTIONS"
    Connect => "CONNECT"
    Trace => "TRACE"
    Query => "QUERY"
    All => "ALL"
  }
  logger.write_string(s)
}

///|
/// Convert Method to string
pub fn Method::to_string(self : Method) -> String {
  match self {
    Get => "GET"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Patch => "PATCH"
    Head => "HEAD"
    Options => "OPTIONS"
    Connect => "CONNECT"
    Trace => "TRACE"
    Query => "QUERY"
    All => "ALL"
  }
}

///|
/// Parse string to Method
pub fn Method::from_string(s : String) -> Method? {
  match s {
    "GET" => Some(Get)
    "POST" => Some(Post)
    "PUT" => Some(Put)
    "DELETE" => Some(Delete)
    "PATCH" => Some(Patch)
    "HEAD" => Some(Head)
    "OPTIONS" => Some(Options)
    "CONNECT" => Some(Connect)
    "TRACE" => Some(Trace)
    "QUERY" => Some(Query)
    "ALL" => Some(All)
    _ => None
  }
}

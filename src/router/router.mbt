///|
/// Handler ID for storing handlers
pub(all) struct HandlerId(Int) derive(Eq, Hash, Debug)

///|
pub impl Show for HandlerId with fn output(self, logger) {
  let HandlerId(id) = self
  logger.write_string("HandlerId(")
  logger.write_string(id.to_string())
  logger.write_string(")")
}

///|
/// Router trait for HTTP routing
/// The router stores handlers by ID, and the actual handler lookup is done externally
pub(open) trait Router {
  /// Get the name of the router implementation
  fn name(Self) -> String
  /// Add a route to the router, returns the handler ID
  fn add(Self, Method, String) -> HandlerId
  /// Match a request and return matching handler IDs with params
  fn match_(Self, Method, String) -> MatchResult[HandlerId]
}

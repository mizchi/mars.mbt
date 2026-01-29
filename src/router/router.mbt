///|
/// Handler ID for storing handlers
pub(all) struct HandlerId(Int) derive(Eq, Hash, Show)

///|
/// Router trait for HTTP routing
/// The router stores handlers by ID, and the actual handler lookup is done externally
pub(open) trait Router {
  /// Get the name of the router implementation
  name(Self) -> String
  /// Add a route to the router, returns the handler ID
  add(Self, Method, String) -> HandlerId
  /// Match a request and return matching handler IDs with params
  match_(Self, Method, String) -> MatchResult[HandlerId]
}

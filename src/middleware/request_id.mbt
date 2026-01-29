///|
/// Request ID Middleware
/// Adds unique ID to each request for tracing

///|
/// Request ID counter
let request_id_counter : Ref[Int] = Ref::new(0)

///|
/// Request ID options
pub(all) struct RequestIdOptions {
  /// Header name to use
  header_name : String
  /// Prefix for generated IDs
  prefix : String
  /// Whether to use existing ID from request header
  use_existing : Bool
}

///|
/// Default request ID options
pub fn RequestIdOptions::default() -> RequestIdOptions {
  { header_name: "X-Request-ID", prefix: "req-", use_existing: true }
}

///|
/// Generate a new request ID
fn generate_request_id(prefix : String) -> String {
  request_id_counter.val = request_id_counter.val + 1
  let counter = request_id_counter.val
  // Simple ID: prefix + counter + random-like suffix
  let suffix = (counter * 1103515245 + 12345) % 1000000
  "\{prefix}\{counter}-\{suffix}"
}

///|
/// Request ID middleware
pub fn request_id(
  options? : RequestIdOptions = RequestIdOptions::default(),
) -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    let id = if options.use_existing {
      match ctx.header(options.header_name) {
        Some(existing) => existing
        None => generate_request_id(options.prefix)
      }
    } else {
      generate_request_id(options.prefix)
    }
    // Store in context data
    ctx.set("request_id", id)
    // Set response header
    ctx.set_header(options.header_name, id)
  }
}

///|
/// Get request ID from context
pub fn get_request_id(ctx : @mars.Context) -> String? {
  ctx.get("request_id")
}

///|
/// Reset request ID counter (for testing)
pub fn request_id_reset() -> Unit {
  request_id_counter.val = 0
}

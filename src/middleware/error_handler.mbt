///|
/// Error Handler
/// Global error handling and custom error pages

///|
/// HTTP Error
pub(all) struct HttpError {
  status : Int
  message : String
  details : String
}

///|
/// Create HTTP error
pub fn HttpError::new(status : Int, message : String) -> HttpError {
  { status, message, details: "" }
}

///|
/// Create HTTP error with details
pub fn HttpError::with_details(
  status : Int,
  message : String,
  details : String,
) -> HttpError {
  { status, message, details }
}

///|
/// Common HTTP errors
pub fn HttpError::bad_request(message? : String = "Bad Request") -> HttpError {
  HttpError::new(400, message)
}

///|
pub fn HttpError::unauthorized(message? : String = "Unauthorized") -> HttpError {
  HttpError::new(401, message)
}

///|
pub fn HttpError::forbidden(message? : String = "Forbidden") -> HttpError {
  HttpError::new(403, message)
}

///|
pub fn HttpError::not_found(message? : String = "Not Found") -> HttpError {
  HttpError::new(404, message)
}

///|
pub fn HttpError::method_not_allowed(
  message? : String = "Method Not Allowed",
) -> HttpError {
  HttpError::new(405, message)
}

///|
pub fn HttpError::conflict(message? : String = "Conflict") -> HttpError {
  HttpError::new(409, message)
}

///|
pub fn HttpError::unprocessable(
  message? : String = "Unprocessable Entity",
) -> HttpError {
  HttpError::new(422, message)
}

///|
pub fn HttpError::internal(
  message? : String = "Internal Server Error",
) -> HttpError {
  HttpError::new(500, message)
}

///|
pub fn HttpError::service_unavailable(
  message? : String = "Service Unavailable",
) -> HttpError {
  HttpError::new(503, message)
}

///|
/// Error handler options
pub(all) struct ErrorHandlerOptions {
  /// Show error details in response
  show_details : Bool
  /// Custom error renderer
  render : (HttpError) -> String
  /// Use JSON format
  json : Bool
}

///|
/// Default error handler options
pub fn ErrorHandlerOptions::default() -> ErrorHandlerOptions {
  { show_details: false, render: default_error_render, json: false }
}

///|
/// Development error handler options (shows details)
pub fn ErrorHandlerOptions::development() -> ErrorHandlerOptions {
  { show_details: true, render: default_error_render, json: false }
}

///|
/// JSON error handler options
pub fn ErrorHandlerOptions::json_api() -> ErrorHandlerOptions {
  { show_details: false, render: default_error_render, json: true }
}

///|
/// Default error renderer
fn default_error_render(err : HttpError) -> String {
  if err.details.is_empty() {
    err.message
  } else {
    err.message + ": " + err.details
  }
}

///|
/// Send HTTP error response
pub async fn send_error(
  ctx : @mars.Context,
  err : HttpError,
  options? : ErrorHandlerOptions = ErrorHandlerOptions::default(),
) -> Unit {
  if options.json {
    let json = if options.show_details && not(err.details.is_empty()) {
      Json::object({
        "error": Json::string(err.message),
        "details": Json::string(err.details),
        "status": Json::number(err.status.to_double()),
      })
    } else {
      Json::object({
        "error": Json::string(err.message),
        "status": Json::number(err.status.to_double()),
      })
    }
    ctx.json(json, status=err.status)
  } else {
    let body = if options.show_details {
      (options.render)(err)
    } else {
      err.message
    }
    ctx.text(body, status=err.status)
  }
}

///|
/// Custom not found handler
pub fn not_found_handler(render : (@mars.Context) -> String) -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    let body = render(ctx)
    ctx.html(body, status=404)
  }
}

///|
/// Simple not found handler
pub fn not_found_simple(message? : String = "Not Found") -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error { ctx.text(message, status=404) }
}

///|
/// JSON not found handler
pub fn not_found_json() -> @mars.Handler {
  async fn(ctx : @mars.Context) raise Error {
    ctx.json(
      Json::object({
        "error": Json::string("Not Found"),
        "path": Json::string(ctx.path()),
      }),
      status=404,
    )
  }
}

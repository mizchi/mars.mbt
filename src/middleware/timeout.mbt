///|
/// Timeout Middleware
/// Request timeout handling
/// Note: Actual timeout requires async runtime support
/// This provides timeout context and manual checking pattern

///|
/// Timeout options
pub(all) struct TimeoutOptions {
  /// Timeout in milliseconds
  timeout_ms : Int
  /// Message to send on timeout
  message : String
  /// Status code to send on timeout
  status : Int
}

///|
/// Default timeout options (30 seconds)
pub fn TimeoutOptions::default() -> TimeoutOptions {
  { timeout_ms: 30000, message: "Request Timeout", status: 408 }
}

///|
/// Create timeout options
pub fn TimeoutOptions::new(timeout_ms : Int) -> TimeoutOptions {
  { ..TimeoutOptions::default(), timeout_ms, }
}

///|
/// Timeout context for manual checking
pub(all) struct TimeoutContext {
  start_time : Int
  timeout_ms : Int
  mut timed_out : Bool
}

///|
/// Timeout timer counter
let timeout_timer : Ref[Int] = Ref::new(0)

///|
fn timeout_now() -> Int {
  timeout_timer.val = timeout_timer.val + 1
  timeout_timer.val
}

///|
/// Create timeout context
pub fn TimeoutContext::new(timeout_ms : Int) -> TimeoutContext {
  { start_time: timeout_now(), timeout_ms, timed_out: false }
}

///|
/// Check if timeout exceeded
pub fn TimeoutContext::is_timed_out(self : TimeoutContext) -> Bool {
  if self.timed_out {
    return true
  }
  let elapsed = timeout_now() - self.start_time
  if elapsed > self.timeout_ms {
    self.timed_out = true
    true
  } else {
    false
  }
}

///|
/// Get elapsed time
pub fn TimeoutContext::elapsed(self : TimeoutContext) -> Int {
  timeout_now() - self.start_time
}

///|
/// Mark as timed out
pub fn TimeoutContext::mark_timed_out(self : TimeoutContext) -> Unit {
  self.timed_out = true
}

///|
/// Timeout middleware
/// Sets up timeout context in request data
pub fn timeout(
  options? : TimeoutOptions = TimeoutOptions::default(),
) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    ctx.set("_timeout_start", timeout_now().to_string())
    ctx.set("_timeout_ms", options.timeout_ms.to_string())
    ctx.set("_timeout_message", options.message)
    ctx.set("_timeout_status", options.status.to_string())
  }
}

///|
/// Check if request should timeout (call in long-running handlers)
pub fn check_timeout(ctx : @flame.Context) -> Bool {
  let start = match ctx.get("_timeout_start") {
    Some(s) => parse_timeout_int(s)
    None => return false
  }
  let timeout_ms = match ctx.get("_timeout_ms") {
    Some(s) => parse_timeout_int(s)
    None => return false
  }
  let elapsed = timeout_now() - start
  elapsed > timeout_ms
}

///|
/// Send timeout response if timed out
pub async fn send_timeout_if_needed(ctx : @flame.Context) -> Bool {
  if check_timeout(ctx) {
    let message = ctx.get("_timeout_message").unwrap_or("Request Timeout")
    let status = match ctx.get("_timeout_status") {
      Some(s) => parse_timeout_int(s)
      None => 408
    }
    ctx.text(message, status~)
    true
  } else {
    false
  }
}

///|
/// Parse int for timeout
fn parse_timeout_int(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
/// Reset timeout timer (for testing)
pub fn timeout_timer_reset() -> Unit {
  timeout_timer.val = 0
}

///|
/// Advance timeout timer (for testing)
pub fn timeout_timer_advance(ms : Int) -> Unit {
  timeout_timer.val = timeout_timer.val + ms
}

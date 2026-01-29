///|
/// Logger Middleware
/// Request logging with response time measurement

///|
/// Log level
pub(all) enum LogLevel {
  Debug
  Info
  Warn
  Error
} derive(Show, Eq)

///|
/// Logger options
pub(all) struct LoggerOptions {
  /// Minimum log level
  level : LogLevel
  /// Include request headers
  headers : Bool
  /// Include query parameters
  query : Bool
}

///|
/// Default logger options
pub fn LoggerOptions::default() -> LoggerOptions {
  { level: LogLevel::Info, headers: false, query: false }
}

///|
/// Get current timestamp as string (simplified - uses counter)
let log_counter : Ref[Int] = Ref::new(0)

///|
fn get_timestamp() -> String {
  log_counter.val = log_counter.val + 1
  log_counter.val.to_string()
}

///|
/// Format log entry
fn format_log_entry(
  meth : String,
  path : String,
  status : Int,
  duration_ms : Int,
  options : LoggerOptions,
  ctx : @flame.Context,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("[")
  buf.write_string(get_timestamp())
  buf.write_string("] ")
  buf.write_string(meth)
  buf.write_string(" ")
  buf.write_string(path)
  buf.write_string(" -> ")
  buf.write_string(status.to_string())
  buf.write_string(" (")
  buf.write_string(duration_ms.to_string())
  buf.write_string("ms)")
  if options.query {
    let queries = ctx.queries()
    if not(queries.is_empty()) {
      buf.write_string(" query=")
      buf.write_string(format_map(queries))
    }
  }
  if options.headers {
    match ctx.header("User-Agent") {
      Some(ua) => {
        buf.write_string(" ua=\"")
        buf.write_string(ua)
        buf.write_string("\"")
      }
      None => ()
    }
  }
  buf.to_string()
}

///|
/// Format map as string
fn format_map(m : Map[String, String]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{")
  let mut first = true
  for key, value in m {
    if not(first) {
      buf.write_string(",")
    }
    first = false
    buf.write_string(key)
    buf.write_string("=")
    buf.write_string(value)
  }
  buf.write_string("}")
  buf.to_string()
}

///|
/// Simple timer using counter (for timing measurement)
let timer_start : Ref[Int] = Ref::new(0)

///|
fn timer_now() -> Int {
  timer_start.val = timer_start.val + 1
  timer_start.val
}

///|
/// Logger middleware
pub fn logger(
  options? : LoggerOptions = LoggerOptions::default(),
) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let start = timer_now()
    let meth = ctx.meth().to_string()
    let path = ctx.path()
    // Store start time for later use
    ctx.set("_log_start", start.to_string())
    ctx.set("_log_meth", meth)
    ctx.set("_log_path", path)
    // Note: Actual logging happens after response in real implementation
    // For now, we just set up the context data
  }
}

///|
/// Log after response (call manually or use with after-middleware pattern)
pub fn log_response(
  ctx : @flame.Context,
  status : Int,
  options? : LoggerOptions = LoggerOptions::default(),
) -> Unit {
  let start = match ctx.get("_log_start") {
    Some(s) => parse_int_simple(s)
    None => 0
  }
  let meth = ctx.get("_log_meth").unwrap_or("?")
  let path = ctx.get("_log_path").unwrap_or("?")
  let duration = timer_now() - start
  let entry = format_log_entry(meth, path, status, duration, options, ctx)
  println(entry)
}

///|
/// Parse int simply
fn parse_int_simple(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
/// Simple logger that logs immediately (for debugging)
pub fn logger_simple() -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let meth = ctx.meth().to_string()
    let path = ctx.path()
    println("--> \{meth} \{path}")
  }
}

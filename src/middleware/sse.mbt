///|
/// Server-Sent Events (SSE) Support
/// Enables real-time server-to-client communication

///|
/// SSE Event
pub(all) struct SseEvent {
  /// Event type (optional)
  event : String
  /// Event data (required)
  data : String
  /// Event ID (optional)
  id : String
  /// Retry interval in milliseconds (optional)
  retry : Int
}

///|
/// Create a simple SSE event with just data
pub fn SseEvent::data(data : String) -> SseEvent {
  { event: "", data, id: "", retry: 0 }
}

///|
/// Create an SSE event with type and data
pub fn SseEvent::new(event : String, data : String) -> SseEvent {
  { event, data, id: "", retry: 0 }
}

///|
/// Create an SSE event with all fields
pub fn SseEvent::full(
  event : String,
  data : String,
  id : String,
  retry : Int,
) -> SseEvent {
  { event, data, id, retry }
}

///|
/// Format SSE event as string
pub fn SseEvent::format(self : SseEvent) -> String {
  let buf = StringBuilder::new()
  if not(self.id.is_empty()) {
    buf.write_string("id: ")
    buf.write_string(self.id)
    buf.write_char('\n')
  }
  if not(self.event.is_empty()) {
    buf.write_string("event: ")
    buf.write_string(self.event)
    buf.write_char('\n')
  }
  if self.retry > 0 {
    buf.write_string("retry: ")
    buf.write_string(self.retry.to_string())
    buf.write_char('\n')
  }
  // Data can be multiline, each line prefixed with "data: "
  let lines = split_lines(self.data)
  for line in lines {
    buf.write_string("data: ")
    buf.write_string(line)
    buf.write_char('\n')
  }
  buf.write_char('\n')
  buf.to_string()
}

///|
/// Split string by newlines
fn split_lines(s : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == '\n' {
      result.push(current.to_string())
      current.reset()
    } else if c != '\r' {
      current.write_char(c)
    }
  }
  result.push(current.to_string())
  result
}

///|
/// SSE Stream writer
/// Allows sending events to a connected client
pub(all) struct SseStream {
  priv ctx : @flame.Context
  priv mut closed : Bool
}

///|
/// Create a new SSE stream
pub fn SseStream::new(ctx : @flame.Context) -> SseStream {
  { ctx, closed: false }
}

///|
/// Check if stream is closed
pub fn SseStream::is_closed(self : SseStream) -> Bool {
  self.closed
}

///|
/// Close the stream
pub fn SseStream::close(self : SseStream) -> Unit {
  self.closed = true
}

///|
/// Send an SSE event
pub async fn SseStream::send(self : SseStream, event : SseEvent) -> Unit {
  if self.closed {
    return
  }
  let formatted = event.format()
  // Write to the underlying connection
  // Note: This assumes the response has been started with sse_start
  self.ctx.write_raw(formatted)
}

///|
/// Send a simple data event
pub async fn SseStream::send_data(self : SseStream, data : String) -> Unit {
  self.send(SseEvent::data(data))
}

///|
/// Send a typed event with data
pub async fn SseStream::send_event(
  self : SseStream,
  event : String,
  data : String,
) -> Unit {
  self.send(SseEvent::new(event, data))
}

///|
/// Send a JSON event
pub async fn SseStream::send_json(
  self : SseStream,
  event : String,
  data : Json,
) -> Unit {
  self.send(SseEvent::new(event, data.stringify()))
}

///|
/// Send a comment (for keep-alive)
pub async fn SseStream::send_comment(
  self : SseStream,
  comment : String,
) -> Unit {
  if self.closed {
    return
  }
  let buf = StringBuilder::new()
  buf.write_string(": ")
  buf.write_string(comment)
  buf.write_char('\n')
  buf.write_char('\n')
  self.ctx.write_raw(buf.to_string())
}

///|
/// Send a keep-alive ping
pub async fn SseStream::ping(self : SseStream) -> Unit {
  self.send_comment("ping")
}

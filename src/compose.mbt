///|
/// Compose multiple handlers into a chain
/// Each handler is called in order
pub fn compose(handlers : Array[Handler]) -> Handler {
  async fn(ctx : Context) raise Error {
    for handler in handlers {
      if ctx.is_response_sent() {
        break
      }
      let Handler(h) = handler
      h(ctx)
    }
  }
}

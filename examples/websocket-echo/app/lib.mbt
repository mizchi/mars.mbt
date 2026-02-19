///|
pub fn build_app() -> @mars.Server {
  let app = @mars.Server::new()
  app.get(
    "/",
    @mars.handler(async fn(ctx) { ctx.text("websocket echo example") }),
  )
  app.get(
    "/ws",
    @mars.handler(async fn(ctx) {
      ctx.text(
        "websocket endpoint is available only on native target",
        status=501,
      )
    }),
  )
  app
}

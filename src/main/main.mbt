///|
async fn main {
  let app = @flame.Flame::new()
  // Add routes
  let _ = app
    .get("/", @flame.handler(async fn(ctx) { ctx.text("Hello, Flame!") }))
    .get(
      "/users/:id",
      @flame.handler(async fn(ctx) {
        let id = ctx.param("id").unwrap_or("unknown")
        ctx.json({ "id": id, "type": "user" })
      }),
    )
    .post(
      "/users",
      @flame.handler(async fn(ctx) {
        ctx.json({ "status": "created" }, status=201)
      }),
    )
    .get(
      "/api/*",
      @flame.handler(async fn(ctx) {
        ctx.json({ "path": ctx.path(), "message": "API wildcard" })
      }),
    )
  let addr = @socket.Addr::parse("127.0.0.1:3000")
  println("Server starting at http://127.0.0.1:3000")
  app.serve(addr)
}

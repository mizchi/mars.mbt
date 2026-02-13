///|
async fn main {
  let app = @mars.Server::new()
  let _ = app
    ..get("/", @mars.handler(async fn(ctx) { ctx.text("Hello, Mars!") }))
    ..get(
      "/users/:id",
      @mars.handler(async fn(ctx) {
        let id = ctx.param("id").unwrap_or("unknown")
        ctx.json({ "id": id, "type": "user" })
      }),
    )
    ..post(
      "/users",
      @mars.handler(async fn(ctx) {
        ctx.json({ "status": "created" }, status=201)
      }),
    )
    ..get(
      "/api/*",
      @mars.handler(async fn(ctx) {
        ctx.json({ "path": ctx.path(), "message": "API wildcard" })
      }),
    )
  println("Server starting at http://127.0.0.1:3000")
  app.serve(host="127.0.0.1", port=3000) catch {
    err => println("Server failed: \{err}")
  }
}

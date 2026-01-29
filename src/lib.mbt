///|
/// Flame - A Hono-inspired HTTP framework for MoonBit
///
/// Example usage:
/// ```moonbit
/// async fn main {
///   let app = Flame::new()
///   app
///     .get("/", handler(async fn(ctx) { ctx.text("Hello, World!") }))
///     .get("/users/:id", handler(async fn(ctx) {
///       let id = ctx.param("id").unwrap_or("unknown")
///       ctx.json(Json::Object({ "id": Json::String(id) }))
///     }))
///   app.serve(@socket.Addr::parse("127.0.0.1:3000"))
/// }
/// ```

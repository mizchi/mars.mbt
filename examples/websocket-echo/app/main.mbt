///|
async fn main {
  let app = build_app()
  let handler = build_server_handler(app)
  let server = @http.Server::new(host="127.0.0.1", port=3000)
  println("Server starting at http://127.0.0.1:3000")
  println("WebSocket endpoint: ws://127.0.0.1:3000/ws")
  server.run_forever(handler) catch {
    err => println("Server failed: \{err}")
  }
}

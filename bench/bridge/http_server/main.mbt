///|
async fn main {
  let args = @sys.get_cli_args()
  let mode = args[1]
  let port = @string.parse_int(args[2])
  let duration_ms = @string.parse_int(args[3])
  let _ = @async.with_timeout_opt(duration_ms, async fn() {
    match mode {
      "mars" => {
        let app = @mars.Server::new()
        app.get("/api/users/:id", async fn(ctx) {
          ctx.text(ctx.param("id").unwrap())
        })
        app.serve(host="127.0.0.1", port~)
      }
      "x" => {
        let server = @xhttp.Server::new(host="127.0.0.1", port~)
        server.run_forever(async fn(_request, _body, conn) {
          conn.send_response(200, "OK", extra_headers={
            "Content-Type": "text/plain; charset=utf-8",
          })
          conn.write(b"123")
          conn.end_response()
        })
      }
      "async" => {
        let server = @http.Server(@socket.Addr::parse("127.0.0.1:\{port}"))
        server.run_forever(async fn(_request, _body, conn) {
          conn.send_response(200, "OK", extra_headers={
            "Content-Type": "text/plain; charset=utf-8",
          })
          conn.write(b"123")
          conn.end_response()
        })
      }
      _ => abort("expected mars, x, or async")
    }
  }) catch {
    // x 0.6.1 translates the timeout's cancellation into an HTTP error.
    // Only ignore that exact shutdown signal in this finite profiling harness.
    @xhttp.HttpError::NetworkError("Cancelled") => None
    err => raise err
  }
}

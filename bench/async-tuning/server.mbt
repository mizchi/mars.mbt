///|
async fn main {
  let args = @sys.get_cli_args()
  let port = @string.parse_int(args[1])
  let duration = @string.parse_int(args[2])
  let size = @string.parse_int(args[3])
  let fixed = args[4] == "fixed"
  let header_count = @string.parse_int(args[5])
  let body = "x".repeat(size)
  let length = size.to_string()
  let _ = @async.with_timeout_opt(duration, async fn() {
    let app = @mars.Server::new()
    app.get("/bench", async fn(ctx) {
      if header_count > 0 {
        assert_eq(ctx.header("x-63"), Some("x".repeat(40)))
      }
      if fixed {
        ctx.set_header("Content-Length", length)
      }
      ctx.text(body)
    })
    app.serve(host="127.0.0.1", port~)
  }) catch {
    @xhttp.HttpError::NetworkError("Cancelled") => None
    err => raise err
  }
}

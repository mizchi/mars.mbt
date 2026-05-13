///|
async test "jwks_fetch_node reads response body" {
  @async.with_task_group(group => {
    let server = @http.Server::new(host="127.0.0.1", port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        let headers : Map[String, String] = {
          "Content-Type": "application/json",
        }
        conn.send_response(200, "OK", extra_headers=headers)
        conn.write("{\"keys\":[]}")
        conn.end_response()
      })
    })
    @async.sleep(20)
    inspect(
      jwks_fetch_node("http://127.0.0.1:\{port}/.well-known/jwks.json"),
      content="{\"keys\":[]}",
    )
  })
}

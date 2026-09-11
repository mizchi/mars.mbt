///|
async test "ws echo endpoint" {
  @async.with_task_group(group => {
    let app = build_app()
    let handler = build_server_handler(app)
    let server = @http.Server::new(host="127.0.0.1", port=0)
    defer server.close()
    let port = server.port()

    group.spawn_bg(no_wait=true, () => {
      server.run_forever(handler) catch {
        _ => ()
      }
    })

    let ws = @websocket.Conn::connect("ws://127.0.0.1:\{port}/ws")
    defer ws.close()

    ws.send_text("hello")
    guard ws.recv() is @websocket.Text(text) else { fail("expected text echo") }
    assert_eq(text, "hello")
    ws.send_binary(b"binary\x00message")
    guard ws.recv() is @websocket.Binary(bytes) else {
      fail("expected binary echo")
    }
    assert_eq(bytes, b"binary\x00message")
    ws.send_close()
  })
}

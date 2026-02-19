///|
async test "ws echo endpoint" {
  @async.with_task_group(group => {
    let app = build_app()
    let handler = build_server_handler(app)
    let server = @http.Server::new(host="127.0.0.1", port=0)
    let port = server.port()

    group.spawn_bg(no_wait=true, () => {
      server.run_forever(handler) catch {
        _ => ()
      }
    })

    @async.sleep(50)
    let ws = @websocket.connect("ws://127.0.0.1:\{port}/ws")
    defer ws.close()

    ws.send_text("hello")
    let msg = ws.recv()
    inspect(msg.kind, content="Text")
    inspect(msg.read_all().text(), content="hello")
    ws.send_close()
    server.close()
  })
}

///|
fn is_websocket_upgrade(request : @http.Request) -> Bool {
  match request.headers.get("upgrade") {
    Some(value) => value.to_lower() == "websocket"
    None => false
  }
}

///|
async fn handle_websocket_echo(
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  let ws = @websocket.from_http_server(request, conn)
  defer ws.close()
  for ;; {
    let msg = ws.recv() catch {
      @websocket.WebSocketError::ConnectionClosed(_, _) => break
      err => raise err
    }
    match msg {
      @websocket.Text(text) => ws.send_text(text)
      @websocket.Binary(bytes) => ws.send_binary(bytes[:])
    }
  }
}

///|
pub fn build_server_handler(app : @mars.Server) -> @mars.AppHandler {
  let mars_handler = app.to_handler()
  async fn(request, body_reader, conn) {
    if request.path == "/ws" && is_websocket_upgrade(request) {
      handle_websocket_echo(request, conn)
    } else {
      mars_handler(request, body_reader, conn)
    }
  }
}

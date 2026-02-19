///|
fn to_async_request_method(
  meth : @http.RequestMethod,
) -> @async_http.RequestMethod {
  match meth {
    @http.RequestMethod::Get => @async_http.RequestMethod::Get
    @http.RequestMethod::Post => @async_http.RequestMethod::Post
    @http.RequestMethod::Put => @async_http.RequestMethod::Put
    @http.RequestMethod::Delete => @async_http.RequestMethod::Delete
    @http.RequestMethod::Patch => @async_http.RequestMethod::Patch
    @http.RequestMethod::Head => @async_http.RequestMethod::Head
    @http.RequestMethod::Options => @async_http.RequestMethod::Options
    @http.RequestMethod::Connect => @async_http.RequestMethod::Connect
    @http.RequestMethod::Trace => @async_http.RequestMethod::Trace
  }
}

///|
fn to_async_request(request : @http.Request) -> @async_http.Request {
  {
    meth: to_async_request_method(request.meth),
    path: request.path,
    headers: request.headers,
  }
}

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
  // `mars` uses mizchi/x HTTP types; async websocket expects async HTTP types.
  let ws = @websocket.from_http_server(to_async_request(request), conn.inner)
  defer ws.close()
  for {
    let msg = ws.recv() catch {
      @websocket.ConnectionClosed(_) => break
      err => raise err
    }
    ws..start_message(msg.kind)..write_reader(msg).end_message()
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

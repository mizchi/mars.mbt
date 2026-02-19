///|
pub fn build_server_handler(app : @mars.Server) -> @mars.AppHandler {
  app.to_handler()
}

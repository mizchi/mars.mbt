///|
fn main {
  println("Run this example with --target native for WebSocket echo server.")
  ignore(@async.now())
  ignore(build_app())
}

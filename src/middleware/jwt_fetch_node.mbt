///|
/// JWKS fetcher for Node.js (js target)
pub async fn jwks_fetch_node(url : String) -> String {
  @jwt.fetch_http_async(url) catch {
    err => fail(err.to_string())
  }
}

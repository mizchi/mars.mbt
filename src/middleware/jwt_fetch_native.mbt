///|
/// JWKS fetcher for native
pub async fn jwks_fetch_native(url : String) -> String {
  @jwt.fetch_http_async(url) catch {
    err => fail(err.to_string())
  }
}

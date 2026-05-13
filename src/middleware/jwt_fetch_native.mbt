///|
/// JWKS fetcher for native
pub async fn jwks_fetch_native(url : String) -> String {
  let (resp, body) = @http.get(url, headers={ "Accept": "application/json" }) catch {
    err => fail("JWKS fetch failed: \{err}")
  }
  if resp.code < 200 || resp.code >= 300 {
    fail("JWKS fetch failed: HTTP \{resp.code}")
  }
  body.text() catch {
    _ => fail("JWKS fetch failed: invalid UTF-8 response")
  }
}

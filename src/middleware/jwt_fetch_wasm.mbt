///|
/// JWKS fetcher for wasm (requires host-provided fetch)
async fn suspend_fetch(
  f : ((String) -> Unit, (String) -> Unit) -> Unit,
) -> String raise String = "%async.suspend"

///|
extern "js" fn ffi_fetch_text_async(
  url : String,
  ok : (String) -> Unit,
  err : (String) -> Unit,
) -> Unit =
  #| (url, ok, err) => {
  #|   fetch(url)
  #|     .then((res) => {
  #|       if (!res.ok) throw new Error(`HTTP ${res.status}`)
  #|       return res.text()
  #|     })
  #|     .then((text) => ok(text))
  #|     .catch((e) => err(e && e.message ? e.message : String(e)))
  #| }

///|
pub async fn jwks_fetch_wasm(url : String) -> String {
  suspend_fetch(fn(ok, err) { ffi_fetch_text_async(url, ok, err) }) catch {
    msg => fail(msg)
  }
}

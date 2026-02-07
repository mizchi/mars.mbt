///|
/// Re-export cabi_realloc for wasm linking
pub fn cabi_realloc(
  old_ptr : Int,
  old_size : Int,
  align : Int,
  new_size : Int,
) -> Int {
  @cabi.cabi_realloc(old_ptr, old_size, align, new_size)
}

///|
pub fn wasmExportRun() -> Int {
  let result = run()
  match result {
    Ok(_) => 0
    Err(_) => 1
  }
}

///|
fn main {
  ()
}

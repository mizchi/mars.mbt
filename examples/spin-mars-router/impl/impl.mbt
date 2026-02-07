///|
fn ffi_get_arguments(retptr : Int) -> Int = "wasi:cli/environment@0.2.9" "get-arguments"

///|
fn ffi_get_environment(retptr : Int) -> Int = "wasi:cli/environment@0.2.9" "get-environment"

///|
fn ffi_get_stdout() -> Int = "wasi:cli/stdout@0.2.9" "get-stdout"

///|
fn ffi_output_stream_blocking_write_and_flush(
  stream : Int,
  bytes_ptr : Int,
  bytes_len : Int,
  retptr : Int,
) -> Int = "wasi:io/streams@0.2.9" "[method]output-stream.blocking-write-and-flush"

///|
extern "wasm" fn ffi_mem_store32(ptr : Int, val : Int) -> Unit =
  #|(func (param i32 i32) (result i32) (i32.store (local.get 0) (local.get 1)) (i32.const 0))

///|
extern "wasm" fn ffi_memory_size_pages() -> Int =
  #|(func (result i32) (memory.size))

///|
fn is_valid_memory_range(ptr : Int, len : Int, mem_bytes : Int) -> Bool {
  if ptr < 0 || len < 0 || ptr > mem_bytes {
    false
  } else {
    len <= mem_bytes - ptr
  }
}

///|
fn decode_environment_as_lines_by_string_list(
  result_ptr : Int,
  result_len : Int,
  mem_bytes : Int,
) -> Array[String] {
  let lines : Array[String] = []
  if result_len <= 0 || not(is_valid_memory_range(result_ptr, 0, mem_bytes)) {
    return lines
  }
  let max_entries = (mem_bytes - result_ptr) / 8
  let safe_len = if result_len < max_entries { result_len } else { max_entries }
  for i = 0; i < safe_len; i = i + 1 {
    let elem_ptr = result_ptr + i * 8
    if is_valid_memory_range(elem_ptr, 8, mem_bytes) {
      let ptr = @cabi.cabi_read_i32(elem_ptr)
      let len = @cabi.cabi_read_i32(elem_ptr + 4)
      if is_valid_memory_range(ptr, len, mem_bytes) {
        lines.push(@cabi.cabi_lift_string(ptr, len))
      }
    }
  }
  lines
}

///|
fn decode_environment_as_lines_by_tuple_list(
  result_ptr : Int,
  result_len : Int,
  mem_bytes : Int,
) -> Array[String] {
  let lines : Array[String] = []
  if result_len <= 0 || not(is_valid_memory_range(result_ptr, 0, mem_bytes)) {
    return lines
  }
  let max_entries = (mem_bytes - result_ptr) / 16
  let safe_len = if result_len < max_entries { result_len } else { max_entries }
  for i = 0; i < safe_len; i = i + 1 {
    let elem_ptr = result_ptr + i * 16
    if is_valid_memory_range(elem_ptr, 16, mem_bytes) {
      let k_ptr = @cabi.cabi_read_i32(elem_ptr)
      let k_len = @cabi.cabi_read_i32(elem_ptr + 4)
      let v_ptr = @cabi.cabi_read_i32(elem_ptr + 8)
      let v_len = @cabi.cabi_read_i32(elem_ptr + 12)
      if is_valid_memory_range(k_ptr, k_len, mem_bytes) &&
        is_valid_memory_range(v_ptr, v_len, mem_bytes) {
        let key = @cabi.cabi_lift_string(k_ptr, k_len)
        let value = @cabi.cabi_lift_string(v_ptr, v_len)
        lines.push(key + "=" + value)
      }
    }
  }
  lines
}

///|
fn has_wagi_env_lines(lines : Array[String]) -> Bool {
  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    if line.has_prefix("REQUEST_METHOD=") || line.has_prefix("PATH_INFO=") {
      return true
    }
  }
  false
}

///|
fn read_environment_lines() -> Array[String] {
  let retptr = @cabi.cabi_realloc(0, 0, 4, 8)
  ffi_mem_store32(retptr, 0)
  ffi_mem_store32(retptr + 4, 0)
  let _ = ffi_get_environment(retptr)
  let result_ptr = @cabi.cabi_read_i32(retptr)
  let result_len = @cabi.cabi_read_i32(retptr + 4)
  let mem_bytes = ffi_memory_size_pages() * 65536
  let as_string_list = decode_environment_as_lines_by_string_list(
    result_ptr, result_len, mem_bytes,
  )
  if has_wagi_env_lines(as_string_list) {
    return as_string_list
  }
  let as_tuple_list = decode_environment_as_lines_by_tuple_list(
    result_ptr, result_len, mem_bytes,
  )
  if as_tuple_list.length() > 0 {
    as_tuple_list
  } else {
    as_string_list
  }
}

///|
fn find_method_from_environment_lines(lines : Array[String]) -> String? {
  for i = 0; i < lines.length(); i = i + 1 {
    match lines[i].chop_prefix("REQUEST_METHOD=") {
      Some(v) => return Some(v.to_string())
      None => ()
    }
  }
  None
}

///|
fn method_from_environment_lines(lines : Array[String]) -> String {
  match find_method_from_environment_lines(lines) {
    Some(meth) => if meth == "" { "GET" } else { meth }
    None => "GET"
  }
}

///|
fn read_arguments() -> Array[String] {
  let retptr = @cabi.cabi_realloc(0, 0, 4, 8)
  let _ = ffi_get_arguments(retptr)
  let result_ptr = @cabi.cabi_read_i32(retptr)
  let result_len = @cabi.cabi_read_i32(retptr + 4)
  let arr = Array::new(capacity=result_len)
  for i = 0; i < result_len; i = i + 1 {
    let elem_ptr = result_ptr + i * 8
    let ptr = @cabi.cabi_read_i32(elem_ptr)
    let len = @cabi.cabi_read_i32(elem_ptr + 4)
    arr.push(@cabi.cabi_lift_string(ptr, len))
  }
  arr
}

///|
fn path_from_arguments(args : Array[String]) -> String {
  for i = 0; i < args.length(); i = i + 1 {
    let arg = args[i]
    if arg.has_prefix("/") {
      if arg == "" {
        return "/"
      } else {
        return arg
      }
    }
  }
  "/"
}

///|
fn should_use_environment_method(args : Array[String]) -> Bool {
  for i = 0; i < args.length(); i = i + 1 {
    if args[i] == "--use-env-method" {
      return true
    }
  }
  false
}

///|
/// Write WAGI-compatible HTTP response bytes to stdout.
fn write_stdout(content : String) -> Bool {
  let stream = ffi_get_stdout()
  let (bytes_ptr, bytes_len) = @cabi.cabi_lower_string(content)
  let retptr = @cabi.cabi_realloc(0, 0, 4, 12)
  let _ = ffi_output_stream_blocking_write_and_flush(
    stream, bytes_ptr, bytes_len, retptr,
  )
  @cabi.cabi_read_i32(retptr) == 0
}

///|
fn render_wagi_response(status : Int, body : String) -> String {
  "Content-Type: text/plain\nStatus: " +
  status.to_string() +
  "\n\n" +
  body +
  "\n"
}

///|
pub fn run() -> Result[Unit, Unit] {
  let args = read_arguments()
  let path = path_from_arguments(args)
  let http_method = if should_use_environment_method(args) {
    let env_lines = read_environment_lines()
    method_from_environment_lines(env_lines)
  } else {
    "GET"
  }
  let routed = @app.route(http_method, path)
  let response = render_wagi_response(routed.status, routed.body)
  let _ = write_stdout(response)
  Ok(())
}

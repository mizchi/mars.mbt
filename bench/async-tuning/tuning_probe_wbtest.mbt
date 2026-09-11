///|
extern "C" fn tuning_begin(scenario : Int, iterations : Int) -> Unit = "mars_probe_begin"

///|
extern "C" fn tuning_end() -> Unit = "mars_probe_end"

///|
extern "C" fn tuning_checkpoint() -> Unit = "mars_probe_checkpoint"

///|
extern "C" fn tuning_now() -> Int64 = "mars_tuning_now"

///|
#borrow(data)
extern "C" fn tuning_consume(data : Bytes) -> Int = "mars_probe_consume"

///|
test "allocator calibration" {
  tuning_begin(-1, 1)
  let data = Bytes::make(257, b'x')
  let first = tuning_consume(data)
  tuning_end()
  assert_eq(first, 120)
}

///|
priv struct TuningWriter {
  mut bytes : Int64
  mut calls : Int
}

///|
impl @io.Writer for TuningWriter with fn write_once(self, _data, offset~, len~) {
  ignore(offset)
  self.bytes += len.to_int64()
  self.calls += 1
  tuning_checkpoint()
  len
}

///|
async test "body sizes and framing" {
  for index, size in [3, 1024, 65536, 1048576] {
    for fixed in [false, true] {
      let scenario = index * 2 + (if fixed { 1 } else { 0 })
      let iterations = if size >= 1048576 {
        100
      } else if size >= 65536 {
        1000
      } else {
        20000
      }
      let body = Bytes::make(size, b'x')
      let headers : Headers = if fixed {
        { "Content-Length": size.to_string() }
      } else {
        Map([])
      }
      let writer = TuningWriter::{ bytes: 0L, calls: 0, }
      let sender = Sender::new(writer)
      sender.send_response(
        200,
        "OK",
        extra_headers=headers,
        cookies=[],
        request_method=Get,
      )
      sender.write(body)
      sender.end_body()
      let wire_bytes = writer.bytes
      let wire_calls = writer.calls
      writer.bytes = 0L
      writer.calls = 0
      tuning_begin(scenario, iterations)
      let started = tuning_now()
      for _ in 0..<iterations {
        sender.send_response(
          200,
          "OK",
          extra_headers=headers,
          cookies=[],
          request_method=Get,
        )
        sender.write(body)
        sender.end_body()
      }
      let elapsed = tuning_now() - started
      tuning_end()
      assert_eq(writer.bytes, wire_bytes * iterations.to_int64())
      assert_eq(writer.calls, wire_calls * iterations)
      println(
        "TUNING \{scenario} \{iterations} \{elapsed} \{wire_calls} \{wire_bytes}",
      )
    }
  }
}

///|
priv struct TuningReader {
  data : Bytes
  mut pos : Int
  max_read : Int
  buffer : @io.ReaderBuffer
}

///|
impl @io.Reader for TuningReader with fn _get_internal_buffer(self) {
  self.buffer
}

///|
impl @io.Reader for TuningReader with fn _direct_read(
  self,
  dst,
  offset~,
  max_len~,
) {
  let n = @cmp.minimum(
    @cmp.minimum(max_len, self.max_read),
    self.data.length() - self.pos,
  )
  dst.blit_from_bytes(offset, self.data, self.pos, n)
  self.pos += n
  n
}

///|
async test "request headers cold connection" {
  for
    index, (count, size, max_read) in [
      (0, 0, 1048576),
      (16, 40, 1048576),
      (64, 40, 1048576),
      (16, 40, 7),
      (1, 65536, 1048576),
      (1, 1048576, 1048576),
    ] {
    let scenario = 10 + index
    let iterations = if size >= 1048576 {
      3
    } else if size >= 65536 {
      100
    } else if count == 64 {
      5000
    } else {
      10000
    }
    let b = Buffer()
    b.write_bytes(b"GET /bench HTTP/1.1\r\n")
    for i in 0..<count {
      b.write_bytes(@utf8.encode("X-\{i}: " + "x".repeat(size) + "\r\n"))
    }
    b.write_bytes(b"\r\n")
    let data = b.contents()
    let mut retained_capacity = 0
    tuning_begin(scenario, iterations)
    let started = tuning_now()
    for _ in 0..<iterations {
      let transport = TuningReader::{
        data,
        pos: 0,
        max_read,
        buffer: @io.ReaderBuffer::new(),
      }
      let reader = Reader::new(transport)
      let request = reader.read_request()
      assert_eq(request.path, "/bench")
      assert_eq(request.headers.length(), count)
      if count > 0 {
        assert_eq(request.headers.get("X-0").unwrap().length(), size)
      }
      retained_capacity = transport.buffer.get_repr().buf.length()
      tuning_checkpoint()
    }
    let elapsed = tuning_now() - started
    tuning_end()
    println(
      "TUNING \{scenario} \{iterations} \{elapsed} \{retained_capacity} \{data.length()}",
    )
  }
}

///|
async test "post IO yield" {
  let iterations = 100000
  tuning_begin(20, iterations)
  let started = tuning_now()
  for _ in 0..<iterations {
    // The runner substitutes the expression used by this variant's Unix IO.
    @coroutine.protect_from_cancel(() => @coroutine.pause())
  }
  let elapsed = tuning_now() - started
  tuning_end()
  println("TUNING 20 \{iterations} \{elapsed} 0 0")
}

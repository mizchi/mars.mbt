///|
extern "C" fn probe_begin(scenario : Int, iterations : Int) -> Unit = "mars_probe_begin"

///|
extern "C" fn probe_end() -> Unit = "mars_probe_end"

///|
extern "C" fn probe_checkpoint() -> Unit = "mars_probe_checkpoint"

///|
extern "C" fn probe_blocked() -> Unit = "mars_probe_blocked"

///|
#borrow(data)
extern "C" fn probe_consume(data : Bytes) -> Int = "mars_probe_consume"

///|
test "allocator probe calibration" {
  probe_begin(-1, 1)
  let data = Bytes::make(257, b'x')
  let first = probe_consume(data)
  probe_end()
  assert_eq(first, 120)
}

///|
priv struct MemoryProbeWriter {
  mut bytes : Int
}

///|
impl @io.Writer for MemoryProbeWriter with fn write_once(
  self,
  _data,
  offset~,
  len~,
) {
  ignore(offset)
  probe_checkpoint()
  self.bytes += len
  len
}

///|
async test "response head memory probe" {
  let cases = [
    (0, 0),
    (1, 40),
    (1, 128),
    (1, 4096),
    (1, 65536),
    (64, 64),
    (1, 1048576),
  ]
  for scenario, (header_count, value_size) in cases {
    let iterations = if value_size >= 1048576 { 3 } else { 100 }
    let headers : Headers = Map([])
    let value = "x".repeat(value_size)
    for i in 0..<header_count {
      headers[CaseInsensitiveString("X-Probe-\{i}")] = value
    }
    let writer = MemoryProbeWriter::{ bytes: 0, }
    let sender = Sender::new(writer)
    // Warm up the same reusable connection before enabling accounting.
    sender.send_response(
      200,
      "OK",
      extra_headers=headers,
      cookies=[],
      request_method=Get,
    )
    sender.end_body()
    let expected_bytes = writer.bytes
    writer.bytes = 0
    probe_begin(scenario, iterations)
    for _ in 0..<iterations {
      sender.send_response(
        200,
        "OK",
        extra_headers=headers,
        cookies=[],
        request_method=Get,
      )
      sender.end_body()
    }
    probe_end()
    assert_eq(writer.bytes, expected_bytes * iterations)
    println("BUFFER_WIRE \{scenario} \{expected_bytes}")
  }
}

///|
priv struct BlockedMemoryProbeWriter {
  ready : @async.Semaphore
  resume : @async.Semaphore
  mut did_block : Bool
  mut bytes : Int
}

///|
impl @io.Writer for BlockedMemoryProbeWriter with fn write_once(
  self,
  _data,
  offset~,
  len~,
) {
  ignore(offset)
  if !self.did_block {
    self.did_block = true
    self.ready.release()
    self.resume.acquire()
  }
  probe_checkpoint()
  self.bytes += len
  len
}

///|
async test "response head blocked memory probe" {
  let connections = 64
  for scenario, (header_count, value_size) in [(1, 40), (64, 64), (1, 65536)] {
    let headers : Headers = Map([])
    let value = "x".repeat(value_size)
    for i in 0..<header_count {
      headers[CaseInsensitiveString("X-Probe-\{i}")] = value
    }
    let ready = @async.Semaphore(connections, initial_value=0)
    let resume = @async.Semaphore(connections, initial_value=0)
    let writers = Array::makei(connections, _ => BlockedMemoryProbeWriter::{
      ready,
      resume,
      did_block: false,
      bytes: 0,
    })
    let senders = writers.map(writer => Sender::new(writer))
    probe_begin(100 + scenario, connections)
    @async.with_task_group() <| group => {
      for sender in senders {
        group.spawn_bg() <| () => {
          sender.send_response(
            200,
            "OK",
            extra_headers=headers,
            cookies=[],
            request_method=Get,
          )
          sender.end_body()
        }
      }
      for _ in 0..<connections {
        ready.acquire()
      }
      // Every sender is suspended inside its first underlying write.
      probe_blocked()
      for _ in 0..<connections {
        resume.release()
      }
    }
    let wire_bytes = writers[0].bytes
    for writer in writers {
      assert_eq(writer.bytes, wire_bytes)
    }
    probe_end()
    println("BUFFER_WIRE \{100 + scenario} \{wire_bytes}")
  }
}

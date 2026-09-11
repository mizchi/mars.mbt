# Four independent async tuning experiments for Mars

For the standalone parser proposal against upstream main and separate 4a/4b
measurements, see the [follow-up report](async-header-followup.md).

These experiments continue the measurements I collected while benchmarking
Mars, my web server implementation. Each patch applies independently to async
commit `fcc109cc2cb82cbd122974b4e4718b3670ee04b6`, the bounded response-head
implementation in [PR #603](https://github.com/moonbitlang/async/pull/603).
The four patches are not stacked, and these results do not measure combining them.
The existing response-head PR is unchanged.

## Implementations and boundaries

1. [Large body bypass](../bench/patches/async-tuning-body.patch): writes of at
   least 4 KiB bypass the 1 KiB sender staging buffer. Fixed-length output flushes
   pending headers before passing the body to the transport. Chunked output
   writes a chunk prefix, the body, and the trailing CRLF without copying the
   whole body through the staging buffer. Partial writes, offsets, remaining
   content length, and subsequent responses are covered by tests. This changes
   chunk boundaries, but preserves the decoded body and framing. `write_reader`
   is unchanged. An initial 1 KiB threshold increased a 1 KiB chunked response
   from two transport writes to three; the final threshold retains coalescing
   for that case, with a regression test.
2. [Buffered header parser](../bench/patches/async-tuning-parser.patch): complete
   lines already present in the transport read buffer use a synchronous parser.
   ASCII headers decode only the field name and value, avoiding the temporary
   whole-line String. Non-ASCII and fragmented lines retain the existing path.
   A new internal `ReaderBuffer::take_buffered_until` API returns a view that
   must be consumed before the next read mutates the buffer. Tests cover
   one-byte fragments, duplicate names, Unicode, invalid UTF-8, duplicate framing
   headers, and pipelined requests. This does not change request-line parsing.
3. [Post-I/O yield](../bench/patches/async-tuning-scheduler.patch): a dedicated
   `pause_after_io` avoids the generic cancellation-protection wrapper after a
   successful Unix read/write. It still yields after every successful operation.
   Tests check round-robin order, cancellation pending before the operation,
   cancellation during suspension, and restoration of an enclosing cancellation
   shield. There is no yield budget or change to how often peers can run.
4. [Read-buffer growth and header insertion](../bench/patches/async-tuning-buffer.patch):
   read buffers double up to 16 KiB, then grow in 16 KiB steps instead of 1 KiB
   steps. Header insertion uses `Map::update_or_default` for a single lookup.
   Tests cover copy volume, compaction, retained capacity, duplicate headers,
   and malformed framing. Large buffers retain up to roughly 16 KiB of spare
   capacity. Growth for arbitrarily large inputs remains quadratic; this is a
   bounded-spare-capacity compromise, not an asymptotic fix or a header-size limit.

## Measurement method

All measurements use native release builds on the same developer machine.
[Microbenchmark results](../bench/results/async-tuning.json) contain five timing
rounds and three allocation rounds per variant, reversing variant order on
alternate rounds. Timing binaries do not intercept allocations. Separate
instrumented binaries count allocation requests, preserving the runtime's
allocator and reference-count initialization. Each allocation run verifies
that a 257-byte `Bytes` allocation requests exactly 266 bytes including its
header and terminator, and is freed. The three allocation runs must match.
These are requested bytes, not allocator-rounded memory or RSS.

Body microbenchmarks reuse a Sender and precreated body bytes. Their counting
Writer immediately accepts every write. Writer-call counts are not syscall
counts; the microbenchmark excludes the network and UTF-8 body encoding.
Header microbenchmarks use precreated request bytes with a fresh Reader each
time, so large-line growth is measured on a cold connection. They include
parsing and result checks. A keep-alive connection can amortize buffer growth
while retaining the resulting capacity. Scenario 20 runs the Unix post-I/O
yield expression without a syscall; its elapsed time includes the event loop.

[Small-response network results](../bench/results/async-tuning-network.json) and
[bulk network results](../bench/results/async-tuning-network-bulk.json), and
[header network results](../bench/results/async-tuning-network-headers.json) use Mars
commit `66277d49502626d8c2f477d63d7eb285d1ba5157` and registry `mizchi/x@0.6.1`.
A real Mars route calls `Context::text`, including its body encoding and the
normal x/async adapter. Each case runs three rounds of a 1-second warmup and
3-second load, reversing variant order on alternate rounds. The load generator
uses four wrk threads and 64 connections for small/header cases. Bulk cases use
16 connections from a Node HTTP load generator that drains every response before
closing connections, for the reason described below. Bulk response byte counts
are checked throughout the load. Its RPS is affected by the Node client and is
not directly comparable to the wrk cases.
CPU and instruction counters come from `/usr/bin/time -lp` for the server only,
normalized by completed requests including warmup and readiness. Outstanding
requests at wrk shutdown are not included; the bulk generator counts all drained
responses. Raw load-generator output, CPU counters, binary
hashes, patch hashes, and build provenance are embedded in the JSON.

Readiness requests validate complete response bytes, Content-Type, and framing.
wrk checks HTTP and socket errors during load; it does not validate every body.
Short runs on a shared developer machine have noise and do not establish
production throughput. The 64 KiB/1 MiB header cases are stress cases, not an
estimate of their prevalence in actual traffic.

## Results

The numbers below are medians; allocation values are rounded requested bytes per
operation. The elapsed times refer to the microbenchmarks, not network latency.

| Experiment and input | Baseline → experiment | Interpretation |
| --- | --- | --- |
| 1: 64 KiB chunked body | 11.73 → 0.629 µs; 65 → 3 Writer calls; 36,131 → 3,117 allocated bytes | Large bodies benefit substantially. |
| 1: 1 MiB fixed body | 173.03 → 0.690 µs; 1,025 → 2 Writer calls; 543,626 → 3,034 allocated bytes | Most staging-buffer iterations disappear. |
| 1: 1 KiB chunked body | 0.724 → 0.946 µs; 3,118 → 3,230 allocated bytes | Still regresses despite preserving two Writer calls. Extra allocation remains in the async write path; investigate before a general-purpose PR. |
| 2: 16 headers, 40-byte values, buffered | 5.221 → 3.006 µs; 17,518 → 8,113 allocated bytes | −42% elapsed time and −54% allocation. |
| 2: 64 headers, 40-byte values, buffered | 18.448 → 11.661 µs; 62,654 → 28,130 allocated bytes | −37% elapsed time and −55% allocation. |
| 2: 16 headers received in 7-byte fragments | 13.100 → 13.917 µs; 67,942 → 68,657 allocated bytes | Fast-path misses cost time and about 1% extra allocation. |
| 3: post-I/O yield | 11.839 → 11.772 µs; 404 → 296 allocated bytes | Time is nearly unchanged in this event-loop microbenchmark; allocation falls 27%. |
| 4: one 64 KiB header value | 111.12 → 55.79 µs; 2,623,157 → 661,321 allocated bytes | Growth copies decrease, with additional retained capacity. |
| 4: one 1 MiB header value | 14.523 → 1.790 ms; 545,223,854 → 41,485,918 allocated bytes | −88% elapsed time and −92% cumulative allocation in a stress case. |

For a 3-byte Mars response, experiment 2 reduces server instructions/request by
6.3% (87,251 → 81,790), and experiment 3 by 2.2% (87,251 → 85,307).
Experiment 1 changes instructions by +0.5%; experiment 4 by −0.6%. The small-case
RPS changes are much larger than some instruction changes, so they are not used
to claim corresponding server improvements.

With 64 additional request headers, experiment 2 reduces server instructions
from 580,724 to 406,425 per request (−30.0%) and server CPU time from 33.06 to
24.45 µs/request (−26.1%). Experiment 4 changes instructions by only −0.2% for
this case. All short lines fit in the existing read buffer, so that case mainly
exercises its Map change, whose benefit is not established by these measurements.

With real bulk responses, experiment 1 reduces instructions/request from
4,345,173 to 3,142,169 (−27.7%) for 64 KiB chunked output, and from 67,504,928 to
48,330,997 (−28.4%) for 1 MiB fixed output. Server CPU time/request falls from
309.4 to 143.4 µs and from 4,578.0 to 2,115.8 µs respectively. Mars's body encoding
and adapter work remain in these measurements; the microbenchmark's roughly
95–100% reductions in staging-path time are not whole-server speedups.

Experiment 4 retains 81,920 bytes after the 64 KiB header instead of 66,560, and
1,064,960 after the 1 MiB header instead of 1,049,600: an extra 15,360 bytes per
such connection. Whole-parse peak live allocations also rise by 15,360 bytes
(460,463 → 475,823 for the 64 KiB value). The Map change alone adds 12 allocated
bytes per header in this build: 64 short headers go from 62,654 to 63,422 bytes.
Buffer growth and Map insertion deserve separate upstream evaluation.

The strongest general-purpose candidate is experiment 2, with its fragmented
input overhead documented. Experiment 3 has a small real-server CPU improvement
with narrowly scoped behavior and explicit cancellation tests. Experiment 1 is
valuable for bulk bodies but still needs work on small-write overhead. Experiment
4 is conditional on long-header workloads and the acceptable retained-memory
budget; it is not an unqualified memory reduction.

## Additional finding: disconnect during a partial response

The first bulk wrk run aborted the **baseline** server when wrk stopped with
responses still in flight. A separate reproduction returned `-6` (SIGABRT) in
three runs, including both settings of Python's signal inheritance. It was not
SIGPIPE. [Raw reproduction output](../bench/results/async-tuning-disconnect.json)
includes `Handler error: ... Broken pipe` immediately before the abort.

Code inspection points to Mars's fallback handling: `Context::text` sets
`response_sent` only after the body and final framing finish. A write failure is
caught by dispatch while this flag is still false, so `to_handler_with_env`
attempts a 500 response. async's `Sender::send_response` requires the previous
message to be finished and aborts on that invalid state. This is an existing Mars
correctness issue, independent of these four patches. It remains to be fixed;
the benchmark avoids triggering it by draining bulk responses before closing.

## Validation and reproduction

Each experimental worktree is separate from the existing PR worktree.
[Validation logs](../bench/results/async-tuning-tests.json) record the checks.
Relevant
HTTP, io, read-buffer, coroutine, and event-loop tests pass in native release.
The individual counts are 119 for body bypass, 118 for parsing, 119 for the
scheduler, and 119 for buffer growth/Map insertion.
Mars's native root-package tests also pass: 92/92 on the baseline and on each
of the four independent async variants.
Wasm and JS type checks pass; the parser variant has one unused UTF-8 import
warning on JS. The scheduler also passes the public async API and socket tests
on the same baseline and patched environments.

Use an async checkout containing the base commit above, macOS, MoonBit, wrk,
and Python 3.9 or later:

```sh
just profile-async-tuning /path/to/async
just profile-async-network
```

The first command exports the base commit into disposable directories, applies
each patch independently, builds all five variants, and writes the microbenchmark
JSON. The second uses those temporary async builds to compile and measure Mars.
Do not delete them between commands. No installed package or existing checkout
is modified. The scripts validate patch hashes before using the saved results.

To inspect or test one patch independently:

```sh
git -C /path/to/async worktree add --detach /tmp/async-body fcc109cc2cb82cbd122974b4e4718b3670ee04b6
git -C /tmp/async-body apply /path/to/mars.mbt/bench/patches/async-tuning-body.patch
cd /tmp/async-body
moon test src/http src/io src/internal/io_buffer src/internal/coroutine src/internal/event_loop --target native --release
moon check src/http src/io src/internal/io_buffer src/internal/coroutine src/internal/event_loop --target wasm
moon check src/http src/io --target js
```

For the scheduler patch, also run `moon test src src/socket --target native --release`.
The fixtures and runners live in [bench/async-tuning](../bench/async-tuning).
Allocation interception reuses the calibrated
[buffer-memory probe](../bench/buffer-memory).

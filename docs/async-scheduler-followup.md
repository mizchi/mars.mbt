# Standalone post-I/O yield experiment

These are measurements I collected while benchmarking Mars, my web server
implementation. This follow-up measures the post-I/O yield proposal independently
against async main at `43e41261f99261f4030efbed1970388930229baa`.
Neither the response-head batching in [PR #603](https://github.com/moonbitlang/async/pull/603)
nor the header parser in [PR #604](https://github.com/moonbitlang/async/pull/604)
is included in the baseline or the proposed variant.

The [patch](../bench/patches/async-tuning-scheduler.patch) is unchanged from
experiment 3 in the [earlier report](async-tuning-experiments.md). Its SHA-256 is
`1e11a098c711439279f47a97ac90e27b2b69e9ea82edb5e487bf749ed20b15d6`.
The standalone async commit is `16037458e6552c17eb6c87933802ca75bc939a31`.

## Implementation and contract

The Unix read/write paths currently use
`protect_from_cancel(() => pause())` after a syscall returns a nonnegative result.
That yield lets other tasks run while protecting the completed I/O result from
cancellation. A specialized internal `pause_after_io` performs the same queueing
and suspension without the generic higher-order cancellation wrapper.

The helper saves and restores the coroutine's previous cancellation shield.
Pending cancellation remains pending, and is observed at the next cancellation
point after the completed result has been returned. Every existing post-I/O yield
remains a yield; there is no yield budget or change to scheduling frequency.
The paths that wait for I/O readiness are unchanged.

Four regression tests cover round-robin execution, cancellation already pending
before the yield, cancellation during suspension, and restoration of an enclosing
cancellation shield.

## Measurement method

The [microbenchmark data](../bench/results/async-scheduler-followup.json) uses
native release builds on macOS arm64. Scenario 20 executes the post-I/O yield
expression 100,000 times without a syscall; its timing includes the event loop.
Elapsed time comes from five rounds of uninstrumented binaries, alternating
variant order. Three separate allocator-instrumented rounds give identical
allocation results. The probe validates a 257-byte `Bytes` allocation as a
266-byte allocation request, including its header and terminator, and verifies
that it is freed. Counts include runtime object headers, but exclude allocator
rounding and RSS.

The [network data](../bench/results/async-scheduler-followup-network.json) uses
Mars `66277d49502626d8c2f477d63d7eb285d1ba5157`, `mizchi/x@0.6.1`, and the same two
async variants. A real Mars route sends a three-byte chunked text response.
Each variant runs six times, with a one-second warmup and five-second load per
run, using four wrk threads and 64 connections. Variant order alternates, so each
variant runs first in three rounds. Server-only CPU and instruction counts come
from `/usr/bin/time -lp`, normalized by completed requests including warmup and
readiness. Outstanding requests at wrk shutdown are excluded. Readiness checks
validate the response bytes and HTTP framing; load runs check HTTP/socket errors.

These are short runs on a shared developer machine. They establish neither Linux
performance nor production throughput. Timing and allocation binaries are
separate, and no validation builds run concurrently with the measurements.

## Results

The values below are medians. Allocation counts are per yield and rounded; the
raw measurements retain the small fixed event-loop setup costs.

| Metric | Baseline | Specialized yield | Change |
| --- | --- | --- | --- |
| Requested allocation bytes/yield | 404 | 296 | −26.7% |
| Allocation requests/yield | 14 | 10 | Four fewer requests |
| Microbenchmark elapsed time/yield | 11.788 µs | 11.735 µs | Nearly unchanged |
| Mars instructions/request | 93,775 | 92,067 | −1.8% |
| Mars server CPU time/request | 6.871 µs | 6.690 µs | −2.6% |

All six paired network rounds reduce instructions/request, by 1.65–2.20%.
CPU time and RPS vary more across rounds, so the allocation reduction and small
instruction reduction are the main evidence for the proposal. The event-loop
microbenchmark does not establish a meaningful elapsed-time improvement.

The result supports a small internal allocation optimization while preserving
the existing yield and cancellation contract. It does not demonstrate a general
scheduler throughput improvement or measure combining this change with PR #603
or PR #604.

## Validation and reproduction

[Local validation logs](../bench/results/async-scheduler-followup-tests.json)
record the commands, compiler version, patch hash, and outputs.

On macOS, native release passes 116 HTTP/io/buffer/coroutine/event-loop tests and
119 public async/socket tests. Native debug passes 134 coroutine/event-loop/public
async/socket tests, and JS passes all five coroutine tests. Workspace checks with
`--deny-warn` pass for native, JS, Wasm, and Wasm-GC. Linux native validation uses
the upstream PR CI; the measurements above are macOS-only.

Mars's native root-package tests pass 92/92 against both standalone variants.
Mars's `just release-check` also passes, including all 331 JS tests.

From Mars, with macOS, MoonBit, wrk, Python 3.9 or later, and an async checkout
containing the base revision:

```sh
just profile-async-tuning /path/to/async \
  --base 43e41261f99261f4030efbed1970388930229baa \
  --variants baseline scheduler \
  --output bench/results/async-scheduler-followup.json
just profile-async-network \
  --micro-results bench/results/async-scheduler-followup.json \
  --cases small --runs 6 --duration 5 \
  --output bench/results/async-scheduler-followup-network.json
```

The first command exports the common base into disposable directories and applies
the patch to just the scheduler variant. Keep those directories until the network
command finishes. Raw data includes build provenance, binary hashes, allocation
samples, wrk output, and server counters. The measured patch matches the complete
standalone PR diff byte for byte after normalizing diff path prefixes.

To run the relevant native tests in the proposed async checkout:

```sh
moon test src/http src/io src/internal/io_buffer src/internal/coroutine src/internal/event_loop --target native --release
moon test src src/socket --target native --release
moon test src/internal/coroutine src/internal/event_loop src src/socket --target native
moon test src/internal/coroutine --target js
```

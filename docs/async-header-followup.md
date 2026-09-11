# Buffered header parser proposal and separate buffer/Map measurements

I collected these measurements while benchmarking Mars, my web server
implementation. All four builds in this report start from upstream async commit
`43e41261f99261f4030efbed1970388930229baa`. Each optimization is applied alone.
The response-head change in PR #603 is not part of this baseline.

| Variant | Change |
| --- | --- |
| `baseline` | Unmodified upstream commit |
| `parser-pr` | Buffered header parsing; proposed as its own PR |
| `buffer-growth` (4a) | Read-buffer growth only |
| `header-map` (4b) | Header Map insertion only, matching the production change in [PR #390](https://github.com/moonbitlang/async/pull/390) |

The earlier [four-experiment report](async-tuning-experiments.md) used a common
baseline with response-head batching and combined 4a/4b. This report evaluates
the parser directly against upstream and separates the two components of 4.

## Buffered header parser

When a complete header line is already in the input buffer, the proposed parser
consumes it synchronously. For ASCII headers it decodes the field name and value
directly, avoiding a temporary whole-line String. Non-ASCII lines retain the
whole-line decoder; incomplete lines use the existing async reader. Request-line
parsing, duplicate-header behavior, cookies, and message-body handling are
unchanged.

The internal `ReaderBuffer::take_buffered_until` helper exposes a temporary view.
The parser consumes that view synchronously before the next read can mutate the
underlying buffer. The helper is marked internal, consistent with ReaderBuffer's
existing API. The UTF-8 import is also referenced by HTTP's existing unsupported
backend stub so the JS/Wasm-GC checks pass with `--deny-warn`.

The proposal is [this independent patch](../bench/patches/async-tuning-parser-pr.patch).

| Input | Time, baseline → parser (µs) | Requested bytes/parse, baseline → parser |
| --- | --- | --- |
| 16 headers, 40-byte values | 4.455 → 2.703 | 17,518 → 8,113 |
| 64 headers, 40-byte values | 17.313 → 10.669 | 62,654 → 28,130 |
| 16 headers in 7-byte fragments | 12.368 → 12.661 | 67,942 → 68,657 |

Fragmented input adds about 1% allocation and was 2.4% slower in this microbenchmark; the benefit is concentrated in already buffered lines.

| Mars workload | Instructions/request, baseline → parser | Change | Server CPU µs/request, baseline → parser |
| --- | --- | --- | --- |
| 3-byte response, standard request headers | 94,155 → 88,700 | -5.8% | 7.34 → 6.64 |
| 64 additional headers, 40-byte values | 593,563 → 415,189 | -30.1% | 32.92 → 24.67 |

## 4a: read-buffer growth alone

[This patch](../bench/patches/async-tuning-buffer-growth.patch) changes only
`internal/io_buffer`: capacities grow geometrically up to 16 KiB, then in 16 KiB
steps. It preserves compaction and bounds spare capacity while reducing the
copies caused by repeated 1 KiB growth. No Map operation changes.

| Header value | Time, baseline → 4a (µs) | Requested bytes/parse, baseline → 4a | Retained buffer, baseline → 4a (KiB) |
| --- | --- | --- | --- |
| 64 KiB | 109.3 → 53.2 | 2,623,157 → 661,309 | 65 → 80 |
| 1 MiB | 13948.0 → 1683.0 | 545,223,854 → 41,485,906 | 1025 → 1040 |

The extra retained capacity is 15 KiB per such connection. For the 64 KiB value, peak live allocations rise from 460,463 to 475,823 bytes despite the lower cumulative allocation.

| Mars workload | Instructions/request, baseline → variant | Change |
| --- | --- | --- |
| Standard request headers | 94,155 → 93,964 | -0.20% |
| 64 additional short headers | 593,563 → 589,464 | -0.69% |

Changes stay below 1% in these short-header workloads; the clear benefit is in the cold, long-header stress cases.

Larger capacities remain attached to the connection until cleared or released.
The growth policy still has quadratic copying for arbitrarily large inputs;
it is a compromise between copying and spare capacity. The 64 KiB/1 MiB header
values are stress tests, not representative traffic proportions. Changes to the
shared reader-buffer default need workloads beyond HTTP before upstream adoption.

## 4b: header Map insertion alone

[This patch](../bench/patches/async-tuning-header-map.patch) replaces `get` followed
by assignment with `update_or_default`. Buffer allocation/growth is unchanged.
The current core Map implementation performs a single probe, but the net effect
also includes the update callback and generated code's allocation costs.

| Input | Time, baseline → 4b (µs) | Requested bytes/parse, baseline → 4b |
| --- | --- | --- |
| 16 headers, 40-byte values | 4.455 → 5.017 | 17,518 → 17,710 |
| 64 headers, 40-byte values | 17.313 → 16.558 | 62,654 → 63,422 |

The Map-only change adds 12 requested bytes per header in this compiler/runtime build. It does not reduce the large-line allocation cost. The timing changes are small and inconsistent across these inputs.

| Mars workload | Instructions/request, baseline → variant | Change |
| --- | --- | --- |
| Standard request headers | 94,155 → 93,946 | -0.22% |
| 64 additional short headers | 593,563 → 586,996 | -1.11% |

The 64-header case shows about 1.1% fewer instructions, while the standard-header case changes by only 0.2%. This is a modest CPU/memory tradeoff, not the large benefit seen in 4a’s long-header stress case.
Given the additional allocation and small CPU reduction, I would keep this change separate and lower priority than the buffered parser.

## Method and raw data

- [Microbenchmarks and exact allocation counts](../bench/results/async-header-followup.json)
- [Native Mars network measurements](../bench/results/async-header-followup-network.json)
- [Validation logs](../bench/results/async-header-followup-tests.json)

The same fixtures are compiled into each variant. Timing uses uninstrumented
native release binaries; a separately linked allocator probe counts requested
bytes, including runtime object headers but excluding allocator rounding and
RSS. Each memory run verifies the 266-byte allocation and release of a 257-byte
Bytes object. The three allocation runs must match exactly. Inputs are
precreated. Header microbenchmarks parse a fresh connection each iteration and
include validation of the parsed fields.

There are five timing rounds and three allocation rounds, reversing variant
order on alternate rounds. The network harness uses Mars commit
`66277d49502626d8c2f477d63d7eb285d1ba5157`, registry `mizchi/x@0.6.1`, four wrk
threads, and 64 connections. Each of three rounds includes a one-second warmup
and a three-second load. The route returns a 3-byte text body. The header case
adds 64 headers with 40-byte values; standard client headers are also present.

Only the server process is measured by `/usr/bin/time -lp`. CPU/instructions are
normalized by completed requests including warmup and one readiness request;
outstanding requests abandoned when wrk stops are not counted. Response bytes,
Content-Type, and framing are validated before load; HTTP/socket errors are
checked during load. This is a shared developer machine, and the short RPS/time
measurements should not be interpreted as isolated production throughput.
Binary, patch, runtime, and fixture hashes are recorded in the raw data.

## Validation and reproduction

The parser passes 115 native release tests for HTTP, io, read-buffer, coroutine,
and event-loop packages, 104 native debug HTTP/io tests, and 52 JS HTTP/io tests.
Workspace-wide checks pass with `--deny-warn` for native, JS, Wasm, and Wasm-GC.
Each split patch passes 103 native release HTTP/io/read-buffer tests and the
relevant Wasm/JS checks. Mars's native root-package tests pass 92/92 on all four builds, and `just release-check` passes all 331 JS tests.

On macOS with MoonBit, Python 3.9+, Node 24+, and wrk:

```sh
just profile-async-tuning /path/to/async \
  --base 43e41261f99261f4030efbed1970388930229baa \
  --variants baseline parser-pr buffer-growth header-map \
  --output bench/results/async-header-followup.json

just profile-async-network \
  --micro-results bench/results/async-header-followup.json \
  --cases small headers-64 \
  --output bench/results/async-header-followup-network.json
```

Keep the disposable build directory reported by the first command until the
second finishes. The scripts apply each patch to its own export of the same
commit, and verify patch hashes before building the network servers.

# Bounded async response-head batching

The upstream candidate batches small HTTP response heads before entering the
async writer. A conservative UTF-8 size preflight limits each batch to 256
bytes and to the remaining space in Sender's existing 1,024-byte buffer.
Larger heads use the original incremental writer. This retains the allocation
savings for small responses while avoiding an unbounded combined header copy.

Candidate patch: [async-bounded-response-head.patch](../bench/patches/async-bounded-response-head.patch).
It changes only async's private HTTP sender and its tests. Cookie serialization,
body framing, request sending, and public interfaces retain their existing code.
The PR branch starts at upstream main `43e41261f99261f4030efbed1970388930229baa`.
The two changed files are identical between that commit and v0.21.3, allowing
the same patch to be measured against the published v0.21.3 baseline.

## Memory comparison

The [initial Buffer experiment](buffer-memory-2026-09-11.md) reduced allocation
traffic but tripled transient memory for large values and retained a complete
head across blocked writes. This candidate bounds the optimization instead.

Results: [buffer-memory-bounded.json](../bench/results/buffer-memory-bounded.json).
The native release allocation probe is described in the earlier report. It
counts requested bytes, including object headers, while excluding existing
Senders, their send buffers, input Strings, allocator rounding, and RSS.
All three fresh-process repetitions match exactly.

| Extra headers | Allocated bytes/response, baseline → bounded | Peak live bytes, baseline → bounded |
|---|---:|---:|
| None | 2,828.44 → 1,728.44 | 412 → 501 |
| One, 40-byte value | 4,139.44 → 1,853.44 (−55.2%) | 605 → 525 |
| One, 128-byte value | 4,227.44 → 4,355.44 | 693 → 705 |
| One, 4 KiB value | 10,307.44 → 10,435.44 | 4,877 → 4,889 |
| One, 64 KiB value | 102,467.44 → 102,595.44 | 66,317 → 66,329 |
| 64, each a 64-byte value | 90,626.44 → 90,790.44 | 845 → 857 |
| One, 1 MiB value | 1,577,074 → 1,577,202 | 1,049,357 → 1,049,369 |

The conservative preflight uses at most three UTF-8 bytes per UTF-16 code unit.
It checks lengths before multiplying, without allocating encoded Strings.
Some ASCII heads smaller than 256 bytes therefore still use the fallback, as
in the 128-byte-value case. This trades optimization coverage for a cheap bound.
Fallback cases have a small preflight overhead: 128–164 cumulative bytes per
response and 12 extra bytes at the measured peak in these cases. Empty heads
also have an 89-byte higher peak, despite lower cumulative allocation traffic.

At the checkpoint where all 64 underlying writers are blocked:

| Headers per response | Baseline live bytes | Bounded live bytes |
|---|---:|---:|
| One, 40-byte value | 50,160 | 50,160 |
| 64, each a 64-byte value | 73,632 | 73,632 |
| One, 64 KiB value | 4,267,296 | 4,267,296 |

For comparison, the unbounded experiment retained 383,968 bytes in the
64-header case. All serial cases finish with zero tracked live bytes. The
concurrent fixture retains the same 14,920–16,472 bytes before its full teardown
in both variants; it is not a general server leak test.

## Native CPU comparison

Five alternating baseline/bounded runs serve the same Mars route as the
original profile: `GET /api/users/123`, status 200, text/plain, body `123`.
Both executables use async v0.21.3, with the candidate applied only to the
second. Each run uses four wrk threads, 64 connections, one second of warmup,
and five seconds of load. There is no allocation or sampling instrumentation.
Server CPU and retired instructions come from macOS `/usr/bin/time -lp` and
are normalized by readiness, warmup, and measured requests.

| Median metric | Baseline | Bounded candidate | Change |
|---|---:|---:|---:|
| Instructions/request | 96,013.1 | 85,521.5 | −10.9% |
| User CPU microseconds/request | 4.217 | 3.692 | −12.5% |
| User + system CPU microseconds/request | 7.870 | 7.494 | −4.8% |
| Requests/second | 125,430 | 132,132 | +5.3% |

These runs use a shared Apple M5 development machine; throughput is exploratory,
not a production guarantee. Full samples and settings are in
[profile-review-native-bounded.json](../bench/results/profile-review-native-bounded.json).
[Build provenance](../bench/results/profile-bounded-builds.json) records the
baseline commit, toolchain, patch, harness, and binary hashes. Historical
unbounded results remain separate and are not attributed to this candidate.

## Validation

- Upstream main with the patch: all 61 native release HTTP tests pass.
- Native workspace and HTTP Wasm checks with `--deny-warn`, formatting check, and native
  interface generation pass; no public interface changes.
- Added regressions cover conservative byte limits, three-byte UTF-8 and
  surrogate pairs, remaining sender space, persistent/ignored headers, an
  actual UTF-8 response at the batch boundary, and a long-header fallback
  followed by another response on the same sender.
- Mars: `just release-check` passes, including all 331 JS tests; all 92 native
  tests in the root Mars package pass with the candidate dependency. Native CPU
  comparisons use the unchanged native Mars source and validate status,
  Content-Type, response body, and absence of wrk socket/HTTP errors.

## Reproduce

```sh
# From the Mars root. The async checkout must contain v0.21.3.
just profile-buffer-memory /path/to/moonbitlang/async \
  --patch bench/patches/async-bounded-response-head.patch \
  --output bench/results/buffer-memory-bounded.json
```

The script exports two clean copies of async v0.21.3, applies the candidate to
one, and builds/instruments each with the same installed MoonBit toolchain.
Source, patch, runtime, and executable hashes are included in the results.

For native server timing, follow the temporary workspace build procedure in
[the profiling report](profiling-2026-09-11.md#reproduce), substituting the
bounded patch. Keep the two executable paths distinct, then run:

```sh
python3 bench/compare-native.py \
  --baseline /path/to/baseline/http_server.exe \
  --patched /path/to/bounded/http_server.exe \
  --patch patches/async-bounded-response-head.patch \
  --profiles profiles/bounded \
  --output results/profile-review-native-bounded.json
```

# Response-head Buffer memory review (2026-09-11)

Follow-up: the [bounded upstream candidate](async-response-head-pr.md) applies
a 256-byte preflight and removes the large-head/blocked-writer memory regression.
The measurements below preserve the original unbounded experiment for comparison.

The experimental async response-head patch reduces allocation traffic for
small responses, but increases temporary memory for large or numerous headers.
Keep the batching optimization, but bound its size before proposing it upstream.
The experiment has not changed async's production dependency or the patch itself.

Raw results: [buffer-memory.json](../bench/results/buffer-memory.json).
The [earlier CPU review](profiling-2026-09-11.md) measured a 12.5% reduction in
native instructions/request; that remains useful evidence, but covers only a
small response head.

## Serial response sending

Each case precreates its headers and reuses a Sender and its 1,024-byte send
buffer. A writer consumes bytes immediately without socket I/O. Measurement
covers `send_response` plus `end_body`, after a warmup response. There are 100
responses per case, or three for the 1 MiB case, repeated in three fresh
processes. All three repetitions produced identical allocation results.

These are allocator-requested bytes, including MoonBit object headers and
array terminators. They exclude allocator size-class rounding, fragmentation,
RSS, existing header Strings, and the existing Sender/send buffer. Allocation
traffic is cumulative bytes divided by response count; peak is maximum live
memory at any instant and is **not** divided by response count.

| Extra headers | Allocated KiB/response, baseline → Buffer | Peak live KiB, baseline → Buffer |
|---|---:|---:|
| None | 2.76 → 1.55 | 0.40 → 0.49 |
| One, 40-byte value | 4.04 → 1.64 | 0.59 → 0.51 |
| One, 128-byte value | 4.13 → 1.72 | 0.68 → 0.57 |
| One, 4 KiB value | 10.07 → 23.21 | 4.76 → 12.25 |
| One, 64 KiB value | 100.07 → 353.24 | 64.76 → 192.25 |
| 64, each a 64-byte value | 88.50 → 26.27 | 0.83 → 13.05 |
| One, 1 MiB value | 1,540.11 → 5,633.32 | 1,024.76 → 3,072.25 |

For the 40-byte value, allocation count falls from 78.02 to 31.02 per response,
and allocated bytes fall from 4,139.44 to 1,677.44 (59.5%). Fractional counts
include fixed harness setup spread across the measured response loop.
For the 64 KiB value, allocation count still falls slightly, but allocated
bytes increase 3.53 times. Counting allocations alone would miss this regression.
All serial cases return to zero tracked live bytes after the measured loop.
This establishes cleanup for these cases, not a general leak test of the server.

## Why memory grows

The patch creates a fresh `Buffer(size_hint=256)` for each response. This
allocates a 265-byte backing array in the current native runtime, plus the
Buffer object. Capacity doubles on growth; the old and new arrays coexist
during the copy. The Buffer also copies persistent response headers into its
new backing array.

`Buffer::contents()` is an alias for `to_bytes()` and returns a full copy.
For an encoded head of H bytes and a final Buffer capacity C, the output copy
temporarily overlaps with the C-byte backing array. Growth can instead be the
peak: growing from 64 KiB to 128 KiB needs both arrays at once. A value exactly
64 KiB long plus its header name and status line triggers that growth, producing
the roughly 192 KiB peak above. These boundary cases intentionally expose
capacity doubling; not every 64 KiB-sized response has exactly this peak.

The Buffer is released before awaiting the writer. Its copied Bytes can remain
live while the existing 1,024-byte send buffer is repeatedly flushed. In the
baseline, extra headers are encoded and sent individually, so many small
headers do not require a combined head-sized allocation.

## Concurrent blocked writers

A separate test creates 64 Senders before measurement, then suspends every
sender inside its first underlying write using semaphores. It records live
bytes only after all 64 are blocked, releases them, and validates that every
writer consumed the same wire length. No wall-clock sleeps or network timing
are involved. Headers are shared, and existing Senders, their buffers, and
header Strings are excluded. Task and semaphore allocations during the
measurement are included equally in both variants.

| Headers per response | Live KiB with 64 blocked senders, baseline → Buffer |
|---|---:|
| One, 40-byte value | 48.98 → 48.98 |
| 64, each a 64-byte value | 71.91 → 374.97 |
| One, 64 KiB value | 4,167.28 → 4,160.41 |

Many small headers retain about 303 KiB more across these 64 blocked writers,
because the patch keeps the combined encoded head. A single large value is
already retained as encoded Bytes in the baseline, so blocked memory is similar
there. Small complete heads fit in the existing send buffer and are released
before the underlying write, giving equal blocked memory in the first case.

The roughly 3H construction peak should not be multiplied by connection count:
async uses one thread for these coroutines, so only one head is being assembled
at a time. Retained copies across suspended senders can accumulate.

The blocked fixture's completion checkpoint still has 14,920–16,472 tracked
bytes in both variants, before full fixture/runtime teardown. This is identical
between baseline and patch; unlike the serial loop, this checkpoint does not
establish zero retained memory for the concurrent fixture.

## Instrumentation and validation

The installed `moon-pprof memprofile-native` rewrites the generated allocator
with `ptr->rc = 1`, whereas this runtime uses `Moonbit_init_dynamic_rc` and a
different reference-count representation. This is a likely cause of the prior
instrumented crash. Its generated-C-only hook also misses the separate runtime
allocation paths for Bytes and Strings. Those failed profiles are not evidence
for this memory comparison.

The focused probe instead overrides `MOONBIT_MALLOC_RAW` and
`MOONBIT_FREE_RAW` in both generated C and a separately rebuilt `runtime.c`,
preserving the original reference-count code and mimalloc backend. Its pointer
tracking table uses static storage outside the counted heap. A calibration test
requires exactly one allocation of 266 bytes for a 257-byte Bytes object
(eight-byte object header plus trailing NUL), followed by zero live bytes.
The test executable also checks response wire lengths. All measured counts
must agree across three processes; the script fails if calibration, test
results, repetitions, or baseline/patched wire lengths disagree.

Builds are isolated Git archives at async commit
`3e54be1f084b320aad774d6bb450f04bce560509` (v0.21.3), with and without the
saved response-head patch. Compiler version, source/patch hashes, and executable
hashes are recorded in the JSON. Installed toolchain and registry files are
not edited. This probe measures the native release backend only.

```sh
# From the Mars root; requires macOS, Moon, C toolchain, Python 3.9+, and an
# async checkout containing the v0.21.3 commit. Builds are retained in /tmp.
just profile-buffer-memory /path/to/moonbitlang/async
```

## Upstream recommendation

The small-response CPU and allocation gains justify continuing the PR work.
The current unbounded Buffer implementation should be revised first: batch
small heads within a defined byte budget and use the existing send path for
larger heads, or assemble directly into the existing fixed-size send buffer.
Then rerun both the CPU comparison and these large-header/blocked-writer cases.
Increasing the initial Buffer size alone would trade one allocation pattern
for another without bounding memory or removing the `contents()` copy.

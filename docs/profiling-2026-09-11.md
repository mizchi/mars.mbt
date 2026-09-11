# Mars profiling review (2026-09-11)

Upstream candidate: [bounded response-head batching](async-response-head-pr.md),
with a separate memory comparison and new CPU measurements. The unbounded
experiment below is retained as the initial profiling evidence.

Mars's JS request-header conversion and async's native HTTP response-head
writer are actionable hotspots. The local Mars change reduces measured Fetch
time by 16–23%. A patch against async 0.21.3 reduces native instructions per
request by 12.5% and user CPU time per request by 14.5% in this experiment.

The Mars change is included with this report. The original async experiment is
preserved in [async-0.21.3-response-head.patch](../bench/patches/async-0.21.3-response-head.patch);
the bounded upstream candidate is linked above. Registry dependencies and
mizchi/x's source are unchanged. This profiling workflow does not publish packages.

Follow-up: the [Buffer memory review](buffer-memory-2026-09-11.md) confirms
lower allocation traffic for small responses but higher peak memory for large
heads and higher retained memory for many headers under backpressure. Bound
the batching size before proposing the current async experiment upstream.

## Inputs and measurement boundaries

- Mars: `418123437691591487bbb45806494fef59f471ab` (0.3.12).
- Registry dependencies: mizchi/x 0.6.1, async 0.21.3, moonbitlang/x 0.5.5,
  regexp 0.3.5. The async patch starts at upstream tag `v0.21.3`, commit
  `3e54be1f084b320aad774d6bb450f04bce560509`.
- Apple M5, arm64 macOS, Node 24.21.0, Moon 0.1.20260904. Hono 4.11.7 remains
  the reference in the existing JS comparison.
- JS CPU profiles: release build, warmup excluded, five-second recording via
  Node inspector at a requested 100 µs interval, converted with
  `moon-pprof cpuprofile2pprof`. Actual sample intervals vary.
- Native stacks: release build, `samply` at 1 kHz, presymbolicated, converted
  with `moon-pprof firefox2pprof`. Only the server process is sampled; wrk is a
  separate process. Captures include startup, one readiness request, one second
  of warmup, five seconds of load, and trailing idle time before shutdown.
- Native comparison: five alternating baseline/patched runs, four wrk threads,
  64 connections. Both serve `GET /api/users/123` as status 200, identical
  Content-Type, and body `123`. `/usr/bin/time -lp` records the server's CPU
  time and retired instructions. Normalization includes warmup requests and
  the readiness request. These runs have no sampling/allocation profiler.
- This is a shared development machine. Other active CPU workloads caused
  substantial RPS variation. Final benchmark/profiling runs were serialized
  within this task. RPS is exploratory; the consistently lower instruction
  count is stronger evidence than a single throughput result.

Native pprof weights describe sampled stack occupancy, including blocked
`kevent`, `read`, and `write` frames. They are **not exclusively on-CPU time**.
Use the separate uninstrumented CPU measurements below for CPU cost. Inlining
and unresolved `OUTLINED_FUNCTION_*` names also limit package attribution.

## Hotspots

Percentages and source profile paths are in
[profile-hotspots.json](../bench/results/profile-hotspots.json). Cumulative
percentages include descendants and must not be added to other overlapping
groups.

| Workload | Baseline observation | Action |
|---|---|---|
| JS Fetch | Request-header conversion: 20.3% cumulative; URL parsing: 1.8% | Visit present headers once, preserve the common-header set and canonical names, slice the URL without a Char array and StringBuilder |
| JS UUID regex route | Character-class/quantifier/atom parsing: 18.7% self; scanning alternatives: another 14.4% self | Next candidate: compile regex plans during route registration |
| JS dynamic route | Array initialization: 20.6% self; GC: 4.8% | Next candidate: reduce temporary parameter/result maps and path arrays |
| Native Mars | Response-head sending: 8.0% cumulative; memory allocation/drop/GC: 16.0% self | Encode the response head synchronously and issue one async write |
| Native Mars | Request-header parsing: 3.0% cumulative | Further parser work is lower priority than the measured send-path improvement |

After the Mars change, JS header conversion accounts for 1.4% cumulative and
URL parsing 0.8%. After the async experiment, native response-head sending
accounts for 3.0% cumulative. These are profile-shape observations across
separate captures, not independent estimates of speedup.

The native lower-layer captures use the same wire response with direct
mizchi/x and direct async handlers. Their dominant library paths are still
async's sender, reader, and runtime memory management. Identifiable mizchi/x
self frames are small (0.36% in the Mars capture); this does not include all
inlined work or runtime allocations caused by the wrapper. Its String-keyed
header maps require conversions to/from async's CaseInsensitiveString maps.
Those conversions remain a candidate for a header-heavy workload, but this
run does not justify changing the public header API. `CaseInsensitiveString`
already implements `to_string` by returning its inner String, so replacing
that call with field access would not eliminate a copy.

Regex precompilation remains unimplemented. `Node` and `Pattern` are public
types with publicly constructible fields/variants. Storing a compiled plan
needs an explicit API design; a global, unbounded pattern cache would add
retained state. The current router implementation is unchanged, so small
router differences in the comparison should be treated as noise/JIT effects.

## JS comparison without profiling

The existing same-process harness rotates baseline Mars, modified Mars, and
Hono order. Nine runs, 5,000 Fetch operations per run, fresh Request objects,
consumed response bodies. Six-header cases include Accept, Authorization,
Cookie, Origin, User-Agent, and X-Request-ID. Raw samples, module hashes, and
all 26 cases: [profile-review-js.json](../bench/results/profile-review-js.json).

| Fetch case | Baseline ns/op | Modified ns/op | Time reduction |
|---|---:|---:|---:|
| Dynamic response | 10,029.5 | 7,684.6 | 23.4% |
| Dynamic + middleware | 9,084.8 | 7,208.6 | 20.7% |
| Dynamic + 6 request headers | 10,072.6 | 8,465.4 | 16.0% |
| Middleware + 6 request headers | 10,145.5 | 8,534.4 | 15.9% |

Hono remains faster in all four Fetch cases. These are in-process dispatch
measurements and do not establish network throughput.

## Native async experiment without profiling

`Sender::send_response` previously crossed the async writer boundary for the
status prefix, status code, spaces, reason, CRLF, persistent headers, and every
piece of each extra header. The patch writes these pieces to a local Buffer
synchronously, then passes the encoded head to the existing async writer once.
Cookie serialization and body framing retain their existing implementation.
The generated C no longer needs the same sequence of sender continuations.

| Median metric | Baseline | Modified async | Change |
|---|---:|---:|---:|
| Instructions/request | 96,718.7 | 84,646.7 | −12.5% |
| User CPU µs/request | 4.384 | 3.747 | −14.5% |
| User + system CPU µs/request | 8.228 | 7.642 | −7.1% |
| Requests/second | 113,998 | 121,150 | +6.3% |

The individual baseline RPS values span 79,717–131,651 and patched values
100,201–144,510. Instruction counts are much tighter: baseline 96,183–98,182,
patched 84,145–85,388 per request. This supports keeping the async patch for
further review, while avoiding a firm production throughput claim. Raw data:
[profile-review-native.json](../bench/results/profile-review-native.json).

## Validation

- Mars: 331 JS tests; 349 native tests using the patched async workspace
  (344 library tests plus 5 example tests); 76 Wasm router/Spin tests.
- async: all 57 native HTTP tests passed, including 15 sender tests. The new
  regression checks a header exceeding 3 KiB, Unicode, forbidden transfer
  encoding, fixed body length, and another response on the same sender.
  Existing cookie, HEAD, empty-body, incorrect-length, and streaming tests pass.
- x: 82 native HTTP tests on the published dependency baseline passed.
- Warning-free JS checks and benchmark JS/native checks; async HTTP Wasm
  check passed. Formatting, generated interfaces, and script syntax checked.
- API/header behavior was captured before optimization. The added Mars tests
  retain the common-header names/set, raw custom-header access, query strings,
  Unicode paths, and empty headers. Performance baselines were captured before
  implementation changes and compared again after the changes.

## Reproduce

Requirements: Moon, Node 24+, Python 3.9+, moon-pprof; native captures also
need samply and wrk. Native CPU accounting currently uses macOS `time -lp`.

```sh
just profile-js --scenario fetch --output profiles/current/js-fetch
just profile-js --scenario 'regex UUID' --output profiles/current/js-regex
just profile-js --scenario dynamic --output profiles/current/js-dynamic
just profile-native mars cpu --output profiles/current/native-mars
just profile-native x cpu --output profiles/current/native-x
just profile-native async cpu --output profiles/current/native-async

# Compare the current Mars source to the measured release with the same harness.
cd bench
node --expose-gc compare.mjs 418123437691591487bbb45806494fef59f471ab \
  --output results/reproduced-js.json
```

For the native patch, first build the baseline and copy its executable to a
separate path. Apply the supplied patch to an async worktree at `v0.21.3`:

```sh
# From the Mars root
moon -C bench build bridge/http_server --target native --release
cp bench/_build/native/release/build/mizchi/mars_bench/http_server/http_server.exe \
  /tmp/mars-http-baseline.exe

# Substitute your async worktree directory for /path/to/async-profile.
git -C /path/to/async-profile apply "$PWD/bench/patches/async-0.21.3-response-head.patch"
profile_workspace=$(mktemp -d)
cat > "$profile_workspace/moon.work" <<EOF
members = ["$PWD", "$PWD/bench", "/path/to/async-profile"]
EOF
moon -C "$profile_workspace" build "$PWD/bench/bridge/http_server" --target native --release
python3 bench/compare-native.py \
  --baseline /tmp/mars-http-baseline.exe \
  --patched "$profile_workspace/_build/native/release/build/mizchi/mars_bench/http_server/http_server.exe"
```

The temporary workspace overrides only the dependency used for the experiment.
It does not edit registry caches or require changing Mars's root workspace.
The worktree must not already contain the patch before `git apply`.

The profiling wrappers set `DYLD_LIBRARY_PATH=/usr/lib` for tool invocations
on macOS because the installed moon-pprof/samply binaries reference a removed
Nix libiconv path. No global library installation is modified. The native
allocation experiment (`just profile-native mars alloc`) produced SIGSEGV in
the instrumented binary; its partial output was excluded from the results.
The later [focused memory probe](buffer-memory-2026-09-11.md) preserves the
current runtime's reference-count initialization and measures response sending
in isolation. Its allocation counts are separate from these network captures.
The uninstrumented native binary and samply capture both complete successfully.

Compact pprof files, summaries, and timing metadata are retained under
[`bench/profiles`](../bench/profiles). Raw Node and Firefox profiles remain
local and are ignored by Git. For interactive inspection:

```sh
DYLD_LIBRARY_PATH=/usr/lib go tool pprof -http 127.0.0.1:8081 \
  bench/profiles/baseline/native-mars-cpu.pb.gz
```

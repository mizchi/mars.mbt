# Implementation review and benchmarks

Measured on 2026-09-11 against `a71bade` (Mars 0.3.11).

The paired results below were measured before the dependency update described
at the end of this report; keep them as a record of that implementation comparison.

## Changes

- Removed the JavaScript call to an old private async scheduler symbol. `Promise::from_async` already schedules its coroutine; Fetch handlers now execute with the installed async dependency.
- Stop dispatch after a middleware error and return 500 when no response has been sent. Mounted middleware now uses the same response-aware composition as other handler chains.
- Keep terminal wildcard handlers active when their trie node also has children. Match an empty suffix after a regex parameter followed by `/*`. Avoid visiting dynamic nodes twice when request segments literally contain `:id` or `*`.
- Reuse one parameter map during traversal, restore shadowed parameters on return, and copy only the parameters owned by each result. Use the standard map copy operation instead of reinserting every entry.
- Avoid rebuilding routing paths that contain no regex groups. Calculate regex backtracking offsets directly instead of allocating an array for every atom.
- Restrict the Spin example's Wasm FFI packages to Wasm targets so workspace JS/native checks work, and remove current compiler warnings. Public Mars/router type and function signatures are unchanged.

## Method

- Apple M5, arm64 macOS (Darwin 25.5.0), 32 GiB RAM; Node v24.21.0; Moon 0.1.20260904.
- Hono 4.11.7, resolved by the committed pnpm lockfile. Router comparisons use its `TrieRouter`; Fetch comparisons use the default `Hono` application.
- Release builds. The baseline library is exported from Git into a temporary directory and compiled with the same MoonBit benchmark bridge as the working tree.
- Baseline, working tree, and Hono run in one Node process, rotating order for each case and run. There are 9 measured runs of 100,000 router operations after 20,000 warmup operations per implementation. Explicit GC runs before each timed batch.
- Registration creates a fresh router for every operation and retains the result. Matching uses prebuilt routers, consumes the match count, and rotates request paths where the case provides multiple paths. Handler order and parameter values are checked against Hono before timing.
- Fetch uses 1,000 warmup operations and 9 runs of 5,000 operations, including a fresh Request and consuming the response body. It measures in-process dispatch, not network throughput.
- Values below are medians in ns/op (lower is better). Raw samples, standard deviations, environment, source revision, and module/harness hashes are in [paired.json](../bench/results/paired.json). No other tests/builds were run concurrently by this task. This is a shared development machine; small differences should be treated as noise.

The old registration microbenchmarks grew one Mars router indefinitely while Hono created a fresh router per operation. They are not comparable. Both the MoonBit microbenchmarks and the JS comparison now use fresh routers, and MoonBit matching benchmarks use `b.keep` to retain their results.

## Paired JavaScript results

| Operation | Baseline Mars | Reviewed Mars | Hono | Mars time reduction |
|---|---:|---:|---:|---:|
| register: create router | 87.3 | 85.1 | 28.6 | +2.5% |
| register: register static | 476.0 | 415.9 | 219.2 | +12.6% |
| register: register dynamic | 761.7 | 606.7 | 355.0 | +20.4% |
| register: register wildcard | 444.1 | 391.7 | 220.9 | +11.8% |
| register: register regex | 954.5 | 968.2 | 566.6 | -1.4% |
| register: register REST API | 3445.4 | 2528.1 | 4021.4 | +26.6% |
| match: static short | 244.8 | 251.1 | 133.4 | -2.6% |
| match: static long | 355.9 | 367.3 | 347.3 | -3.2% |
| match: dynamic | 389.6 | 367.8 | 481.9 | +5.6% |
| match: nested dynamic | 597.9 | 565.0 | 586.6 | +5.5% |
| match: wildcard | 329.2 | 327.5 | 278.5 | +0.5% |
| match: regex digits | 502.2 | 493.1 | 421.7 | +1.8% |
| match: regex UUID | 1499.7 | 1255.0 | 440.6 | +16.3% |
| match: middleware multi-match | 568.1 | 571.2 | 473.1 | -0.5% |
| match: not found | 142.0 | 142.2 | 69.3 | -0.1% |
| match: 100 static routes | 294.9 | 300.4 | 171.8 | -1.9% |
| match: 100 dynamic routes | 385.0 | 380.6 | 360.9 | +1.1% |
| match: mixed routes | 514.9 | 510.7 | 436.7 | +0.8% |
| match: optional absent | 253.5 | 256.4 | 164.2 | -1.1% |
| match: optional present | 368.0 | 359.6 | 337.7 | +2.3% |
| match: deep overlap | 1463.4 | 1170.5 | 1673.4 | +20.0% |
| match: ALL method | 253.6 | 258.8 | 168.7 | -2.1% |
| fetch: dynamic response | unavailable | 8348.5 | 3680.3 | n/a |
| fetch: dynamic + middleware | unavailable | 8330.0 | 4626.5 | n/a |

REST API registration took 26.6% less time, deep overlapping route matching 20.0% less, and UUID matching 16.3% less. Static-route results were roughly unchanged (the reviewed implementation was 1–3% slower in several cases). Hono remains faster for static routing, UUID matching, and the measured Fetch cases; these results do not establish a general framework throughput advantage.

Baseline Fetch cases fail correctness validation with `ReferenceError: moonbitlang$async$internal$event_loop$$reschedule is not defined`. They are recorded as failures rather than timed. The reviewed Fetch cases return the expected status, body, and middleware header.

## MoonBit microbenchmarks

The standalone suite has 22 cases and uses the corrected registration setup and result retention. Full output: [native](../bench/results/router-native.txt), [JavaScript](../bench/results/router-js.txt). These use MoonBit's benchmark harness, so compare them within that harness rather than directly against the JS/Hono timing loop.

## Reproduce

Validation passed: 329 JS tests, 349 native tests, and 76 Wasm router/Spin-app
tests. `moon check --deny-warn` passes on JS and native, and the Spin Wasm
implementation also passes its target-specific check. All 13 topology tests
reproduce the existing message-count and convergence tables. Native workspace
commands still emit Moon's existing notice about the WebSocket example placing
blackbox tests in an executable package.

```sh
just check
moon check --target native --deny-warn
just test
moon test --target native
moon test src/router/trie examples/spin-mars-router/app --target wasm

# Current Mars versus Hono
just bench --output results/latest.json

# Git baseline, current Mars, and Hono in one process
just bench-compare a71bade --label reviewed-paired --output results/paired.json

# Independent MoonBit benchmark harness
just bench-router native
just bench-router js

# Deterministic topology simulation
moon test src/topology --target native
```

The comparison command removes only its own temporary baseline directory. It leaves the working tree and existing build artifacts in place. Benchmarks require Node 24+, pnpm, Moon, Git, and tar. Benchmark versions are independent of library publishing.

## Dependency update (2026-09-11)

| Module | Before | Updated |
|---|---|---|
| `moonbitlang/async` | 0.20.0 | 0.21.3 |
| `moonbitlang/x` | 0.4.46 | 0.5.5 |
| `mizchi/x` | 0.5.1 | 0.6.1 |
| Spin example: `moonbitlang/regexp` | 0.3.4 | 0.3.5 |

Mars 0.3.12 and its WebSocket example use the published x 0.6.1, which adapts
native HTTP and WebSocket header keys to async 0.21 while retaining
`Map[String, String]` in the public API. The WebSocket example now uses
`mizchi/x/websocket` directly and tests both text and binary echo. Example
manifests use `moon.mod` and resolve local Mars through the root `moon.work`.

The intermediate update to async 0.20.6 and x 0.6.0 remains recorded in
[dependencies.json](../bench/results/dependencies.json). The final release
benchmark is recorded separately in
[release-0.3.12.json](../bench/results/release-0.3.12.json), including the
resolved MoonBit versions. Hono remains at the previously locked 4.11.7;
no npm dependencies are updated in this change.

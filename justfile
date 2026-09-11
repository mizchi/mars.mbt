# MoonBit Project Commands

# Default target (js for browser compatibility)
target := "js"

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Type check
check:
    moon check --deny-warn --target {{target}}

# Run tests
test:
    moon test --target {{target}}

# Router microbenchmarks (release build; native or js)
bench-router target="native":
    moon bench src/router/trie --target {{target}} --release --no-parallelize

# Mars/Hono comparison with identical inputs, validation, and timing
bench *args:
    cd bench && pnpm install --frozen-lockfile && pnpm bench {{args}}

# Measure a Git revision and the working tree in the same process
bench-compare revision="HEAD" *args:
    cd bench && pnpm install --frozen-lockfile && node compare.mjs {{revision}} {{args}}

# Capture a warmed-up JS workload and convert the Node profile with moon-pprof
profile-js *args:
    cd bench && moon build --target js --release
    cd bench && node --expose-gc profile-js.mjs {{args}}

# Capture native server stacks (cpu), allocations (alloc), or throughput (time)
profile-native layer="mars" capture="cpu" *args:
    cd bench && moon build bridge/http_server --target native --release
    cd bench && python3 profile-native.py --layer {{layer}} --capture {{capture}} {{args}}

# Compare response-head allocations using disposable async builds (macOS)
profile-buffer-memory async_repo *args:
    python3 bench/buffer-memory/measure.py --async-repo {{quote(async_repo)}} {{args}}

# Update snapshot tests
test-update:
    moon test --update --target {{target}}

# Run main
run:
    moon run src/main --target {{target}}

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test

name = "mizchi/mars"

version = "0.3.11"

import {
  "moonbitlang/async@0.20.0",
  "moonbitlang/x@0.4.46",
  "mizchi/x@0.5.1",
}

readme = "README.mbt.md"

repository = "https://github.com/mizchi/mars.mbt"

license = "MIT"

keywords = [
  "moonbit",
  "http",
  "router",
  "web-framework",
  "middleware",
  "sse",
  "nodejs",
  "api",
]

description = "Hono-inspired MoonBit web framework with trie routing, middleware, SSE, and mizchi/x HTTP backend for native and Node.js"

preferred_target = "native"

options(
  source: "src",
)

# Mars

A Hono-inspired HTTP framework for MoonBit.

## Features

- **Trie-based Router**: Fast URL matching with parameter extraction
- **Dynamic Parameters**: Support for `:id` style URL parameters
- **Wildcard Routes**: Support for `*` wildcard patterns
- **Optional Parameters**: Support for `:param?` optional parameters
- **Regex Parameters**: Support for `:id{[0-9]+}` regex-constrained parameters
- **HTTP Methods**: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS, CONNECT, TRACE
- **Middleware Support**: Chain multiple handlers
- **JSON/HTML/Text Responses**: Built-in response helpers

## Installation

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "mizchi/mars": "0.1.0"
  }
}
```

## Usage

```moonbit
async fn main {
  let app = @mars.Mars::new()

  // Static route
  let _ = app.get("/", @mars.handler(async fn(ctx) {
    ctx.text("Hello, Mars!")
  }))

  // Dynamic parameter
  let _ = app.get("/users/:id", @mars.handler(async fn(ctx) {
    let id = ctx.param("id").unwrap_or("unknown")
    ctx.json({ "id": id })
  }))

  // Wildcard
  let _ = app.get("/files/*", @mars.handler(async fn(ctx) {
    ctx.text("File path: " + ctx.path())
  }))

  // Multiple methods
  let _ = app.post("/users", @mars.handler(async fn(ctx) {
    ctx.json({ "status": "created" }, status=201)
  }))

  // Start server
  app.serve(@socket.Addr::parse("127.0.0.1:3000"))
}
```

## JWT Middleware

```moonbit
import { "mizchi/mars/middleware" as @mw }
import { "mizchi/jwt.mbt" as @jwt }
import { "moonbitlang/core/encoding/utf8" as @utf8 }
let now = fn() => 1_700_000_000L

// HS256
let hs_key = @jwt.Key::hs256(@utf8.encode("secret"))
app.use_(@mw.jwt_bearer_with_key(hs_key, now))

// JWKS (native / js)
let jwks_url = "https://example.com/.well-known/jwks.json"
app.use_(
  @mw.jwt_bearer_with_jwks(
    jwks_url,
    @mw.jwks_fetch_native,
    now,
    3600,
  ),
)

// Node/wasm で独自 fetch を注入する例
app.use_(@mw.jwt_bearer_with_jwks(jwks_url, @mw.jwks_fetch_node, now, 3600))
app.use_(@mw.jwt_bearer_with_jwks(jwks_url, @mw.jwks_fetch_wasm, now, 3600))

// claims を型安全に取得
struct Claims {
  sub : String
  exp : Int
} derive(FromJson)

match @mw.jwt_claims_decode[Claims](ctx) {
  Ok(claims) => println(claims.sub)
  Err(_) => println("no claims")
}
```

## API

### Mars

- `Mars::new() -> Mars` - Create new application
- `Mars::get(path, handler) -> Mars` - Register GET route
- `Mars::post(path, handler) -> Mars` - Register POST route
- `Mars::put(path, handler) -> Mars` - Register PUT route
- `Mars::delete(path, handler) -> Mars` - Register DELETE route
- `Mars::patch(path, handler) -> Mars` - Register PATCH route
- `Mars::all(path, handler) -> Mars` - Register route for all methods
- `Mars::use_(middleware) -> Mars` - Add middleware
- `Mars::serve(addr)` - Start HTTP server

### Context

- `Context::param(name) -> String?` - Get URL parameter
- `Context::path() -> String` - Get request path
- `Context::header(name) -> String?` - Get request header
- `Context::text(body, status?)` - Send text response
- `Context::json(data, status?)` - Send JSON response
- `Context::html(body, status?)` - Send HTML response
- `Context::redirect(url)` - Send redirect response
- `Context::not_found()` - Send 404 response

### Router Patterns

- `/users` - Static path
- `/users/:id` - Dynamic parameter
- `/users/:id{[0-9]+}` - Regex-constrained parameter
- `/files/*` - Wildcard (matches any path)
- `/api/:type?` - Optional parameter

## License

MIT

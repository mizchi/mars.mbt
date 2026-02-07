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

`jwt_bearer_with_key`, `jwt_bearer_with_jwks`, and `jwks_fetch_*` are
temporarily disabled while cross-target JWT support is being redesigned.
Current behavior is fail-closed (always unauthorized).

Claims helper APIs are still available:

- `jwt_claims_json`
- `jwt_claims_map`
- `jwt_claims_decode`
- `jwt_claims_decode_string`

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

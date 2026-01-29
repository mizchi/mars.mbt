# Flame

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
    "mizchi/flame": "0.1.0"
  }
}
```

## Usage

```moonbit
async fn main {
  let app = @flame.Flame::new()

  // Static route
  let _ = app.get("/", @flame.handler(async fn(ctx) {
    ctx.text("Hello, Flame!")
  }))

  // Dynamic parameter
  let _ = app.get("/users/:id", @flame.handler(async fn(ctx) {
    let id = ctx.param("id").unwrap_or("unknown")
    ctx.json({ "id": id })
  }))

  // Wildcard
  let _ = app.get("/files/*", @flame.handler(async fn(ctx) {
    ctx.text("File path: " + ctx.path())
  }))

  // Multiple methods
  let _ = app.post("/users", @flame.handler(async fn(ctx) {
    ctx.json({ "status": "created" }, status=201)
  }))

  // Start server
  app.serve(@socket.Addr::parse("127.0.0.1:3000"))
}
```

## API

### Flame

- `Flame::new() -> Flame` - Create new application
- `Flame::get(path, handler) -> Flame` - Register GET route
- `Flame::post(path, handler) -> Flame` - Register POST route
- `Flame::put(path, handler) -> Flame` - Register PUT route
- `Flame::delete(path, handler) -> Flame` - Register DELETE route
- `Flame::patch(path, handler) -> Flame` - Register PATCH route
- `Flame::all(path, handler) -> Flame` - Register route for all methods
- `Flame::use_(middleware) -> Flame` - Add middleware
- `Flame::serve(addr)` - Start HTTP server

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

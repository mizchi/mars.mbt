# Flame

A Hono-inspired HTTP framework for MoonBit.

## Installation

```json
{
  "deps": {
    "mizchi/flame": "0.1.0"
  }
}
```

## Quick Start

```moonbit
async fn main {
  let app = @flame.Flame::new()

  app
    .get("/", async fn(ctx) { ctx.text("Hello, Flame!") })
    .get("/users/:id", async fn(ctx) {
      let id = ctx.param("id").unwrap()
      ctx.json({ "id": id })
    })
    .post("/users", async fn(ctx) {
      let body = ctx.body_json()
      ctx.json({ "created": true }, status=201)
    })

  app.serve(@socket.Addr::new("127.0.0.1", 3000)!)
}
```

## Routing

### HTTP Methods

```moonbit
app.get("/path", handler)      // GET
app.post("/path", handler)     // POST
app.put("/path", handler)      // PUT
app.delete("/path", handler)   // DELETE
app.patch("/path", handler)    // PATCH
app.query("/path", handler)    // QUERY (RFC 9110)
app.all("/path", handler)      // All methods
```

### Path Parameters

```moonbit
app.get("/users/:id", async fn(ctx) {
  let id = ctx.param("id")  // -> String?
})

app.get("/users/:user_id/posts/:post_id", async fn(ctx) {
  let user_id = ctx.param("user_id")
  let post_id = ctx.param("post_id")
})
```

## Context API

### Request

```moonbit
ctx.path()                    // Request path
ctx.meth()                    // HTTP method
ctx.param("id")               // Path parameter
ctx.query("page")             // Query parameter: ?page=1
ctx.queries()                 // All query parameters
ctx.header("Content-Type")    // Request header
ctx.body()                    // Request body as String
ctx.body_json()               // Request body as Json
```

### Response

```moonbit
ctx.text("Hello")                        // text/plain
ctx.json({ "key": "value" })             // application/json
ctx.html("<h1>Hello</h1>")               // text/html
ctx.redirect("/new-path")                // 302 redirect
ctx.not_found()                          // 404

// With status code
ctx.text("Created", status=201)
ctx.json(data, status=201)
```

### Cookies

```moonbit
// Get cookies
ctx.cookie("session")         // -> String?
ctx.cookies()                 // -> Map[String, String]

// Set cookie
ctx.set_cookie(
  "session",
  "abc123",
  max_age=3600,               // 1 hour
  path="/",
  http_only=true,
  same_site="Lax"             // Lax | Strict | None
)

// Delete cookie
ctx.delete_cookie("session")
```

### Context Variables

```moonbit
// Typed variable storage
ctx.vars.set_string("user_id", "123")
ctx.vars.set_number("count", 42.0)
ctx.vars.set_bool("active", true)
ctx.vars.set_json("data", json_value)

ctx.vars.get_string("user_id")  // -> String?
ctx.vars.get_number("count")    // -> Double?
ctx.vars.get_bool("active")     // -> Bool?
ctx.vars.get_json("data")       // -> Json?
```

### Background Tasks (waitUntil)

```moonbit
ctx.wait_until(async fn() {
  // Run after response is sent
  println("Background task completed")
}, name="logging")
```

## Middleware

### Using Middleware

```moonbit
app
  .use_(logger())
  .use_(cors())
  .use_(secure_headers())
  .get("/", handler)
```

### Available Middleware

| Middleware | Description |
|------------|-------------|
| `logger()` | Request logging |
| `cors()` | CORS headers |
| `secure_headers()` | Security headers (CSP, X-Frame-Options, etc.) |
| `session(options)` | Signed cookie sessions (HMAC-SHA256) |
| `basic_auth(options)` | HTTP Basic Authentication |
| `rate_limit(options)` | Rate limiting |
| `timeout(options)` | Request timeout |
| `body_limit_kb(size)` | Request body size limit |
| `compress()` | Response compression |
| `etag()` | ETag generation |
| `cache_control(options)` | Cache-Control headers |
| `trailing_slash(options)` | Trailing slash handling |
| `ip_filter(options)` | IP whitelist/blacklist |
| `api_key(options)` | API key authentication |
| `request_id()` | X-Request-ID header |

### Session Example

```moonbit
let session_opts = @middleware.SessionOptions::new("your-secret-key")

app
  .use_(@middleware.session(session_opts))
  .get("/profile", async fn(ctx) {
    let session_id = ctx.get("session_id")
    ctx.json({ "session": session_id })
  })
```

### CORS Example

```moonbit
let cors_opts = @middleware.CorsOptions::new()
  .with_origin("https://example.com")
  .with_credentials(true)

app.use_(@middleware.cors(options=cors_opts))
```

## Environment & Platform Adapters

### Environment Variables

```moonbit
let env = @flame.MapEnv::new()
  .with_var("API_KEY", "secret")
  .with_var("ENV", "production")

app.serve_with_env(addr, env)

// In handler
ctx.env_var("API_KEY")  // -> String?
```

### Cloudflare Workers Adapter

```moonbit
import { CloudflareEnv, KVNamespace } from "mizchi/flame/adapters"

let cf_env = CloudflareEnv::new()
  .with_var("SECRET", "value")
  .with_kv("CACHE", KVNamespace::new("CACHE"))

let map_env = cf_env.to_map_env()
app.serve_with_env(addr, map_env)
```

## Code Generation

Generate type-safe API clients from route specifications:

```moonbit
import { RouteSpec, generate_client, ClientOptions } from "mizchi/flame/codegen"

let routes = [
  RouteSpec::get("/users", "get_users", "Array[User]"),
  RouteSpec::post("/users", "create_user", "CreateUserInput", "User"),
  RouteSpec::get("/users/:id", "get_user", "User"),
  RouteSpec::delete("/users/:id", "delete_user", "Unit"),
]

let code = generate_client(routes)
// Or with custom options
let code = generate_client(routes, options=ClientOptions::new("MyApiClient"))
```

Generated code:

```moonbit
pub(all) struct ApiClient {
  base_url : String
}

pub fn ApiClient::new(base_url : String) -> ApiClient

pub async fn ApiClient::get_users(self : ApiClient) -> Array[User] raise
pub async fn ApiClient::create_user(self : ApiClient, body : CreateUserInput) -> User raise
pub async fn ApiClient::get_user(self : ApiClient, id : String) -> User raise
pub async fn ApiClient::delete_user(self : ApiClient, id : String) -> Unit raise
```

## SSE (Server-Sent Events)

```moonbit
app.get("/events", async fn(ctx) {
  ctx.sse_start()

  for i = 0; i < 10; i = i + 1 {
    ctx.write_raw("data: Event \{i}\n\n")
    // await sleep(1000)
  }

  ctx.end_response()
})
```

## Project Structure

```
src/
├── flame.mbt           # Flame app and routing
├── context.mbt         # Request/Response context
├── handler.mbt         # Handler type
├── compose.mbt         # Middleware composition
├── env.mbt             # Environment abstraction
├── execution_context.mbt  # Background tasks
├── router/             # Trie-based router
│   ├── types.mbt
│   └── trie/
├── middleware/         # Built-in middleware
│   ├── cors.mbt
│   ├── session.mbt
│   ├── rate_limit.mbt
│   └── ...
├── adapters/           # Platform adapters
│   └── cloudflare.mbt
└── codegen/            # Client code generator
    ├── types.mbt
    └── generator.mbt
```

## License

MIT

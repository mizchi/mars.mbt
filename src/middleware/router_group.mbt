///|
/// Router Group
/// Group routes with common prefix and middleware

///|
/// Route definition
pub(all) struct RouteDefinition {
  meth : String
  path : String
  handler : @flame.Handler
}

///|
/// Router group
pub(all) struct RouterGroup {
  prefix : String
  middlewares : Array[@flame.Handler]
  routes : Array[RouteDefinition]
  groups : Array[RouterGroup]
}

///|
/// Create a new router group
pub fn RouterGroup::new(prefix : String) -> RouterGroup {
  { prefix, middlewares: [], routes: [], groups: [] }
}

///|
/// Add middleware to group
pub fn RouterGroup::use_(
  self : RouterGroup,
  handler : @flame.Handler,
) -> RouterGroup {
  self.middlewares.push(handler)
  self
}

///|
/// Add GET route
pub fn RouterGroup::get(
  self : RouterGroup,
  path : String,
  handler : @flame.Handler,
) -> RouterGroup {
  self.routes.push({ meth: "GET", path, handler })
  self
}

///|
/// Add POST route
pub fn RouterGroup::post(
  self : RouterGroup,
  path : String,
  handler : @flame.Handler,
) -> RouterGroup {
  self.routes.push({ meth: "POST", path, handler })
  self
}

///|
/// Add PUT route
pub fn RouterGroup::put(
  self : RouterGroup,
  path : String,
  handler : @flame.Handler,
) -> RouterGroup {
  self.routes.push({ meth: "PUT", path, handler })
  self
}

///|
/// Add DELETE route
pub fn RouterGroup::delete(
  self : RouterGroup,
  path : String,
  handler : @flame.Handler,
) -> RouterGroup {
  self.routes.push({ meth: "DELETE", path, handler })
  self
}

///|
/// Add PATCH route
pub fn RouterGroup::patch(
  self : RouterGroup,
  path : String,
  handler : @flame.Handler,
) -> RouterGroup {
  self.routes.push({ meth: "PATCH", path, handler })
  self
}

///|
/// Create a sub-group
pub fn RouterGroup::group(self : RouterGroup, prefix : String) -> RouterGroup {
  let sub = RouterGroup::new(prefix)
  self.groups.push(sub)
  sub
}

///|
/// Apply group to Flame app
pub fn RouterGroup::apply(self : RouterGroup, app : @flame.Flame) -> Unit {
  apply_group(app, self, self.prefix, self.middlewares)
}

///|
/// Apply group recursively
fn apply_group(
  app : @flame.Flame,
  group : RouterGroup,
  prefix : String,
  parent_middlewares : Array[@flame.Handler],
) -> Unit {
  // Combine parent and current middlewares
  let middlewares : Array[@flame.Handler] = []
  for mw in parent_middlewares {
    middlewares.push(mw)
  }
  for mw in group.middlewares {
    middlewares.push(mw)
  }
  // Apply routes
  for route in group.routes {
    let full_path = join_paths(prefix, route.path)
    let wrapped = wrap_with_middlewares(route.handler, middlewares)
    match route.meth {
      "GET" => ignore(app.get(full_path, wrapped))
      "POST" => ignore(app.post(full_path, wrapped))
      "PUT" => ignore(app.put(full_path, wrapped))
      "DELETE" => ignore(app.delete(full_path, wrapped))
      "PATCH" => ignore(app.patch(full_path, wrapped))
      _ => ()
    }
  }
  // Apply sub-groups
  for sub in group.groups {
    let sub_prefix = join_paths(prefix, sub.prefix)
    apply_group(app, sub, sub_prefix, middlewares)
  }
}

///|
/// Join two paths
fn join_paths(a : String, b : String) -> String {
  if a.is_empty() {
    return b
  }
  if b.is_empty() {
    return a
  }
  let a_ends_slash = ends_with_char(a, '/')
  let b_starts_slash = starts_with_char(b, '/')
  if a_ends_slash && b_starts_slash {
    a + skip_first_char(b)
  } else if a_ends_slash || b_starts_slash {
    a + b
  } else {
    a + "/" + b
  }
}

///|
/// Check if string ends with char
fn ends_with_char(s : String, c : Char) -> Bool {
  let mut last = ' '
  for ch in s {
    last = ch
  }
  last == c
}

///|
/// Check if string starts with char
fn starts_with_char(s : String, c : Char) -> Bool {
  for ch in s {
    return ch == c
  }
  false
}

///|
/// Skip first character
fn skip_first_char(s : String) -> String {
  let buf = StringBuilder::new()
  let mut first = true
  for c in s {
    if first {
      first = false
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Wrap handler with middlewares
fn wrap_with_middlewares(
  handler : @flame.Handler,
  middlewares : Array[@flame.Handler],
) -> @flame.Handler {
  if middlewares.is_empty() {
    return handler
  }
  @flame.handler(async fn(ctx) {
    // Run middlewares
    for mw in middlewares {
      if ctx.is_response_sent() {
        return
      }
      let @flame.Handler(mw_fn) = mw
      mw_fn(ctx)
    }
    // Run handler
    if not(ctx.is_response_sent()) {
      let @flame.Handler(h) = handler
      h(ctx)
    }
  })
}

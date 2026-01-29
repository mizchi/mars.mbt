///|
/// Trailing Slash Middleware
/// Normalize URLs by adding or removing trailing slashes

///|
/// Trailing slash mode
pub(all) enum TrailingSlashMode {
  /// Add trailing slash if missing
  Add
  /// Remove trailing slash if present
  Remove
  /// Keep as-is (no normalization)
  Keep
} derive(Show, Eq)

///|
/// Trailing slash options
pub(all) struct TrailingSlashOptions {
  /// Mode for handling trailing slashes
  mode : TrailingSlashMode
  /// Redirect instead of rewrite (301 redirect)
  redirect : Bool
  /// Paths to exclude from normalization
  exclude : Array[String]
}

///|
/// Default: remove trailing slash with redirect
pub fn TrailingSlashOptions::default() -> TrailingSlashOptions {
  { mode: Remove, redirect: true, exclude: [] }
}

///|
/// Add trailing slash with redirect
pub fn TrailingSlashOptions::add() -> TrailingSlashOptions {
  { mode: Add, redirect: true, exclude: [] }
}

///|
/// Remove trailing slash with redirect
pub fn TrailingSlashOptions::remove() -> TrailingSlashOptions {
  { mode: Remove, redirect: true, exclude: [] }
}

///|
/// Check if path ends with slash
fn ends_with_slash(path : String) -> Bool {
  if path.is_empty() {
    return false
  }
  let chars : Array[Char] = []
  for c in path {
    chars.push(c)
  }
  chars[chars.length() - 1] == '/'
}

///|
/// Add trailing slash to path
fn add_slash(path : String) -> String {
  path + "/"
}

///|
/// Remove trailing slash from path
fn remove_slash(path : String) -> String {
  if path.is_empty() || path == "/" {
    return path
  }
  let chars : Array[Char] = []
  for c in path {
    chars.push(c)
  }
  if chars[chars.length() - 1] == '/' {
    let buf = StringBuilder::new()
    for i = 0; i < chars.length() - 1; i = i + 1 {
      buf.write_char(chars[i])
    }
    buf.to_string()
  } else {
    path
  }
}

///|
/// Check if path should be excluded
fn is_excluded(path : String, exclude : Array[String]) -> Bool {
  for pattern in exclude {
    if path_matches_exclude(path, pattern) {
      return true
    }
  }
  false
}

///|
/// Check if path matches exclude pattern
fn path_matches_exclude(path : String, pattern : String) -> Bool {
  // Simple prefix/exact matching
  if pattern.has_prefix("*") {
    // Suffix match
    let suffix = safe_substring_from(pattern, 1)
    path.contains(suffix)
  } else if ends_with_star(pattern) {
    // Prefix match
    let prefix = safe_substring(pattern, 0, pattern.length() - 1)
    path.has_prefix(prefix)
  } else {
    // Exact match
    path == pattern
  }
}

///|
/// Check if pattern ends with *
fn ends_with_star(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  chars[chars.length() - 1] == '*'
}

///|
/// Trailing slash middleware
pub fn trailing_slash(
  options? : TrailingSlashOptions = TrailingSlashOptions::default(),
) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    let path = ctx.path()
    // Skip root path
    if path == "/" {
      return
    }
    // Skip excluded paths
    if is_excluded(path, options.exclude) {
      return
    }
    // Check if path has file extension (skip normalization)
    if has_extension(path) {
      return
    }
    let has_slash = ends_with_slash(path)
    let new_path = match options.mode {
      Add =>
        if has_slash { path } else { add_slash(path) }
      Remove =>
        if has_slash { remove_slash(path) } else { path }
      Keep => path
    }
    if new_path != path && options.redirect {
      // Redirect to normalized URL
      ctx.set_header("Location", new_path)
      ctx.text("", status=301)
    }
  }
}

///|
/// Check if path has a file extension
fn has_extension(path : String) -> Bool {
  let chars : Array[Char] = []
  for c in path {
    chars.push(c)
  }
  // Find last dot and slash
  let mut last_dot = -1
  let mut last_slash = -1
  for i, c in chars {
    if c == '.' {
      last_dot = i
    } else if c == '/' {
      last_slash = i
    }
  }
  // Has extension if dot comes after last slash
  last_dot > last_slash && last_dot > 0
}

///|
/// Remove trailing slash middleware (convenience)
pub fn remove_trailing_slash() -> @flame.Handler {
  trailing_slash(options=TrailingSlashOptions::remove())
}

///|
/// Add trailing slash middleware (convenience)
pub fn add_trailing_slash() -> @flame.Handler {
  trailing_slash(options=TrailingSlashOptions::add())
}

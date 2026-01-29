///|
/// Split a URL path into segments
/// "/hello/world" => ["hello", "world"]
/// "/" => []
pub fn split_path(path : String) -> Array[String] {
  let paths : Array[String] = []
  let parts = path.split("/")
  for part in parts {
    let s = part.to_string()
    if s != "" {
      paths.push(s)
    }
  }
  paths
}

///|
/// Split a routing path with group marker preservation
/// This handles regex patterns in braces like :id{[0-9]+}
pub fn split_routing_path(route_path : String) -> Array[String] {
  let (groups, processed_path) = extract_groups_from_path(route_path)
  let paths = split_path(processed_path)
  replace_group_marks(paths, groups)
}

///|
/// Extract regex groups from path and replace them with markers
/// :id{[0-9]+} becomes :id@N where N is the index
fn extract_groups_from_path(path : String) -> (Array[(String, String)], String) {
  let groups : Array[(String, String)] = []
  let result = StringBuilder::new()
  let mut i = 0
  let len = path.length()
  while i < len {
    let c = path[i]
    if c == '{'.to_int().to_uint16() {
      let start = i
      let mut depth = 1
      i += 1
      while i < len && depth > 0 {
        let c2 = path[i]
        if c2 == '{'.to_int().to_uint16() {
          depth += 1
        } else if c2 == '}'.to_int().to_uint16() {
          depth -= 1
        }
        i += 1
      }
      let group_content = path
        .view(start_offset=start, end_offset=i)
        .to_string()
      let mark = "@\{start}"
      groups.push((mark, group_content))
      result.write_string(mark)
    } else {
      result.write_char(c.to_int().unsafe_to_char())
      i += 1
    }
  }
  (groups, result.to_string())
}

///|
/// Replace group markers back with their original content
fn replace_group_marks(
  paths : Array[String],
  groups : Array[(String, String)],
) -> Array[String] {
  let result : Array[String] = []
  for path in paths {
    let mut current = path
    for j = groups.length() - 1; j >= 0; j = j - 1 {
      let (mark, content) = groups[j]
      current = current.replace(old=mark, new=content)
    }
    result.push(current)
  }
  result
}

///|
/// Pattern types for URL matching
pub(all) enum Pattern {
  /// Wildcard pattern (*)
  Wildcard
  /// Parameter pattern (:name)
  Param(String)
  /// Parameter with regex pattern (:name{regex})
  /// Stores (name, regex_string, compiled_regex?)
  ParamWithRegex(String, String, @regexp.Regexp?)
}

///|
pub impl Show for Pattern with output(self, logger) {
  match self {
    Wildcard => logger.write_string("Wildcard")
    Param(name) => {
      logger.write_string("Param(")
      logger.write_string(name)
      logger.write_string(")")
    }
    ParamWithRegex(name, regex, _) => {
      logger.write_string("ParamWithRegex(")
      logger.write_string(name)
      logger.write_string(", ")
      logger.write_string(regex)
      logger.write_string(")")
    }
  }
}

///|
pub impl Eq for Pattern with equal(self, other) {
  match (self, other) {
    (Wildcard, Wildcard) => true
    (Param(a), Param(b)) => a == b
    (ParamWithRegex(a1, a2, _), ParamWithRegex(b1, b2, _)) =>
      a1 == b1 && a2 == b2
    _ => false
  }
}

///|
/// Find index of substring in string
fn index_of(s : String, needle : String) -> Int {
  let s_len = s.length()
  let n_len = needle.length()
  if n_len == 0 {
    return 0
  }
  if n_len > s_len {
    return -1
  }
  for i = 0; i <= s_len - n_len; i = i + 1 {
    let mut found = true
    for j = 0; j < n_len; j = j + 1 {
      if s[i + j] != needle[j] {
        found = false
        break
      }
    }
    if found {
      return i
    }
  }
  -1
}

///|
/// Compile a regex pattern, returning None on failure
fn compile_regex(pattern : String) -> @regexp.Regexp? {
  let full_pattern = "^" + pattern + "$"
  Some(@regexp.compile(full_pattern)) catch {
    _ => None
  }
}

///|
/// Get pattern from a path segment
/// Returns None for static segments
/// "*" => Wildcard
/// ":id" => Param("id")
/// ":id{[0-9]+}" => ParamWithRegex("id", "[0-9]+", compiled_regex)
pub fn get_pattern(label : String) -> Pattern? {
  if label == "*" {
    return Some(Wildcard)
  }
  if label.length() > 0 && label[0] == ':'.to_int().to_uint16() {
    let rest = label.view(start_offset=1).to_string()
    // Check for regex pattern in braces
    let brace_start = index_of(rest, "{")
    if brace_start >= 0 {
      let name = rest.view(end_offset=brace_start).to_string()
      // Extract regex (without braces)
      let regex_start = brace_start + 1
      let regex_end = rest.length() - 1 // Remove closing brace
      if regex_end > regex_start {
        let regex = rest
          .view(start_offset=regex_start, end_offset=regex_end)
          .to_string()
        // Pre-compile the regex at pattern creation time
        let compiled = compile_regex(regex)
        return Some(ParamWithRegex(name, regex, compiled))
      }
    }
    return Some(Param(rest))
  }
  None
}

///|
/// Check for optional parameters in path
/// "/api/animals/:type?" => ["/api/animals", "/api/animals/:type"]
/// Returns None if path doesn't end with optional parameter
pub fn check_optional_parameter(path : String) -> Array[String]? {
  let len = path.length()
  if len == 0 ||
    path[len - 1] != '?'.to_int().to_uint16() ||
    not(path.contains(":")) {
    return None
  }
  let segments = path.split("/")
  let results : Array[String] = []
  let base_path = StringBuilder::new()
  for segment in segments {
    let seg = segment.to_string()
    if seg == "" {
      continue
    }
    if not(seg.contains(":")) {
      base_path.write_char('/')
      base_path.write_string(seg)
    } else if seg.contains(":") {
      if seg.contains("?") {
        // Optional parameter found
        let current_base = base_path.to_string()
        if results.is_empty() && current_base == "" {
          results.push("/")
        } else {
          results.push(current_base)
        }
        // Remove trailing ? from segment
        let optional_segment = seg.view(end_offset=seg.length() - 1).to_string()
        base_path.write_char('/')
        base_path.write_string(optional_segment)
        results.push(base_path.to_string())
      } else {
        base_path.write_char('/')
        base_path.write_string(seg)
      }
    }
  }
  // Remove duplicates while preserving order
  let unique : Array[String] = []
  for r in results {
    if not(unique.contains(r)) {
      unique.push(r)
    }
  }
  if unique.is_empty() {
    None
  } else {
    Some(unique)
  }
}

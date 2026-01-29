///|
/// Handler set with metadata for scoring
pub(all) struct HandlerSet {
  handler_id : Int
  possible_keys : Array[String]
  score : Int
}

///|
/// Trie node for URL routing
pub(all) struct Node {
  /// Methods mapped to arrays of handler sets
  methods : Map[String, Array[HandlerSet]]
  /// Child nodes keyed by path segment
  children : Map[String, Node]
  /// Dynamic patterns at this node (for :param and * matching)
  patterns : Array[Pattern]
}

///|
/// Create a new empty node
pub fn Node::new() -> Node {
  { methods: Map::new(), children: Map::new(), patterns: [] }
}

///|
/// Create a new node with an initial method and handler
pub fn Node::with_handler(meth : String, handler_id : Int) -> Node {
  let methods : Map[String, Array[HandlerSet]] = Map::new()
  let handler_set : HandlerSet = { handler_id, possible_keys: [], score: 0 }
  methods.set(meth, [handler_set])
  { methods, children: Map::new(), patterns: [] }
}

///|
/// Insert a route into the trie
/// Returns the score (order) of the inserted handler
pub fn Node::insert(
  self : Node,
  meth : String,
  path : String,
  handler_id : Int,
  order : Int,
) -> Int {
  let mut cur_node = self
  let parts = split_routing_path(path)
  let possible_keys : Array[String] = []
  for i, part in parts {
    let next_part : String? = if i + 1 < parts.length() {
      Some(parts[i + 1])
    } else {
      None
    }
    let pattern = get_pattern(part)
    let key = match pattern {
      Some(Wildcard) => "*"
      Some(Param(name)) => {
        possible_keys.push(name)
        ":" + name
      }
      Some(ParamWithRegex(name, regex, _)) => {
        possible_keys.push(name)
        ":" + name + "{" + regex + "}"
      }
      None => part
    }

    // Check if child exists
    match cur_node.children.get(key) {
      Some(child) => {
        cur_node = child
        // Still add pattern info for matching
        match pattern {
          Some(Param(name)) | Some(ParamWithRegex(name, _, _)) =>
            if not(possible_keys.contains(name)) {
              possible_keys.push(name)
            }
          _ => ()
        }
      }
      None => {
        // Create new child
        let child = Node::new()
        cur_node.children.set(key, child)

        // Add pattern for dynamic matching
        match pattern {
          Some(p) => cur_node.patterns.push(p)
          None => ()
        }
        cur_node = child
      }
    }
    ignore(next_part)
  }

  // Add handler to the final node
  let handler_set : HandlerSet = {
    handler_id,
    possible_keys: dedupe_strings(possible_keys),
    score: order,
  }
  match cur_node.methods.get(meth) {
    Some(handlers) => handlers.push(handler_set)
    None => cur_node.methods.set(meth, [handler_set])
  }
  order
}

///|
/// Remove duplicate strings while preserving order
fn dedupe_strings(arr : Array[String]) -> Array[String] {
  let result : Array[String] = []
  for s in arr {
    if not(result.contains(s)) {
      result.push(s)
    }
  }
  result
}

///|
/// Handler with extracted parameters
pub(all) struct HandlerParamsSet {
  handler_id : Int
  params : @router.Params
  score : Int
  possible_keys : Array[String]
}

///|
/// Search for matching handlers
pub fn Node::search(
  self : Node,
  meth : String,
  path : String,
) -> Array[HandlerParamsSet] {
  let handler_sets : Array[HandlerParamsSet] = []
  let parts = split_path(path)
  search_recursive(self, meth, parts, 0, @router.Params::new(), handler_sets)

  // Sort by score
  if handler_sets.length() > 1 {
    handler_sets.sort_by(fn(a, b) { a.score - b.score })
  }
  handler_sets
}

///|
/// Recursive search helper
fn search_recursive(
  node : Node,
  meth : String,
  parts : Array[String],
  index : Int,
  params : @router.Params,
  results : Array[HandlerParamsSet],
) -> Unit {
  if index >= parts.length() {
    // At the end of path, collect handlers
    collect_handlers(node, meth, params, results)

    // Also check for wildcard child that matches empty
    match node.children.get("*") {
      Some(wildcard_child) =>
        collect_handlers(wildcard_child, meth, params, results)
      None => ()
    }
    return
  }
  let part = parts[index]
  let is_last = index == parts.length() - 1

  // Try exact match first
  match node.children.get(part) {
    Some(child) =>
      if is_last {
        // Check for wildcard at end: '/hello/*' => match '/hello'
        match child.children.get("*") {
          Some(wildcard_child) =>
            collect_handlers(wildcard_child, meth, params, results)
          None => ()
        }
        collect_handlers(child, meth, params, results)
      } else {
        search_recursive(child, meth, parts, index + 1, params, results)
      }
    None => ()
  }

  // Try pattern matches
  for pattern in node.patterns {
    match pattern {
      Wildcard =>
        // Wildcard behavior depends on whether it's terminal or not
        match node.children.get("*") {
          Some(wildcard_child) =>
            // If wildcard_child has children, it's a middle wildcard (e.g., /wild/*/card)
            // Match one segment and continue recursing
            if wildcard_child.children.length() > 0 {
              search_recursive(
                wildcard_child,
                meth,
                parts,
                index + 1,
                params,
                results,
              )
            } else {
              // Terminal wildcard - matches all remaining, collect immediately
              collect_handlers(wildcard_child, meth, params, results)
            }
          None => ()
        }
      Param(name) => {
        let key = ":" + name
        match node.children.get(key) {
          Some(child) => {
            let new_params = params.with_param(name, part)
            if is_last {
              collect_handlers(child, meth, new_params, results)
              // Check for trailing wildcard
              match child.children.get("*") {
                Some(wildcard_child) =>
                  collect_handlers(wildcard_child, meth, new_params, results)
                None => ()
              }
            } else {
              search_recursive(
                child,
                meth,
                parts,
                index + 1,
                new_params,
                results,
              )
            }
          }
          None => ()
        }
      }
      ParamWithRegex(name, regex, compiled) => {
        let key = ":" + name + "{" + regex + "}"
        match node.children.get(key) {
          Some(child) =>
            // Use pre-compiled regex for faster matching
            if matches_compiled_regex(part, compiled) {
              let new_params = params.with_param(name, part)
              if is_last {
                collect_handlers(child, meth, new_params, results)
              } else {
                search_recursive(
                  child,
                  meth,
                  parts,
                  index + 1,
                  new_params,
                  results,
                )
              }
            }
          None => ()
        }
      }
    }
  }
}

///|
/// Check if string matches pre-compiled regex
fn matches_compiled_regex(s : String, compiled : @regexp.Regexp?) -> Bool {
  match compiled {
    Some(re) =>
      match re.match_(s) {
        Some(_) => true
        None => false
      }
    None => false
  }
}

///|
/// Collect handlers from a node for a given method
fn collect_handlers(
  node : Node,
  meth : String,
  params : @router.Params,
  results : Array[HandlerParamsSet],
) -> Unit {
  // Check specific method
  match node.methods.get(meth) {
    Some(handlers) =>
      for h in handlers {
        results.push({
          handler_id: h.handler_id,
          params: params.clone(),
          score: h.score,
          possible_keys: h.possible_keys,
        })
      }
    None => ()
  }

  // Also check ALL method
  if meth != "ALL" {
    match node.methods.get("ALL") {
      Some(handlers) =>
        for h in handlers {
          results.push({
            handler_id: h.handler_id,
            params: params.clone(),
            score: h.score,
            possible_keys: h.possible_keys,
          })
        }
      None => ()
    }
  }
}

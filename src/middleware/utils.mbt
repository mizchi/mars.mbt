///|
/// Common utilities for middleware

///|
/// Safe substring extraction (start to end)
pub fn safe_substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in s {
    if i >= start && i < end {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Safe substring from start to end of string
pub fn safe_substring_from(s : String, start : Int) -> String {
  let buf = StringBuilder::new()
  let mut i = 0
  for c in s {
    if i >= start {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.to_string()
}

///|
/// Safe trim whitespace
pub fn safe_trim(s : String) -> String {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  // Find start
  let mut start = 0
  while start < chars.length() && is_whitespace(chars[start]) {
    start = start + 1
  }
  // Find end
  let mut end = chars.length()
  while end > start && is_whitespace(chars[end - 1]) {
    end = end - 1
  }
  // Build result
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// Check if character is whitespace
fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Convert character to lowercase
pub fn char_to_lower(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    (c.to_int() + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
/// Convert string to lowercase
pub fn string_to_lower(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    buf.write_char(char_to_lower(c))
  }
  buf.to_string()
}

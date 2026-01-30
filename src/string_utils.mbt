///|
/// Common string utilities for Mars framework

///|
/// Extract substring from start to end index
pub fn substring(s : String, start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i, c in s {
    if i >= start && i < end {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Extract substring from start to end of string
pub fn substring_from(s : String, start : Int) -> String {
  let buf = StringBuilder::new()
  for i, c in s {
    if i >= start {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

///|
/// Split string by separator character
pub fn split_by_char(s : String, sep : Char) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  for c in s {
    if c == sep {
      result.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  result.push(current.to_string())
  result
}

///|
/// Find first occurrence of character in string, returns -1 if not found
pub fn find_char(s : String, c : Char) -> Int {
  for i, ch in s {
    if ch == c {
      return i
    }
  }
  -1
}

///|
/// Trim whitespace from both ends of string
pub fn trim(s : String) -> String {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  // Find start (skip leading whitespace)
  let mut start = 0
  while start < chars.length() && is_whitespace(chars[start]) {
    start = start + 1
  }
  // Find end (skip trailing whitespace)
  let mut end = chars.length()
  while end > start && is_whitespace(chars[end - 1]) {
    end = end - 1
  }
  // Build result
  let buf = StringBuilder::new()
  for i in start..<end {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// Check if character is whitespace
pub fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// URL decode a string (handles %XX and + encoding)
pub fn url_decode(s : String) -> String {
  let buf = StringBuilder::new()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '%' && i + 2 < chars.length() {
      let high = hex_to_int(chars[i + 1])
      let low = hex_to_int(chars[i + 2])
      if high >= 0 && low >= 0 {
        buf.write_char(((high << 4) | low).unsafe_to_char())
        i = i + 3
        continue
      }
    } else if c == '+' {
      buf.write_char(' ')
      i = i + 1
      continue
    }
    buf.write_char(c)
    i = i + 1
  }
  buf.to_string()
}

///|
/// Convert hex character to integer, returns -1 for invalid
pub fn hex_to_int(c : Char) -> Int {
  match c {
    '0'..='9' => c.to_int() - '0'.to_int()
    'a'..='f' => c.to_int() - 'a'.to_int() + 10
    'A'..='F' => c.to_int() - 'A'.to_int() + 10
    _ => -1
  }
}

///|
/// Convert character to lowercase
pub fn char_to_lower(c : Char) -> Char {
  match c {
    'A'..='Z' => (c.to_int() + 32).unsafe_to_char()
    _ => c
  }
}

///|
/// Convert string to lowercase
pub fn to_lower(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    buf.write_char(char_to_lower(c))
  }
  buf.to_string()
}

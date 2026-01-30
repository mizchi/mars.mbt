///|
/// Common utilities for middleware
/// Re-export string utilities from main package for convenience

///|
/// Safe substring extraction (start to end)
/// @deprecated Use @mars.substring instead
pub fn safe_substring(s : String, start : Int, end : Int) -> String {
  @mars.substring(s, start, end)
}

///|
/// Safe substring from start to end of string
/// @deprecated Use @mars.substring_from instead
pub fn safe_substring_from(s : String, start : Int) -> String {
  @mars.substring_from(s, start)
}

///|
/// Safe trim whitespace
/// @deprecated Use @mars.trim instead
pub fn safe_trim(s : String) -> String {
  @mars.trim(s)
}

///|
/// Convert character to lowercase
/// @deprecated Use @mars.char_to_lower instead
pub fn char_to_lower(c : Char) -> Char {
  @mars.char_to_lower(c)
}

///|
/// Convert string to lowercase
/// @deprecated Use @mars.to_lower instead
pub fn string_to_lower(s : String) -> String {
  @mars.to_lower(s)
}

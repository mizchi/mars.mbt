///|
/// Form Data Parser
/// Parse application/x-www-form-urlencoded and multipart/form-data

///|
/// Form field value
pub(all) enum FormValue {
  Text(String)
  File(FormFile)
}

///|
/// Form file
pub(all) struct FormFile {
  filename : String
  content_type : String
  data : Bytes
}

///|
/// Parsed form data
pub(all) struct FormData {
  fields : Map[String, Array[FormValue]]
}

///|
/// Create empty form data
pub fn FormData::new() -> FormData {
  { fields: {} }
}

///|
/// Get text value
pub fn FormData::get(self : FormData, key : String) -> String? {
  match self.fields.get(key) {
    Some(values) =>
      if values.length() > 0 {
        match values[0] {
          Text(s) => Some(s)
          File(_) => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
/// Get all text values for a key
pub fn FormData::get_all(self : FormData, key : String) -> Array[String] {
  let result : Array[String] = []
  match self.fields.get(key) {
    Some(values) =>
      for v in values {
        match v {
          Text(s) => result.push(s)
          File(_) => ()
        }
      }
    None => ()
  }
  result
}

///|
/// Get file value
pub fn FormData::get_file(self : FormData, key : String) -> FormFile? {
  match self.fields.get(key) {
    Some(values) =>
      if values.length() > 0 {
        match values[0] {
          File(f) => Some(f)
          Text(_) => None
        }
      } else {
        None
      }
    None => None
  }
}

///|
/// Get all file values for a key
pub fn FormData::get_files(self : FormData, key : String) -> Array[FormFile] {
  let result : Array[FormFile] = []
  match self.fields.get(key) {
    Some(values) =>
      for v in values {
        match v {
          File(f) => result.push(f)
          Text(_) => ()
        }
      }
    None => ()
  }
  result
}

///|
/// Add text field
pub fn FormData::add(self : FormData, key : String, value : String) -> Unit {
  let arr = match self.fields.get(key) {
    Some(a) => a
    None => {
      let a : Array[FormValue] = []
      self.fields.set(key, a)
      a
    }
  }
  arr.push(FormValue::Text(value))
}

///|
/// Add file field
pub fn FormData::add_file(
  self : FormData,
  key : String,
  file : FormFile,
) -> Unit {
  let arr = match self.fields.get(key) {
    Some(a) => a
    None => {
      let a : Array[FormValue] = []
      self.fields.set(key, a)
      a
    }
  }
  arr.push(FormValue::File(file))
}

///|
/// Parse URL-encoded form data
pub fn parse_form_urlencoded(body : String) -> FormData {
  let form = FormData::new()
  let pairs = split_form_string(body, '&')
  for pair in pairs {
    let eq_pos = find_form_char(pair, '=')
    if eq_pos >= 0 {
      let key = url_decode_form(extract_form_substring(pair, 0, eq_pos))
      let value = url_decode_form(
        extract_form_substring(pair, eq_pos + 1, pair.length()),
      )
      form.add(key, value)
    }
  }
  form
}

///|
/// Parse multipart form data
pub fn parse_multipart(body : String, boundary : String) -> FormData {
  let form = FormData::new()
  let delimiter = "--" + boundary
  let parts = split_multipart(body, delimiter)
  for part in parts {
    if part.is_empty() || part == "--" || part == "--\r\n" {
      continue
    }
    parse_multipart_part(part, form)
  }
  form
}

///|
/// Parse a single multipart part
fn parse_multipart_part(part : String, form : FormData) -> Unit {
  // Find header/body separator
  let sep_pos = find_double_newline(part)
  if sep_pos < 0 {
    return
  }
  let headers = extract_form_substring(part, 0, sep_pos)
  let body_start = skip_newlines(part, sep_pos)
  let body = extract_form_substring(part, body_start, part.length())
  // Parse Content-Disposition header
  let name = extract_header_param(headers, "name")
  if name.is_empty() {
    return
  }
  let filename = extract_header_param(headers, "filename")
  if filename.is_empty() {
    // Text field
    form.add(name, trim_crlf(body))
  } else {
    // File field
    let content_type = extract_content_type(headers)
    let file = {
      filename,
      content_type,
      data: string_to_bytes_form(trim_crlf(body)),
    }
    form.add_file(name, file)
  }
}

///|
/// Extract header parameter value
fn extract_header_param(headers : String, param : String) -> String {
  let search = param + "=\""
  let pos = find_substring(headers, search)
  if pos < 0 {
    return ""
  }
  let start = pos + search.length()
  let end = find_char_from(headers, '"', start)
  if end < 0 {
    return ""
  }
  extract_form_substring(headers, start, end)
}

///|
/// Extract Content-Type header
fn extract_content_type(headers : String) -> String {
  let search = "Content-Type: "
  let pos = find_substring(headers, search)
  if pos < 0 {
    return "application/octet-stream"
  }
  let start = pos + search.length()
  let end = find_newline_from(headers, start)
  if end < 0 {
    extract_form_substring(headers, start, headers.length())
  } else {
    trim_crlf(extract_form_substring(headers, start, end))
  }
}

///|
/// Find substring position
fn find_substring(s : String, sub : String) -> Int {
  let s_chars : Array[Char] = []
  let sub_chars : Array[Char] = []
  for c in s {
    s_chars.push(c)
  }
  for c in sub {
    sub_chars.push(c)
  }
  if sub_chars.is_empty() {
    return 0
  }
  for i = 0; i <= s_chars.length() - sub_chars.length(); i = i + 1 {
    let mut match_ = true
    for j = 0; j < sub_chars.length(); j = j + 1 {
      if s_chars[i + j] != sub_chars[j] {
        match_ = false
        break
      }
    }
    if match_ {
      return i
    }
  }
  -1
}

///|
/// Find character from position
fn find_char_from(s : String, c : Char, from : Int) -> Int {
  let mut i = 0
  for ch in s {
    if i >= from && ch == c {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Find newline from position
fn find_newline_from(s : String, from : Int) -> Int {
  let mut i = 0
  for ch in s {
    if i >= from && (ch == '\n' || ch == '\r') {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Find double newline position
fn find_double_newline(s : String) -> Int {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  for i = 0; i < chars.length() - 1; i = i + 1 {
    if chars[i] == '\n' && chars[i + 1] == '\n' {
      return i
    }
    if i < chars.length() - 3 &&
      chars[i] == '\r' &&
      chars[i + 1] == '\n' &&
      chars[i + 2] == '\r' &&
      chars[i + 3] == '\n' {
      return i
    }
  }
  -1
}

///|
/// Skip newlines and return new position
fn skip_newlines(s : String, from : Int) -> Int {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let mut i = from
  while i < chars.length() && (chars[i] == '\r' || chars[i] == '\n') {
    i = i + 1
  }
  i
}

///|
/// Split string by delimiter for multipart
fn split_multipart(s : String, delimiter : String) -> Array[String] {
  let result : Array[String] = []
  let del_chars : Array[Char] = []
  for c in delimiter {
    del_chars.push(c)
  }
  let s_chars : Array[Char] = []
  for c in s {
    s_chars.push(c)
  }
  let mut start = 0
  let mut i = 0
  while i <= s_chars.length() - del_chars.length() {
    let mut match_ = true
    for j = 0; j < del_chars.length(); j = j + 1 {
      if s_chars[i + j] != del_chars[j] {
        match_ = false
        break
      }
    }
    if match_ {
      if i > start {
        result.push(extract_form_substring(s, start, i))
      }
      i = i + del_chars.length()
      start = i
    } else {
      i = i + 1
    }
  }
  if start < s_chars.length() {
    result.push(extract_form_substring(s, start, s_chars.length()))
  }
  result
}

///|
/// Trim CRLF from end
fn trim_crlf(s : String) -> String {
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let mut end = chars.length()
  while end > 0 && (chars[end - 1] == '\r' || chars[end - 1] == '\n') {
    end = end - 1
  }
  let buf = StringBuilder::new()
  for i = 0; i < end; i = i + 1 {
    buf.write_char(chars[i])
  }
  buf.to_string()
}

///|
/// Split string by char for form parsing
fn split_form_string(s : String, sep : Char) -> Array[String] {
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
/// Find char in string for form parsing
fn find_form_char(s : String, c : Char) -> Int {
  for i, ch in s {
    if ch == c {
      return i
    }
  }
  -1
}

///|
/// Extract substring for form parsing
fn extract_form_substring(s : String, start : Int, end : Int) -> String {
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
/// URL decode for form parsing
fn url_decode_form(s : String) -> String {
  let buf = StringBuilder::new()
  let chars : Array[Char] = []
  for c in s {
    chars.push(c)
  }
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '%' && i + 2 < chars.length() {
      let high = hex_to_int_form(chars[i + 1])
      let low = hex_to_int_form(chars[i + 2])
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
/// Convert hex char to int for form parsing
fn hex_to_int_form(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// Convert string to bytes for form file
fn string_to_bytes_form(s : String) -> Bytes {
  let bytes = FixedArray::make(s.length(), b'\x00')
  for i, c in s {
    bytes[i] = c.to_int().to_byte()
  }
  Bytes::from_array(bytes)
}

///|
/// Parse form from context
pub async fn parse_form(ctx : @flame.Context) -> FormData {
  let content_type = ctx.header("Content-Type").unwrap_or("")
  let body = ctx.body()
  if content_type.contains("multipart/form-data") {
    let boundary = extract_boundary(content_type)
    parse_multipart(body, boundary)
  } else {
    parse_form_urlencoded(body)
  }
}

///|
/// Extract boundary from Content-Type
fn extract_boundary(content_type : String) -> String {
  let search = "boundary="
  let pos = find_substring(content_type, search)
  if pos < 0 {
    return ""
  }
  let start = pos + search.length()
  extract_form_substring(content_type, start, content_type.length())
}

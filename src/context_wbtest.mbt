///|
test "parse_query_string empty" {
  let result = parse_query_string("/path")
  inspect(result.length(), content="0")
}

///|
test "parse_query_string single param" {
  let result = parse_query_string("/path?name=alice")
  inspect(result.get("name"), content="Some(\"alice\")")
}

///|
test "parse_query_string multiple params" {
  let result = parse_query_string("/path?name=alice&age=25")
  inspect(result.get("name"), content="Some(\"alice\")")
  inspect(result.get("age"), content="Some(\"25\")")
}

///|
test "parse_query_string url encoded" {
  let result = parse_query_string("/path?message=hello%20world")
  inspect(result.get("message"), content="Some(\"hello world\")")
}

///|
test "parse_query_string plus as space" {
  let result = parse_query_string("/path?message=hello+world")
  inspect(result.get("message"), content="Some(\"hello world\")")
}

///|
test "parse_query_string special chars" {
  let result = parse_query_string("/path?email=user%40example.com")
  inspect(result.get("email"), content="Some(\"user@example.com\")")
}

///|
test "parse_query_string empty value" {
  let result = parse_query_string("/path?empty=")
  inspect(result.get("empty"), content="Some(\"\")")
}

///|
test "parse_query_string japanese encoded" {
  // %E3%81%82 is UTF-8 encoding of あ
  let result = parse_query_string("/path?name=%E3%81%82")
  inspect(result.get("name") is Some(_), content="true")
}

///|
test "parse_cookies empty" {
  let result = parse_cookies("")
  inspect(result.length(), content="0")
}

///|
test "parse_cookies single" {
  let result = parse_cookies("session=abc123")
  inspect(result.get("session"), content="Some(\"abc123\")")
}

///|
test "parse_cookies multiple" {
  let result = parse_cookies("session=abc123; user=alice")
  inspect(result.get("session"), content="Some(\"abc123\")")
  inspect(result.get("user"), content="Some(\"alice\")")
}

///|
test "parse_cookies with spaces" {
  let result = parse_cookies("  session=abc123  ;  user=alice  ")
  inspect(result.get("session"), content="Some(\"abc123\")")
  inspect(result.get("user"), content="Some(\"alice\")")
}

///|
test "build_set_cookie basic" {
  let cookie = build_set_cookie(
    "session",
    "abc123",
    max_age=3600,
    path="/",
    http_only=true,
    same_site="Lax",
  )
  inspect(cookie.contains("session=abc123"), content="true")
  inspect(cookie.contains("Path=/"), content="true")
  inspect(cookie.contains("Max-Age=3600"), content="true")
  inspect(cookie.contains("HttpOnly"), content="true")
  inspect(cookie.contains("SameSite=Lax"), content="true")
}

///|
test "build_set_cookie without http_only" {
  let cookie = build_set_cookie(
    "token",
    "xyz",
    max_age=86400,
    path="/api",
    http_only=false,
    same_site="Strict",
  )
  inspect(cookie.contains("token=xyz"), content="true")
  inspect(cookie.contains("Path=/api"), content="true")
  inspect(cookie.contains("HttpOnly"), content="false")
  inspect(cookie.contains("SameSite=Strict"), content="true")
}

///|
test "url_decode simple" {
  inspect(url_decode("hello"), content="hello")
}

///|
test "url_decode with percent encoding" {
  inspect(url_decode("hello%20world"), content="hello world")
}

///|
test "url_decode with plus" {
  inspect(url_decode("hello+world"), content="hello world")
}

///|
test "url_decode special chars" {
  inspect(url_decode("%40%23%24"), content="@#$")
}

///|
test "url_decode mixed" {
  inspect(url_decode("a%20b+c%21"), content="a b c!")
}

///|
test "hex_to_int digits" {
  inspect(hex_to_int('0'), content="0")
  inspect(hex_to_int('5'), content="5")
  inspect(hex_to_int('9'), content="9")
}

///|
test "hex_to_int lowercase" {
  inspect(hex_to_int('a'), content="10")
  inspect(hex_to_int('f'), content="15")
}

///|
test "hex_to_int uppercase" {
  inspect(hex_to_int('A'), content="10")
  inspect(hex_to_int('F'), content="15")
}

///|
test "hex_to_int invalid" {
  inspect(hex_to_int('g'), content="-1")
  inspect(hex_to_int('z'), content="-1")
}

///|
test "extract_substring basic" {
  inspect(extract_substring("hello world", 0, 5), content="hello")
  inspect(extract_substring("hello world", 6, 11), content="world")
}

///|
test "extract_substring empty" {
  inspect(extract_substring("hello", 2, 2), content="")
}

///|
test "split_string basic" {
  let parts = split_string("a,b,c", ',')
  inspect(parts.length(), content="3")
  inspect(parts[0], content="a")
  inspect(parts[1], content="b")
  inspect(parts[2], content="c")
}

///|
test "split_string no separator" {
  let parts = split_string("hello", ',')
  inspect(parts.length(), content="1")
  inspect(parts[0], content="hello")
}

///|
test "split_string empty parts" {
  let parts = split_string("a,,c", ',')
  inspect(parts.length(), content="3")
  inspect(parts[1], content="")
}

///|
test "find_char_in_string found" {
  inspect(find_char_in_string("hello=world", '='), content="5")
}

///|
test "find_char_in_string not found" {
  inspect(find_char_in_string("hello", '='), content="-1")
}

///|
test "find_char_in_string first occurrence" {
  inspect(find_char_in_string("a=b=c", '='), content="1")
}

///|
test "trim_string basic" {
  inspect(trim_string("  hello  "), content="hello")
}

///|
test "trim_string tabs" {
  inspect(trim_string("\t\thello\t\t"), content="hello")
}

///|
test "trim_string no whitespace" {
  inspect(trim_string("hello"), content="hello")
}

///|
test "trim_string all whitespace" {
  inspect(trim_string("   "), content="")
}

///|
test "trim_string mixed" {
  inspect(trim_string(" \t hello world \t "), content="hello world")
}

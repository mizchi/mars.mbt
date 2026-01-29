///|
/// Middleware tests

///|
test "rate_limit_clear" {
  rate_limit_clear()
  let (count, _, _) = rate_limit_info("test")
  inspect(count, content="0")
}

///|
test "rate_limit_tick" {
  rate_limit_clear()
  rate_limit_tick()
  rate_limit_tick()
  // Window should be 2 now
}

///|
test "ip_matches_pattern exact" {
  inspect(ip_matches_pattern("192.168.1.1", "192.168.1.1"), content="true")
  inspect(ip_matches_pattern("192.168.1.1", "192.168.1.2"), content="false")
}

///|
test "ip_matches_pattern wildcard" {
  inspect(ip_matches_pattern("192.168.1.1", "192.168.1.*"), content="true")
  inspect(ip_matches_pattern("192.168.1.100", "192.168.1.*"), content="true")
  inspect(ip_matches_pattern("192.168.2.1", "192.168.1.*"), content="false")
  inspect(ip_matches_pattern("10.0.0.1", "10.*.*.*"), content="true")
}

///|
test "ip_matches_pattern cidr" {
  inspect(ip_matches_pattern("10.0.0.1", "10.0.0.0/8"), content="true")
  inspect(ip_matches_pattern("10.255.255.255", "10.0.0.0/8"), content="true")
  inspect(ip_matches_pattern("11.0.0.1", "10.0.0.0/8"), content="false")
  inspect(ip_matches_pattern("192.168.1.1", "192.168.1.0/24"), content="true")
  inspect(ip_matches_pattern("192.168.2.1", "192.168.1.0/24"), content="false")
}

///|
test "compute_hmac_sha256" {
  let hash = compute_hmac_sha256("secret", "message")
  // Just verify it produces a hex string of correct length (64 chars for SHA256)
  inspect(hash.length(), content="64")
}

///|
test "verify_webhook_hmac" {
  let secret = "mysecret"
  let body = "test payload"
  let signature = compute_hmac_sha256(secret, body)
  inspect(verify_webhook_hmac(secret, signature, body), content="Valid")
  inspect(
    verify_webhook_hmac(secret, "wrong", body),
    content="Invalid(\"Signature mismatch\")",
  )
}

///|
test "verify_github_webhook" {
  let secret = "mysecret"
  let body = "test payload"
  let signature = compute_hmac_sha256(secret, body)
  let header = "sha256=" + signature
  inspect(verify_github_webhook(secret, header, body), content="Valid")
  inspect(
    verify_github_webhook(secret, "invalid", body),
    content="Invalid(\"Invalid signature format\")",
  )
}

///|
test "oauth2_authorization_url" {
  let config = oauth2_github(
    "client123", "secret456", "http://localhost/callback",
  )
  let url = oauth2_authorization_url(config, "xyz")
  inspect(
    url.has_prefix("https://github.com/login/oauth/authorize?"),
    content="true",
  )
  inspect(url.contains("client_id=client123"), content="true")
  inspect(url.contains("state=xyz"), content="true")
}

///|
test "oauth2_generate_state" {
  let state = oauth2_generate_state()
  // Should be 32 hex characters (16 bytes)
  inspect(state.length(), content="32")
}

///|
test "oauth2_parse_token" {
  let json = "{\"access_token\":\"abc123\",\"token_type\":\"Bearer\",\"expires_in\":3600}"
  let result = oauth2_parse_token(json)
  guard result is Ok(token) else {
    fail("Expected Ok result")
    return
  }
  inspect(token.access_token, content="abc123")
  inspect(token.token_type, content="Bearer")
  inspect(token.expires_in, content="3600")
}

///|
test "oauth2_parse_token invalid" {
  let result = oauth2_parse_token("invalid json")
  inspect(result is Err(_), content="true")
}

///|
test "session_cookie_header" {
  let options = SessionOptions::default("secret")
  let header = session_cookie_header(options, "sess_123")
  inspect(header.has_prefix("session=sess_123."), content="true")
  inspect(header.contains("HttpOnly"), content="true")
  inspect(header.contains("SameSite=Lax"), content="true")
  // Default mode should NOT have Secure flag
  inspect(header.contains("Secure"), content="false")
}

///|
test "session_cookie_header_production" {
  let options = SessionOptions::production("secret")
  let header = session_cookie_header(options, "sess_123")
  inspect(header.has_prefix("session=sess_123."), content="true")
  inspect(header.contains("HttpOnly"), content="true")
  // Production mode SHOULD have Secure flag
  inspect(header.contains("Secure"), content="true")
}

///|
test "session_destroy" {
  let options = SessionOptions::default("secret")
  let header = session_destroy(options)
  inspect(header.contains("Max-Age=0"), content="true")
}

///|
test "safe_substring" {
  inspect(safe_substring("hello world", 0, 5), content="hello")
  inspect(safe_substring("hello world", 6, 11), content="world")
  inspect(safe_substring_from("hello world", 6), content="world")
}

///|
test "safe_trim" {
  inspect(safe_trim("  hello  "), content="hello")
  inspect(safe_trim("hello"), content="hello")
  inspect(safe_trim("  "), content="")
}

///|
test "cors_options_default" {
  let opts = CorsOptions::default()
  inspect(opts.origin, content="*")
  inspect(opts.credentials, content="false")
}

///|
test "cors_options_with_credentials" {
  let opts = CorsOptions::with_credentials("https://example.com")
  inspect(opts.origin, content="https://example.com")
  inspect(opts.credentials, content="true")
}

///|
test "validation_result_new" {
  let result = ValidationResult::new()
  inspect(result.is_valid(), content="true")
}

///|
test "validation_result_add_error" {
  let result = ValidationResult::new()
  result.add_error(ValidationError::Required("name"))
  inspect(result.is_valid(), content="false")
  inspect(result.messages()[0], content="name is required")
}

///|
test "validator_required_string" {
  let json = Json::object({ "name": Json::string("John") })
  let result = Validator::new(json).required_string("name").validate()
  inspect(result.is_valid(), content="true")
}

///|
test "validator_required_string_missing" {
  let json = Json::object({})
  let result = Validator::new(json).required_string("name").validate()
  inspect(result.is_valid(), content="false")
}

///|
test "validator_min_length" {
  let json = Json::object({ "password": Json::string("ab") })
  let result = Validator::new(json).min_length("password", 3).validate()
  inspect(result.is_valid(), content="false")
}

///|
test "validator_email" {
  let json = Json::object({ "email": Json::string("test@example.com") })
  let result = Validator::new(json).email("email").validate()
  inspect(result.is_valid(), content="true")
}

///|
test "validator_email_invalid" {
  let json = Json::object({ "email": Json::string("invalid") })
  let result = Validator::new(json).email("email").validate()
  inspect(result.is_valid(), content="false")
}

///|
test "sse_event_format_simple" {
  let event = SseEvent::data("hello")
  let formatted = event.format()
  inspect(formatted.contains("data: hello"), content="true")
}

///|
test "sse_event_format_with_type" {
  let event = SseEvent::new("message", "hello")
  let formatted = event.format()
  inspect(formatted.contains("event: message"), content="true")
  inspect(formatted.contains("data: hello"), content="true")
}

///|
test "sse_event_format_full" {
  let event = SseEvent::full("update", "data", "123", 5000)
  let formatted = event.format()
  inspect(formatted.contains("id: 123"), content="true")
  inspect(formatted.contains("event: update"), content="true")
  inspect(formatted.contains("retry: 5000"), content="true")
}

///|
test "secure_headers_default" {
  let opts = SecureHeadersOptions::default()
  inspect(opts.hsts, content="true")
  inspect(opts.no_sniff, content="true")
  inspect(opts.frame_options, content="SAMEORIGIN")
}

///|
test "secure_headers_strict" {
  let opts = SecureHeadersOptions::strict()
  inspect(opts.frame_options, content="DENY")
  inspect(opts.csp.is_empty(), content="false")
}

///|
test "request_id_generate" {
  request_id_reset()
  let opts = RequestIdOptions::default()
  // Just verify the function exists and works
  inspect(opts.prefix, content="req-")
}

///|
test "timeout_options_default" {
  let opts = TimeoutOptions::default()
  inspect(opts.timeout_ms, content="30000")
  inspect(opts.status, content="408")
}

///|
test "http_error_bad_request" {
  let err = HttpError::bad_request()
  inspect(err.status, content="400")
  inspect(err.message, content="Bad Request")
}

///|
test "http_error_not_found" {
  let err = HttpError::not_found()
  inspect(err.status, content="404")
}

///|
test "http_error_with_details" {
  let err = HttpError::with_details(500, "Error", "Stack trace")
  inspect(err.details, content="Stack trace")
}

///|
test "router_group_new" {
  let group = RouterGroup::new("/api")
  inspect(group.prefix, content="/api")
  inspect(group.routes.length(), content="0")
}

///|
test "form_data_parse_urlencoded" {
  let form = parse_form_urlencoded("name=John&age=30")
  inspect(form.get("name"), content="Some(\"John\")")
  inspect(form.get("age"), content="Some(\"30\")")
}

///|
test "form_data_url_decode" {
  let form = parse_form_urlencoded("msg=Hello%20World")
  inspect(form.get("msg"), content="Some(\"Hello World\")")
}

///|
test "form_data_get_all" {
  let form = parse_form_urlencoded("tag=a&tag=b&tag=c")
  let tags = form.get_all("tag")
  inspect(tags.length(), content="3")
}

///|
test "mock_request_get" {
  let req = MockRequest::get("/users")
  inspect(req.meth, content="GET")
  inspect(req.path, content="/users")
}

///|
test "mock_request_post_json" {
  let req = MockRequest::post("/users").json(
    Json::object({ "name": Json::string("John") }),
  )
  inspect(req.headers.get("Content-Type"), content="Some(\"application/json\")")
}

///|
test "mock_response" {
  let res = MockResponse::new()
  inspect(res.status, content="200")
  inspect(res.is_sent(), content="false")
}

///|
test "mock_context_basic" {
  let req = MockRequest::get("/test").header("X-Custom", "value")
  let ctx = MockContext::from_request(req)
  inspect(ctx.path(), content="/test")
  inspect(ctx.header("X-Custom"), content="Some(\"value\")")
}

///|
test "mock_context_text_response" {
  let req = MockRequest::get("/test")
  let ctx = MockContext::from_request(req)
  ctx.text("Hello", status=200)
  inspect(ctx.is_response_sent(), content="true")
  let res = ctx.get_response()
  inspect(res.get_body(), content="Hello")
}

///|
test "assert_status" {
  let res = MockResponse::new()
  res.status = 404
  inspect(assert_status(res, 404), content="true")
  inspect(assert_status(res, 200), content="false")
}

///|
test "basic_auth_simple" {
  let opts = BasicAuthOptions::simple("admin", "secret")
  inspect(opts.realm, content="Restricted")
  inspect((opts.validate)("admin", "secret"), content="true")
  inspect((opts.validate)("admin", "wrong"), content="false")
}

///|
test "basic_auth_timing_safe" {
  // Test that validation works correctly even with different length passwords
  let opts = BasicAuthOptions::simple("admin", "verylongpassword")
  inspect((opts.validate)("admin", "short"), content="false")
  inspect((opts.validate)("admin", "verylongpassword"), content="true")
  inspect((opts.validate)("admin", "verylongpassword!"), content="false")
}

///|
test "trusted_proxy_config" {
  let none = TrustedProxyConfig::none()
  inspect(none.enabled, content="false")
  let localhost = TrustedProxyConfig::localhost()
  inspect(localhost.enabled, content="true")
  inspect(localhost.proxies.length(), content="2")
}

///|
test "etag_generate" {
  let etag = generate_etag("hello world", true)
  inspect(etag.has_prefix("W/\""), content="true")
  // Same content should produce same ETag
  let etag2 = generate_etag("hello world", true)
  inspect(etag == etag2, content="true")
  // Different content should produce different ETag
  let etag3 = generate_etag("hello world!", true)
  inspect(etag == etag3, content="false")
}

///|
test "etag_matches" {
  let etag = "\"abc123\""
  inspect(etag_matches(etag, "\"abc123\""), content="true")
  inspect(etag_matches(etag, "\"xyz789\""), content="false")
  inspect(etag_matches(etag, "*"), content="true")
  // Multiple ETags
  inspect(etag_matches(etag, "\"xyz\", \"abc123\", \"def\""), content="true")
}

///|
test "cache_control_build" {
  let header = build_cache_control(CacheOptions::public_(3600))
  inspect(header.contains("public"), content="true")
  inspect(header.contains("max-age=3600"), content="true")
}

///|
test "cache_control_no_cache" {
  let header = build_cache_control(CacheOptions::no_cache())
  inspect(header.contains("no-store"), content="true")
  inspect(header.contains("no-cache"), content="true")
  inspect(header.contains("private"), content="true")
}

///|
test "cache_control_immutable" {
  let header = build_cache_control(CacheOptions::immutable(31536000))
  inspect(header.contains("immutable"), content="true")
  inspect(header.contains("public"), content="true")
}

///|
test "compress_parse_accept_encoding" {
  let encodings = parse_accept_encoding("gzip, deflate, br")
  inspect(encodings.length(), content="3")
}

///|
test "compress_negotiate" {
  let accepted = [Gzip, Deflate]
  let supported = [Br, Gzip]
  let result = negotiate_encoding(accepted, supported)
  inspect(result, content="Gzip")
}

///|
test "compress_should_compress_type" {
  inspect(should_compress_type("text/html"), content="true")
  inspect(should_compress_type("application/json"), content="true")
  inspect(should_compress_type("image/png"), content="false")
}

///|
test "api_key_generate" {
  let key = generate_api_key()
  inspect(key.has_prefix("sk_"), content="true")
  // Should be 35 chars: 3 prefix + 32 random
  inspect(key.length(), content="35")
}

///|
test "redirect_status_to_code" {
  inspect(RedirectStatus::MovedPermanently.to_code(), content="301")
  inspect(RedirectStatus::Found.to_code(), content="302")
  inspect(RedirectStatus::TemporaryRedirect.to_code(), content="307")
}

// ============================================
// ETag additional tests
// ============================================

///|
test "etag_strong_vs_weak" {
  let weak = generate_etag("test", true)
  let strong = generate_etag("test", false)
  inspect(weak.has_prefix("W/\""), content="true")
  inspect(strong.has_prefix("\""), content="true")
  inspect(strong.has_prefix("W/"), content="false")
}

///|
test "etag_matches_weak_comparison" {
  // Weak comparison should match W/"abc" with "abc"
  inspect(etag_matches("W/\"abc\"", "\"abc\""), content="true")
  inspect(etag_matches("\"abc\"", "W/\"abc\""), content="true")
}

///|
test "etag_matches_multiple_with_spaces" {
  let etag = "\"target\""
  inspect(etag_matches(etag, "\"a\", \"b\", \"target\""), content="true")
  inspect(etag_matches(etag, "\"a\",\"target\",\"c\""), content="true")
}

// ============================================
// Cache-Control additional tests
// ============================================

///|
test "cache_control_cdn" {
  let header = build_cache_control(CacheOptions::cdn(60, 3600))
  inspect(header.contains("max-age=60"), content="true")
  inspect(header.contains("s-maxage=3600"), content="true")
  inspect(header.contains("public"), content="true")
}

///|
test "cache_control_presets" {
  inspect(build_cache_control(cache_1_minute()).contains("max-age=60"), content="true")
  inspect(build_cache_control(cache_1_hour()).contains("max-age=3600"), content="true")
  inspect(build_cache_control(cache_1_day()).contains("max-age=86400"), content="true")
  inspect(build_cache_control(cache_1_week()).contains("max-age=604800"), content="true")
}

///|
test "cache_control_private" {
  let header = build_cache_control(CacheOptions::private_(300))
  inspect(header.contains("private"), content="true")
  inspect(header.contains("max-age=300"), content="true")
  inspect(header.contains("public"), content="false")
}

// ============================================
// Compress additional tests
// ============================================

///|
test "compress_parse_with_quality" {
  let encodings = parse_accept_encoding("gzip;q=1.0, deflate;q=0.5, br;q=0.8")
  inspect(encodings.length(), content="3")
}

///|
test "compress_negotiate_no_match" {
  let accepted = [Deflate]
  let supported = [Br]
  let result = negotiate_encoding(accepted, supported)
  inspect(result, content="Identity")
}

///|
test "compress_negotiate_priority" {
  let accepted = [Gzip, Br, Deflate]
  let supported = [Deflate, Gzip]  // Server prefers Deflate
  let result = negotiate_encoding(accepted, supported)
  inspect(result, content="Deflate")
}

///|
test "compress_content_types" {
  inspect(should_compress_type("text/plain"), content="true")
  inspect(should_compress_type("text/css"), content="true")
  inspect(should_compress_type("application/javascript"), content="true")
  inspect(should_compress_type("application/xml"), content="true")
  inspect(should_compress_type("image/svg+xml"), content="true")
  inspect(should_compress_type("image/jpeg"), content="false")
  inspect(should_compress_type("video/mp4"), content="false")
}

///|
test "compress_encoding_to_header" {
  inspect(encoding_to_header(Gzip), content="gzip")
  inspect(encoding_to_header(Deflate), content="deflate")
  inspect(encoding_to_header(Br), content="br")
  inspect(encoding_to_header(Identity), content="identity")
}

// ============================================
// Trailing Slash tests
// ============================================

///|
test "trailing_slash_options" {
  let add = TrailingSlashOptions::add()
  inspect(add.mode, content="Add")
  inspect(add.redirect, content="true")
  let remove = TrailingSlashOptions::remove()
  inspect(remove.mode, content="Remove")
}

// ============================================
// API Key additional tests
// ============================================

///|
test "api_key_simple_validation" {
  let opts = ApiKeyOptions::simple(["key1", "key2", "key3"])
  inspect((opts.validate)("key1"), content="Valid(\"key1\")")
  inspect((opts.validate)("key2"), content="Valid(\"key2\")")
  inspect((opts.validate)("invalid"), content="Invalid")
}

///|
test "api_key_format" {
  let key = generate_api_key()
  // Key should have prefix and be 35 chars
  inspect(key.has_prefix("sk_"), content="true")
  inspect(key.length(), content="35")
  // Key should only contain valid hex characters after prefix
  let chars_valid = check_hex_chars(key)
  inspect(chars_valid, content="true")
}

///|
fn check_hex_chars(key : String) -> Bool {
  let valid = "0123456789abcdef"
  let mut i = 0
  for c in key {
    // Skip prefix "sk_"
    if i >= 3 {
      let mut found = false
      for vc in valid {
        if c == vc {
          found = true
          break
        }
      }
      if not(found) {
        return false
      }
    }
    i = i + 1
  }
  true
}

///|
test "api_key_custom_prefix" {
  let key = generate_api_key(prefix="pk_live_")
  inspect(key.has_prefix("pk_live_"), content="true")
}

///|
test "api_key_location_types" {
  let header_loc = ApiKeyLocation::Header("X-API-Key")
  let query_loc = ApiKeyLocation::Query("api_key")
  let both_loc = ApiKeyLocation::Both("X-API-Key", "api_key")
  // Just verify construction works
  inspect(header_loc is Header(_), content="true")
  inspect(query_loc is Query(_), content="true")
  inspect(both_loc is Both(_, _), content="true")
}

// ============================================
// Redirect additional tests
// ============================================

///|
test "redirect_rule_permanent" {
  let rule = RedirectRule::permanent("/old", "/new")
  inspect(rule.from, content="/old")
  inspect(rule.to, content="/new")
  inspect(rule.status.to_code(), content="301")
}

///|
test "redirect_rule_temporary" {
  let rule = RedirectRule::temporary("/temp", "/dest")
  inspect(rule.status.to_code(), content="302")
}

///|
test "redirect_all_status_codes" {
  inspect(RedirectStatus::MovedPermanently.to_code(), content="301")
  inspect(RedirectStatus::Found.to_code(), content="302")
  inspect(RedirectStatus::SeeOther.to_code(), content="303")
  inspect(RedirectStatus::TemporaryRedirect.to_code(), content="307")
  inspect(RedirectStatus::PermanentRedirect.to_code(), content="308")
}

// ============================================
// Session additional tests
// ============================================

///|
test "session_data_operations" {
  session_clear()
  let data = SessionData::{ id: "test_session" }
  // Initially empty
  inspect(data.get("user"), content="None")
  // Set and get
  data.set("user", "john")
  inspect(data.get("user"), content="Some(\"john\")")
  // Delete
  data.delete("user")
  inspect(data.get("user"), content="None")
}

///|
test "session_data_multiple_keys" {
  session_clear()
  let data = SessionData::{ id: "multi_key_session" }
  data.set("name", "Alice")
  data.set("role", "admin")
  data.set("theme", "dark")
  inspect(data.get("name"), content="Some(\"Alice\")")
  inspect(data.get("role"), content="Some(\"admin\")")
  inspect(data.get("theme"), content="Some(\"dark\")")
}

///|
test "session_clear_all" {
  session_clear()
  let data = SessionData::{ id: "clear_test" }
  data.set("key1", "value1")
  data.set("key2", "value2")
  data.clear_all()
  inspect(data.get("key1"), content="None")
  inspect(data.get("key2"), content="None")
}

// ============================================
// Form Data additional tests
// ============================================

///|
test "form_data_empty" {
  let form = parse_form_urlencoded("")
  inspect(form.get("any"), content="None")
}

///|
test "form_data_special_chars" {
  let form = parse_form_urlencoded("msg=Hello%2BWorld")  // + encoded as %2B
  inspect(form.get("msg"), content="Some(\"Hello+World\")")
}

///|
test "form_data_plus_as_space" {
  let form = parse_form_urlencoded("msg=Hello+World")
  inspect(form.get("msg"), content="Some(\"Hello World\")")
}

///|
test "form_data_empty_value" {
  let form = parse_form_urlencoded("name=&age=30")
  inspect(form.get("name"), content="Some(\"\")")
  inspect(form.get("age"), content="Some(\"30\")")
}

///|
test "form_data_add_and_get" {
  let form = FormData::new()
  form.add("color", "red")
  form.add("color", "blue")
  inspect(form.get("color"), content="Some(\"red\")")  // First value
  let all = form.get_all("color")
  inspect(all.length(), content="2")
}

// ============================================
// Validation additional tests
// ============================================

///|
test "validator_max_length" {
  let json = Json::object({ "name": Json::string("verylongname") })
  let result = Validator::new(json).max_length("name", 5).validate()
  inspect(result.is_valid(), content="false")
}

///|
test "validator_range" {
  let json = Json::object({ "age": Json::number(25.0) })
  let result = Validator::new(json).range("age", 18, 65).validate()
  inspect(result.is_valid(), content="true")
}

///|
test "validator_range_invalid" {
  let json = Json::object({ "age": Json::number(10.0) })
  let result = Validator::new(json).range("age", 18, 65).validate()
  inspect(result.is_valid(), content="false")
}

///|
test "validator_required_number" {
  let json = Json::object({ "count": Json::number(42.0) })
  let result = Validator::new(json).required_number("count").validate()
  inspect(result.is_valid(), content="true")
}

///|
test "validator_chained" {
  let json = Json::object({
    "email": Json::string("test@example.com"),
    "name": Json::string("John"),
  })
  let result = Validator::new(json)
    .required_string("email")
    .email("email")
    .required_string("name")
    .min_length("name", 2)
    .validate()
  inspect(result.is_valid(), content="true")
}

///|
test "validator_multiple_errors" {
  let json = Json::object({})
  let result = Validator::new(json)
    .required_string("email")
    .required_string("name")
    .validate()
  inspect(result.is_valid(), content="false")
  inspect(result.messages().length() >= 2, content="true")
}

// ============================================
// Rate Limit additional tests
// ============================================

///|
test "rate_limit_increment" {
  rate_limit_clear()
  // Simulate requests
  let (count1, _, _) = rate_limit_info("user1")
  inspect(count1, content="0")
}

///|
test "rate_limit_options" {
  let opts = RateLimitOptions::default()
  inspect(opts.limit, content="100")
  inspect(opts.window_size, content="1")
}

// ============================================
// Webhook additional tests
// ============================================

///|
test "verify_stripe_webhook" {
  let secret = "whsec_test"
  let body = "{\"type\":\"payment_intent.succeeded\"}"
  let timestamp = "1234567890"
  let payload = timestamp + "." + body
  let signature = compute_hmac_sha256(secret, payload)
  let header = "t=" + timestamp + ",v1=" + signature
  inspect(verify_stripe_webhook(secret, header, body), content="Valid")
}

///|
test "verify_stripe_webhook_invalid_format" {
  let result = verify_stripe_webhook("secret", "invalid", "body")
  inspect(result, content="Invalid(\"Invalid signature format\")")
}

// ============================================
// HTTP Error additional tests
// ============================================

///|
test "http_error_all_types" {
  inspect(HttpError::unauthorized().status, content="401")
  inspect(HttpError::forbidden().status, content="403")
  inspect(HttpError::method_not_allowed().status, content="405")
  inspect(HttpError::conflict().status, content="409")
  inspect(HttpError::unprocessable().status, content="422")
  inspect(HttpError::internal().status, content="500")
  inspect(HttpError::service_unavailable().status, content="503")
}

///|
test "http_error_custom_message" {
  let err = HttpError::not_found(message="User not found")
  inspect(err.message, content="User not found")
}

// ============================================
// SSE additional tests
// ============================================

///|
test "sse_event_multiline_data" {
  let event = SseEvent::data("line1\nline2\nline3")
  let formatted = event.format()
  // Each line should have data: prefix
  inspect(formatted.contains("data: line1"), content="true")
  inspect(formatted.contains("data: line2"), content="true")
}

///|
test "sse_event_with_id" {
  let event = SseEvent::full("update", "data", "evt-123", 3000)
  let formatted = event.format()
  inspect(formatted.contains("id: evt-123"), content="true")
  inspect(formatted.contains("retry: 3000"), content="true")
}

// ============================================
// Mock Context additional tests
// ============================================

///|
test "mock_request_put_delete" {
  let put = MockRequest::put("/resource")
  inspect(put.meth, content="PUT")
  let delete = MockRequest::delete("/resource")
  inspect(delete.meth, content="DELETE")
}

///|
test "mock_request_with_body" {
  let req = MockRequest::post("/data").with_body("raw content")
  inspect(req.body, content="raw content")
}

///|
test "mock_request_auth" {
  let req = MockRequest::get("/api").auth("token123")
  inspect(req.headers.get("Authorization"), content="Some(\"Bearer token123\")")
}

///|
test "mock_request_query_params" {
  let req = MockRequest::get("/search").query("q", "test").query("page", "1")
  inspect(req.query.get("q"), content="Some(\"test\")")
  inspect(req.query.get("page"), content="Some(\"1\")")
}

///|
test "mock_context_json_response" {
  let req = MockRequest::get("/api")
  let ctx = MockContext::from_request(req)
  ctx.json_response(Json::object({ "ok": Json::boolean(true) }))
  let res = ctx.get_response()
  inspect(res.get_header("Content-Type"), content="Some(\"application/json\")")
}

///|
test "mock_context_set_get_data" {
  let req = MockRequest::get("/test")
  let ctx = MockContext::from_request(req)
  ctx.set("user_id", "123")
  inspect(ctx.get("user_id"), content="Some(\"123\")")
  inspect(ctx.get("nonexistent"), content="None")
}

///|
test "mock_context_params" {
  let req = MockRequest::get("/users/42")
  let ctx = MockContext::from_request(req).set_param("id", "42")
  inspect(ctx.param("id"), content="Some(\"42\")")
}

///|
test "assert_body_contains" {
  let res = MockResponse::new()
  res.body = "Hello World"
  inspect(assert_body_contains(res, "World"), content="true")
  inspect(assert_body_contains(res, "Foo"), content="false")
}

///|
test "assert_header" {
  let res = MockResponse::new()
  res.headers.set("Content-Type", "application/json")
  inspect(assert_header(res, "Content-Type", "application/json"), content="true")
  inspect(assert_header(res, "Content-Type", "text/plain"), content="false")
}

// ============================================
// Timeout tests
// ============================================

///|
test "timeout_context" {
  timeout_timer_reset()
  let ctx = TimeoutContext::new(1000)
  inspect(ctx.is_timed_out(), content="false")
  timeout_timer_advance(500)
  inspect(ctx.is_timed_out(), content="false")
  timeout_timer_advance(600)  // Total 1100ms
  inspect(ctx.is_timed_out(), content="true")
}

///|
test "timeout_elapsed" {
  timeout_timer_reset()
  let ctx = TimeoutContext::new(5000)
  timeout_timer_advance(100)
  inspect(ctx.elapsed() > 0, content="true")
}

// ============================================
// Request ID tests
// ============================================

///|
test "request_id_custom_prefix" {
  let opts = RequestIdOptions::{
    header_name: "X-Request-ID",
    prefix: "api-",
    use_existing: true,
  }
  inspect(opts.prefix, content="api-")
  inspect(opts.use_existing, content="true")
}

// ============================================
// Body Limit tests
// ============================================

///|
test "body_limit_options_default" {
  let opts = BodyLimitOptions::default()
  inspect(opts.max_size, content="1048576")  // 1MB
  inspect(opts.status, content="413")
}

///|
test "body_limit_options_kb" {
  let opts = BodyLimitOptions::kb(100)
  inspect(opts.max_size, content="102400")
}

///|
test "body_limit_options_mb" {
  let opts = BodyLimitOptions::mb(5)
  inspect(opts.max_size, content="5242880")
}

///|
test "body_limit_check_content_length" {
  inspect(check_content_length("1000", 2000), content="true")
  inspect(check_content_length("3000", 2000), content="false")
  inspect(check_content_length("2000", 2000), content="true")  // Equal is OK
}

///|
test "body_limit_is_within_limit" {
  inspect(is_within_limit("hello", 10), content="true")
  inspect(is_within_limit("hello world", 5), content="false")
}

///|
test "body_limit_format_size" {
  inspect(format_size(500), content="500 bytes")
  inspect(format_size(1024), content="1 KB")
  inspect(format_size(10240), content="10 KB")
  inspect(format_size(1048576), content="1 MB")
  inspect(format_size(5242880), content="5 MB")
}

///|
test "body_limit_size_constants" {
  inspect(size_1kb(), content="1024")
  inspect(size_10kb(), content="10240")
  inspect(size_100kb(), content="102400")
  inspect(size_1mb(), content="1048576")
  inspect(size_10mb(), content="10485760")
}

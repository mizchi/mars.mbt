///|
/// Webhook Verification Helpers
/// Helper functions for verifying webhook signatures (not middleware due to Context lacking body field)

///|
/// Webhook verification result
pub(all) enum WebhookResult {
  Valid
  Invalid(String)
} derive(Show, Eq)

///|
/// Hex characters for encoding
let hex_chars : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

///|
/// Compute HMAC-SHA256 and return as hex string
pub fn compute_hmac_sha256(secret : String, payload : String) -> String {
  let key_bytes = string_to_bytes(secret)
  let msg_bytes = string_to_bytes(payload)
  let hash = @crypto.hmac(@crypto.SHA256::new(), key_bytes[:], msg_bytes[:])
  fixed_bytes_to_hex(hash)
}

///|
/// Convert string to bytes
fn string_to_bytes(s : String) -> Bytes {
  let bytes = FixedArray::make(s.length(), b'\x00')
  for i, c in s {
    bytes[i] = c.to_int().to_byte()
  }
  Bytes::from_array(bytes)
}

///|
/// Convert fixed bytes to hex string
fn fixed_bytes_to_hex(bytes : FixedArray[Byte]) -> String {
  let result = StringBuilder::new()
  for i = 0; i < bytes.length(); i = i + 1 {
    let b = bytes[i].to_int()
    let high = (b >> 4) & 0x0F
    let low = b & 0x0F
    result.write_char(hex_chars[high])
    result.write_char(hex_chars[low])
  }
  result.to_string()
}

///|
/// Constant-time string comparison to prevent timing attacks
fn constant_time_compare(a : String, b : String) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut result = 0
  for i = 0; i < a.length(); i = i + 1 {
    result = result | (a[i].to_int() ^ b[i].to_int())
  }
  result == 0
}

///|
/// Verify generic HMAC webhook signature
pub fn verify_webhook_hmac(
  secret : String,
  signature_hex : String,
  body : String,
) -> WebhookResult {
  let computed = compute_hmac_sha256(secret, body)
  if constant_time_compare(computed, string_to_lower(signature_hex)) {
    WebhookResult::Valid
  } else {
    WebhookResult::Invalid("Signature mismatch")
  }
}

///|
/// Verify GitHub webhook signature
/// GitHub uses X-Hub-Signature-256 header with format: sha256=<hex>
pub fn verify_github_webhook(
  secret : String,
  signature_header : String,
  body : String,
) -> WebhookResult {
  // Parse "sha256=<hex>"
  if not(signature_header.has_prefix("sha256=")) {
    return WebhookResult::Invalid("Invalid signature format")
  }
  let signature = safe_substring_from(signature_header, 7)
  verify_webhook_hmac(secret, signature, body)
}

///|
/// Verify Stripe webhook signature
/// Stripe uses Stripe-Signature header with format: t=<timestamp>,v1=<sig>
pub fn verify_stripe_webhook(
  secret : String,
  signature_header : String,
  body : String,
) -> WebhookResult {
  // Parse timestamp and signature
  let mut timestamp = ""
  let mut signature = ""
  let parts = split_by_char(signature_header, ',')
  for part in parts {
    let kv = split_by_char(part, '=')
    if kv.length() == 2 {
      let key = kv[0]
      let value = kv[1]
      if key == "t" {
        timestamp = value
      } else if key == "v1" {
        signature = value
      }
    }
  }
  if timestamp.is_empty() || signature.is_empty() {
    return WebhookResult::Invalid("Invalid signature format")
  }
  // Stripe expects: HMAC(timestamp + "." + body)
  let payload = timestamp + "." + body
  verify_webhook_hmac(secret, signature, payload)
}

///|
/// Split string by character
fn split_by_char(s : String, sep : Char) -> Array[String] {
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

///|
/// Validation Module
/// Request validation helpers

///|
/// Validation error
pub(all) enum ValidationError {
  Required(String)
  InvalidType(String, String)
  MinLength(String, Int)
  MaxLength(String, Int)
  Pattern(String, String)
  Range(String, Double, Double)
  Custom(String, String)
} derive(Show, Eq)

///|
/// Validation result
pub(all) struct ValidationResult {
  errors : Array[ValidationError]
}

///|
/// Create a new validation result
pub fn ValidationResult::new() -> ValidationResult {
  { errors: [] }
}

///|
/// Check if validation passed
pub fn ValidationResult::is_valid(self : ValidationResult) -> Bool {
  self.errors.is_empty()
}

///|
/// Add an error
pub fn ValidationResult::add_error(
  self : ValidationResult,
  error : ValidationError,
) -> Unit {
  self.errors.push(error)
}

///|
/// Get error messages as array
pub fn ValidationResult::messages(self : ValidationResult) -> Array[String] {
  let msgs : Array[String] = []
  for err in self.errors {
    msgs.push(validation_error_message(err))
  }
  msgs
}

///|
/// Convert error to message
fn validation_error_message(err : ValidationError) -> String {
  match err {
    Required(field) => "\{field} is required"
    InvalidType(field, expected) => "\{field} must be \{expected}"
    MinLength(field, len) => "\{field} must be at least \{len} characters"
    MaxLength(field, len) => "\{field} must be at most \{len} characters"
    Pattern(field, pattern) => "\{field} must match pattern \{pattern}"
    Range(field, min, max) => "\{field} must be between \{min} and \{max}"
    Custom(field, msg) => "\{field}: \{msg}"
  }
}

///|
/// Field validator
pub(all) struct Validator {
  result : ValidationResult
  data : Json
}

///|
/// Create a validator from JSON
pub fn Validator::new(data : Json) -> Validator {
  { result: ValidationResult::new(), data }
}

///|
/// Validate required string field
pub fn Validator::required_string(
  self : Validator,
  field : String,
) -> Validator {
  match get_json_field(self.data, field) {
    Some(String(s)) =>
      if s.is_empty() {
        self.result.add_error(ValidationError::Required(field))
      }
    Some(_) =>
      self.result.add_error(ValidationError::InvalidType(field, "string"))
    None => self.result.add_error(ValidationError::Required(field))
  }
  self
}

///|
/// Validate optional string field with min length
pub fn Validator::min_length(
  self : Validator,
  field : String,
  min : Int,
) -> Validator {
  match get_json_field(self.data, field) {
    Some(String(s)) =>
      if s.length() < min {
        self.result.add_error(ValidationError::MinLength(field, min))
      }
    _ => ()
  }
  self
}

///|
/// Validate optional string field with max length
pub fn Validator::max_length(
  self : Validator,
  field : String,
  max : Int,
) -> Validator {
  match get_json_field(self.data, field) {
    Some(String(s)) =>
      if s.length() > max {
        self.result.add_error(ValidationError::MaxLength(field, max))
      }
    _ => ()
  }
  self
}

///|
/// Validate required number field
pub fn Validator::required_number(
  self : Validator,
  field : String,
) -> Validator {
  match get_json_field(self.data, field) {
    Some(Number(_, ..)) => ()
    Some(_) =>
      self.result.add_error(ValidationError::InvalidType(field, "number"))
    None => self.result.add_error(ValidationError::Required(field))
  }
  self
}

///|
/// Validate number field is in range
pub fn Validator::range(
  self : Validator,
  field : String,
  min : Double,
  max : Double,
) -> Validator {
  match get_json_field(self.data, field) {
    Some(Number(n, ..)) =>
      if n < min || n > max {
        self.result.add_error(ValidationError::Range(field, min, max))
      }
    _ => ()
  }
  self
}

///|
/// Validate required boolean field
pub fn Validator::required_bool(self : Validator, field : String) -> Validator {
  match get_json_field(self.data, field) {
    Some(True) | Some(False) => ()
    Some(_) =>
      self.result.add_error(ValidationError::InvalidType(field, "boolean"))
    None => self.result.add_error(ValidationError::Required(field))
  }
  self
}

///|
/// Validate required array field
pub fn Validator::required_array(self : Validator, field : String) -> Validator {
  match get_json_field(self.data, field) {
    Some(Array(_)) => ()
    Some(_) =>
      self.result.add_error(ValidationError::InvalidType(field, "array"))
    None => self.result.add_error(ValidationError::Required(field))
  }
  self
}

///|
/// Add custom validation
pub fn Validator::custom(
  self : Validator,
  field : String,
  check : (Json) -> Bool,
  message : String,
) -> Validator {
  if not(check(self.data)) {
    self.result.add_error(ValidationError::Custom(field, message))
  }
  self
}

///|
/// Get validation result
pub fn Validator::validate(self : Validator) -> ValidationResult {
  self.result
}

///|
/// Email pattern validation
pub fn Validator::email(self : Validator, field : String) -> Validator {
  match get_json_field(self.data, field) {
    Some(String(s)) =>
      if not(is_valid_email(s)) {
        self.result.add_error(
          ValidationError::Pattern(field, "valid email address"),
        )
      }
    _ => ()
  }
  self
}

///|
/// Simple email validation
fn is_valid_email(s : String) -> Bool {
  let mut has_at = false
  let mut has_dot_after_at = false
  let mut at_pos = -1
  for i, c in s {
    if c == '@' {
      if has_at {
        return false
      }
      has_at = true
      at_pos = i
    } else if c == '.' && has_at && i > at_pos + 1 {
      has_dot_after_at = true
    }
  }
  has_at && has_dot_after_at && at_pos > 0
}

///|
/// Get field from JSON object
fn get_json_field(data : Json, field : String) -> Json? {
  match data {
    Object(obj) => obj.get(field)
    _ => None
  }
}

///|
/// Validation middleware - validates request body and adds errors to context
pub fn validate_body(validator_fn : (Validator) -> Validator) -> @flame.Handler {
  async fn(ctx : @flame.Context) raise Error {
    guard ctx.body_json() is Some(json) else {
      ctx.json(
        Json::object({ "error": Json::string("Invalid JSON body") }),
        status=400,
      )
      return
    }
    let validator = validator_fn(Validator::new(json))
    let result = validator.validate()
    if not(result.is_valid()) {
      let errors : Array[Json] = []
      for msg in result.messages() {
        errors.push(Json::string(msg))
      }
      ctx.json(Json::object({ "errors": Json::array(errors) }), status=400)
    }
  }
}

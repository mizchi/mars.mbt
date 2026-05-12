///|
priv struct ParsedAtom {
  atom : RegexAtom
  next : Int
}

///|
priv struct ParsedChar {
  char : UInt16
  next : Int
}

///|
priv struct ParsedQuantifier {
  min : Int
  max : Int
  next : Int
}

///|
priv enum RegexAtom {
  Literal(UInt16)
  Any
  CharClass(Array[(UInt16, UInt16)], Bool)
}

///|
fn is_regex_meta_char(c : UInt16) -> Bool {
  c == '+'.to_int().to_uint16() ||
  c == '*'.to_int().to_uint16() ||
  c == '?'.to_int().to_uint16() ||
  c == '|'.to_int().to_uint16() ||
  c == ')'.to_int().to_uint16() ||
  c == '}'.to_int().to_uint16()
}

///|
fn parse_class_char(pattern : String, index : Int) -> ParsedChar? {
  if index >= pattern.length() {
    return None
  }
  if pattern[index] == '\\'.to_int().to_uint16() && index + 1 < pattern.length() {
    Some({ char: pattern[index + 1], next: index + 2 })
  } else {
    Some({ char: pattern[index], next: index + 1 })
  }
}

///|
fn parse_char_class(pattern : String, start : Int) -> ParsedAtom? {
  let mut index = start + 1
  let mut negated = false
  if index < pattern.length() && pattern[index] == '^'.to_int().to_uint16() {
    negated = true
    index += 1
  }
  let ranges : Array[(UInt16, UInt16)] = []
  while index < pattern.length() && pattern[index] != ']'.to_int().to_uint16() {
    let first = match parse_class_char(pattern, index) {
      Some(parsed) => parsed
      None => return None
    }
    index = first.next
    if index < pattern.length() &&
      pattern[index] == '-'.to_int().to_uint16() &&
      index + 1 < pattern.length() &&
      pattern[index + 1] != ']'.to_int().to_uint16() {
      let second = match parse_class_char(pattern, index + 1) {
        Some(parsed) => parsed
        None => return None
      }
      index = second.next
      if first.char.to_int() <= second.char.to_int() {
        ranges.push((first.char, second.char))
      } else {
        ranges.push((second.char, first.char))
      }
    } else {
      ranges.push((first.char, first.char))
    }
  }
  if index >= pattern.length() || pattern[index] != ']'.to_int().to_uint16() {
    return None
  }
  Some({ atom: CharClass(ranges, negated), next: index + 1 })
}

///|
fn parse_atom(pattern : String, start : Int) -> ParsedAtom? {
  if start >= pattern.length() {
    return None
  }
  let c = pattern[start]
  if c == '['.to_int().to_uint16() {
    parse_char_class(pattern, start)
  } else if c == '\\'.to_int().to_uint16() {
    if start + 1 < pattern.length() {
      Some({ atom: Literal(pattern[start + 1]), next: start + 2 })
    } else {
      None
    }
  } else if c == '.'.to_int().to_uint16() {
    Some({ atom: Any, next: start + 1 })
  } else if is_regex_meta_char(c) {
    None
  } else {
    Some({ atom: Literal(c), next: start + 1 })
  }
}

///|
fn is_ascii_digit(c : UInt16) -> Bool {
  c.to_int() >= '0'.to_int() && c.to_int() <= '9'.to_int()
}

///|
fn parse_number_until(pattern : String, start : Int, end : Int) -> Int? {
  if start >= end {
    return None
  }
  let mut result = 0
  for i = start; i < end; i = i + 1 {
    let c = pattern[i]
    if !is_ascii_digit(c) {
      return None
    }
    result = result * 10 + c.to_int() - '0'.to_int()
  }
  Some(result)
}

///|
fn parse_brace_quantifier(pattern : String, start : Int) -> ParsedQuantifier? {
  let mut index = start + 1
  while index < pattern.length() && pattern[index] != '}'.to_int().to_uint16() {
    index += 1
  }
  if index >= pattern.length() {
    return None
  }
  let mut comma = -1
  for i = start + 1; i < index; i = i + 1 {
    if pattern[i] == ','.to_int().to_uint16() {
      comma = i
      break
    }
  }
  if comma < 0 {
    match parse_number_until(pattern, start + 1, index) {
      Some(n) => Some({ min: n, max: n, next: index + 1 })
      None => None
    }
  } else {
    let min = match parse_number_until(pattern, start + 1, comma) {
      Some(n) => n
      None => return None
    }
    let max = if comma + 1 == index {
      -1
    } else {
      match parse_number_until(pattern, comma + 1, index) {
        Some(n) => n
        None => return None
      }
    }
    if max >= 0 && max < min {
      None
    } else {
      Some({ min, max, next: index + 1 })
    }
  }
}

///|
fn parse_quantifier(pattern : String, start : Int) -> ParsedQuantifier {
  if start >= pattern.length() {
    return { min: 1, max: 1, next: start }
  }
  let c = pattern[start]
  if c == '+'.to_int().to_uint16() {
    { min: 1, max: -1, next: start + 1 }
  } else if c == '*'.to_int().to_uint16() {
    { min: 0, max: -1, next: start + 1 }
  } else if c == '?'.to_int().to_uint16() {
    { min: 0, max: 1, next: start + 1 }
  } else if c == '{'.to_int().to_uint16() {
    match parse_brace_quantifier(pattern, start) {
      Some(q) => q
      None => { min: 1, max: 1, next: start }
    }
  } else {
    { min: 1, max: 1, next: start }
  }
}

///|
fn char_in_class(c : UInt16, ranges : Array[(UInt16, UInt16)]) -> Bool {
  for range in ranges {
    let (start, end) = range
    if c.to_int() >= start.to_int() && c.to_int() <= end.to_int() {
      return true
    }
  }
  false
}

///|
fn atom_matches(atom : RegexAtom, s : String, index : Int) -> Bool {
  if index >= s.length() {
    return false
  }
  let c = s[index]
  match atom {
    Literal(expected) => c == expected
    Any => true
    CharClass(ranges, negated) => {
      let matched = char_in_class(c, ranges)
      if negated {
        !matched
      } else {
        matched
      }
    }
  }
}

///|
fn match_sequence_from(
  pattern : String,
  pattern_index : Int,
  s : String,
  s_index : Int,
) -> Bool {
  if pattern_index >= pattern.length() {
    return s_index == s.length()
  }
  let parsed = match parse_atom(pattern, pattern_index) {
    Some(parsed) => parsed
    None => return false
  }
  let quantifier = parse_quantifier(pattern, parsed.next)
  let positions : Array[Int] = [s_index]
  let mut cursor = s_index
  let mut count = 0
  while (quantifier.max < 0 || count < quantifier.max) &&
        atom_matches(parsed.atom, s, cursor) {
    cursor += 1
    count += 1
    positions.push(cursor)
  }
  let mut reps = positions.length() - 1
  while reps >= quantifier.min {
    if match_sequence_from(pattern, quantifier.next, s, positions[reps]) {
      return true
    }
    reps -= 1
  }
  false
}

///|
fn match_sequence(pattern : String, s : String) -> Bool {
  match_sequence_from(pattern, 0, s, 0)
}

///|
fn matches_top_level_alternative(
  pattern : String,
  start : Int,
  end : Int,
  s : String,
) -> Bool {
  let alt = pattern.view(start_offset=start, end_offset=end).to_owned()
  match_sequence(alt, s)
}

///|
fn matches_segment_regex(s : String, pattern : String) -> Bool {
  let mut start = 0
  let mut index = 0
  let mut in_class = false
  let mut escaped = false
  while index < pattern.length() {
    let c = pattern[index]
    if escaped {
      escaped = false
    } else if c == '\\'.to_int().to_uint16() {
      escaped = true
    } else if c == '['.to_int().to_uint16() {
      in_class = true
    } else if c == ']'.to_int().to_uint16() {
      in_class = false
    } else if !in_class && c == '|'.to_int().to_uint16() {
      if matches_top_level_alternative(pattern, start, index, s) {
        return true
      }
      start = index + 1
    }
    index += 1
  }
  matches_top_level_alternative(pattern, start, pattern.length(), s)
}

///|
/// Strict parser settings preserve integer spelling and reject decoded duplicates.
fn document(source : String) -> Json raise PlanError {
  if source.length() > 8388608 {
    fail("input exceeds 8 Mi UTF-16 units")
  }
  @json.parse(
    source,
    max_nesting_depth=24,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ => fail("invalid JSON, duplicate object key or nesting limit exceeded")
  }
}

///|
fn object(value : Json) -> Map[String, Json] raise PlanError {
  match value {
    Object(f) => f
    _ => fail("expected object")
  }
}

///|
fn only(f : Map[String, Json], keys : Array[String]) -> Unit raise PlanError {
  for key, _ in f {
    if !keys.contains(key) {
      fail("unknown or inapplicable field")
    }
  }
}

///|
fn required(f : Map[String, Json], key : String) -> Json raise PlanError {
  match f.get(key) {
    Some(v) => v
    None => fail("missing field: " + key)
  }
}

///|
fn text(value : Json) -> String raise PlanError {
  match value {
    String(s) => s
    _ => fail("expected string")
  }
}

///|
fn number(value : Json) -> Int32 raise PlanError {
  match value {
    Number(n, repr=Some(token)) => {
      if token.length() < 1 || token.length() > 10 {
        fail("integer token out of range")
      }
      for i in 0..<token.length() {
        let c = token[i]
        if (c < 48 || c > 57) && !(i == 0 && c == 45) {
          fail("use decimal integer tokens, no fractions or exponents")
        }
      }
      if n < 0.0 || n > 2000000.0 {
        fail("number outside supported nonnegative range")
      }
      n.to_int()
    }
    _ => fail("expected integer token")
  }
}

///|
fn int_default(
  f : Map[String, Json],
  key : String,
  default : Int32,
) -> Int32 raise PlanError {
  match f.get(key) {
    Some(v) => number(v)
    None => default
  }
}

///|
fn boolean(
  f : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool raise PlanError {
  match f.get(key) {
    None => default
    Some(True) => true
    Some(False) => false
    _ => fail("expected boolean")
  }
}

///|
fn array(value : Json, max : Int32) -> Array[Json] raise PlanError {
  match value {
    Array(a) => {
      if a.length() > max {
        fail("array capacity exceeded")
      }
      a
    }
    _ => fail("expected array")
  }
}

///|
fn read_timetable(value : Json) -> Timetable raise PlanError {
  let f = object(value)
  only(f, ["name", "stops", "trips", "footpaths"])
  let stops = array(required(f, "stops"), 512).map(v => {
    let s = object(v)
    only(s, ["id", "name", "min_change", "accessible"])
    let id = text(required(s, "id"))
    let name = match s.get("name") {
      Some(v) => text(v)
      None => id
    }
    Stop::{
      id,
      name,
      min_change: int_default(s, "min_change", 0),
      accessible: boolean(s, "accessible", false),
    }
  })
  let trips = array(required(f, "trips"), 2048).map(v => {
    let s = object(v)
    only(s, ["id", "calls", "accessible", "cancelled", "delay"])
    let calls = array(required(s, "calls"), 128).map(v => {
      let c = object(v)
      only(c, ["stop", "arrival", "departure", "pickup", "dropoff"])
      Call::{
        stop: text(required(c, "stop")),
        arrival: number(required(c, "arrival")),
        departure: number(required(c, "departure")),
        pickup: boolean(c, "pickup", true),
        dropoff: boolean(c, "dropoff", true),
      }
    })
    Trip::{
      id: text(required(s, "id")),
      calls,
      accessible: boolean(s, "accessible", false),
      cancelled: boolean(s, "cancelled", false),
      delay: int_default(s, "delay", 0),
    }
  })
  let paths = match f.get("footpaths") {
    None => []
    Some(v) => array(v, 4096)
  }
  let footpaths = paths.map(v => {
    let s = object(v)
    only(s, ["id", "from", "to", "duration", "accessible"])
    Footpath::{
      id: text(required(s, "id")),
      from: text(required(s, "from")),
      to: text(required(s, "to")),
      duration: number(required(s, "duration")),
      accessible: boolean(s, "accessible", false),
    }
  })
  let t = Timetable::{
    name: text(required(f, "name")),
    stops,
    trips,
    footpaths,
  }
  validate(t)
  t
}

///|
fn read_query(value : Json) -> Query raise PlanError {
  let f = object(value)
  only(f, [
    "from", "to", "departure", "latest", "max_boardings", "max_walk", "accessible",
    "max_labels", "max_work",
  ])
  query(
    text(required(f, "from")),
    text(required(f, "to")),
    number(required(f, "departure")),
    latest=int_default(f, "latest", 259199),
    max_boardings=int_default(f, "max_boardings", 4),
    max_walk=int_default(f, "max_walk", 1800),
    accessible=boolean(f, "accessible", false),
    max_labels=int_default(f, "max_labels", 100000),
    max_work=int_default(f, "max_work", 2000000),
  )
}

///|
fn read_scenario(t : Timetable, value : Json) -> Timetable raise PlanError {
  let f = object(value)
  only(f, ["updates", "closed_paths"])
  let values = match f.get("updates") {
    None => []
    Some(v) => array(v, 2048)
  }
  let updates = values.map(v => {
    let u = object(v)
    only(u, ["id", "delay", "cancelled"])
    TripUpdate::{
      id: text(required(u, "id")),
      delay: int_default(u, "delay", 0),
      cancelled: boolean(u, "cancelled", false),
    }
  })
  let closed = match f.get("closed_paths") {
    None => []
    Some(v) => array(v, 4096).map(text)
  }
  scenario(t, updates, closed_paths=closed)
}

///|
pub fn decode_timetable(source : String) -> Timetable raise PlanError {
  read_timetable(document(source))
}

///|
/// Decode a complete versioned request, including optional scenario overrides.
pub fn decode_request(source : String) -> (Timetable, Query) raise PlanError {
  let f = object(document(source))
  only(f, ["schema_version", "timetable", "query", "scenario"])
  if number(required(f, "schema_version")) != 1 {
    fail("unsupported schema_version")
  }
  let base = read_timetable(required(f, "timetable"))
  let t = match f.get("scenario") {
    Some(v) => read_scenario(base, v)
    None => base
  }
  let q = read_query(required(f, "query"))
  validate_query(t, q)
  (t, q)
}

///|
pub fn plan_json(source : String) -> String raise PlanError {
  let (t, q) = decode_request(source)
  plan(t, q).to_json().stringify()
}

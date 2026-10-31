///|
/// An explicitly maintained stop. min_change is seconds before reboarding.
pub(all) struct Stop {
  id : String
  name : String
  min_change : Int32
  accessible : Bool
} derive(Eq, ToJson)

///|
/// Times are service-day seconds, including hours beyond 24.
pub(all) struct Call {
  stop : String
  arrival : Int32
  departure : Int32
  pickup : Bool
  dropoff : Bool
} derive(Eq, ToJson)

///|
pub(all) struct Trip {
  id : String
  calls : Array[Call]
  accessible : Bool
  cancelled : Bool
  delay : Int32
} derive(Eq, ToJson)

///|
/// Directed walking link; positive duration makes its resource use explicit.
pub(all) struct Footpath {
  id : String
  from : String
  to : String
  duration : Int32
  accessible : Bool
} derive(Eq, ToJson)

///|
/// Functions validate and detach this caller-owned value before use.
pub(all) struct Timetable {
  name : String
  stops : Array[Stop]
  trips : Array[Trip]
  footpaths : Array[Footpath]
} derive(Eq, ToJson)

///|
pub(all) struct Query {
  from : String
  to : String
  departure : Int32
  latest : Int32
  max_boardings : Int32
  max_walk : Int32
  accessible : Bool
  max_labels : Int32
  max_work : Int32
} derive(Eq, ToJson)

///|
/// A ride may pass intermediate calls without another boarding.
pub(all) struct Leg {
  kind : String
  id : String
  from : String
  to : String
  departure : Int32
  arrival : Int32
  board_index : Int32
  alight_index : Int32
} derive(Eq, ToJson)

///|
pub(all) struct Journey {
  arrival : Int32
  boardings : Int32
  walked : Int32
  legs : Array[Leg]
} derive(Eq, ToJson)

///|
pub(all) struct Report {
  schema_version : Int32
  timetable : String
  query : Query
  status : String
  complete : Bool
  journeys : Array[Journey]
  labels : Int32
  work : Int32
} derive(ToJson)

///|
pub(all) suberror PlanError {
  PlanError(String)
} derive(Eq)

///|
fn[T] fail(message : String) -> T raise PlanError {
  raise PlanError(message)
}

///|
pub fn query(
  from : String,
  to : String,
  departure : Int32,
  latest~ : Int32 = 259199,
  max_boardings~ : Int32 = 4,
  max_walk~ : Int32 = 1800,
  accessible~ : Bool = false,
  max_labels~ : Int32 = 100000,
  max_work~ : Int32 = 2000000,
) -> Query {
  {
    from,
    to,
    departure,
    latest,
    max_boardings,
    max_walk,
    accessible,
    max_labels,
    max_work,
  }
}

///|
fn identifier(s : String) -> Unit raise PlanError {
  if s.length() < 1 || s.length() > 128 {
    fail("IDs must contain 1..128 UTF-16 units")
  }
}

///|
/// Validate all references, event chronology and resource bounds up front.
pub fn validate(t : Timetable) -> Unit raise PlanError {
  if t.name.length() > 256 ||
    t.stops.length() < 1 ||
    t.stops.length() > 512 ||
    t.trips.length() > 2048 ||
    t.footpaths.length() > 4096 {
    fail("timetable capacity exceeded")
  }
  let stops : Map[String, Bool] = Map([])
  for s in t.stops {
    identifier(s.id)
    if s.name.length() > 256 || s.min_change < 0 || s.min_change > 86400 {
      fail("invalid stop attributes")
    }
    if stops.contains(s.id) {
      fail("duplicate stop ID")
    }
    stops[s.id] = true
  }
  let trips : Map[String, Bool] = Map([])
  let mut total = 0
  for trip in t.trips {
    identifier(trip.id)
    if trips.contains(trip.id) {
      fail("duplicate trip ID")
    }
    trips[trip.id] = true
    if trip.calls.length() < 2 ||
      trip.calls.length() > 128 ||
      trip.delay < 0 ||
      trip.delay > 86400 {
      fail("invalid trip size or delay")
    }
    total = total + trip.calls.length()
    if total > 20000 {
      fail("at most 20000 stop calls")
    }
    let mut previous = 0
    for c in trip.calls {
      if !stops.contains(c.stop) {
        fail("call references unknown stop")
      }
      if c.arrival < previous ||
        c.arrival < 0 ||
        c.departure < c.arrival ||
        c.departure.to_int64() + trip.delay.to_int64() > 259199 {
        fail("invalid or overflowing trip chronology")
      }
      previous = c.departure
    }
  }
  let links : Map[String, Bool] = Map([])
  for f in t.footpaths {
    identifier(f.id)
    if links.contains(f.id) {
      fail("duplicate footpath ID")
    }
    links[f.id] = true
    if !stops.contains(f.from) ||
      !stops.contains(f.to) ||
      f.duration < 1 ||
      f.duration > 86400 {
      fail("invalid footpath")
    }
  }
}

///|
pub fn validate_query(t : Timetable, q : Query) -> Unit raise PlanError {
  validate(t)
  if !t.stops.any(s => s.id == q.from) || !t.stops.any(s => s.id == q.to) {
    fail("query references unknown stop")
  }
  if q.departure < 0 ||
    q.latest < q.departure ||
    q.latest > 259199 ||
    q.max_boardings < 0 ||
    q.max_boardings > 8 ||
    q.max_walk < 0 ||
    q.max_walk > 86400 ||
    q.max_labels < 1 ||
    q.max_labels > 100000 ||
    q.max_work < 1 ||
    q.max_work > 2000000 {
    fail("invalid query bounds")
  }
}

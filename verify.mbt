///|
/// Verify feasibility against original facts, not optimality/completeness.
pub fn verify_journey(
  t : Timetable,
  q : Query,
  j : Journey,
) -> Bool raise PlanError {
  validate_query(t, q)
  if j.legs.length() > 8192 {
    return false
  }
  let stops : Map[String, Stop] = Map([])
  let trips : Map[String, Trip] = Map([])
  let paths : Map[String, Footpath] = Map([])
  for s in t.stops {
    stops[s.id] = s
  }
  for trip in t.trips {
    trips[trip.id] = trip
  }
  for f in t.footpaths {
    paths[f.id] = f
  }
  if q.accessible && (!stops[q.from].accessible || !stops[q.to].accessible) {
    return false
  }
  let mut current = q.from
  let mut clock = q.departure
  let mut count = 0
  let mut walked = 0
  for leg in j.legs {
    if leg.from != current {
      return false
    }
    match leg.kind {
      "walk" => {
        let f = match paths.get(leg.id) {
          Some(f) => f
          None => return false
        }
        if f.from != leg.from ||
          f.to != leg.to ||
          leg.departure != clock ||
          leg.arrival != clock + f.duration ||
          leg.board_index != -1 ||
          leg.alight_index != -1 {
          return false
        }
        if q.accessible && (!f.accessible || !stops[f.to].accessible) {
          return false
        }
        walked = walked + f.duration
      }
      "ride" => {
        let trip = match trips.get(leg.id) {
          Some(v) => v
          None => return false
        }
        if trip.cancelled ||
          leg.board_index < 0 ||
          leg.alight_index <= leg.board_index ||
          leg.alight_index >= trip.calls.length() {
          return false
        }
        let board = trip.calls[leg.board_index]
        let alight = trip.calls[leg.alight_index]
        let ready = clock +
          (if count == 0 { 0 } else { stops[current].min_change })
        if !board.pickup ||
          !alight.dropoff ||
          board.stop != leg.from ||
          alight.stop != leg.to ||
          board.departure + trip.delay != leg.departure ||
          alight.arrival + trip.delay != leg.arrival ||
          leg.departure < ready {
          return false
        }
        if q.accessible &&
          (
            !trip.accessible ||
            !stops[board.stop].accessible ||
            !stops[alight.stop].accessible
          ) {
          return false
        }
        count = count + 1
      }
      _ => return false
    }
    clock = leg.arrival
    current = leg.to
    if clock > q.latest || walked > q.max_walk || count > q.max_boardings {
      return false
    }
  }
  current == q.to &&
  clock == j.arrival &&
  count == j.boardings &&
  walked == j.walked
}

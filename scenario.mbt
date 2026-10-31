///|
/// Absolute delay and cancellation overrides, applied to a detached snapshot.
pub(all) struct TripUpdate {
  id : String
  delay : Int32
  cancelled : Bool
} derive(Eq, ToJson)

///|
pub extend TripUpdate with Eq::{equal, not_equal}

///|
pub extend TripUpdate with ToJson::{to_json}

///|
/// Recompute from source facts; failure cannot partly mutate the input network.
pub fn scenario(
  t : Timetable,
  updates : Array[TripUpdate],
  closed_paths~ : Array[String] = [],
) -> Timetable raise PlanError {
  validate(t)
  if updates.length() > 2048 || closed_paths.length() > 4096 {
    fail("scenario capacity exceeded")
  }
  let by_id : Map[String, TripUpdate] = Map([])
  for u in updates {
    if by_id.contains(u.id) || !t.trips.any(trip => trip.id == u.id) {
      fail("duplicate or unknown updated trip")
    }
    if u.delay < 0 || u.delay > 86400 {
      fail("invalid absolute delay")
    }
    by_id[u.id] = u
  }
  let closed : Map[String, Bool] = Map([])
  for id in closed_paths {
    if closed.contains(id) || !t.footpaths.any(f => f.id == id) {
      fail("duplicate or unknown closed path")
    }
    closed[id] = true
  }
  let trips = t.trips.map(fn(trip) {
    match by_id.get(trip.id) {
      None => { ..trip, calls: trip.calls.copy(), }
      Some(u) =>
        {
          ..trip,
          calls: trip.calls.copy(),
          delay: u.delay,
          cancelled: u.cancelled,
        }
    }
  })
  let result = {
    ..t,
    stops: t.stops.copy(),
    trips,
    footpaths: t.footpaths.filter(f => !closed.contains(f.id)),
  }
  validate(result)
  result
}

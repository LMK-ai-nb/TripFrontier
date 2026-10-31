///|
fn stop(id : String, change~ : Int32 = 0, accessible~ : Bool = true) -> Stop {
  { id, name: id, min_change: change, accessible, }
}

///|
fn call(
  id : String,
  time : Int32,
  pickup~ : Bool = true,
  dropoff~ : Bool = true,
) -> Call {
  { stop: id, arrival: time, departure: time, pickup, dropoff, }
}

///|
fn trip(
  id : String,
  calls : Array[Call],
  accessible~ : Bool = true,
  cancelled~ : Bool = false,
  delay~ : Int32 = 0,
) -> Trip {
  { id, calls, accessible, cancelled, delay, }
}

///|
fn table(
  stops : Array[Stop],
  trips : Array[Trip],
  footpaths~ : Array[Footpath] = [],
) -> Timetable {
  { name: "synthetic", stops, trips, footpaths, }
}

///|
test "validate overnight, repeated-stop and nondecreasing call times" {
  validate(
    table([stop("A"), stop("B")], [
      trip("t", [call("A", 86000), call("B", 87000), call("A", 88000)]),
    ]),
  )
}

///|
test "reject duplicate identities, unknown references and decreasing times" {
  for
    t in [
      table([stop("A"), stop("A")], []),
      table([stop("A")], [trip("t", [call("A", 10), call("B", 20)])]),
      table([stop("A")], [trip("t", [call("A", 10), call("A", 9)])]),
    ] {
    assert_true(
      try {
        validate(t)
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "later low-walking labels survive beside an earlier high-walking label" {
  let t = table(
    [stop("A"), stop("B"), stop("D")],
    [
      trip("to-b", [call("A", 1), call("B", 6)]),
      trip("to-d", [call("B", 7), call("D", 10)]),
    ],
    footpaths=[{ id: "ab", from: "A", to: "B", duration: 5, accessible: true, }],
  )
  let r = plan(t, query("A", "D", 0, max_walk=5))
  assert_eq(r.journeys.length(), 2)
  assert_eq(r.journeys[0].boardings, 1)
  assert_eq(r.journeys[0].walked, 5)
  assert_eq(r.journeys[1].boardings, 2)
  assert_eq(r.journeys[1].walked, 0)
}

///|
test "walking-only and transit answers form a proper three-dimensional frontier" {
  let t = table(
    [stop("A"), stop("D")],
    [trip("bus", [call("A", 2), call("D", 5)])],
    footpaths=[
      { id: "walk", from: "A", to: "D", duration: 10, accessible: true, },
    ],
  )
  let r = plan(t, query("A", "D", 0, max_walk=10))
  assert_eq(r.journeys.length(), 2)
  for j in r.journeys {
    assert_true(verify_journey(t, r.query, j))
  }
}

///|
test "walking cycles terminate and equal-score witnesses are deterministic" {
  let links : Array[Footpath] = [
    { id: "ab", from: "A", to: "B", duration: 1, accessible: true, },
    { id: "ba", from: "B", to: "A", duration: 1, accessible: true, },
  ]
  let t = table(
    [stop("A"), stop("B"), stop("D")],
    [
      trip("z", [call("B", 4), call("D", 8)]),
      trip("a", [call("B", 4), call("D", 8)]),
    ],
    footpaths=links,
  )
  let q = query("A", "D", 0, max_walk=20)
  let r = plan(t, q)
  assert_eq(r.journeys.length(), 1)
  assert_eq(r.journeys[0].legs[1].id, "a")
  assert_true(plan({ ..t, trips: t.trips.rev(), }, q).journeys == r.journeys)
}

///|
test "repeated stop calls and pickup/dropoff flags retain actual call indices" {
  let t = table([stop("A"), stop("D")], [
    trip("loop", [call("A", 1, pickup=false), call("A", 3), call("D", 5)]),
  ])
  let r = plan(t, query("A", "D", 0))
  assert_eq(r.journeys[0].legs[0].board_index, 1)
  assert_true(verify_journey(t, r.query, r.journeys[0]))
}

///|
test "transfers after walking charge destination buffer, first boarding does not" {
  let t = table(
    [stop("A"), stop("B"), stop("C", change=3), stop("D")],
    [
      trip("ab", [call("A", 1), call("B", 5)]),
      trip("cd", [call("C", 9), call("D", 12)]),
    ],
    footpaths=[{ id: "bc", from: "B", to: "C", duration: 2, accessible: true, }],
  )
  assert_eq(plan(t, query("A", "D", 0)).journeys.length(), 0)
  assert_eq(plan(t, query("B", "D", 5)).journeys[0].arrival, 12)
}

///|
test "destination deadline and delayed midnight trips use service-day seconds" {
  let t = table([stop("A"), stop("D")], [
    trip("night", [call("A", 86390), call("D", 86410)], delay=5),
  ])
  let r = plan(t, query("A", "D", 86395, latest=86415))
  assert_eq(r.journeys[0].arrival, 86415)
  assert_eq(plan(t, query("A", "D", 86396)).journeys.length(), 0)
  assert_eq(plan(t, query("A", "D", 86395, latest=86414)).journeys.length(), 0)
}

///|
test "caller edits of results cannot alter timetable call arrays" {
  let t = table([stop("A"), stop("D")], [
    trip("t", [call("A", 1), call("D", 2)]),
  ])
  let r = plan(t, query("A", "D", 0))
  r.journeys[0].legs.clear()
  assert_eq(plan(t, query("A", "D", 0)).journeys[0].legs.length(), 1)
}

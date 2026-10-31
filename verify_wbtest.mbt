///|
test "every returned itinerary replays against stop calls and exact transfer buffer" {
  let t = table([stop("A"), stop("B", change=3), stop("D")], [
    trip("one", [call("A", 10), call("B", 20)]),
    trip("too-soon", [call("B", 22), call("D", 25)]),
    trip("ok", [call("B", 23), call("D", 30)]),
  ])
  let q = query("A", "D", 0)
  let result = plan(t, q)
  assert_eq(result.journeys[0].arrival, 30)
  assert_true(verify_journey(t, q, result.journeys[0]))
  let forged = { ..result.journeys[0], arrival: 29, }
  assert_true(!verify_journey(t, q, forged))
  let legs = result.journeys[0].legs.copy()
  legs[1] = { ..legs[1], id: "too-soon", departure: 22, arrival: 25, }
  assert_true(
    !verify_journey(t, q, { ..result.journeys[0], arrival: 25, legs, }),
  )
}

///|
test "accessibility applies to boarding/alighting rather than through-station passage" {
  let t = table([stop("A"), stop("B", accessible=false), stop("D")], [
    trip("good", [call("A", 10), call("B", 20), call("D", 30)]),
    trip("bad", [call("A", 9), call("D", 25)], accessible=false),
  ])
  let q = query("A", "D", 0, accessible=true)
  let r = plan(t, q)
  assert_eq(r.journeys[0].arrival, 30)
  assert_true(verify_journey(t, q, r.journeys[0]))
  assert_eq(plan(t, query("A", "B", 0, accessible=true)).journeys.length(), 0)
}

///|
test "equal origin destination yields a valid zero-leg journey" {
  let t = table([stop("A")], [])
  let q = query("A", "A", 100, max_boardings=0, max_walk=0)
  let r = plan(t, q)
  assert_eq(r.journeys[0].arrival, 100)
  assert_eq(r.journeys[0].legs.length(), 0)
  assert_true(verify_journey(t, q, r.journeys[0]))
}

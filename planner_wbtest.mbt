///|
test "an early arrival can trade a second boarding for a later direct journey" {
  let t = table([stop("A"), stop("B", change=2), stop("D")], [
    trip("first", [call("A", 10), call("B", 20)]),
    trip("second", [call("B", 22), call("D", 30)]),
    trip("direct", [call("A", 12), call("D", 40)]),
  ])
  let r = plan(t, query("A", "D", 0, max_walk=0))
  assert_eq(r.journeys.length(), 2)
  assert_eq(r.journeys[0].arrival, 30)
  assert_eq(r.journeys[0].boardings, 2)
  assert_eq(r.journeys[1].arrival, 40)
  assert_eq(r.journeys[1].boardings, 1)
  assert_eq(
    plan(t, query("A", "D", 0, max_boardings=1)).journeys[0].arrival,
    40,
  )
}

///|
test "staying on the same trip ignores interchange and no-pickup intermediate calls" {
  let t = table([stop("A"), stop("B", change=1000), stop("D")], [
    trip("through", [
      call("A", 10),
      call("B", 20, pickup=false, dropoff=false),
      call("D", 30),
    ]),
  ])
  let r = plan(t, query("A", "D", 0, max_boardings=1))
  assert_eq(r.journeys[0].boardings, 1)
  assert_eq(r.journeys[0].legs.length(), 1)
  assert_eq(r.journeys[0].legs[0].alight_index, 2)
}

///|
test "multi-hop walks enforce directed links, total walking budget and readiness" {
  let paths : Array[Footpath] = [
    { id: "ab", from: "A", to: "B", duration: 3, accessible: true, },
    { id: "bc", from: "B", to: "C", duration: 4, accessible: true, },
  ]
  let t = table(
    [stop("A"), stop("B"), stop("C"), stop("D")],
    [trip("bus", [call("C", 7), call("D", 12)])],
    footpaths=paths,
  )
  assert_eq(plan(t, query("A", "D", 0, max_walk=7)).journeys[0].arrival, 12)
  assert_eq(plan(t, query("A", "D", 0, max_walk=6)).journeys.length(), 0)
  assert_eq(plan(t, query("C", "A", 0)).journeys.length(), 0)
}

///|
test "overtaking does not discard a later faster trip" {
  let t = table([stop("A"), stop("D")], [
    trip("slow", [call("A", 10), call("D", 50)]),
    trip("fast", [call("A", 20), call("D", 30)]),
  ])
  assert_eq(plan(t, query("A", "D", 0)).journeys[0].arrival, 30)
}

///|
test "small explicit budgets fail instead of returning a partial frontier" {
  let t = table([stop("A"), stop("D")], [
    trip("t", [call("A", 1), call("D", 2)]),
  ])
  assert_true(
    try {
      ignore(plan(t, query("A", "D", 0, max_labels=1)))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(plan(t, query("A", "D", 0, max_work=1)))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "delay misses a transfer; original and alternate snapshots are independent" {
  let t = table([stop("A"), stop("B", change=2), stop("D")], [
    trip("one", [call("A", 10), call("B", 20)]),
    trip("two", [call("B", 22), call("D", 30)]),
    trip("direct", [call("A", 15), call("D", 45)]),
  ])
  let q = query("A", "D", 0)
  assert_eq(plan(t, q).journeys[0].arrival, 30)
  let changed = scenario(t, [{ id: "one", delay: 1, cancelled: false, }])
  assert_eq(plan(changed, q).journeys[0].arrival, 45)
  assert_eq(plan(t, q).journeys[0].arrival, 30)
  let cancel = scenario(t, [{ id: "two", delay: 0, cancelled: true, }])
  assert_eq(plan(cancel, q).journeys[0].arrival, 45)
  changed.trips[0].calls.push(call("D", 50))
  assert_eq(t.trips[0].calls.length(), 2)
}

///|
test "closing a footpath creates an unreachable result, without rewriting the source" {
  let t = table([stop("A"), stop("D")], [], footpaths=[
    { id: "link", from: "A", to: "D", duration: 5, accessible: true, },
  ])
  assert_eq(plan(t, query("A", "D", 0)).journeys.length(), 1)
  let changed = scenario(t, [], closed_paths=["link"])
  assert_eq(plan(changed, query("A", "D", 0)).journeys.length(), 0)
  assert_eq(t.footpaths.length(), 1)
}

///|
test "invalid scenario references and overflowing delay reject atomically" {
  let t = table([stop("A"), stop("D")], [
    trip("t", [call("A", 259190), call("D", 259199)]),
  ])
  assert_true(
    try {
      ignore(scenario(t, [{ id: "t", delay: 1, cancelled: false, }]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(scenario(t, [{ id: "unknown", delay: 0, cancelled: true, }]))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(t.trips[0].delay, 0)
}

///|
test "typed timetable serializes to strict roundtrip without losing call semantics" {
  let t = table([stop("A"), stop("B")], [
    trip("t", [call("A", 1, pickup=false), call("B", 2)], cancelled=true),
  ])
  assert_true(decode_timetable(encode_timetable(t)) == t)
}

///|
test "strict JSON rejects key collisions, floats, exponents and misspelled fields" {
  for
    source in [
      "{\"name\":\"a\",\"na\\u006de\":\"b\",\"stops\":[],\"trips\":[]}", "{\"name\":\"t\",\"stops\":[{\"id\":\"a\",\"min_change\":1.00000000000000001}],\"trips\":[]}",
      "{\"name\":\"t\",\"stops\":[{\"id\":\"a\",\"min_change\":1e0}],\"trips\":[]}",
      "{\"name\":\"t\",\"stops\":[{\"id\":\"a\",\"min_change\":1e-999}],\"trips\":[]}",
      "{\"name\":\"t\",\"stops\":[{\"id\":\"a\",\"min_chang\":1}],\"trips\":[]}",
    ] {
    assert_true(
      try {
        ignore(decode_timetable(source))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "unverified access defaults to false, never an implicit accessible claim" {
  let t = decode_timetable(
    "{\"name\":\"t\",\"stops\":[{\"id\":\"a\"}],\"trips\":[]}",
  )
  assert_true(!t.stops[0].accessible)
  assert_eq(plan(t, query("a", "a", 0, accessible=true)).journeys.length(), 0)
}

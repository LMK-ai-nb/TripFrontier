///|
fn main {
  let source =
    #|{"schema_version":1,"timetable":{"name":"commute","stops":[{"id":"A"},{"id":"B","min_change":2},{"id":"D"}],"trips":[{"id":"first","calls":[{"stop":"A","arrival":10,"departure":10},{"stop":"B","arrival":20,"departure":20}]},{"id":"second","calls":[{"stop":"B","arrival":22,"departure":22},{"stop":"D","arrival":30,"departure":30}]},{"id":"direct","calls":[{"stop":"A","arrival":12,"departure":12},{"stop":"D","arrival":40,"departure":40}]}]},"query":{"from":"A","to":"D","departure":0,"max_walk":0}}
  let (t, q) = @p.decode_request(source) catch { _ => abort("invalid example") }
  let report = @p.plan(t, q) catch { _ => abort("search failed") }
  if report.journeys.length() != 2 {
    abort("wrong frontier cardinality")
  }
  for j in report.journeys {
    if !(@p.verify_journey(t, q, j) catch { _ => false }) {
      abort("invalid itinerary")
    }
    println(
      "arrival=\{j.arrival}, boardings=\{j.boardings}, walked=\{j.walked}",
    )
  }
  let delayed = @p.scenario(t, [{ id: "first", delay: 1, cancelled: false, }]) catch {
    _ => abort("invalid scenario")
  }
  let after = @p.plan(delayed, q) catch { _ => abort("scenario failed") }
  if after.journeys[0].arrival != 40 {
    abort("delay did not invalidate transfer")
  }
  println("after delay: arrival=\{after.journeys[0].arrival}")
}

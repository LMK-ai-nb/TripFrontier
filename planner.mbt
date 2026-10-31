///|
/// Search state is private; parent indices retain immutable witnesses.
priv struct Label {
  stop : Int32
  arrival : Int32
  boardings : Int32
  walked : Int32
  parent : Int32
  leg : Leg?
}

///|
priv struct Search {
  q : Query
  labels : Array[Label]
  active : Array[Bool]
  frontiers : Map[(Int32, Int32), Array[Int32]]
  mut work : Int32
}

///|
fn Search::charge(self : Search) -> Unit raise PlanError {
  if self.work >= self.q.max_work {
    fail("SEARCH_WORK_LIMIT: no complete frontier returned")
  }
  self.work = self.work + 1
}

///|
/// Keep one witness per nondominated arrival/walking pair at exact boarding count.
fn Search::admit(self : Search, label : Label) -> Unit raise PlanError {
  self.charge()
  if label.arrival > self.q.latest ||
    label.walked > self.q.max_walk ||
    label.boardings > self.q.max_boardings {
    return
  }
  let key = (label.stop, label.boardings)
  let current = self.frontiers.get(key).unwrap_or([])
  for id in current {
    self.charge()
    let old = self.labels[id]
    if old.arrival <= label.arrival && old.walked <= label.walked {
      return
    }
  }
  let keep = []
  for id in current {
    self.charge()
    let old = self.labels[id]
    if label.arrival <= old.arrival && label.walked <= old.walked {
      self.active[id] = false
    } else {
      keep.push(id)
    }
  }
  if self.labels.length() >= self.q.max_labels {
    fail("SEARCH_LABEL_LIMIT: no complete frontier returned")
  }
  keep.push(self.labels.length())
  self.frontiers[key] = keep
  self.labels.push(label)
  self.active.push(true)
}

///|
fn journey_order(a : Journey, b : Journey) -> Int32 {
  if a.arrival != b.arrival {
    a.arrival.compare(b.arrival)
  } else if a.boardings != b.boardings {
    a.boardings.compare(b.boardings)
  } else {
    a.walked.compare(b.walked)
  }
}

///|
fn dominates(a : Journey, b : Journey) -> Bool {
  a.arrival <= b.arrival && a.boardings <= b.boardings && a.walked <= b.walked
}

///|
fn Search::witness(self : Search, index : Int32) -> Journey {
  let last = self.labels[index]
  let reverse = []
  let mut at = index
  while self.labels[at].parent >= 0 {
    if self.labels[at].leg is Some(leg) {
      reverse.push(leg)
    }
    at = self.labels[at].parent
  }
  let forward = Array::makei(reverse.length(), i => {
    reverse[reverse.length() - 1 - i]
  })
  {
    arrival: last.arrival,
    boardings: last.boardings,
    walked: last.walked,
    legs: forward,
  }
}

///|
/// Exact within explicit query/model/resource bounds. No online service calls.
pub fn plan(t : Timetable, q : Query) -> Report raise PlanError {
  validate_query(t, q)
  let index : Map[String, Int32] = Map([])
  for i, s in t.stops {
    index[s.id] = i
  }
  let origin = index[q.from]
  let target = index[q.to]
  let search = Search::{
    q,
    labels: [],
    active: [],
    frontiers: Map([]),
    work: 0,
  }
  if q.accessible &&
    (!t.stops[origin].accessible || !t.stops[target].accessible) {
    return {
      schema_version: 1,
      timetable: t.name,
      query: q,
      status: "unreachable",
      complete: true,
      journeys: [],
      labels: 0,
      work: 0,
    }
  }
  let walking : Map[Int32, Array[Footpath]] = Map([])
  let departures : Map[Int32, Array[(Int32, Int32)]] = Map([])
  // Normalize iteration order for deterministic equal-score witnesses.
  let paths = t.footpaths.copy()
  paths.sort_by(fn(a, b) { a.id.compare(b.id) })
  let trips = t.trips.copy()
  trips.sort_by(fn(a, b) { a.id.compare(b.id) })
  for f in paths {
    let k = index[f.from]
    match walking.get(k) {
      Some(a) => a.push(f)
      None => walking[k] = [f]
    }
  }
  for ti, trip in trips {
    if trip.cancelled || (q.accessible && !trip.accessible) {
      continue
    }
    for ci in 0..<(trip.calls.length() - 1) {
      let c = trip.calls[ci]
      if !c.pickup || (q.accessible && !t.stops[index[c.stop]].accessible) {
        continue
      }
      let k = index[c.stop]
      match departures.get(k) {
        Some(a) => a.push((ti, ci))
        None => departures[k] = [(ti, ci)]
      }
    }
  }
  search.admit({
    stop: origin,
    arrival: q.departure,
    boardings: 0,
    walked: 0,
    parent: -1,
    leg: None,
  })
  let mut cursor = 0
  while cursor < search.labels.length() {
    let id = cursor
    cursor = cursor + 1
    if !search.active[id] {
      continue
    }
    let label = search.labels[id]
    // Reaching the destination already dominates any subsequent departure from it.
    if label.stop == target {
      continue
    }
    for f in walking.get(label.stop).unwrap_or([]) {
      search.charge()
      let to = index[f.to]
      if q.accessible && (!f.accessible || !t.stops[to].accessible) {
        continue
      }
      let arrival = label.arrival + f.duration
      let leg = Leg::{
        kind: "walk",
        id: f.id,
        from: f.from,
        to: f.to,
        departure: label.arrival,
        arrival,
        board_index: -1,
        alight_index: -1,
      }
      search.admit({
        stop: to,
        arrival,
        boardings: label.boardings,
        walked: label.walked + f.duration,
        parent: id,
        leg: Some(leg),
      })
    }
    if label.boardings >= q.max_boardings {
      continue
    }
    let ready = label.arrival +
      (if label.boardings == 0 { 0 } else { t.stops[label.stop].min_change })
    for pair in departures.get(label.stop).unwrap_or([]) {
      search.charge()
      let (ti, ci) = pair
      let trip = trips[ti]
      let board = trip.calls[ci]
      let departure = board.departure + trip.delay
      if departure < ready || departure > q.latest {
        continue
      }
      for ai in (ci + 1)..<trip.calls.length() {
        search.charge()
        let alight = trip.calls[ai]
        if !alight.dropoff ||
          (q.accessible && !t.stops[index[alight.stop]].accessible) {
          continue
        }
        let arrival = alight.arrival + trip.delay
        let leg = Leg::{
          kind: "ride",
          id: trip.id,
          from: board.stop,
          to: alight.stop,
          departure,
          arrival,
          board_index: ci,
          alight_index: ai,
        }
        search.admit({
          stop: index[alight.stop],
          arrival,
          boardings: label.boardings + 1,
          walked: label.walked,
          parent: id,
          leg: Some(leg),
        })
      }
    }
  }
  let candidates = []
  for b in 0..<=q.max_boardings {
    for id in search.frontiers.get((target, b)).unwrap_or([]) {
      candidates.push(search.witness(id))
    }
  }
  candidates.sort_by(journey_order)
  let result : Array[Journey] = []
  for candidate in candidates {
    if !result.any(old => dominates(old, candidate)) {
      result.push(candidate)
    }
  }
  {
    schema_version: 1,
    timetable: t.name,
    query: q,
    status: if result.length() == 0 {
      "unreachable"
    } else {
      "ok"
    },
    complete: true,
    journeys: result,
    labels: search.labels.length(),
    work: search.work,
  }
}

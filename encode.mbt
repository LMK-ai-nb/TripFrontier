///|
/// Serialization does not replace validation at the receiving boundary.
pub fn encode_timetable(t : Timetable) -> String raise PlanError {
  validate(t)
  @json.to_json(t).stringify()
}

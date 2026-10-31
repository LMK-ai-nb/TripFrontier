///|
/// String-in/string-out bridge keeps all routing and validation in MoonBit.
pub fn route_request(source : String) -> String {
  @planner.plan_json(source) catch {
    @planner.PlanError(message) => {
      let code = if message.contains("SEARCH_") {
        "SEARCH_LIMIT"
      } else {
        "INVALID_INPUT"
      }
      let value : Json = {
        "schema_version": 1,
        "error": { "code": code, "message": message },
      }
      value.stringify()
    }
  }
}

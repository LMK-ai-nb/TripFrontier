# 可执行库使用示例

以下代码随 `moon test` 编译、运行，使用公开接口；模块目前是本地临时命名，不是 Mooncakes 安装地址。

```mbt check
///|
test "public library query, route reconstruction and scenario planning" {
  let t : @tripfrontier.Timetable = {
    name: "public API sample",
    stops: [
      { id: "A", name: "A", min_change: 0, accessible: true, },
      { id: "D", name: "D", min_change: 0, accessible: true, },
    ],
    trips: [
      {
        id: "bus",
        accessible: true,
        cancelled: false,
        delay: 0,
        calls: [
          {
            stop: "A",
            arrival: 10,
            departure: 10,
            pickup: true,
            dropoff: true,
          },
          {
            stop: "D",
            arrival: 20,
            departure: 20,
            pickup: true,
            dropoff: true,
          },
        ],
      },
    ],
    footpaths: [],
  }
  let q = @tripfrontier.query("A", "D", 0, max_walk=0)
  let result = @tripfrontier.plan(t, q)
  assert_eq(result.journeys[0].arrival, 20)
  assert_true(@tripfrontier.verify_journey(t, q, result.journeys[0]))
  let delayed = @tripfrontier.scenario(t, [
    { id: "bus", delay: 5, cancelled: false, },
  ])
  assert_eq(@tripfrontier.plan(delayed, q).journeys[0].arrival, 25)
  assert_eq(@tripfrontier.plan(t, q).journeys[0].arrival, 20)
}
```

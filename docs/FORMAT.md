# JSON v1 与公开接口

输入 `schema_version=1`，`timetable`、`query` 必填，`scenario` 可选。完整可运行输入见 `examples/*.json`。

| 对象 | 必填 | 可选及默认 |
| --- | --- | --- |
| timetable | name, stops, trips | footpaths=[] |
| stop | id | name=id, min_change=0, accessible=false |
| trip | id, calls | accessible=false, cancelled=false, delay=0 |
| call | stop, arrival, departure | pickup=true, dropoff=true |
| footpath | id, from, to, duration | accessible=false |
| query | from, to, departure | latest=259199, max_boardings=4, max_walk=1800, accessible=false, max_labels=100000, max_work=2000000 |
| scenario | 无 | updates=[], closed_paths=[] |
| trip update | id | delay=0, cancelled=false |

所有时间使用服务日相对整数秒。`delay` 是绝对覆盖值，不是增量。单个更新未写 cancelled 时默认 false，所以要保留取消状态应显式填写。步行链接为单向，无自动反向边；时刻表不是经纬度路网。

严格 JSON 拒绝重复解码键（含 Unicode 转义等价键）、未知字段、null 代替默认、整数的小数或指数拼写。文本输入上限 8 Mi UTF-16 单元、嵌套 24 层。

输出 Report 包括 normalized query、timetable 名称、status（ok/unreachable）、complete=true、journeys、labels、work。每条行程的 arrival、boardings、walked 是目标值；legs 为完整见证，kind=walk/ride。ride 的 board_index、alight_index 指向班次停站数组；walk 的两索引为 -1。不得将 boardings 与通常的换乘次数混淆。

达到标签或操作预算时抛出错误，不返回 complete=true 的部分结果。JS 适配器返回 `error.code=SEARCH_LIMIT` 或 `INVALID_INPUT`；命令行错误退出 2。正常完整前沿退出 0，给定约束下不可达退出 1。

公开 MoonBit API：`validate`、`validate_query`、`query`、`plan`、`verify_journey`、`scenario`、`encode_timetable`、`decode_timetable`、`decode_request`、`plan_json`。签名以 `pkg.generated.mbti` 为准。可变数组由调用者拥有；求解函数同步读取并验证输入，不修改它，不保留对外可变的搜索实例。结果腿数组可独立修改。

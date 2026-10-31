# 三个完整场景与验证方式

所有数据合成，不对应真实线路/客户。三种场景使用同一份 MoonBit 规划函数；不是三个独立子项目。

| 场景 | 使用者与问题 | 输入与操作 | 预期输出 | 验证 |
| --- | --- | --- | --- | --- |
| 通勤取舍与延误 | 班车/公交信息软件开发者需要同时展示早到和少换乘，且不能把错过的班车继续拼接 | commute.json：08:00 起步，local 08:05→08:20，站点换乘 120s，connector 08:23→08:30，direct 08:10→08:40。再把 local 整体延误 61s | 原前沿为 (08:30,2次上车,0接驳)、(08:40,1次上车,0接驳)；延误 60s 恰好可换，61s 错过后只剩直达 | Node 集成、浏览器边界、MoonBit 缓冲测试 |
| 明确无障碍接驳 | 园区出行应用不能把未知道路或有楼梯的捷径当作可用 | accessible.json：楼梯接驳 60s+quick 08:20 到；明确无障碍坡道 240s+step-free 08:30 到。开关严格无障碍 | 严格模式输出 08:30、1次上车、240s；普通模式前者支配后者，输出 08:20、1次上车、60s | Node 集成、浏览器切换；MoonBit 上下车/车内经过约束 |
| 服务日跨午夜与例外 | 夜间接驳/活动班车工具需要在同一服务日处理 24 点后时刻并选对服务 | examples/gtfs 选择 2026-10-31，周历 DAILY，日期额外加入 SPECIAL；overnight.json 从23:40查询 | 返回 24:10、2次上车 和 24:30、1次上车；选择11-01时 DAILY被移除且SPECIAL不活动，导出无活跃班次 | Python calendar/24h 测试、Node、浏览器、MoonBit 夜间边界 |

运行：

```text
moon run cmd/demo
node scripts/build.mjs
node bin/tripfrontier.mjs examples/commute.json
node bin/tripfrontier.mjs examples/accessible.json
node bin/tripfrontier.mjs examples/overnight.json
python scripts/import_gtfs.py examples/gtfs --date 2026-10-31 --out artifacts/day.json
node --test tests/cli.test.mjs
python -m unittest discover -s tests -p test_gtfs.py
```

情景更新可以在请求增加 scenario：`{"updates":[{"id":"local","delay":61,"cancelled":false}]}`。库的 scenario 还支持取消班次与关闭原生步行链接；变更返回独立快照，原始输入不变。

# 静态 GTFS 子集导入边界

依据 [GTFS Schedule Reference](https://gtfs.org/documentation/schedule/reference/) 的字段语义编写独立适配器，不是 GTFS 全规格实现。使用 Python 标准库读取未压缩 UTF-8 CSV 目录；不自动下载或打开 ZIP。真实 GTFS 数据另有提供方许可证，使用者必须自行确认授权。

```text
python scripts/import_gtfs.py examples/gtfs --date 2026-10-31 --out artifacts/day.json
```

输出 timetable 对象和独立 metadata。将对象放入 v1 请求的 `timetable` 字段，与 query 一起交给 CLI。`examples/overnight.json` 正是从这个样例日期导出；样例全部合成。

支持：stops.txt、trips.txt、明确时刻的 stop_times.txt；calendar.txt 与 calendar_dates.txt；非连续 stop_sequence 排序；24:00:00 之后的服务日时刻；pickup/dropoff 0/1；车站/平台的已知 wheelchair 属性及一级 parent_station 继承；同站 type=2 最短换乘时间。

不同站点的 type=2 transfer 可作为**保守接驳用时链接**导入。该数值是 GTFS 的最小接驳时间，不是测得的纯步行时间；计入预算，且此前乘过车时还叠加到达站 min_change。metadata 明示此映射，因而不能声称导入后与完整 GTFS 路由语义等价或恢复所有 GTFS 可行行程。无法据此推断链接无障碍，默认 false。若要精确的物理步行预算，请使用已核实步行链接的原生 JSON 输入。

明确拒绝：频率班次、pathways 文件的有数据行、贯通 block_id、空白/需插值的到发时刻、按需上客、连续上客、Flex/预约位置、trip/route 专属 transfers、type 0/1/3 等不支持的 transfer 规则。该取舍避免对不支持的语义静默生成路线。仅有标题无数据的可选文件不触发拒绝。

服务日期必须显式输入。先按周历和区间选择服务，再以 calendar_dates 增删；异常可定义无常规周历的服务。导入的是该服务日的班次，可能延伸到后续午夜；不合并相邻服务日的其他班次。多 agency timezone 被拒绝，不处理 DST、时区转换或实时 GTFS-RT。

不使用 stop_lat/lon、shape、票价、headsign 进行路线求解；未建模的纯展示字段可保留在原数据，不能被当作已支持的能力。无障碍未知不当作 true；源数据标记也不等于实际设施核验。每文件 16 MiB、100000 CSV 行，站点/班次/停站还受内核容量限制。

当前只验证了合成且符合这个子集的 feed；**尚未验证真实运营商整份 feed 的兼容性**。这应作为初审边界说明与后续验证事项，不应写成“已完整兼容 GTFS”或“已在某公交系统落地”。

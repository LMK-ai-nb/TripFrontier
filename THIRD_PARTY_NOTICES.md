# 来源、依赖和许可

TripFrontier 的班次模型、三目标标签搜索、行程见证、情景重算、JSON 边界、命令行、网页与测试在此独立编写，使用 AI 辅助开发。没有移植第三方业务实现，没有从 AgentCanary、TideWeave、MoonGate、WasmSlim 或同盘其他项目复制业务源码；不依赖这些工程。

原创代码采用根目录 MIT。MoonBit 运行时仅导入 moonbitlang/core/json；标准库使用 Apache-2.0 WITH LLVM-exception，具体全文和 NOTICE 在 third_party/ 中。构建脚本复制声明到 JS 分发，保留标准库再分发许可。Node/Python 适配使用各自标准库，无第三方运行时库；可选浏览器测试使用 Playwright/Chromium，不打包其实现。

概念参考：[公共交通 RAPTOR 论文](https://www.microsoft.com/en-us/research/wp-content/uploads/2012/01/raptor_alenex.pdf)、[GTFS 官方字段规范](https://gtfs.org/documentation/schedule/reference/)。本项目不是 RAPTOR、OpenTripPlanner、RouteAble 或 ATS 项目的源码移植，也不声称发明多目标行程规划。调研链接与已查明许可证见 docs/RESEARCH.md；未查明的许可不会被假定为可复制。

所有示例时刻表、站名和小型 GTFS 数据由本项目生成，均为合成数据。agency URL 使用保留示例域名，不代表运营机构；坐标不用于求解，也不是实际地图。没有姓名、电话、邮箱、身份证、银行卡、私密行程轨迹或客户数据。

真实 GTFS/设施数据的授权、时区、服务日选择、无障碍事实和时刻准确性由使用者核实；不会因本项目 MIT 许可证而改变其原始数据许可。

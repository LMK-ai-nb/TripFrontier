# 选题调查与独立价值（2026-10-31）

这是有边界的调查，不是“不存在竞品”的证明。调研包含当天重新拉取的 Mooncakes registry（3483 个模块）、公开 GitHub README/元数据、MoonBit community 相关检索及成熟外语项目。未查询私有仓库、未发布工程或所有项目的每个历史版本。原始网页快照仅保存在本机调研目录，不作为本项目开源内容分发。

## 先提出、后放弃的三个候选

| 候选与真实用户 | 已查证的同类 | 核心重合、局限和结论 |
| --- | --- | --- |
| 带锯缝/纹理的材料切割规划：加工店按有限库存生成可切割方案 | [mooncutstock](https://github.com/3smallpig/mooncutstock)（MIT）；[moon_binpack](https://github.com/zmjknn/moon_binpack)（Apache-2.0）；[rectloom](https://github.com/YM-ai-nb/rectloom)（MIT）；外语 [PackingSolver](https://github.com/fontanf/packingsolver)（MIT）、[rectpack](https://github.com/secnot/rectpack)（Apache-2.0） | 已有一维采购/余料及二维 guillotine/矩形排布能力。不能用多加 grain/kerf 宣称独立空白，且当日实现完整工业约束有风险。放弃。 |
| 量纲与不确定度计算：仪器、实验软件处理仿射单位和误差传播 | [LunarUnits](https://github.com/FrozenLemonTee/LunarUnits)、[LunarUncertainty](https://github.com/FrozenLemonTee/LunarUncertainty)（均 Apache-2.0）；外语 [Pint](https://pint.readthedocs.io/en/stable/)、[uncertainties](https://pythonhosted.org/uncertainties/) | 本地当前索引和 README 已覆盖核心单位/测量能力，不能把组合接口当成新主题。外语库功能也成熟。未使用这些代码，两个 Python 项目的逐文件许可未完整核对。放弃。 |
| 丢包与不完整中继编码：边缘传输开发者从独立编码包恢复数据 | [moonrecoder](https://github.com/ZJH-666-ZJH/moonrecoder)（MIT）、[MoonErasure](https://github.com/oyjh0381/MoonErasure)（Apache-2.0）；外语 [Wirehair](https://github.com/catid/wirehair)（BSD-3-Clause）、[rlnc](https://github.com/itzmeanjan/rlnc) | MoonRecoder 已有增量秩、未解码中继重编码、反馈修复和帧处理；MoonErasure 提供 Reed–Solomon 方案。核心需求重合，故放弃，不另写相似库。rlnc 的许可未逐文件核对，不复用。 |

## 补充候选并选择 TripFrontier

TripFrontier 解决乘客行程计算：到站、等车、最短换乘时间、同车直通、步行接驳、班次取消/延误，以及早到/少乘车/少接驳之间的取舍。用户是构建园区班车、公交铁路信息和离线出行应用的开发者，不是运行图调度员。

| 最接近的项目 | 已查证能力与适用场景 | 与本项目的已验证区别 | 不能据此宣称的东西 |
| --- | --- | --- | --- |
| [RouteAble](https://github.com/13131116363/zhangyc/blob/main/README.mbt.md)，Apache-2.0 | 静态步行图、可达性属性与加权 Dijkstra，面向园区等维护场所 | 本项目按班次停站时刻搜索，保留三目标非支配标签，区分同车与重新上车，处理发车时刻/换乘缓冲 | 不声称本项目具备其坡度、照明、宽度或道路维护能力；无障碍部分存在需求相邻性，必须披露 |
| [moonbit-ats-timetable](https://github.com/zhtzht12345678/moonbit-ats-timetable)，Apache-2.0 | 列车运行图、资源冲突、遥测、调度建议，面向 OCC 工具链 | 本项目不调度车辆，求解乘客从起点到终点的完整可行行程与 Pareto 取舍 | 本次按公开说明比较，未全面审计其所有 API；不能保证其未来或未描述功能没有重叠 |
| [MoonGeoRoute](https://github.com/phjphj676/MoonGeoRoute)、[moonnavkit](https://github.com/cn-cheems/moonnavkit) | 地理/静态路径、网格或加权规划，具体以各自文档为准 | 地理最短路与可赶上的服务日班次不同；TripFrontier 不以距离边代替班次时刻 | 未完整运行这两个工程；无上游代码使用，逐文件许可未完整核对 |
| [OpenTripPlanner](https://github.com/opentripplanner/OpenTripPlanner) | 成熟公共交通多模态规划系统，覆盖范围和规模远大于本版 | 本项目是无服务端、无在线地图依赖、可编译到 JS/Wasm 的有界 MoonBit 库 | 不是功能领先、性能领先或完整替代。上游存在多份许可，GitHub SPDX 为 NOASSERTION；未逐文件核验，不复制代码 |
| [planarnetwork/raptor](https://github.com/planarnetwork/raptor)，package.json 标注 GPL-3.0 | 基于 RAPTOR 的行程规划、日期/跨日/换乘与范围查询 | 本项目使用独立标签校正搜索，在搜索过程中保留 walking 资源前沿；不调用 Node 侧 routing 库 | 不是 RAPTOR 移植，不声称三目标思想新颖，不具有其完整 GTFS/范围查询/并行能力 |

检索词包括 gtfs、journey、public transit/transport、timetable、earliest arrival、RAPTOR、connection scan、公交、时刻表、换乘。registry 的 gtfs/journey/raptor/earliest arrival 元数据检索未命中；timetable 命中 ATS 库，route/accessibility 命中 RouteAble 等。**元数据未命中不是无竞争证明**，相邻项目已如上披露。

成熟概念参考：[Round-Based Public Transit Routing](https://www.microsoft.com/en-us/research/wp-content/uploads/2012/01/raptor_alenex.pdf)。该论文阐述的公共交通多目标问题早已存在；我们的实现不是论文中 RAPTOR 的逐行移植。GTFS 字段依 [官方规范](https://gtfs.org/documentation/schedule/reference/) 解释，具体受限适配见 GTFS_SUBSET.md。

选择理由是生态定位和可完成性：独立执行有实际输入和结果的行程计算，不是某个已有包的审计/封装附属品；当日可实现与解释完整的有界规划模型。它的独立价值需要评审认定，不能靠换语言或漂亮页面直接推出。

## 与既有自有/协作项目的关系

AgentCanary 是先前的 AI 工具策略回放工程，本次没有获得其被驳回的证据，不将它列为已驳回。TideWeave 是事件时间窗口库，用户提供了初审驳回案例；本次不把它的新增版本、状态机、回放代码或检查点改名使用。WasmSlim、MoonGate 等用户描述的驳回教训仅作为选题风险输入。

本项目独立新建目录和 Git 根历史；MoonBit imports 只有标准库 JSON 和本项目自身，未从上述项目导入模块。通用项目文件和标准库许可不构成旧业务复用；本项目的班次、行程、步行、支配标签及 GTFS 适配均在这里独立实现。保留 AI 辅助开发事实，不伪造参与者或生产客户。

## 初审与季度评选风险

1. 评委可能认为有界服务日路由范围偏小，或应向完整 RAPTOR/GTFS 发展。本版承诺的是清晰模型内完整搜索，并公开拒绝不支持的数据，而非全国规模平台。
2. 没有真实运营商 feed 的兼容性和用户采用证据；不能将合成场景写成落地案例。真实数据验证是下一步，不是已完成的亮点。
3. ATS/无障碍/地理规划存在相邻性，需将实际接口与求解对象比较材料一起提供，不能隐瞒。
4. “世界唯一”“无任何重合”“保证初审”“必得季度奖”均没有依据。本项目没有这些保证。

# 本地验证与未完成项 — 2026-10-31

结论：本地版本能运行、核心路径和有界正确性有证据；**不是“已通过初审/官方验收”**。按用户要求暂不推送，公开仓库、真实账号/命名、远程 CI 和 Mooncakes 发布仍未完成。

## 实际环境

Windows x64，Intel Core i7-14650HX；moon 0.1.20261021 / moonc v0.10.17+093cb8f9c，匹配的 core；Node v24.22.1；Python 3.13（脚本最低要求 3.12）。项目 D:\CodexProjects\TripFrontier。无第三方 npm 或 Python 运行时依赖。

## 已实际通过

完整复现命令：`python scripts/verify.py --browser`。18 条步骤全部 exit 0，逐条 stdout/stderr 与耗时在 ignored `artifacts/validation.json`。

| 命令/检查 | 结果 |
| --- | --- |
| moon version --all | 工具链版本已记录 |
| moon check --target all --deny-warn | 四目标静态检查通过 |
| moon test --target wasm --deny-warn | 24/24 |
| moon test --target wasm-gc --deny-warn | 24/24 |
| moon test --target js --deny-warn | 24/24 |
| 对应三个目标的 moon build --deny-warn | 全部通过 |
| moon fmt --check | 通过 |
| moon info；git diff --exit-code -- '*.mbti' | 已提交公开接口没有意外漂移 |
| moon run cmd/demo | 输出 arrival=30/40、boardings=2/1；延误后 arrival=40，带实际断言 |
| node scripts/build.mjs | CLI/浏览器使用相同 MoonBit release JS 核心 |
| node --test tests/cli.test.mjs | 7/7 |
| python -m unittest discover -s tests -p test_gtfs.py | 7/7 |
| python tests/oracle.py | 固定种子 20261031，240 个小网络，2051 个穷举状态，221 条结果；全部目标值前沿一致 |
| python scripts/package_check.py | 实际 Moon 归档已检查，未含工作目录、凭据、生成引擎/构建缓存、私人交付材料 |
| python tests/browser.py（临时本地服务） | 延误60/61秒边界、无障碍、24:10、报告下载、原始重复键、标记文本安全、390px 布局通过 |

oracle 不使用主实现的支配标签剪枝：枚举资源/时间内所有可行步行和上车路线，最后对目标值集合做全对全支配筛选。它提供小模型差分证据，不证明所有大输入或所有现实交通语义。`verify_journey` 对原班次逐段核查可行性，不能单独证明最优性。

原生 JSON 路径在给定模型内声称完整；GTFS 适配采用文档化子集，不能把子集外的拒绝或保守映射当作完整 GTFS 语义。真实运营商 feed 尚未验证。

## 已尝试但环境不具备

实际命令：`moon build --target native --deny-warn`。返回 1，错误为 Windows 后端需要 MSVC cl.exe/clang-cl.exe 驱动、C++ Build Tools 和 Windows SDK。本机没有这些工具；未宣称 native 执行通过。已配置的 Windows CI 会初始化 MSVC，但本轮没有推送，因此远程 native 结果未知。

## 初审材料与最终验收差距

1. 独立性材料和真实可运行功能已具备；新项目题目是否足以通过初审仍由组委会判定。不能用本地测试推导初审通过。
2. 本地 Git 历史含真实的功能、测试、适配、展示与文档里程碑，没有空提交。数量不代替官方“有效 commits”判定。
3. 模块临时为 local/tripfrontier，未设置 repository；`moon package` 会提示缺 repository。这是先不推送/账号待定的真实状态，发布前必须改成实际值并核对贡献者身份。
4. 没有 origin、GitHub 公开 URL、远程默认分支或远程 CI 成绩；没有 Mooncakes 发布/独立 registry 下载结果。
5. 本人正式申报书、实际联系方式/往届信息、诚信承诺、提交回执、入群均需参赛者完成。事实材料和空白提纲不能冒充本人申报正文。
6. 日期、次数、换账号口径和仍含九月日期的章程差异见 RULES_2026-10-31.md；本轮按用户已确认的今晚24点安排，不替主办方认定资格。

## 基准

`node scripts/benchmark.mjs`：40站、192班次、1128停站、39链接、8次上车/900s接驳预算的一次合成查询；2次预热后7样本。中位 4.0916ms，范围 3.0175..7.3084ms；176 个标签，32092 次候选操作。包含 JSON 输入/输出与 JS 结果解析。仅单机器/单样本网络，不提供大规模、真实 feed、峰值内存或优于 RAPTOR 的保证。

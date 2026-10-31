# TripFrontier 0.1.0 发布核对

维护者与参赛者：李明坤 / **LMK-ai-nb**。原始开发与身份绑定说明见 AUTHORSHIP.md。

## 公开入口

- [GitHub](https://github.com/LMK-ai-nb/TripFrontier)，实际默认分支 `main`。
- [在线工作台](https://lmk-ai-nb.github.io/TripFrontier/)。
- [Mooncakes 版本入口](https://mooncakes.io/docs/LMK-ai-nb/tripfrontier@0.1.0)。
- [CI](https://github.com/LMK-ai-nb/TripFrontier/actions/workflows/ci.yml)。

## 已验证的远程工程结果

[CI 运行 41175996318](https://github.com/LMK-ai-nb/TripFrontier/actions/runs/41175996318) 对应 `15e64d0e26fc2abfb89b260142e31029401d159a`：Windows、macOS、Linux 均成功，执行 check/test/build 四目标（wasm、wasm-gc、js、native）、格式、公开接口、typed demo、CLI、GTFS 导入、独立 oracle 和 Linux 浏览器检查。

24 项 MoonBit 测试、7 项 Node 集成、7 项 Python GTFS、240 组独立穷举前沿对照；具体含义和范围见 VALIDATION.md。不能将有限合成对照外推为真实运营商完整兼容或无限规模保证。

[Pages 部署 41175996292](https://github.com/LMK-ai-nb/TripFrontier/actions/runs/41175996292) 的 build/deploy 均成功。

## 发布包消费方式

```text
moon add LMK-ai-nb/tripfrontier@0.1.0
```

调用包导入 `LMK-ai-nb/tripfrontier`，使用 `query`、`plan`、`scenario`、`verify_journey`。可执行示例见 API.mbt.md。

2026-10-31 实际执行：`moon whoami` 返回 LMK-ai-nb；`moon publish` 返回服务器 **200 OK**；版本页面公开 HTTP 200。发布前对真实归档扫描通过，未含私人联系方式、其他参赛者身份或未绑定 namespace。

随后在新建消费项目和全新 Moon home/registry 下执行 `moon update`、`moon check --target all --deny-warn`，默认 Wasm-GC 和 JS 两个后端分别运行。实际下载日志包含 `Downloading LMK-ai-nb/tripfrontier@0.1.0`，实际程序输出：

```text
Fresh Mooncakes consumer OK: frontier=30/40, delayed=40, witness verification passed, source unchanged.
```

消费程序断言两条前沿、延误造成失接后只剩直达、逐段见证有效以及源时刻表未被修改；不是用本地路径依赖替代下载。发布包中的五个核心文件与工作源码逐字节核对。

本地源码验证环境为 moonc 0.10.17+093cb8f9c。源码分发不包含凭据、工作工具链或私人报名材料；JavaScript 编译分发保留标准库许可与 NOTICE。

官方报名并未代提交，诚信承诺未代确认，不存在由技术测试自动产生的初审/验收成功结论。

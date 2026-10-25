# HoopTrace v2 当前候选完整 CI 验收计划

2026-10-06 用户明确批准执行。此文件存档本次范围，不构成后续推送、合并或发布的常驻授权；实际结果以交接和发布前验收记录为准。

## 目标与边界

取得包含计时修复的候选提交全部五项远端 CI 通过记录。

- 工作区 `C:/Users/48029/.codex/worktrees/hooptrace-v2/hooptrace`，分支 `codex/hooptrace-v2`。
- 待验提交 `2ef56aaad86f55f9d9a95379bf23a0f8ac516e78`，应用源码 `480984fd61dc59dd907e435eb12e7b0eb30e11e4`。
- 复用已通过的分析与 1173 项本地测试；输入不变不重跑。
- 本轮仅候选推送、CI 和适用失败修复；不合并 main、不建 PR／tag／Release，不正式签名或恢复长期监控。保留 main 用户修改。
- 应用 API、schema 3、JSON 格式 2、版本 `2.0.0+4` 保持不变。

## 执行步骤

- [x] 核对工作区干净、应用输入未变、远端可快进；不同远端新提交先处理差异，不强推。
- [x] 正常推送 `git push origin HEAD:refs/heads/codex/hooptrace-v2`，回读远端 SHA 一致。
- [x] 同 SHA 已在运行则复用；本轮没有活动运行，手动触发 `gh workflow run flutter-ci.yml --repo x1a0Y4NGren/hooptrace --ref codex/hooptrace-v2`。
- [x] 核验 run ID、实际 SHA、分支和事件；本轮为 run `37429173938`、`workflow_dispatch`、上述 `2ef56aa`。
- [x] 有界等待质量、API24、API36、Android 可复现、iOS 无签名五项作业完成。

| 作业 | 必须通过 |
| --- | --- |
| 质量 | 格式／分析／全量与 Golden／工具／schema／依赖／性能／原生测试及 Debug 构建 |
| API24 | 主流程、文件恢复 |
| API36 | 主流程、文件恢复、球员比较及命令性能 |
| Android 可复现 | 两份 fresh 源码未签名 APK 完整字节一致 |
| iOS | macOS Release 无签名编译 |

## 失败处理

- 先保存失败日志和诊断，再区分源码、工作流及基础设施问题；不放宽门槛。
- 明确的偶发基础设施失败可同 SHA 重跑失败作业一次，保留原失败；再次失败转诊断。
- 真实缺陷最小修复并补适用回归；应用改动重建 Debug、复验受影响流程，共享数据变更运行全量 Flutter。
- 源码／工作流修复后提交推送，以新 SHA 重获完整五项结果。
- 失败、取消、跳过及平台不可用不算通过；CI 不替代正式包验收或渲染 ANR 根因复核。

## 证据与交付

- [x] 仓库外按 run／attempt 保存状态、五项日志、失败诊断、产物 metadata 和 CI 报告的 APK SHA-256。
- [x] 默认不下载重复 APK，不建立本地模拟器；未下载的二进制只记录远端来源。
- [x] 更新 HANDOFF 和发布前验收，分清 CI 提交、应用源码和后续文档提交。
- [x] 文档内容／链接及 `git diff --check`，独立提交；不重复 Flutter。

完成条件：同一最终待验 SHA 五项全部成功，Debug／未签名可复现产物存在，日志可追溯，记录同步。正式签名、同证升级和正式包 API24／36 仍为下一阶段门槛。

实际执行：`37429173938 / attempt 1` 首次五项通过，无应用／工作流改动或失败重跑；结果及来源见[本次 CI 验收](../../release/v2.0.0-final-ci-verification.md)。

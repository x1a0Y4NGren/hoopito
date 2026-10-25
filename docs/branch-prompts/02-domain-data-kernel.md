# 核心模型与数据库支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：核心模型与数据库支线
- Branch：`codex/domain-data-kernel`
- Worktree：`.worktrees/domain-data-kernel`
- Plan tasks：Task 3-6
- 依赖：项目地基支线已合回 `main`
- 作用：建立比赛、球员、规则、事件、落点、审计等核心模型，以及 Drift SQLite 本地数据库。

## Prompt

```text
请基于已完成并合回 main 的 Flutter scaffold，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 3-6。

当前分支应为 codex/domain-data-kernel，当前工作目录应为 .worktrees/domain-data-kernel。

目标：
1. 实现比赛领域模型、值对象、计分 reducer、规则提示和审计模型。
2. 实现 Drift SQLite 数据库、迁移入口和基础 repository。
3. 保证比分和统计可以从事件流派生。

限制：
- 不要实现 UI 主流程。
- 不要实现计分页、复盘页、设置页。
- 数据模型命名必须和计划文档保持一致；若必须调整，先在最终说明里解释原因。

质量要求：
- 按 Task 3-6 的测试先行步骤执行。
- 运行 build_runner 生成 Drift 文件。
- 完成后运行 dart format、flutter test、flutter analyze。

输出：
- 汇总核心模型和数据库表。
- 汇总验证命令和结果。
- 说明 schema 或 repository 设计是否有偏离计划。
```

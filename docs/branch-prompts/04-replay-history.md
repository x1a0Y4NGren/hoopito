# 复盘历史支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：复盘历史支线
- Branch：`codex/replay-history`
- Worktree：`.worktrees/replay-history`
- Plan tasks：Task 10
- 依赖：现场计分主线支线已合回 `main`
- 作用：实现只读复盘页和本机历史比赛列表，能从历史记录进入某场复盘。

## Prompt

```text
请基于已完成并合回 main 的 scoring main loop，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 10。

当前分支应为 codex/replay-history，当前工作目录应为 .worktrees/replay-history。

目标：
1. 实现只读复盘页。
2. 实现事件时间线入口和筛选入口。
3. 实现复盘历史列表。
4. 支持从历史列表打开对应比赛复盘。

限制：
- 不要实现编辑模式和高级统计。
- 不要实现导出备份。
- 复盘页默认只读，避免提前引入审计修改逻辑。

质量要求：
- 按 Task 10 的测试先行步骤执行。
- 完成后运行相关 tests、dart format、flutter analyze。

输出：
- 汇总复盘页和历史页的用户路径。
- 汇总验证命令和结果。
- 说明后续编辑、统计、导出需要接入的点。
```

# 复盘统计支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：复盘统计支线
- Branch：`codex/analytics`
- Worktree：`.worktrees/analytics`
- Plan tasks：Task 14
- 依赖：复盘历史支线已合回 `main`；若规则审计已合回，应基于最新 `main`
- 作用：实现比分流、领先变化、最大分差、命中率、关键回合、长期统计等分析能力。

## Prompt

```text
请基于当前 main，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 14。

当前分支应为 codex/analytics，当前工作目录应为 .worktrees/analytics。

目标：
1. 实现本场 analytics 纯 domain 计算。
2. 覆盖比分流、领先变化、最大分差、命中率、关键回合。
3. 接入复盘页展示基础分析摘要。

限制：
- 优先写纯 domain 测试，再接 UI。
- 不要实现导出备份。
- 不要改变事件语义；统计必须从 MatchEvent 和 ShotLocation 派生。

质量要求：
- 按 Task 14 的测试先行步骤执行。
- 完成后运行相关 tests、dart format、flutter analyze。

输出：
- 汇总每项统计口径。
- 汇总验证命令和结果。
- 说明哪些长期统计仍待后续 UI 深化。
```

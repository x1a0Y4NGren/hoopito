# 现场计分主线支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：现场计分主线支线
- Branch：`codex/scoring-main-loop`
- Worktree：`.worktrees/scoring-main-loop`
- Plan tasks：Task 7-9
- 依赖：核心模型与数据库支线已合回 `main`
- 作用：实现赛前设置、横屏球场优先计分页、半场绘制、红蓝计分按钮、待确认落点条、确认/跳过/撤销流程。

## Prompt

```text
请基于已完成并合回 main 的 domain/database 主线，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 7-9。

当前分支应为 codex/scoring-main-loop，当前工作目录应为 .worktrees/scoring-main-loop。

目标：
1. 实现赛前设置页。
2. 实现球场优先型横屏计分页。
3. 实现半场 CustomPainter、红蓝计分按钮、待确认落点条。
4. 实现得分后临时落点、拖拽、确认、跳过和撤销流程。

限制：
- 先保证核心现场计分闭环可用。
- 不要实现复盘高级统计、导出备份、编辑审计 UI。
- 计分页要保持球场优先，不要塞入过多数据面板。

质量要求：
- 按 Task 7-9 的测试先行步骤执行。
- 完成后运行相关 unit/widget tests、dart format、flutter analyze。

输出：
- 汇总用户从赛前设置到计分落点的可用流程。
- 汇总验证命令和结果。
- 说明当前未覆盖的复盘或保存能力边界。
```

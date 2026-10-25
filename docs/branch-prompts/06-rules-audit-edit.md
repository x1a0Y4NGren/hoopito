# 规则与审计编辑支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：规则与审计编辑支线
- Branch：`codex/rules-audit-edit`
- Worktree：`.worktrees/rules-audit-edit`
- Plan tasks：Task 11-12
- 依赖：复盘历史支线已合回 `main`
- 作用：实现规则模板管理、非阻断球权提示、复盘编辑模式、事件软删除、落点移动和审计历史。

## Prompt

```text
请基于当前 main，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 11-12。

当前分支应为 codex/rules-audit-edit，当前工作目录应为 .worktrees/rules-audit-edit。

目标：
1. 实现规则模板管理。
2. 实现非阻断球权提示。
3. 实现复盘编辑模式。
4. 实现事件软删除、落点移动、备注修改。
5. 确保所有修改都有 audit log。

限制：
- 不要实现长期统计。
- 不要实现导出备份。
- 不要让规则系统阻断手动计分。

质量要求：
- 按 Task 11-12 的测试先行步骤执行。
- 涉及 Drift schema 时运行 build_runner。
- 完成后运行相关 tests、dart format、flutter analyze。

输出：
- 汇总规则模板能力和审计写入策略。
- 汇总验证命令和结果。
- 说明 schema migration 版本变化。
```

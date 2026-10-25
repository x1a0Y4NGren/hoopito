# 导出备份支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：导出备份支线
- Branch：`codex/export-backup`
- Worktree：`.worktrees/export-backup`
- Plan tasks：Task 15-16
- 依赖：数据库、设置页、复盘历史已合回 `main`
- 作用：实现 JSON 备份导入导出、CSV 导出、复盘图片导出、自动本地备份。

## Prompt

```text
请基于当前 main，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 15-16。

当前分支应为 codex/export-backup，当前工作目录应为 .worktrees/export-backup。

目标：
1. 实现 JSON 完整备份导出和导入。
2. 实现 CSV 导出。
3. 实现复盘图片导出。
4. 实现自动本地备份服务和设置页入口。

限制：
- 不做云同步。
- 不做 PDF。
- 自动备份必须默认关闭，且需要用户显式授权目录。
- 导入必须校验 schema version，不能静默接受未来版本。

质量要求：
- 按 Task 15-16 的测试先行步骤执行。
- 重点测试 JSON round-trip、schema version 和 CSV 字段。
- 完成后运行相关 tests、dart format、flutter analyze。

输出：
- 汇总导出格式和恢复策略。
- 汇总验证命令和结果。
- 说明 Android 文件权限或目录选择的处理方式。
```

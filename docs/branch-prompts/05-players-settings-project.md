# 球员设置与项目页支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：球员设置与项目页支线
- Branch：`codex/players-settings-project`
- Worktree：`.worktrees/players-settings-project`
- Plan tasks：Task 13
- 依赖：复盘历史支线已合回 `main`
- 作用：实现本地球员档案、完整设置页、项目详情页，展示永久免费、永久开源、本地离线等说明。

## Prompt

```text
请基于当前 main，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 13。

当前分支应为 codex/players-settings-project，当前工作目录应为 .worktrees/players-settings-project。

目标：
1. 实现本地球员档案列表和编辑页。
2. 实现设置页框架。
3. 实现项目详情页。
4. 明确展示“永久免费、永久开源、本地离线、不会上传个人数据”。

限制：
- 不要实现 JSON/CSV/图片导出和自动备份。
- 不要修改核心数据库 schema，除非 Task 13 必须要求。
- 项目详情页只做信息展示和外部链接，不内置网络反馈表单。

质量要求：
- 按 Task 13 的测试先行步骤执行。
- 完成后运行相关 tests、dart format、flutter analyze。

输出：
- 汇总球员、设置、项目页入口。
- 汇总验证命令和结果。
- 说明后续导出备份应接入设置页的哪个区域。
```

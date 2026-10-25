# 项目地基支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：项目地基支线
- Branch：`codex/flutter-scaffold`
- Worktree：`.worktrees/flutter-scaffold`
- Plan tasks：Task 1-2
- 依赖：当前 `main` 上的规划文档
- 作用：创建 Flutter 项目、依赖、主题、路由、本地化结构和首页入口。后续所有支线都依赖它。

## Prompt

```text
请按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 1-2。

当前分支应为 codex/flutter-scaffold，当前工作目录应为 .worktrees/flutter-scaffold。

目标：
1. 创建 Flutter 项目脚手架。
2. 配置 pubspec、analysis_options、基础 smoke test。
3. 建立 app shell、主题、路由、本地化资源结构和首页入口。

限制：
- 只实现 Task 1-2。
- 不要提前实现比赛领域模型、数据库或计分页业务功能。
- 不要修改 docs/superpowers/specs 或 docs/superpowers/plans，除非发现计划本身阻塞实现并明确说明原因。

质量要求：
- 按计划中的测试先行和验证步骤执行。
- 完成后运行对应的 flutter pub get、dart format、flutter analyze、flutter test。
- 完成后提交，提交信息使用计划中的建议或等价清晰信息。

输出：
- 汇总改动文件。
- 汇总验证命令和结果。
- 说明是否有偏离计划的地方。
```

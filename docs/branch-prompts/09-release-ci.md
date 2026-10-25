# 发布与质量支线

> 历史首发任务，非当前待办；使用边界见 [README](README.md)。

- 中文名：发布与质量支线
- Branch：`codex/release-ci`
- Worktree：`.worktrees/release-ci`
- Plan tasks：Task 17-18
- 依赖：所有功能支线已合回 `main`
- 作用：补齐集成测试、README、隐私说明、贡献指南、发布清单、F-Droid 准备和 GitHub Actions CI。

## Prompt

```text
请基于功能完整的 main，按 docs/superpowers/plans/2026-05-12-hooptrace-first-release.md 执行 Task 17-18。

当前分支应为 codex/release-ci，当前工作目录应为 .worktrees/release-ci。

目标：
1. 补齐主流程 integration test。
2. 补齐 README、CONTRIBUTING、PRIVACY。
3. 补齐 release checklist 和 F-Droid notes。
4. 添加 GitHub Actions Flutter CI。

限制：
- 不要新增产品功能。
- 不要改动核心业务逻辑，除非 integration test 暴露真实阻塞问题。
- 发布文档必须明确永久免费、永久开源、本地离线、不上传个人数据。

质量要求：
- 运行 dart format --set-exit-if-changed .。
- 运行 flutter analyze。
- 运行 flutter test。
- 运行 integration test。
- 运行 flutter build apk --debug。

输出：
- 汇总发布资料和 CI 配置。
- 汇总所有验证命令和结果。
- 说明是否已具备 GitHub Release 前置条件。
```

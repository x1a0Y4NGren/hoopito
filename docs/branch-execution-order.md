# HoopTrace 历史分支对话执行顺序

> 本文保留首发阶段的执行记录，不是后续任务的默认流程。不要据此重建全部 worktree 或等待旧波次；当前工作以 [AGENTS.md](../AGENTS.md)、[CONTRIBUTING.md](../CONTRIBUTING.md) 和本次需求为准。

## 基本工作流

1. `main` 只保存已经确认的规划和已合并成果。
2. 每个功能支线使用一个独立 git worktree。
3. 每个 Codex 新对话只进入一个 worktree，只处理一个 prompt。
4. 分支完成后先验证、提交，再合回 `main`。
5. 下一个依赖分支必须基于已经更新的 `main` 创建或同步。

## 一键准备脚本

先预览：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-worktrees.ps1 -DryRun
```

按波次创建 worktree：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-worktrees.ps1 -Create -Wave 1
```

可用波次：

- `1`：项目地基支线
- `2`：核心模型与数据库支线
- `3`：现场计分主线支线
- `4`：复盘历史支线
- `5A`：球员设置与项目页支线
- `5B`：规则与审计编辑支线、复盘统计支线
- `5C`：导出备份支线
- `6`：发布与质量支线
- `all`：创建全部 worktree。只建议用于准备目录，不建议同时开工。

## 推荐执行顺序

| 波次 | 中文名 | Branch | Prompt |
|---|---|---|---|
| 1 | 项目地基支线 | `codex/flutter-scaffold` | `docs/branch-prompts/01-flutter-scaffold.md` |
| 2 | 核心模型与数据库支线 | `codex/domain-data-kernel` | `docs/branch-prompts/02-domain-data-kernel.md` |
| 3 | 现场计分主线支线 | `codex/scoring-main-loop` | `docs/branch-prompts/03-scoring-main-loop.md` |
| 4 | 复盘历史支线 | `codex/replay-history` | `docs/branch-prompts/04-replay-history.md` |
| 5A | 球员设置与项目页支线 | `codex/players-settings-project` | `docs/branch-prompts/05-players-settings-project.md` |
| 5B | 规则与审计编辑支线 | `codex/rules-audit-edit` | `docs/branch-prompts/06-rules-audit-edit.md` |
| 5B | 复盘统计支线 | `codex/analytics` | `docs/branch-prompts/07-analytics.md` |
| 5C | 导出备份支线 | `codex/export-backup` | `docs/branch-prompts/08-export-backup.md` |
| 6 | 发布与质量支线 | `codex/release-ci` | `docs/branch-prompts/09-release-ci.md` |

## 哪些可以并行

前四个不要并行：

- 项目地基支线
- 核心模型与数据库支线
- 现场计分主线支线
- 复盘历史支线

这些是强依赖链。后一个分支需要前一个分支的真实代码和测试结果。

可以谨慎并行：

- 球员设置与项目页支线可以和部分统计探索并行，但合并时要注意路由和设置页冲突。
- 规则与审计编辑支线、复盘统计支线都可能修改复盘相关文件，不建议无人看管地同时合并。
- 导出备份支线要等数据库和设置页稳定。
- 发布与质量支线必须最后做。

## 新建分支对话时怎么操作

以项目地基支线为例：

1. 在主仓库运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-worktrees.ps1 -Create -Wave 1
```

2. 在 Codex 中新建对话。
3. 把工作目录设置为：

```text
D:\GitHub\hooptrace\.worktrees\flutter-scaffold
```

4. 打开 `docs/branch-prompts/01-flutter-scaffold.md`。
5. 复制 Prompt 区块给新对话。
6. 等该对话完成验证和提交。
7. 回到主仓库，把分支合并回 `main`。
8. 再创建下一波 worktree。

## 合并建议

每条支线完成后，在主仓库中检查：

```powershell
git status --short --branch
git log --oneline --decorate --graph --all -10
```

确认分支提交后，再合并：

```powershell
git checkout main
git merge --no-ff codex/flutter-scaffold
```

如果有冲突，不要盲目解决。先读冲突文件，确认哪个分支拥有该模块的事实来源。

## 常见错误

- 在主仓库和 worktree 中同时让两个对话改同一个文件。
- 还没合并项目地基，就启动数据库或计分页分支。
- 下游 worktree 创建太早，后来没有同步最新 `main`。
- 把 `.worktrees/` 或 `.superpowers/` 提交进仓库。
- 合并前没有跑该分支要求的验证命令。

## 清理 worktree

分支合并完成且不再需要本地目录后，可以删除 worktree：

```powershell
git worktree remove .worktrees\flutter-scaffold
```

如果 Git 提示目录不干净，先进入该 worktree 检查 `git status`，不要直接强删。

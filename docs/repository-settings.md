# GitHub 仓库设置策略

本策略适用于个人公开仓库 `x1a0Y4NGren/hoopito`，记录目标配置、维护约定与验收方法。仓库内文件不能证明远端开关已经生效；启用状态以 GitHub 设置/API 回读、对应规则和实际检查结果为准。仓库设置调整不授权 App 发行、网站部署、项目收尾或账号级权限变更。

## 分支、合并与责任人

| 对象 | 策略 |
| --- | --- |
| `main` | 默认维护分支；禁止 force push 和删除；所有修改经 PR；0 个必需批准；要求解决 review conversation；合并前与最新基线对齐并通过必需检查。 |
| `preview/website` | 长期预览分支的迁移目标；禁止 force push 和删除。迁移验收完成前保留旧预览分支，不提前宣称新入口可用。 |
| `codex/hoopito-website` | 迁移期间保留并保护的旧预览分支，仍使用已记录的入口；新分支的 CI、部署身份、认证和真实地址验证完成后才退役。 |
| 普通开发分支 | 按工作类型和目的命名，使用短生命周期 PR；合并后自动删除远端 head branch。删除保护只匹配实际保留的分支。 |
| `v*` tag | 允许创建；禁止更新和删除，无常规 bypass。发布前仍须创建并验证签名 annotated tag，tag 规则不等于签名校验。 |

默认只允许 squash merge，并对 `main` 要求 linear history；保留 Update branch 按钮。关闭 auto-merge，不配置 Dependabot 自动批准或自动合并。squash 适用于一个 PR 一个完整改动；合并后从最新 `main` 新建分支，避免复用旧 head 导致重复历史。既有 merge commit 和签名 tag 保持原样，不为新规则重写历史。

单人维护不能批准自己的 PR，因此 required approval count 为 0；不启用 required CODEOWNER review 或 require last push approval。[CODEOWNERS](../.github/CODEOWNERS) 只标识关键路径责任人并路由审阅，维护者仍须人工核对改动、风险和 CI。[GitHub 的批准限制](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews)

2026-10-25 已按审计结果删除四个已整合的历史远端分支：`dependabot/github_actions/actions/checkout-7.0.1`、`codex/screenshot-presentation`、`codex/hooptrace-website` 和 `codex/hooptrace-1-1-comparison`；`codex/hoopito-website` 保留并保护。该清单记录本轮范围，不是未来任意清理的常驻授权。squash 合并后的 branch-only commit 不足以证明存在未整合代码；删除前核对 PR、实际树差异和预览引用。自动删除 head branch 的开关不负责回收本地分支、工作树或历史证据。[GitHub 自动删除说明](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches)

## 分支命名与 PR 标题

日常维护流程和命名格式统一以[贡献指南](../CONTRIBUTING.md#日常维护流程)为入口；人工贡献者及自动化工具遵循相同规则。普通分支使用 `类型/改动目的`，PR 标题和最终 squash 提交使用 `类型(可选范围)!: 改动说明`，其中 `!` 只在破坏性变更时使用，范围可省略。中间提交格式仅为建议，不为命名规范重写历史。

`Repository policy required` 对 PR 检查名称与标题，标题编辑时重新运行；只读取事件元数据，不将标题或分支名拼接到 shell。PR 事件缺少必要元数据时失败，push 和手动运行跳过 PR 元数据检查。该门禁校验名称形状，改动目的是否准确仍须人工审阅。

新的 Dependabot 分支使用 `deps/<自动生成内容>`，PR/提交前缀使用 `chore` 并包含依赖 scope；机器人生成的依赖路径允许多层结构。命名例外必须同时匹配真实的本仓库 Dependabot 作者和来源仓库；人工依赖修复使用普通 `build/` 或 `chore/` 分支。既有 #17、#18、#19、#21、#22、#23、#24、#25、#27 依赖 PR 仅按各自 PR 编号与固定原 head 名称过渡，不批量改名，也不给未来任意 `dependabot/*` 分支豁免。

预览迁移按以下顺序执行：保存旧 SHA → 保护新旧分支 → 从旧预览源码建立新分支并更新其自身 CI → 核对同源码的完整网站 CI 与受保护 Vercel Preview → 回读真实地址并更新当前入口 → 确认旧 SHA 未变后收敛保护和删除旧引用。main 的工作流和预览分支内的工作流分别更新，不整体合入 main 以替代迁移。Vercel 权限不足或验收未完成时，继续使用[已记录的旧预览入口](https://hoopito-website-git-codex-hoopito-website-xyr175-9459s-projects.vercel.app)，明确标记迁移未完成；不影响生产官网。历史发行、验证记录和不可变部署地址保留原样。

## 合并门禁与分阶段启用

`main` 必需检查使用下列固定 job context，并绑定 GitHub Actions 来源：

| Context | 契约 |
| --- | --- |
| `App CI required` | 每个 PR 都报告结果；按路径选择 Flutter、Android、iOS 等现有检查；适用工作失败或取消时不得通过。 |
| `Website CI required` | 每个 PR 都报告结果；按路径选择网站格式、类型、单元、构建、预算、三浏览器和软件 WebGL 检查。 |
| `Repository policy required` | 检查 PR 分支名称和标题、顶层远程 Action 的 SHA 固定与允许来源，以及约定的 CI matrix；不提供通用 YAML/schema 校验。 |

不要把会被 workflow 级 `paths` 过滤而不产生结果的 job 直接设为必需检查。聚合门禁必须区分“不适用”和“失败/取消/缺少适用结果”，不以 `always()` 后无条件成功掩盖下游失败；job 名称保持跨 workflow 唯一。`main` 要求 strict up-to-date，别的 PR 合入后需更新分支并重新取得当前基线结果。仅手动 `workflow_dispatch` 成功不能代替 PR 事件的必需检查。[必需检查行为](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)

按以下顺序落地，避免先锁住仓库再补检查：

1. 保存现有设置、规则、分支/PR 和证据来源，检查 classic protection 与 ruleset 是否叠加；保留可回退配置。
2. 先合入并运行新的门禁与策略检查，验证文档 PR 的不适用路径、App/网站改动的适用路径、失败和取消不会误绿，以及 Dependabot PR 不需要写 token 或密钥。
3. 取得当前成功的 check context 与 GitHub Actions integration 身份，再启用 `main` PR、三项必需检查和 strict up-to-date；随后回读规则并用正常 PR 验证。个人公开仓库使用 Active/Disabled，不依赖 Enterprise 的 Evaluate 模式。
4. 运行 CodeQL default setup，仅选择 Actions、JavaScript/TypeScript 和 Python，自动基线采用标准 remote threat model。确认各语言扫描实际成功后，才要求 code scanning 结果，使用 high 及以上安全告警、error 级其他告警阈值；扫描执行成功不表示没有告警。CodeQL 不覆盖本项目 Dart。
5. 回读并核验分支、tag、Actions、安全与 release 设置；历史分支按本轮批准范围单独处理。记录实际失败或未启用项，不把目标策略写成已验收状态。

不配置日常 bypass。门禁异常时先查看 PR 的规则、实际 job 和日志，修复工作流或补足真实验证；若错误配置确实阻断恢复，由 owner 显式编辑或暂时关闭命中的规则，保留原因、范围与前后配置，恢复后回读并验证。不要通过伪造成功状态、放宽失败断言或默认 bypass 绕过检查。[Ruleset 与恢复入口](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/managing-rulesets-for-a-repository)

2026-10-25，[配置 PR #20](https://github.com/x1a0Y4NGren/hoopito/pull/20) 在完整 App、网站及 CodeQL 检查通过后合入，随后启用 `main` 规则。后续只修改本文件等维护文档的 PR，应看到两个分类任务成功、无关 App/网站构建与测试跳过、三项必需门禁成功；不应因路径跳过而无限等待必需检查。

CodeQL 的 ruleset merge protection 与三项 status check 门禁不同；GitHub 明确豁免由 default setup 分析的 Dependabot PR。这不是仓库设置的日常 bypass，也不免除依赖 PR 的三项 CI 门禁和人工审阅。[Code scanning 合并保护的例外](https://docs.github.com/en/code-security/concepts/code-scanning/merge-protection#exceptions-and-limitations)

## Actions 与证据

允许 GitHub 自有 Actions，并仅额外允许 `subosito/flutter-action` 和 `ReactiveCircus/android-emulator-runner`。仓库内顶层远程 `uses:` 必须固定完整 commit SHA，版本注释用于可读性；更新时核对 SHA、上游 release 和执行入口。仓库级全局 SHA enforcement 保持关闭：Flutter action 的嵌套 cache 引用仍使用 tag，直接强制全局规则会阻断现有链；顶层 SHA 由 `Repository policy required` 检查。增加 Action 或更改此例外需独立审阅。

默认 `GITHUB_TOKEN` 使用 read 权限，关闭 Actions 创建/批准 PR 的能力；仅实际需要的 job 可显式申请最小权限。fork 的所有外部贡献者运行 workflow 前都需要批准；批准前检查 workflow 及其调用脚本，不向不可信 PR 代码提供 secrets，不使用特权事件运行其代码。CodeQL 等确需权限的 GitHub 功能按其已验证配置单独处理。

仓库 Actions 默认日志/产物保留 90 天；workflow 的构建和浏览器附件保留 14 天，golden 失败诊断保留 7 天，未签名复现构建诊断保留 14 天。缩短 artifact 期限不等于删除本地或历史发布证据。保持已有源码 SHA、逐文件摘要、同一 run 的 build 传递和使用前校验；失败证据与 flaky 样本照实保存。CI 产物不作为正式签名发行包，也不覆盖已发布 APK。[贡献与验证矩阵](../CONTRIBUTING.md#测试要求)

## 依赖与安全

配置来源为 [dependabot.yml](../.github/dependabot.yml)。全部依赖 PR 都需人工合并；排期、PR 上限和冷静期用于普通版本更新，不延迟安全修复 PR。

| 生态 / 目录 | 普通版本更新 |
| --- | --- |
| Actions `/` | 每周，最多 3 个开放 PR；默认冷静期 7 天；minor/patch 分组，major 单独审阅。 |
| npm `/website` | 每周，最多 3 个开放 PR；默认 7 天、major 30 天冷静期；runtime 与 tooling 的 minor/patch 分组。 |
| pub `/` | 每月，最多 2 个开放 PR；包含运行时和开发依赖；`drift` 与 `drift_dev` 对 version/security 分别成组，不排除 major。 |
| Gradle `/android` | 每月，最多 1 个开放 PR；核对 AGP、Kotlin、Gradle wrapper、Java 与 Flutter 的兼容性，不能因单项更新通过就宣称整套工具链已验证。 |

查看依赖迁移说明、许可、锁文件与代码生成变化；Drift 变更执行生成和数据库验证，网站/原生工具链按影响运行相应 CI。分组只减少 PR 数，不免除测试或允许自动跟进 major。security updates 不受 cooldown 延迟，且有独立的开放 PR 限额；安全修复仍经过同一人工审阅与 CI。[Dependabot 配置参考](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)

启用 dependency graph、Dependabot alerts 和 security updates；保留 secret scanning 与 push protection。启用 private vulnerability reporting，并确认维护者订阅 Security alerts 通知；[SECURITY.md](../SECURITY.md) 与 GitHub 私密报告入口应一致。默认不要求报告者先填写 CWE，以免妨碍有效报告。[私密漏洞报告](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)

2026-10-25 启用安全功能后发现 8 条既有 npm Dependabot 告警（2 high、4 medium、2 low）。这是实际待处理清单，不代表本轮配置引入了 8 个漏洞，也不能称仓库已无漏洞。本轮设置任务不包含依赖修复或合并；后续逐项核对影响、修复版本并经 PR/CI 处理。

Actions、JavaScript/TypeScript 和 Python 的首次 CodeQL 扫描均已执行成功；首次 `remote_and_local` 配置记录 47 条告警，多数涉及本地 CLI 的命令或路径输入。逐项结合真实调用者和输入边界审阅后，将配置恢复为标准 remote threat model；保留首次配置与扫描记录，不批量 dismiss，也不把配置切换后的告警数量变化当作修复证据。最终配置已回读核验，三个语言扫描成功；仍有两条既有告警，位于网站预算检查脚本和测试审计脚本，需结合实际输入边界另行处置，不能宣称安全告警已清零。[Threat model 配置](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/manage-your-configuration/edit-default-setup)

自动基线聚焦远端不可信输入；CLI 工具的本地参数、环境变量、文件路径等输入威胁仍须人工审阅，不能因未纳入该基线就视为安全。本轮不新增原生 Java/Kotlin CodeQL 构建扫描，也不提交 Gradle 传递依赖图；先评估 Flutter 工具链、生成源码和快照来源后再单独实施。Dependabot 的 Gradle manifest 更新不等于完整 Android 运行时传递依赖覆盖。Dart 未获 CodeQL 扫描，仍依赖现有 analyze、测试与依赖核验。

## 发行与保持不变的边界

未来 Release 启用 immutability，严格遵循“已验证签名 tag → draft → 上传全部资产与校验和 → 从草稿回读验证 → publish”。发布后不能补传或替换附件；修复发布递增版本。immutability 不追溯锁定旧 Release，不更改旧 tag、APK 名称、签名或校验和；签名 tag、APK 签名和产物来源仍按[发行清单](release/release-checklist.md#7-github-release) 分别验证。[不可变 Release 行为](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)

本轮不强制所有 commit 签名：GitHub 的 signed-commit 规则会检查 PR 引入的 commit，即便最终 squash commit 由 GitHub 签名也可能被未签名的 head commit 阻断。保留正式 signed tag，不为加规则改写发行历史；后续若引入全量 commit 签名，先验证本地、人工作业和机器人补丁路径。[签名规则](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#require-signed-commits)

保留已上线网站及 Vercel `main` Git 自动生产部署关闭的状态，不创建外部发行、不恢复暂停渠道、不改变预览认证；当前更新不触发网站生产部署。保留旧的 HANDOFF、网站验收、发行来源、失败样本和待维护的认知状态，不把新设置回填成历史验收。

GitHub 的 `Production` environment 仅允许 `main` 分支部署，预览环境保留原配置。此限制只约束使用该 GitHub environment 的任务，不代替 Vercel 的部署控制或用户对发布的授权。

账号 2FA、PAT/SSH/GPG 密钥、第三方 App 安装与权限、Vercel 授权/环境变量、组织策略、计费和仓库外 secrets 不在本轮变更范围；发现风险应记录并由维护者另行决策，不读取或调整这些账号级资产。

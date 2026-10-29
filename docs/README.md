# Hoopito · 球豆文档入口

项目已发布 **Hoopito · 球豆 v2.0.1**（Android `2.0.1+5`），主工作区统一维护 `main` 的 2.0 源码。实际分支以 Git 为准，当前发行来源与范围见 [v2.0.1 发行记录](release/v2.0.1-release-record.md)。应用与签名 tag 来源固定为 `4ecd960e5af1f6b12124a43e330d67efb628281b`；后续宣传文档、截图和网站提交不改变 APK 来源。历史 HoopTrace 发行和候选记录保留各自源码、设备及验收来源。

## 当前开发与维护

- [项目介绍与运行](../README.md)
- [代理工作指南](../AGENTS.md)
- [贡献与验证矩阵](../CONTRIBUTING.md)
- [交接、验收与剩余门槛](development/handoff.md)
- [仓库设置与协作规则](repository-settings.md)
- [应用内更新维护](development/in-app-updates.md)
- [隐私说明](../PRIVACY.md)与[安全报告](../.github/SECURITY.md)
- [变更记录](../CHANGELOG.md)与[第三方许可证](legal/THIRD_PARTY_NOTICES.md)

## 设计

- [品牌名称与兼容性](design/brand/naming-and-compatibility.md)：当前中英文用法、升级身份及历史证据边界；对外改名同步由 [Issue #6](https://github.com/x1a0Y4NGren/hoopito/issues/6) 跟踪。
- [C「独眼球怪」正式标识与验证](design/brand/README.md)
- [Q 弹启动动效、APK 来源与设备验收限制](design/brand/entry-motion.md)

## 构建与发行

- [发行清单](release/release-checklist.md)：正式发行时使用的模板，当前完成状态以对应发行记录为准。
- [可复现构建](release/reproducible-builds.md)与[性能证据](release/performance.md)
- [F-Droid 准备](release/fdroid-notes.md)：按对应渠道任务范围使用。
- [当前 v2.0.1 下载与附件](https://github.com/x1a0Y4NGren/hoopito/releases/tag/v2.0.1)
- [当前双语 v2.0.1 说明](release/v2.0.1-release-notes.md)与[发行记录](release/v2.0.1-release-record.md)
- [截图维护清单](release/screenshots-checklist.md)与[双语八张正式包原图来源](release/v2.0.1-screenshots.json)

## 历史资料

- [归档入口](archive/README.md)：早期任务报告、原始截图、旧工作树脚本及迁移来源。
- [设计与实施记录的使用边界](superpowers/README.md)
- [历史分支提示](branch-prompts/README.md)与[历史执行顺序](branch-execution-order.md)
- [已发布 v1.0 说明](release/v1.0.0-release-notes.md)
- [历史 v2.0.0 说明](release/v2.0.0-release-notes.md)

历史计划中的基线、代理波次、技能要求及发布命令属于当时任务；只在追溯相关决策时查阅，不构成当前待办或授权。

### v2.0.0 发行与验收

- [v2.0.0 GitHub 发行执行、签名恢复与公开产物核验](release/v2.0.0-release-record.md)
- [面向用户的双语 2.0 发行说明](release/v2.0.0-release-notes.md)
- [双语发行说明与逐项验收](release/v2.0.0-candidate.md)
- [发布前 T1–T4 验收、最终源码与产物](release/v2.0.0-pre-release-verification.md)
- [取消长期监控后的剩余验收与 D 盘清理](release/v2.0.0-remaining-acceptance.md)
- [计时显示修复、实际 JSON 恢复和清理后 API36 续验](release/v2.0.0-clock-device-verification.md)
- [当时的候选完整 CI 五项结果、日志及远端产物来源](release/v2.0.0-final-ci-verification.md)
- [新正式签名包、API24／36 核心实测与剩余限制](release/v2.0.0-formal-package-verification.md)
- [当时 APK 启动性能续验与原生定位](release/v2.0.0-startup-performance.md)
- [启动性能环境验收、全部对照与复建步骤](release/v2.0.0-startup-lab.md)
- [新正式签名策略、离线备份待办与原证书历史准备](release/v2.0.0-signing-upgrade-verification.md)
- [自然备份与授权失效 Worker 观察](release/v2.0.0-backup-device-verification.md)
- [目标分 1～999 与手动输入验收](release/v2.0.0-target-score.md)
- [升级、兼容与备份契约](release/v2.0.0-upgrade.md)
- [v2.0.0 归档原图来源](release/v2.0.0-screenshots.json)
- [2.0 设计](superpowers/specs/2026-09-24-hooptrace-v2-design.md)与[实施记录](superpowers/plans/2026-09-24-hooptrace-v2.md)

# Hoopito · 球豆文档入口

项目已以 HoopTrace 名称发布 v2.0.0；当前源码与网站品牌为 Hoopito · 球豆，主工作区统一维护 `main` 的 2.0 源码。实际分支与发行状态以 Git 和 [HANDOFF.md](../HANDOFF.md) 为准；历史候选记录保留各自源码、设备和验收来源，不代表当前仍有独立候选工作区。

## 项目级说明

- [项目介绍与运行](../README.md)
- [代理工作指南](../AGENTS.md)
- [贡献与验证矩阵](../CONTRIBUTING.md)
- [交接、验收与剩余门槛](../HANDOFF.md)
- [隐私说明](../PRIVACY.md)与[安全报告](../SECURITY.md)
- [变更记录](../CHANGELOG.md)与[第三方许可证](../THIRD_PARTY_NOTICES.md)

## 构建与发行

- [发行清单](release/release-checklist.md)：正式发行时使用的模板，当前完成状态以交接和实际发行记录为准。
- [可复现构建](release/reproducible-builds.md)与[性能证据](release/performance.md)
- [F-Droid 准备](release/fdroid-notes.md)：按对应渠道任务范围使用。
- [已发布 v1.0 说明](release/v1.0.0-release-notes.md)
- [已发布 v2.0 说明](release/v2.0.0-release-notes.md)

## 设计与历史

- [品牌名称与兼容性](design/brand/naming-and-compatibility.md)：当前中英文用法、升级身份及历史证据边界；对外改名同步由 [Issue #6](https://github.com/x1a0Y4NGren/hoopito/issues/6) 跟踪。
- [C「独眼球怪」正式标识与验证](design/brand/README.md)
- [Q 弹启动动效、APK 来源与设备验收限制](design/brand/entry-motion.md)
- [设计与实施记录的使用边界](superpowers/README.md)
- [历史分支提示](branch-prompts/README.md)与[历史执行顺序](branch-execution-order.md)

历史计划中的基线、代理波次、技能要求及发布命令属于当时任务；只在追溯相关决策时查阅，不构成当前待办或授权。

## 2.0 发行与历史验收

- [本次 GitHub 发行执行、签名恢复与公开产物核验](release/v2.0.0-release-record.md)
- [面向用户的双语 2.0 发行说明](release/v2.0.0-release-notes.md)
- [双语发行说明与逐项验收](release/v2.0.0-candidate.md)
- [发布前 T1–T4 验收、最终源码与产物](release/v2.0.0-pre-release-verification.md)
- [取消长期监控后的剩余验收与 D 盘清理](release/v2.0.0-remaining-acceptance.md)
- [计时显示修复、实际 JSON 恢复和清理后 API36 续验](release/v2.0.0-clock-device-verification.md)
- [当前候选完整 CI 五项结果、日志及远端产物来源](release/v2.0.0-final-ci-verification.md)
- [新正式签名包、API24／36 核心实测与剩余限制](release/v2.0.0-formal-package-verification.md)
- [启动性能续验、原生定位与当前 APK](release/v2.0.0-startup-performance.md)
- [启动性能环境验收、全部对照与复建步骤](release/v2.0.0-startup-lab.md)
- [新正式签名策略、离线备份待办与原证书历史准备](release/v2.0.0-signing-upgrade-verification.md)
- [自然备份与授权失效 Worker 观察](release/v2.0.0-backup-device-verification.md)
- [目标分 1～999 与手动输入验收](release/v2.0.0-target-score.md)
- [升级、兼容与备份契约](release/v2.0.0-upgrade.md)
- [截图清单](release/screenshots-checklist.md)与[原图来源](release/v2.0.0-screenshots.json)
- [2.0 设计](superpowers/specs/2026-09-24-hooptrace-v2-design.md)与[实施记录](superpowers/plans/2026-09-24-hooptrace-v2.md)

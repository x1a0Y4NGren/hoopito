# Hoopito · 球豆名称与兼容性

当前产品英文名为 **Hoopito**，中文名为 **球豆**；双语并列使用 **Hoopito · 球豆**。原产品名 HoopTrace 仅在升级兼容标识、已发布文件和历史来源中保留。

## Issue #6 同步进展

记录日期：2026-10-13。源码、正式 APK、远端名称、当前素材、受保护 Preview 与本机目录／项目入口已同步，并完成实际验收。

GitHub 跟踪：[Issue #6：同步 Hoopito · 球豆品牌更名到源码、部署、发行及宣传素材](https://github.com/x1a0Y4NGren/hoopito/issues/6)。后续进展在 Issue 中更新，本文保留名称规则与兼容约束。

项目已从 HoopTrace 改名为 Hoopito · 球豆；正式 v2.0.1 安装名称为英文 Hoopito、中文球豆。签名 tag 与 APK 来源固定为 `4ecd960e5af1f6b12124a43e330d67efb628281b`；后续网站、截图和文档提交不改变该来源。实际范围见[发行记录](../../release/v2.0.1-release-record.md)。

- [x] 改名源码合入并推送 main，对应 App 五项 CI 全部通过。
- [x] 更新网站预览，核对双语页面、分享图、隐私页和下载说明；预览保留认证保护并继续禁止搜索收录。
- [x] 发布新名称正式 APK，版本 2.0.1+5，沿用既有 v2 签名和安装身份；旧 v2.0.0 文件未覆盖。
- [x] 正式包 API24 全新安装、API36 同证覆盖升级、真实冷启动、旧 JSON 导入及混合备份保留通过。
- [x] 正式包八张双语原图用于当前商店、网站和宣传入口；旧原图与历史来源按版本保留。
- [x] 新 APK 已公开回读，网站版本、文件大小、APK 链接、SHA-256、说明及二维码同步正式资产。
- [x] GitHub 仓库与 Vercel 项目已更名，既有身份、连接与保护保留，Git remote 与当前链接同步。
- [x] 完整 checkout 迁移至 `D:/GitHub/hoopito`；Codex 同一项目的名称与保存路径已核对，本机 MCP／Hook 绑定和构建命令通过验证。

完成标准：当前对外页面、远端源码、可下载安装包及当前宣传素材均一致使用 Hoopito／球豆，相关链接有效。下文列出的升级兼容标识、历史发行文件与来源记录继续保留原名称，不属于漏改。

本轮 Issue #6 已获授权实施：提交、整合并推送 main，发布 2.0.1+5 正式 APK，更新受保护的网站预览，并更名 GitHub／Vercel 项目及本机入口。网站生产上线、商店发布和项目收尾不在范围内。

未完成项按实际结果更新；网站生产上线保持暂停。

## 当前名称

- 英文界面、英文商店名称和英文文案：Hoopito。
- 中文界面、中文商店名称和中文文案：球豆。
- 项目首页、双语品牌展示和项目级说明：Hoopito · 球豆。
- Dart 包名与导入：`hoopito`、`package:hoopito/...`。
- 当前图标资源：`assets/icons/hoopito-app-icon*.png`。继续使用已审核的 C「独眼球怪」，不改变原图、原生／Flutter 几何或启动动效。
- 当前诊断和发行工具环境变量：`HOOPITO_*`；启动 Profile 开关为 `HOOPITO_ENTRY_PROFILE`。
- 当前启动参数：`--hoopito-entry-motion=<mode>`、`--hoopito-entry-animation=disabled`；Dart 同时接受原 `--hooptrace-...` 参数以兼容既有调用。
- 当前正式 APK：`Hoopito-v2.0.1-android.apk`；后续遵循 `Hoopito-v<version>-android.apk`。实际版本、签名和产物来源按[发行清单](../../release/release-checklist.md)核验。

## 升级与数据兼容

名称更新保留以下技术身份，避免把新名称安装成另一款应用或失去已有数据：

| 范围 | 保留内容 |
| --- | --- |
| Android | Application ID 与原生 namespace：`io.github.x1a0y4ngren.hooptrace`；原生包路径、MethodChannel 和 WorkManager 标识沿用既有值。 |
| iOS | 既有 bundle ID 与原生通道。 |
| 本地数据 | `hooptrace.sqlite`、私有安全副本目录 `hooptrace-safety-backups`、已有偏好键、数据库 schema 3 和 JSON 格式 2。 |
| 正式签名 | v2 使用既有 `.hooptrace/signing/hooptrace-v2-release.jks` 和原 alias，证书 SHA-256 为 `2820ba06e898be1152d38536492282127e9fb0734a0863bb42db63f8a75611dd`。历史 v1 keystore 与 alias 继续保留。改名不生成或替换密钥。 |
| 仓库与工作区 | 当前仓库为 [`x1a0Y4NGren/hoopito`](https://github.com/x1a0Y4NGren/hoopito)；本机 checkout、已有分支和外部证据路径按实际位置使用。 |

保持应用身份与证书后，后续正式版本才可覆盖升级已发布的 v2。历史 v1 与 v2 使用不同正式签名的安装限制仍然适用，见[安装与备份](../../release/v2.0.0-upgrade.md)。改名不触发数据库迁移，也不改变完整备份、恢复、安全副本、离线或隐私契约。

新导出的 JSON 使用 `appName: Hoopito`；新应用可以导入 `Hoopito` 与旧 `HoopTrace` 备份，并按原始名称验证校验和。已发布的旧应用仅识别 `HoopTrace`，因此不能导入新名称的备份。新导出文件使用 `hoopito-` 前缀；自动备份保留策略同时识别新旧前缀，按时间排序，不因品牌名称而误删较新的文件。

## 已发布文件与历史证据

公开 v2.0.0 仍是原 HoopTrace 发行：[Release 页面](https://github.com/x1a0Y4NGren/hoopito/releases/tag/v2.0.0)及 APK `HoopTrace-v2.0.0-android.apk` 保留原名称。当前品牌更新不代表该 APK 已重新构建、替换或以新名称发布。

发行 tag、APK 校验和、签名证书、截图及其来源 JSON、旧源码 SHA、旧命令／日志前缀和外部证据路径，必须保留当时记录。`HANDOFF.md`、既有 Changelog、`docs/release/v*.md`、历史设计／计划与分支提示也保留原来源。不得把它们改标为 Hoopito 的新构建或新验收。

品牌图形继续来源于 2026-10-04 审核的 C「独眼球怪」；[原始透明输出](hooptrace-c-imagegen-source.png)、[来源记录](source.json)和[原验收](verification.md)保留真实文件名与摘要。当前生产资源改名不改变原始生成来源。

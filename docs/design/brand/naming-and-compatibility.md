# Hoopito · 球豆名称与兼容性

当前产品英文名为 **Hoopito**，中文名为 **球豆**；双语并列使用 **Hoopito · 球豆**。原产品名 HoopTrace 仅在升级兼容标识、已发布文件和历史来源中保留。

## 待办：改名尚未完全同步

记录日期：2026-10-12。状态：**本地实现已完成，对外同步未完成**。

GitHub 跟踪：[Issue #6：同步 Hoopito · 球豆品牌更名到源码、部署、发行及宣传素材](https://github.com/x1a0Y4NGren/hoopito/issues/6)。后续进展在 Issue 中更新，本文保留名称规则与兼容约束。

项目已从 HoopTrace 改名为 Hoopito · 球豆；App、网站、当前源码命名及现行文档已在本地更新，但改名尚未完整同步到远端源码、网站预览、正式安装包和宣传素材。用户通过现有下载与部分入口仍会看到旧名称。

- [ ] 提交并按授权推送改名源码，确认远端当前文档与实现使用新品牌。
- [ ] 更新网站预览，核对双语页面、分享图、隐私页和下载说明；预览继续禁止搜索收录。
- [ ] 在后续正式发行中提供使用新名称的安装包；版本／versionCode 递增，继续使用既有签名和安装身份，不覆盖或改标已发布 v2.0.0 文件。
- [ ] 在正式包上验证覆盖升级既有 v2、已有数据与设置读取、旧备份导入及新旧自动备份共存；记录实际构建来源与环境。
- [ ] 从新品牌的实际 App 构建重新采集双语截图，更新网站、商店元数据及宣传入口；保留旧截图的历史来源。
- [ ] 新 APK 发布后集中更新下载配置、版本、APK 链接、SHA-256、发行说明及二维码，确认页面说明与实际安装名称一致。
- [ ] 核对 GitHub 仓库、Vercel 项目等对外名称与地址；需要改动时同步连接、引用和跳转，不能只替换链接文本。

完成标准：当前对外页面、远端源码、可下载安装包及当前宣传素材均一致使用 Hoopito／球豆，相关链接有效。下文列出的升级兼容标识、历史发行文件与来源记录继续保留原名称，不属于漏改。

本轮 Issue #6 已获授权实施：提交、整合并推送 main，发布 2.0.1+5 正式 APK，更新受保护的网站预览，并更名 GitHub／Vercel 项目及本机入口。网站生产上线、商店发布和项目收尾不在范围内。

当前安排：按实际验证逐项完成同步；未完成的对外动作继续保持待办，不以本地修改代替发布或部署结果。

## 当前名称

- 英文界面、英文商店名称和英文文案：Hoopito。
- 中文界面、中文商店名称和中文文案：球豆。
- 项目首页、双语品牌展示和项目级说明：Hoopito · 球豆。
- Dart 包名与导入：`hoopito`、`package:hoopito/...`。
- 当前图标资源：`assets/icons/hoopito-app-icon*.png`。继续使用已审核的 C「独眼球怪」，不改变原图、原生／Flutter 几何或启动动效。
- 当前诊断和发行工具环境变量：`HOOPITO_*`；启动 Profile 开关为 `HOOPITO_ENTRY_PROFILE`。
- 当前启动参数：`--hoopito-entry-motion=<mode>`、`--hoopito-entry-animation=disabled`；Dart 同时接受原 `--hooptrace-...` 参数以兼容既有调用。
- 未来发行 APK：`Hoopito-v<version>-android.apk`。实际版本、签名和产物来源仍须按[发行清单](../../release/release-checklist.md)核验。

## 升级与数据兼容

名称更新保留以下技术身份，避免把新名称安装成另一款应用或失去已有数据：

| 范围 | 保留内容 |
| --- | --- |
| Android | Application ID 与原生 namespace：`io.github.x1a0y4ngren.hooptrace`；原生包路径、MethodChannel 和 WorkManager 标识沿用既有值。 |
| iOS | 既有 bundle ID 与原生通道。 |
| 本地数据 | `hooptrace.sqlite`、私有安全副本目录 `hooptrace-safety-backups`、已有偏好键、数据库 schema 3 和 JSON 格式 2。 |
| 正式签名 | 继续使用已有正式 keystore 与证书；默认 `.hooptrace/signing/hooptrace-release.jks` 和 alias `hooptrace` 保留。改名不授权生成或替换密钥。 |
| 仓库与工作区 | 当前仓库为 [`x1a0Y4NGren/hoopito`](https://github.com/x1a0Y4NGren/hoopito)；本机 checkout、已有分支和外部证据路径按实际位置使用。 |

保持应用身份与证书后，后续正式版本才可覆盖升级已发布的 v2。历史 v1 与 v2 使用不同正式签名的安装限制仍然适用，见[安装与备份](../../release/v2.0.0-upgrade.md)。改名不触发数据库迁移，也不改变完整备份、恢复、安全副本、离线或隐私契约。

新导出的 JSON 使用 `appName: Hoopito`；新应用可以导入 `Hoopito` 与旧 `HoopTrace` 备份，并按原始名称验证校验和。已发布的旧应用仅识别 `HoopTrace`，因此不能导入新名称的备份。新导出文件使用 `hoopito-` 前缀；自动备份保留策略同时识别新旧前缀，按时间排序，不因品牌名称而误删较新的文件。

## 已发布文件与历史证据

公开 v2.0.0 仍是原 HoopTrace 发行：[Release 页面](https://github.com/x1a0Y4NGren/hoopito/releases/tag/v2.0.0)及 APK `HoopTrace-v2.0.0-android.apk` 保留原名称。当前品牌更新不代表该 APK 已重新构建、替换或以新名称发布。

发行 tag、APK 校验和、签名证书、截图及其来源 JSON、旧源码 SHA、旧命令／日志前缀和外部证据路径，必须保留当时记录。`HANDOFF.md`、既有 Changelog、`docs/release/v*.md`、历史设计／计划与分支提示也保留原来源。不得把它们改标为 Hoopito 的新构建或新验收。

品牌图形继续来源于 2026-10-04 审核的 C「独眼球怪」；[原始透明输出](hooptrace-c-imagegen-source.png)、[来源记录](source.json)和[原验收](verification.md)保留真实文件名与摘要。当前生产资源改名不改变原始生成来源。

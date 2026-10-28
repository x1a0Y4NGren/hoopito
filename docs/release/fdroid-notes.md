# Hoopito · 球豆 F-Droid Preparation Notes

本文记录 Hoopito · 球豆申请进入官方 F-Droid 仓库前的构建事实、隐私声明和剩余工作。它不是已经通过审核的 fdroiddata recipe。改名与已发布版本的边界见[品牌与兼容性](../design/brand/naming-and-compatibility.md)。

## 应用身份

- Name：Hoopito；中文名称：球豆；双语品牌：Hoopito · 球豆
- Application ID：`io.github.x1a0y4ngren.hooptrace`
- License：MIT
- Source：`https://github.com/x1a0Y4NGren/hoopito`
- Issue tracker：`https://github.com/x1a0Y4NGren/hoopito/issues`
- Published Android release：Hoopito · 球豆 `2.0.1`，versionCode `5`，Git tag `v2.0.1`；历史 HoopTrace `2.0.0` 为 versionCode `4`，`1.0.0` 为 versionCode `2`
- Platform：Flutter，Android 优先

Application ID 已脱离 Flutter 模板的 `com.example` 命名，并与 GitHub Pages 命名空间对应。v1.0.0 已正式发布后不可再更改。

## 当前发布状态

Hoopito · 球豆 v2.0.1 Android 正式 APK 已通过 [GitHub Release](https://github.com/x1a0Y4NGren/hoopito/releases/tag/v2.0.1) 发布，公开文件为 `Hoopito-v2.0.1-android.apk`，来源见[发行记录](v2.0.1-release-record.md)。原 HoopTrace v2.0.0 文件和验收记录保留历史名称。本文仍是 F-Droid 准备记录，**尚未在官方 F-Droid 仓库发布**；后续渠道工作需单独完成，不改变已发布版本。

## 构建工具链

当前开发和 CI 基准：

- Flutter `3.41.9` stable
- Flutter revision `00b0c91f06209d9e4a41f71b7a512d6eb3b9c694`
- Dart `3.11.5`
- Temurin Java `17.0.20+8`
- Android compile/target SDK `36`
- Android build-tools `36.1.0`
- Android NDK `28.2.13676358`
- Gradle `8.14` wrapper; verify the checked-in wrapper SHA-256 and
  `distributionSha256Sum` in `android/gradle/wrapper/gradle-wrapper.properties`

从源码构建的基本命令：

```bash
flutter pub get
HOOPITO_ALLOW_UNSIGNED_RELEASE=true flutter build apk --release
```

For a release-verification checkout, run the pinned toolchain and source
checks first. The dependency lock and checked-in Android runtime graph must not
change during the build:

```bash
bash tool/release/prepare_android_toolchain.sh
flutter pub get --enforce-lockfile
dart --packages=.dart_tool/package_config.json tool/release/verify_sqlite_source.dart
./android/gradlew -p android :app:exportReleaseRuntimeCoordinates
diff -u third_party/android_runtime/coordinates.txt \
  build/app/reports/release-runtime-coordinates.txt
dart --packages=.dart_tool/package_config.json \
  tool/release/generate_third_party_notices.dart
git diff --exit-code -- THIRD_PARTY_NOTICES.md
```

仓库不包含 keystore 或 `key.properties`。普通 Release 构建在没有正式签名配置时会失败，防止维护者误发未签名 APK；F-Droid 或可复现性验证必须通过上面的显式环境变量选择未签名构建。任何模式都不会回退到 debug key。

## 依赖说明

直接依赖来自 Flutter SDK 或 pub.dev：Drift/SQLite、Riverpod、go_router、file_picker、path_provider、share_plus、url_launcher、csv、crypto、uuid 和 Dart 基础包。

- 没有 Google Play Services、Firebase、广告、分析或专有追踪 SDK。
- `file_picker` 用于系统文件/目录选择器。
- `share_plus` 用于用户主动发起的系统分享。
- `url_launcher` 只在用户点击项目外部链接时调用系统浏览器。
- SQLite 通过仓库内 3.53.4 amalgamation 的 `source: source` hook 编译，不依赖
  `sqlite3` GitHub Release 原生库；Flutter engine 及 Android toolchain 仍需按
  F-Droid 当前对受信构建工具和二进制来源的规则检查。
- `third_party/android_runtime/coordinates.txt` 是 Gradle release runtime
  graph 的排序清单；CI 会重新导出并逐字节比较。每个坐标及完整 Apache-2.0
  文本会进入 `THIRD_PARTY_NOTICES.md`，不能用删节许可证替代。

提交前应在 fdroidserver 环境执行依赖扫描，并确认所有 Maven 和 pub 包来源满足 Inclusion Policy。

## 网络和隐私行为

当前核心功能完全离线：

- 无账号、云同步、广告、分析、追踪或崩溃遥测。
- 无应用运营后端，不上传球员、比赛、落点或设置。
- Android 应用级系统备份关闭。
- 包含应用内更新功能的 Android 源码使用网络权限和 `REQUEST_INSTALL_PACKAGES`。默认每进程启动检查一次公开更新元数据，可在设置中关闭；也可手动检查。先请求官网 stable feed，失败或无效时请求 GitHub latest 的 `android-update.json`。不上传比赛、球员、设置或设备标识，连接信息仍会由分发服务处理。
- 安装包仅在用户点击下载后由 Android DownloadManager 获取，官网失败时最多回退一次同版本 GitHub 附件；下载后校验大小、SHA-256、应用身份、版本和签名。安装需要用户和系统确认，活动比赛期间不发起安装，无后台静默安装，不申请广泛存储或通知权限。
- 其他外部链接仍只在用户点击后交给浏览器。
- 导出和自动备份由系统分享面板或用户授权目录驱动。

F-Droid recipe 和审核必须单独评估应用内更新器、网络端点、安装权限及可能适用的 Anti-Features，不再根据核心功能离线推定无需标注。若渠道要求禁用上游更新器，应明确维护构建差异并验证入口、网络请求与权限一致；不能仅隐藏界面。不同签名渠道不能使用上游 APK 覆盖安装。已发布 v2.0.1 APK 的网络与权限行为不因后续源码文档改变。完整声明见 [`PRIVACY.md`](../../PRIVACY.md)。

## 上游元数据

仓库维护以下 Fastlane-compatible 元数据：

- `fastlane/metadata/android/en-US/short_description.txt`
- `fastlane/metadata/android/en-US/full_description.txt`
- `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`（当前 v2.0.1 为 `5.txt`，历史 v2.0.0 为 `4.txt`）
- 对应的 `zh-CN` 文件
- 两个 locale 的 `images/icon.png`
- 两个 locale 的 4 张手机截图：主页、计分、复盘和历史

当前双语八张截图直接来自正式签名 v2.0.1 APK 在专用 API36 模拟器上的实际画面，全部使用合成球员与对局，逐张按原始分辨率检查后原样复制。版本、摘要、拍摄状态及原始证据见[截图来源](v2.0.1-screenshots.json)与[维护清单](screenshots-checklist.md)；旧八张 PNG 与[历史来源](v2.0.0-screenshots.json)保留在版本化目录。

正式 APK 与签名 tag 的应用提交固定为 `4ecd960e5af1f6b12124a43e330d67efb628281b`。新截图与宣传文档在正式包验收后更新，其提交独立于 APK 来源；不能为了更新宣传素材移动签名 tag。后续 F-Droid recipe 应分别核对构建源码与元数据来源。

## 源码与 tag 要求

- 每个公开 `versionName` 必须有唯一 tag；当前已发布版本为 Hoopito · 球豆 `v2.0.1`。
- tag 必须指向用于构建发布 APK 的干净提交。
- GitHub source archive 应能在无私有文件、无预下载构建产物的环境中完成构建。
- `pubspec.lock` 必须提交，避免解析到不同依赖版本。
- 版本更新同时维护 Fastlane `changelogs/<versionCode>.txt`。

## 可复现构建注意事项

F-Droid 基础收录不强制上游提供可复现构建，但普通 F-Droid 源码构建会由 F-Droid 使用不同证书签名，无法覆盖安装 GitHub 渠道的 APK。Hoopito · 球豆不计划维护两个签名不同的官方 Android 包，因此把可复现构建和上游二进制验证设为项目自己的 F-Droid 首发门槛。

F-Droid 官方文档指出 Flutter/NDK 原生库可能嵌入 SDK 或工作目录路径。首次 recipe 验证应：

1. 固定 Flutter revision、Android SDK/NDK 和 Java 版本。
2. 从干净 tag 在 fdroidserver 标准路径构建。
3. 使用 `diffoscope` 对比上游和 F-Droid 构建产物。
4. 检查 Flutter SDK 路径、Android platform revision 和 VCS info 是否造成差异。
5. 构建可重复后采用 F-Droid 的 `Binaries`/upstream signature 流程，使 GitHub 与 F-Droid 用户都能沿用同一应用签名升级。

参考：

- <https://f-droid.org/docs/Inclusion_Policy/>
- <https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/>
- <https://f-droid.org/docs/Reproducible_Builds/>
- <https://f-droid.org/docs/Building_Applications/>

## 提交前剩余阻断项

- [x] 将 v1.0.0 的完整源码、工作流和 Fastlane 元数据合并并推送到公开 `main`。
- [x] 创建并公开 v1.0.0 签名 Git tag 和 GitHub Release。
- [x] 添加经过隐私检查的手机截图。
- [ ] 在 fdroiddata fork 中生成最终 build metadata，或验证仓库根目录 `.fdroid.yml`。
- [ ] 运行 `fdroid lint` 和 server-mode build。
- [ ] 完成 Flutter 原生库可复现性评估。
- [ ] 向 fdroiddata 提交 merge request；需要前置讨论时再提交 Request For Packaging。

完成这些事项之前，项目属于“本地代码和上游元数据已准备，尚未具备 F-Droid 发布资格”。

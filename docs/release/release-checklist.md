# Hoopito · 球豆 Release Checklist

本清单适用于 GitHub Release，并包含后续 F-Droid 提交所需的前置核验。每个发行版从干净的 `main` 和唯一签名 tag 构建。

仅在准备或执行正式发行时使用本清单；普通维护按 [贡献指南](../../CONTRIBUTING.md#测试要求) 选择验证范围。创建 tag、发布 Release 或提交 F-Droid 申请需要当前任务的对应授权，准备工作不自动授权对外发布。第 8 节仅在本次包含 F-Droid 渠道工作时执行，不阻塞单独的 GitHub Release。

本文件是可复用的发行模板，不是 2.0 的完成状态表。当前候选与原始验收来源见 [HANDOFF.md](../../HANDOFF.md)。复用证据时保留其提交、工具链和设备范围；本地 Debug、未签名复现、文件重开和模拟器验收分别不能代替正式同证升级、远端 CI、进程重启或实体设备结果。

## 1. 范围与版本

- [ ] 确认本次版本范围冻结，没有未处理的发布阻断 Issue。
- [ ] 将 `pubspec.yaml` 的 `version` 更新为目标 `versionName+versionCode`。
- [ ] 同步 `lib/app/app_metadata.dart` 中用于备份清单的版本号。
- [ ] 将 `CHANGELOG.md` 的 Unreleased 内容归入目标版本和发布日期。
- [ ] 确认 Android Application ID 仍为 `io.github.x1a0y4ngren.hooptrace`；保留原签名、原生技术标识和本地数据名称，遵守[品牌与兼容性](../design/brand/naming-and-compatibility.md)。
- [ ] 同步 README 中的当前正式版本、下载与更新说明链接、功能描述和真实界面截图；不得保留上个版本或发布候选文案。
- [ ] 确认显示名使用英文 Hoopito、中文球豆，双语并列使用 Hoopito · 球豆；图标、MIT License 和 PRIVACY 均为最终版本。
- [ ] 搜索源码中的 `TODO`、模板标识、测试域名和调试开关并逐项评估。

## 2. 依赖、隐私与权限

- [ ] 运行 `flutter pub outdated`，评估但不要盲目升级发布分支依赖。
- [ ] 确认 `third_party/sqlite/sqlite3.c` SHA-256 与
      `docs/release/reproducible-builds.md` 一致，且 `pubspec.yaml` 保持
      `source: source`；不得重新引入 `drift_flutter`/EOL SQLite binary 包。
- [ ] 记录所有直接依赖的许可证和来源，确认不存在专有 SDK。
- [ ] 确认没有广告、追踪、分析、崩溃遥测或账号依赖。
- [ ] 确认 `PRIVACY.md` 与真实数据流一致。
- [ ] 检查应用内更新默认开关、官网/GitHub 元数据请求、用户触发下载和系统安装确认；披露分发服务接收连接信息，确认无比赛、球员、设置或设备标识上传。关闭启动检查后不得自动请求，后台自动备份不得触发检查。
- [ ] 确认自动备份默认关闭，只使用用户授权目录。
- [ ] 用 `aapt dump permissions <apk>` 检查最终 APK 权限；不应出现广泛存储、位置、相机、麦克风或联系人权限。
- [ ] 检查合并后的 Manifest，确认 `android:allowBackup="false"` 仍生效。
- [ ] 包含更新器的 APK 仅为更新功能使用网络与 `REQUEST_INSTALL_PACKAGES` 权限，不增加广泛存储或通知权限；核验 FileProvider 只暴露更新安装包子目录。

## 3. 干净构建与自动化验证

从干净 clone 或清理后的发行 worktree 运行：

```powershell
flutter clean
bash tool/release/prepare_android_toolchain.sh
flutter pub get --enforce-lockfile
dart --packages=.dart_tool/package_config.json tool/release/verify_sqlite_source.dart
./android/gradlew -p android :app:exportReleaseRuntimeCoordinates
diff -u third_party/android_runtime/coordinates.txt \
  build/app/reports/release-runtime-coordinates.txt
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test test/performance/task15_query_benchmarks_test.dart --reporter expanded
dart --packages=.dart_tool/package_config.json tool/release/generate_third_party_notices.dart
git diff --exit-code -- THIRD_PARTY_NOTICES.md
dart --packages=.dart_tool/package_config.json tool/release/validate_metadata.dart
flutter test integration_test/main_loop_test.dart -d <android-device-id>
flutter test integration_test/command_performance_test.dart -d <android-device-id>
flutter build apk --debug
```

如果同一工作树此前运行过 Android Integration Test，正式 release 构建不得使用 `--no-pub`：Flutter 必须在 release 模式重新生成 `GeneratedPluginRegistrant.java`，从而排除仅适用于调试构建的 `integration_test`，同时保留运行时插件。正式构建优先使用全新 clone。

- [ ] 所有命令退出码为 0。
- [ ] 发行源码经 PR 合入最新 `main`，`App CI required`、`Website CI required`、`Repository policy required` 全部通过；保存精确源码与 CI 来源，不用后续文档提交替换构建来源。
- [ ] GitHub Actions 的 quality 和 Android integration jobs 均通过。
- [ ] CI 的 golden/widget 测试、Drift schema 测试、API 36 主流程及 Android 命令 p95
      基准均通过；日志保留 `TASK15_QUERY_BENCHMARK` 和
      `TASK15_COMMAND_BENCHMARK` 结果。
- [ ] CI 从两份全新源码快照在固定构建路径顺序重建，并逐字节核验完整的未签名
      Release APK；同时通过 macOS iOS
      `flutter build ios --release --no-codesign`。
- [ ] `THIRD_PARTY_NOTICES.md` 可由当前锁定依赖确定性生成且无 diff。
- [ ] CI 生成的 Debug APK artifact 可以下载并安装。
- [ ] 工作树除预期版本和 Changelog 修改外保持干净。

## 4. Android 正式签名

- [ ] 使用维护者控制的正式 keystore；永远不要使用 debug key 发布。
- [ ] 将 keystore 做至少两份加密离线备份，并记录恢复责任人。
- [ ] 首次发布可运行 `tool/release/setup_android_signing.ps1`，在仓库外创建 keystore 并生成被忽略的签名配置。
- [ ] 在未提交的 `android/key.properties` 中配置 `storeFile`、`storePassword`、`keyAlias` 和 `keyPassword`。
- [ ] 运行 `tool/release/build_android_release.ps1`，从干净提交生成签名 APK、证书记录、权限记录和 `SHA256SUMS`。
- [ ] 确认没有为上游发布设置 `allowUnsignedRelease` 或 `HOOPITO_ALLOW_UNSIGNED_RELEASE`。
- [ ] 使用 `apksigner verify --verbose --print-certs <apk>` 验证签名和证书指纹。
- [ ] 将首次正式签名证书 SHA-256 指纹写入维护者的离线发布记录，后续版本必须一致。
- [ ] 计算 `SHA256SUMS`，至少覆盖发布 APK。

## 5. 设备验收

- [ ] 在 Android API 24 和当前受支持的新版本 Android 上完成启动冒烟测试。
- [ ] 在至少一个实体设备或硬件加速模拟器上完成主流程。
- [ ] 验证主页、赛前、横屏计分、落点、复盘、结束比赛和历史回看。
- [ ] 验证短名称、长名称、小屏横屏和系统字体放大后的布局。
- [ ] 验证 JSON 导出后可恢复，损坏备份不会改变现有数据。
- [ ] 验证 CSV 内容和复盘 PNG 可由真实目标应用接收。
- [ ] 验证自动备份关闭、授权目录、立即备份、重启备份和目录失效错误。
- [ ] 分别测试全新安装和从上一个正式版本覆盖升级，确认本地数据保留。
- [ ] 检查离线模式下所有核心流程。
- [ ] 验证启动检查一次性、开关持久化、手动检查、主源有效时优先、元数据失效与下载失败回退、取消与恢复、损坏/错误签名/错误版本拒绝、未知来源授权返回，以及活动比赛期间禁止安装；断网自动检查失败不得打扰核心流程。
- [ ] 涉及启动动效修改时，验收原生衔接、慢初始化、错误/旧数据库、跳过、减少/关闭动画和返回前台；保存从标准动作直至首页的连续设备录屏。
- [ ] 涉及启动动效修改时，完成约定次数的 Profile 冷启动，分别记录标准动作与降级，按批准帧预算检查构建/绘制耗时；保留失败样本，核对 APK 来源并恢复测试设置。

## 6. 商店与仓库元数据

- [ ] 准备至少两张仅含经过整理的演示数据、不含个人信息的手机截图。
- [ ] 检查 `fastlane/metadata/android/en-US` 和 `zh-CN` 的短描述、完整描述、图标及对应 `versionCode` Changelog。
- [ ] 确认短描述少于 80 个字符，Changelog 不超过 500 个字符。
- [ ] 在目标发布提交创建签名 tag，例如 `v1.0.0`。
- [ ] 验证签名 tag（`git tag -v <tag>`），确认远端 tag 指向相同对象；`v*` 保护禁止更新和删除，不重建既有正式 tag。
- [ ] 确认 tag 中的版本号、源码和构建 APK 完全对应。

## 7. GitHub Release

- [ ] 确认仓库对未来发行启用 release immutability；这不会追溯锁定旧 Release，也不改变旧发行的来源或保留责任，见[仓库设置策略](../repository-settings.md)。
- [ ] 使用已经验证的版本 tag 创建 **draft Release**；命令行创建时使用 `--draft --verify-tag`，避免意外创建 tag 或提前发布。
- [ ] 发布说明包含主要变化、升级说明、隐私声明链接和已知限制。
- [ ] 向草稿上传全部正式资产，包括签名 APK 和 `SHA256SUMS`；新发行 APK 命名为 `Hoopito-v<version>-android.apk`，既有 `HoopTrace-v2.0.0-android.apk` 保留原名。
- [ ] 在 `website/src/data/release.ts` 固定本次已验证签名 APK 的版本、versionCode、minimumApi、双语说明、大小和 SHA-256；用 `npm run export:android-update -- --apk <signed.apk> --output <release-dir>/android-update.json` 校验实际文件并生成附件（在 `website/` 运行）。该命令必须成功，元数据仅导出模式不能替代 APK 校验。`SHA256SUMS` 同时覆盖 `android-update.json`。
- [ ] 从草稿重新下载全部待发布资产，核验文件集合、大小、SHA-256、APK 签名与源码/tag 对应关系；`SHA256SUMS` 覆盖所有需要校验的发布附件，禁止包含密钥或设备数据。
- [ ] 保留 GitHub 自动生成的 source code archives。
- [ ] 明确 Android 优先状态以及 iOS 尚未正式发布。
- [ ] 全部资产与校验和确认后，再在本次发布授权内发布草稿；不可变 Release 发布后不能补传、替换或删除附件，也不能移动关联 tag，修复使用新版本。
- [ ] 发布顺序为签名 APK、`android-update.json` 等附件在草稿中齐备并校验后发布 Release，再在单独的网站部署授权内构建和部署官网；不得向旧 Release 补传更新附件。网站 feed 和附件由同一序列化器生成，必须逐字节相同。网站发布元数据可落后于开发 App 版本，不得提前宣告尚未公开的 APK。
- [ ] 从公开 Release 页面重新下载 APK，核验 SHA-256 和签名后安装冒烟测试。
- [ ] 网站获准部署后验证 `/updates/android/stable.json` 的 JSON、双语说明、可重新验证缓存头和对应 APK 的实际大小/摘要；固定版本 APK 仍使用 immutable 缓存。官网有效旧 feed 优先于备源，因此尚未部署新版官网时不保证即时提示 GitHub 新版。

## 8. F-Droid 准备

- [ ] 完成 [F-Droid Notes](fdroid-notes.md) 中的阻断项。
- [ ] 以公开 tag 和源码归档验证无密钥、无私有依赖构建。
- [ ] 创建并用 `fdroid lint` 检查 build metadata。
- [ ] 在 fdroidserver 环境执行 `fdroid build -v --server io.github.x1a0y4ngren.hooptrace`。
- [ ] 评估 Flutter 原生库中的路径差异并记录可复现构建结果；这是保持两条官方渠道签名一致的项目门槛。
- [ ] 验证 F-Droid `Binaries`/upstream signature 流程可匹配 GitHub Release APK。
- [ ] 向 fdroiddata 提交 merge request；需要前置讨论时再提交 Request For Packaging。

## 9. 发布后

- [ ] 在一台干净设备上验证公开下载渠道。
- [ ] 不删除或替换已经公开的二进制；需要修复时发布递增版本号的新版本。
- [ ] 把本次签名指纹、校验和、测试结果和已知问题归档。

本次发布在适用检查、公开产物核验和归档完成后结束。后续 Issue 监控属于独立任务：仅在明确要求时设置，并约定期限、检查频率和通知条件；无需在发布任务内持续等待新 Issue。

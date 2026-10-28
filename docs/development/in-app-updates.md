# Android 应用内更新

当前开发源码提供此功能，已发布的 2.0.1 APK 不包含更新器。首次启用需要手动安装包含此功能的新正式版；本地开发不会自动发布 APK、更新旧 Release 或部署官网。

## 使用方式

- 「设置 → 软件更新」显示设备实际安装的版本，可手动检查、下载、取消、重试和安装。
- 「启动时检查更新」默认开启，可关闭。自动检查在本地启动及开屏结束后进行，每个前台应用进程最多一次；无新版或检查失败均不提醒，不阻塞记分。
- 发现兼容新版时，显示版本、更新说明和大小。「稍后」只关闭本次提醒，下次冷启动继续检查；未结束的比赛会延后提醒。
- 下载由 Android DownloadManager 管理，切到后台仍可继续。回到 App 可查看进度。下载通知仅显示进行中的任务，完成后在 App 中点击安装；不会静默安装。
- 安装需要比赛状态已确认且没有活动比赛。Android 8 及以上可能要求先允许球豆安装应用，返回后重新检查比赛状态，再交由系统确认。取消安装后仍可重试。

## 结构与数据边界

`lib/core/update/` 包含版本信息解析、有界 HTTPS 请求、设置存储、平台通道和状态控制器；`lib/app/app_update_host.dart` 负责启动检查、前台进度刷新及提醒，更新页面只负责展示和用户动作。版本按设备 PackageManager 返回的数值 versionCode 比较，字符串版本仅用于显示。

启动开关存储在现有 app_settings 的 `updates.preferences.v1`，沿用完整备份对普通设置的处理。下载任务 ID、候选版本及临时状态存储在原生 `app_update_v1` 私有偏好中，下载文件属于 App 的专用目录；它们不进入比赛 JSON 备份。数据库仍为 schema 3，JSON 仍为格式 2。

原生通道 `io.github.x1a0y4ngren.hooptrace/app_update` 仅注册到前台 Activity 引擎，自动备份的无界面引擎不检查更新。后台线程处理文件复制、摘要及 APK 身份校验。只有私有 `files/updates/` 下的已验证 APK 能由非导出的 FileProvider 临时授权给系统安装器；外部暂存文件不作为安装入口。校验包括大小、SHA-256、包名、版本、最低 API 和已安装应用当前签名。

安装采用两阶段协议：`prepareInstall` 在后台校验实际私有 APK，返回 `prepared`、`permissionRequired` 或 `unavailable`；Dart 在等待结束后重新检查发起页面仍已挂载且是当前路由、App 在前台以及实时比赛查询已确认无活动比赛，再调用只负责启动的 `requestInstall`。后者同步消费一次性私有文件封印，复核下载代次、路径、大小、修改时间、只读权限、Activity 已恢复和系统安装权限，不再次异步散列。取消、替换下载或 Activity 暂停使准备失效；缺少实时门禁回调时控制器拒绝启动。候选丢失或校验失败立即刷新下载状态以提供重试；系统设置打不开时清除返回标记并显示错误，之后普通恢复不会触发安装。

应用恢复时重新查询 DownloadManager 和实际文件。文件被系统清理时显示重新下载；升级后设备版本已达到候选版本时清除该更新任务。主下载源的传输失败最多切到备用源一次，包括 DownloadManager 已失败且等待重试的暂停状态（`PAUSED_WAITING_TO_RETRY`）；等待网络或用户 Wi-Fi 限制不会切换，TLS 信任检查保持开启。校验失败需要用户重新下载，不绕过校验。StatefulShellRoute 明确开启 GoRouter 的 `notifyRootObserver`，分支内的筛选底部弹窗与根导航弹窗共同延后启动提醒。

## 版本信息与发版

主源是 `https://hoopito.com/updates/android/stable.json`，主源失败或格式无效才尝试 GitHub 最新正式发行的 `android-update.json`。每个源最多等待 8 秒，版本信息最多 64 KiB，自动失败静默，手动失败可重试。

官网的发行元数据是已发布稳定版的来源，不随尚未发行的开发版本自动提升。官网更新文件与 GitHub 附件由同一个序列化函数生成；版本文件重新验证缓存，带版本号的 APK 地址保持不可变。生成、校验命令及先发布附件再更新官网的顺序见 [website/README](../../website/README.md#发行信息维护) 和[发布清单](../release/release-checklist.md)。当前 2.0.1 Release 没有该附件；两个线上入口均未提供信息时必须报告检查失败，不能假称已是最新。

网络及权限说明见 [PRIVACY](../../PRIVACY.md)。核心记录始终离线，版本请求不附带比赛、球员、设置或设备标识。后续商店或 F-Droid 渠道接入需单独评审分发策略及签名兼容性。

## 开发验证

```powershell
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub test/core/update test/app/app_update_host_test.dart test/app/entry_update_readiness_test.dart test/features/settings/software_update_page_test.dart
flutter test --no-pub
flutter build apk --debug --no-pub
./android/gradlew -p android :app:testDebugUnitTest
```

UI 回归覆盖中英文、明暗主题、窄屏／横屏、200% 字体和从权限页返回时的实时比赛门禁。安装和进程恢复需要专用 Android 设备或隔离用户；普通单元测试的文件关闭重开不等于冷进程验收。测试夹具入口 `integration_test/update_device_fixture.dart` 仅用于构建独立的测试包，不能作为正式发行入口。

覆盖升级测试使用相同测试签名、严格递增的测试版本码及真实文件数据库。记录 APK 摘要、未提交源码输入清单、设备 API 和测试步骤，不将测试包称为正式签名包；验收结束后重新构建正常 Debug APK，避免误交付测试入口。

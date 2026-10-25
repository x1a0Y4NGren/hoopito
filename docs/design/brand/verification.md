# C 标识替换验收 · 2026-10-04

在 `codex/hooptrace-v2` 实施，保留版本 `2.0.0+4`。来源与派生见
[品牌记录](README.md)、[ImageGen 提示词及 SHA-256](source.json)与
[资源生成说明](../../../assets/icons/README.md)。

## 本轮检查

| 检查 | 实际结果 |
| --- | --- |
| 生成脚本回归 | 两项 Python unittest 通过；先复现旧映射将黑色改成白色，再验证三色与单色负空间 |
| 平台资源 | 三张 1024px 生产源／主图、Android 传统／自适应／单色五档、iOS 15 张 AppIcon／三张启动图、双语 512px 商店图标生成和校验通过 |
| 视觉核对 | 三色黑色细节、透明背景、单色负空间；32／48／96／192 px，圆形／圆角方形／squircle 与明暗周边已查看，无裁切 |
| 入口行为 | 25 项入口动画测试通过；覆盖新标识全部阶段、居中弹跳、跳过、降级、禁用动画、反馈和生命周期 |
| 入口资源与设置 | 5 项入口资源、17 项设置／反馈测试通过，共 22 项；未重跑未改动的数据与统计测试 |
| 启动 Golden | 五张新参考图逐张查看；首帧增加显式预加载，避免将图片解码前的黑屏误存为参考图；Windows 与 Linux 各 5 项无更新通过 |
| 格式与分析 | 四个受影响 Dart 文件格式 0 改动；全仓 `flutter analyze --no-pub` 无问题 |
| 发行资料 | 双语 Fastlane metadata 校验通过；八张既有实际截图不含旧标识，保留原始来源 |
| Android 实际安装 | API36 x86_64、独立 synthetic user10；MAIN Debug 覆盖安装成功，桌面显示 C；冷启动原始截图显示新标识，进入原有最近比赛首页 |
| 审查与保留 | 独立只读审查未发现待修问题；旧资源／引用／绘制器移除；原 main 27 项文档 SHA-256 保持与同步后记录一致 |

动画阶段视觉由 Golden 覆盖；Android 截图证明实际桌面与启动标识，
不作为完整设备动画帧率或性能验收。单色资源已验证并查看负空间，
本轮没有把生成预览等同于所有系统主题色下的实际桌面验收。

## 命令

```sh
python -m unittest discover -s tool/release/tests -v
python tool/release/generate_launcher_icons.py
python tool/release/generate_entry_assets.py
dart format --output=none --set-exit-if-changed \
  lib/app/entry/hoop_trace_entry_gate.dart \
  test/app/entry_animation_test.dart \
  test/app/entry_animation_golden_test.dart test/app/entry_assets_test.dart
flutter analyze --no-pub
flutter test test/app/entry_animation_test.dart --reporter expanded
flutter test test/app/entry_assets_test.dart \
  test/core/settings/scoring_feedback_test.dart --reporter expanded
flutter test --no-pub test/app/entry_animation_golden_test.dart --reporter expanded
dart --packages=.dart_tool/package_config.json tool/release/validate_metadata.dart
flutter build apk --debug --no-pub
git diff --check
```

Linux 入口 Golden 使用既有 Flutter 3.41.9／Clang 工具链，在独立快照同步
本次入口源码、前景与五张参考图后执行同一测试，没有放宽差异阈值。
Windows `dart run` 会额外触发本机 SQLite/MSVC hook 的编码错误；纯 metadata
脚本使用 CI 相同的直接 Dart 入口后成功，不将该环境错误计为通过。

## 交付与范围

本轮 Debug APK 与日志独立归档于
`D:/DevCache/HoopTraceV2Artifacts/logo-c-20261004/`。
文件名为 `hooptrace-2.0.0+4-cyclops-debug.apk`，其 SHA-256、应用提交、
资源输入与设备截图来源记录在归档 `verification.json` 和 `SHA256SUMS`。
这是测试签名的可安装 Debug 包，版本为 2.0.0／4，minSdk 24、targetSdk 36。

此前 `94bb58e` 的全量测试、API24/36 主流程、两次 unsignedRelease 字节复现
及其 APK 继续作为原检查点证据；本轮不把它们改标为新图标来源。
核心、数据库、统计、权限和离线契约未改动。本轮按界面／资源范围验证，
未重新执行全量、API24 主流程或 unsignedRelease 可复现构建。

iOS 图像资源检查已完成；Windows 无法完成 macOS 无签名编译。
正式签名／同证升级、远端 CI、macOS 编译仍是发行阻断项，尚未发布就绪。

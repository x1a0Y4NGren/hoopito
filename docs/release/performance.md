# Hoopito · 球豆 Performance evidence / 性能证据

Current branding is Hoopito · 球豆. The dated HoopTrace measurements below retain
their original source commits, environments, paths and results; they do not
establish new performance verification after the rename. See
[naming and compatibility](../design/brand/naming-and-compatibility.md).

## Historical candidate / 历史候选（2026-10-03）

Source `94bb58e094736dfeaf42e524e308236de876a059` full-suite query benchmark: history 20 rows
15.464ms, replay 1,009 events 50.827ms; unchanged 500ms gate.
Android command inputs/DB/transaction/provider are unchanged from 3a, verified in
`D:/DevCache/HoopTraceV2Artifacts/94bb58e/verification/reused-inputs.json`.
Retained API 36 explicit SwiftShader/WHPX p95=81.951ms/100, exit 0/100ms gate;
retained same-source host GPU p95=623.61ms/100, exit 1. This is environment
sensitivity evidence, not a uniquely proven cause or cross-device guarantee.
Both original logs and the file I/O diagnostic remain at
`D:/DevCache/HoopTraceV2Artifacts/3a0166c/verification/performance-environment-comparison.json`.
No thresholds, durability settings, sample count or warm-up rule were relaxed.

## Previous checkpoint / 前次记录（3a0166c）

Updated / 更新：2026-10-03。Historical application source:
`3a0166c3a4a510e76a3093142a8b2d559ba7be93`.

The Windows unit/widget suite passed 1,080 tests in 54 seconds and recorded
history_first_page_ms=20.117 and replay_projection_ms=57.86. Its unchanged
1,000-match / 10,000-event fixture retains both 500 ms gates. The log is
`.superpowers/sdd/2026-09-24-hooptrace-v2/final-share-backup-full-suite.log`.

The API 36 command rerun on 2026-10-03 passed: 100 committed samples,
p95 81.951 ms, exit 0 / +1, against the unchanged 100 ms gate. It used the same
real SQLite file fixture, production background executor and five discarded
warm-up commits, with explicit SwiftShader matching the previous emulator
configuration. Log: `build/integration-v2-api36-final/command_performance_test-swiftshader-20261003.log`.

The preceding host-renderer run failed at p95 623.61 ms / 100 samples (exit 1);
its log remains `command_performance_test-resumed-20261003.log` in the same
directory. Product and benchmark inputs were unchanged between those runs.
Emulator logs record host Vulkan/GLES versus explicit SwiftShader. This is
evidence of environment sensitivity, not proof of one exclusive root cause.
The earlier 65.574 ms run remains historical evidence. No threshold was raised,
transaction durability disabled or samples dropped to obtain a pass. These are
local emulator debug measurements, not physical-device or cross-runner claims.

中文：主机全量 1,080 项通过；历史首屏 20.117ms、复盘投影 57.86ms，500ms
门槛保持。API 36 恢复原 SwiftShader 条件后，100 样本 p95 81.951ms、退出 0，
通过未改动的 100ms 门槛。之前宿主 GPU 条件下的 623.61ms 失败完整保留；
两次产品与测试输入一致，不能将渲染后端差异推断为唯一根因，也不外推为实体
设备或跨 runner 性能。独立文件写入探针同步写 p95 2.2507ms，仅用于排查。
比较测试在息屏后唤醒完成，166 秒不是性能基线；三项主流程/文件恢复/比较
各自 +1，最初 quota/主机停止中断的运行没有结果，不能计为通过或产品失败。

The immutable MAIN Debug was rebuilt after the integration runner in 29.9 s;
its complete SHA-256 still equals the accepted APK. Native backup, sharing,
screenshots and API 24 checks are recorded separately and add no benchmark
samples. The due metadata fixture proves one real headless write, not natural
24-hour scheduling; later completion backups are foreground callbacks.

## Deterministic query fixture / 确定性查询夹具

`test/performance/task15_query_benchmarks_test.dart` creates exactly 1,000
finished matches, 2,000 participants, and 10,000 events. It measures a bounded
20-row history first page and a 1,009-event replay load plus analytics mapping.
Both hard-fail at 500 ms.

该测试精确生成 1,000 场比赛、2,000 名对局参与者和 10,000 条事件，测量 20 条
历史首屏以及包含 1,009 条事件的复盘加载/分析映射；任一达到 500ms 即失败。

Final controller run on 2026-08-24 (Windows 11, Flutter 3.41.9, in-memory
SQLite, debug test process): history first page 17.062 ms; replay projection
51.819 ms. CI logs every run with the `TASK15_QUERY_BENCHMARK` marker. These are
regression measurements, not cross-device marketing claims.

2026-08-24 主控环境参考值（Windows 11、Flutter 3.41.9、内存 SQLite、debug
测试进程）：历史首屏 17.062ms，复盘投影 51.819ms。CI 通过
`TASK15_QUERY_BENCHMARK` 输出每次结果；这些仅用于回归，不用于跨设备宣传。

## Android command benchmark / Android 命令基准

`integration_test/command_performance_test.dart` starts a real command-backed
match through `openAppDatabaseAt` and Drift's production background executor in
a temporary file, discards five warm-up writes, times 100 committed event
commands, sorts the samples, and hard-fails when p95 reaches 100 ms. The
temporary directory is removed after the database closes. The CI reference is
an Android API 36 Pixel 6 x86_64 emulator with animations disabled, running the
Flutter integration-test debug process. Results are logged with
`TASK15_COMMAND_BENCHMARK`.

Final API 36 emulator verification on 2026-08-24 recorded p95 80.061 ms for
100 samples, below the 100 ms gate.

该集成测试启动真实命令层比赛，丢弃 5 次预热，测量 100 次已提交事件命令并计算
p95；达到 100ms 即失败。CI 参考设备为关闭动画的 Android API 36 Pixel 6
x86_64 模拟器，运行 Flutter integration-test debug 进程，日志标记为
`TASK15_COMMAND_BENCHMARK`。

2026-08-24 的 API 36 模拟器最终验证记录为 100 个样本、p95 80.061ms，低于
100ms 门槛。

Run locally with:

```bash
flutter test test/performance/task15_query_benchmarks_test.dart --reporter expanded
flutter test integration_test/command_performance_test.dart -d <android-device-id>
```

Record real-device results separately with model, SoC, Android/API, build mode,
thermal state, available storage, commit, and sample count. Never replace the
CI threshold using a faster unrecorded machine.

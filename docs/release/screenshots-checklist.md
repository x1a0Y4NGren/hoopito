# Hoopito · 球豆 screenshot checklist / 截图清单

Current branding is Hoopito · 球豆. The recorded 2.0 captures below remain original
HoopTrace images with their original provenance. Capture the current branded APK
for a future release; do not relabel old captures as new UI evidence. See
[naming and compatibility](../design/brand/naming-and-compatibility.md).

Screenshots are release metadata and visual evidence; they do not replace flow,
persistence or platform tests. Use synthetic player names and inspect every
selected release image at full resolution before committing it.

截图属于发行元数据与视觉证据，不能代替流程、持久化或平台测试。只能使用虚构
球员名称，提交前必须逐张按原始分辨率检查选中的发行图。

Updated / 更新：2026-10-03。The checkboxes below describe the recorded capture
and inspection scope, not every route × locale × theme combination or release
readiness. 勾选仅表示下述实际采集与检查范围，不代表全部页面、语言、主题组合
均验收，也不表示发布就绪。

## Required matrix / 必需矩阵

- [x] Simplified Chinese and English in the selected release images.
- [x] Warm light and charcoal dark themes in the inspected captures.
- [x] Match/home recovery, compact pregame with recording scope, unified scoring,
      result summary, history list, player growth and backup settings in the
      inspected captures.
- [x] Supplementary applied history filter and safety-copy page captured and
      inspected at source 3a; their inputs are unchanged. Replay/analytics and
      Chinese/English 200% were recaptured and inspected at the revised source.
      Each file retains its actual source/APK metadata; this is the stated scope.
- [x] Compact phone landscape scoring at 1920×1080 / density 420.
- [x] Large emulator portrait and landscape windows at 1800×2560 and 2560×1800.
- [ ] Physical foldable hardware, hinge and posture behavior. Emulator window
      overrides establish only the recorded viewport conditions.
- [x] Inspected critical pregame/scoring layouts at 200% text scale without
      clipping or overflow; app reduced motion and separate Android animation
      scales set to zero are recorded independently.
- [x] Android 16 edge-to-edge in the inspected images, with content clear of
      retained system bars.

## Privacy and fidelity / 隐私与真实性

- [x] No real names, notes, file paths, notifications, account identifiers,
      serial numbers, or other app content in the system recents/background.
      This check applies to the eight selected release images.
- [x] System bars are intentionally retained in the original PNGs; no cropping
      or painting over data.
- [x] Actual installed MAIN Debug UI from the recorded candidate source; no
      mock rendering. The candidate is not a signed production release.
- [x] Captured scores and recording scope agree with each identified synthetic
      match and its capture-time lifecycle. Different match IDs remain distinct.
- [x] Locale-specific screenshots are stored under the matching Fastlane path.
- [x] Selected PNG dimensions and aspect ratios match the original captures.
- [ ] Confirm final production icon/assets as part of the remaining release
      metadata and signing checks.

## Capture record / 拍摄记录

For each final image record commit, build type, emulator/device, API, viewport,
locale, theme, text scale, route/state, and source test fixture. Re-capture after
any visible 2.0 candidate change. Keep widget Goldens and real Android captures
identified separately; neither a prior release image nor a test fixture alone
proves the final installed APK flow.

The final capture index has 25 original PNGs with metadata and matching file
hashes: `D:/DevCache/HoopTraceV2NativeAcceptance/evidence-api36/final-capture-index.json`.
All refer to source `3a0166c3a4a510e76a3093142a8b2d559ba7be93`, the API 36
Pixel x86_64 emulator, synthetic Android user 10 and MAIN Debug APK SHA-256
`6e08827d8a9f2dc1d30d0d1e54b66e3f4950d720bcad831c63a57d36e62d4cda`.
The release selection is eight images, inspected at original resolution and
copied without changes. Each target hash equals the source and the
[repository provenance record](v2.0.0-screenshots.json).

| Locale / 语言 | Fastlane selection / 选图 | Theme / 主题 |
| --- | --- | --- |
| zh-CN | `1-home.png`, `2-scoring.png`, `3-summary.png`, `4-history.png` | Light home/summary/history; dark scoring |
| en-US | `1-home.png`, `2-scoring.png`, `3-summary.png`, `4-history.png` | Dark |

The inspected supplementary scope includes EN scoring and ZH pregame at 200%,
ZH large-window scoring/summary, backup settings and EN career/statistics.
The Chinese light scoring capture with a temporary Snackbar was excluded from
the release selection. Collection is not a blanket claim that all 25 images
were visually accepted.

最终 25 图的文件 SHA、metadata 源码与 APK 来源均已核对；主任务按原始分辨率
检查并选用 8 张发行图，以及上述大字体、大窗口、备份和生涯补充图。三场虚构
比赛分别为 8:11（shotAttempts）、2:3（scoresOnly）、8:11（scoresOnly），
索引保留截图当时 active/finished，不用最后全部 finished 倒推早期计分画面。
图片原样复制，两语言旧 `3-replay.png` 已由 `3-summary.png` 替换。

The independent evidence archive is
`D:/DevCache/HoopTraceV2Artifacts/3a0166c/verification/native-api36/`;
`FILES.json` records copied-file sizes and SHA-256. Natural 24-hour scheduling,
a WorkManager run under a revoked grant, physical foldable hardware and
cross-runner reproduction remain unverified. The [candidate record](v2.0.0-candidate.md)
keeps these limits separate from visual acceptance and the remaining formal
signing, same-certificate upgrade, remote CI and macOS iOS gates.

Latest Replay correction: source `94bb58e094736dfeaf42e524e308236de876a059`, MAIN Debug SHA-256
`60d17a1179099c41a3fc12691edd15793ad4b1cf823a9d9fcb09a97edd088edd`. Raw PNG/XML/metadata and visual review are in
`D:/DevCache/HoopTraceV2Artifacts/94bb58e/verification/supplemental-api36/`.
Overview reads 13% · 1/8 for the same 8:11 fixture; Chinese/English 200% analytics,
lazy scoring flow (including its end) and key possessions were inspected.
The English portrait stays one column; before-fix 3c images are issue evidence.
The eight unchanged Fastlane pages retain their truthful 3a source above.

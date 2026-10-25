# Reproducible Android builds / Android 可复现构建

## Contract / 约定

Hoopito's reproducibility gate compares two unsigned release APKs produced on
one clean CI runner from the same committed source, lockfile, Flutter revision,
Temurin Java version, Android SDK/build-tools/NDK, vendored SQLite amalgamation,
and `SOURCE_DATE_EPOCH`. Each build starts from a fresh `git archive`; the two
archives are built sequentially at the fixed
`/tmp/hoopito-reproducible-source` path because pinned Flutter 3.41.9 embeds
its build path in Dart and native libraries. A passing `cmp` proves the complete
APKs are byte-identical before upstream signing. Cross-runner or cross-OS
reproducibility is a separate comparison using the recorded toolchain files.

Hoopito · 球豆的可复现性门槛会固定源码提交、锁文件、Flutter revision、Java、
Android SDK/build-tools/NDK、仓库内 SQLite amalgamation 与 `SOURCE_DATE_EPOCH`，
在同一干净 CI runner 上从两份全新的 `git archive` 顺序构建未签名 APK。由于
固定的 Flutter 3.41.9 会把构建路径写入 Dart 与原生库，两次构建均使用固定的
`/tmp/hoopito-reproducible-source`；只有完整 APK 逐字节完全一致才通过。
跨 runner 或跨操作系统的结论必须使用输出中的工具链记录另行比较。

Current tooling uses `HOOPITO_ALLOW_UNSIGNED_RELEASE` and the Linux workspace
override `HOOPITO_REPRODUCIBLE_ROOT`. Earlier HoopTrace build paths, hashes and
protocols remain historical evidence; changing the canonical path requires a new
comparison and does not establish equality with a previously released APK. See
[naming and compatibility](../design/brand/naming-and-compatibility.md).

```bash
bash tool/release/verify_unsigned_reproducible_android.sh
sha256sum -c build/reproducible/SHA256SUMS
```

On Windows, use the PowerShell counterpart from a clean committed checkout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/release/verify_unsigned_reproducible_android.ps1 `
  -WorkspaceRoot D:\Hoopito-Reproducibility `
  -AndroidSdkRoot D:\Android\Sdk `
  -JavaHome "C:\path\to\jdk-17.0.20+8"
```

Replace the example `JavaHome` with the installed Temurin 17.0.20+8 directory.

It exports two fresh `git archive` snapshots and builds them sequentially at
`D:\Hoopito-Reproducibility\hoopito-reproducible-source`. The named workspace
must be on D:, outside the checkout and toolchains; the canonical source leaf
must not exist before invocation. Cleanup requires the exact resolved path and
this invocation's ownership marker, and refuses junctions or other reparse
points. Before and after each build, `flutter config --machine` records the Java
and Android SDK that Flutter actually selected; both must match the supplied
paths. Android Studio's bundled JDK can take precedence over `JAVA_HOME`, so an
unset `jdk-dir` alone is insufficient evidence of the Java selection.
Neither snapshot may contain `android/key.properties`; unsigned mode exists
only in the verifier's temporary process environment. The official signed
release command and its signing checks are unchanged.
The verifier also scopes Gradle to a single-use JVM and restores the caller's
`GRADLE_OPTS` afterward. This lets the JVM release mapped R8 intermediates before
the owned first source tree is removed on Windows; no shared daemon is stopped.

If the effective Java differs, prepare a task-specific configuration outside
the project, then scope `APPDATA` to that directory for the invocation. For
example, an operator-prepared
`D:\Hoopito-Reproducibility\flutter-config\.flutter_settings` can contain:

```json
{
  "jdk-dir": "C:\\path\\to\\jdk-17.0.20+8",
  "android-sdk": "D:\\Android\\Sdk"
}
```

```powershell
$reproPreviousAppData = $env:APPDATA
try {
  $env:APPDATA = "D:\Hoopito-Reproducibility\flutter-config"
  & .\tool\release\verify_unsigned_reproducible_android.ps1 `
    -WorkspaceRoot D:\Hoopito-Reproducibility `
    -AndroidSdkRoot D:\Android\Sdk `
    -JavaHome "C:\path\to\jdk-17.0.20+8"
} finally { $env:APPDATA = $reproPreviousAppData }
```

Use the same actual JDK path in the prepared settings and `-JavaHome`. The
verifier only reads Flutter configuration and records the scoped configuration
path; it does not alter the user's global settings.

Each invocation retains both complete APKs, their SHA-256 values, source archive
hashes, build logs, signature inspection, protocol and before/after toolchain
records under an ignored `build/reproducible/windows-<timestamp>-<id>` directory.
A successful complete byte comparison adds `app-release.apk` and records
`apkComparison=byte-identical` in `REPRODUCIBILITY.txt`. Failures retain evidence
and return nonzero. Windows evidence establishes reproducibility within that
one invocation; it does not establish equality with the Linux CI APK.

Windows 下使用 PowerShell 脚本，两份全新源码快照顺序在同一个外部 D 盘目录构建。
脚本拒绝已有源码目录、非本次拥有的目录和 junction/reparse point，固定工具链并
核对锁文件，完整逐字节比较未签名 APK。每次调用的源码、哈希、日志与工具链记录
保留在忽略的 `build/reproducible/windows-<timestamp>-<id>`；只有
`apkComparison=byte-identical` 表示本次比较通过，不代表跨 Windows/Linux 复现。
脚本在当前进程中关闭 Gradle 常驻 daemon，等待单次构建的 JVM 退出释放 R8
中间文件后再删除自己的源码目录，并恢复原 `GRADLE_OPTS`；不停止共享 daemon。

The path, cleanup, native command recording and whole-file comparison helpers
can be checked without a Flutter build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test/tool/release/verify_unsigned_reproducible_android_test.ps1
```

The native SQLite hook is configured with `source: source` and the checked-in
`third_party/sqlite/sqlite3.c` amalgamation (SQLite 3.53.4, SHA-256
`b1dd5d74ec7f29055a6684fa06fb3c2f6821c87dd38f9a458dfd2e8a1db28189`). A clean
build therefore does not fetch a `sqlite3` GitHub release binary. The matching
`sqlite3.h`, public-domain notice, and official archive URL live beside it.

原生 SQLite hook 使用 `source: source`，从仓库内固定的
`third_party/sqlite/sqlite3.c`（SQLite 3.53.4，SHA-256 如上）编译；干净构建不再
下载 `sqlite3` GitHub Release 原生库。对应的 `sqlite3.h`、公有领域声明和官方
源码归档 URL 与其放在同一目录。

CI runs this from two fresh `git archive` exports, deleting and recreating the
fixed build root between runs, and publishes the verified unsigned artifact
with `PUBSPEC_LOCK_SHA256`,
`RUNNER_IDENTITY.txt`, `REPRODUCIBILITY.txt`, and the toolchain snapshots. The
script re-hashes `pubspec.lock` after each locked dependency resolution and
checks the runner fingerprint before each build; `sameRunner=true` therefore
describes this single invocation only. The artifact is evidence, not an install
channel and not an official signed release.

CI 会在同一 runner 上顺序解包两份全新的 `git archive`，每次构建间删除并重建
固定构建根目录，并随产物保存锁文件哈希、runner 身份、复现结论和工具链快照；
脚本会在每次锁定依赖解析后重新计算 `pubspec.lock`，并在每次构建前核对 runner
指纹。`sameRunner=true`
只表示这一次脚本调用，不代表跨 runner 复现。产物只是短期证据，不是安装渠道，
也不是正式签名发行包。

The pinned release toolchain is Flutter 3.41.9 at framework revision
`00b0c91f06209d9e4a41f71b7a512d6eb3b9c694`, Temurin 17.0.20+8,
compile/target SDK 36, Android build-tools 36.1.0, NDK 28.2.13676358,
AGP 8.11.1, and Gradle 8.14. The wrapper JAR is checked against
`7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172`; the
distribution is checked against
`efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1`. The
output records Flutter, Java, Android, wrapper, commit, and epoch details beside
the APK hash.

固定发行工具链为 Flutter 3.41.9（framework revision 如上）、Temurin
17.0.20+8、compile/target SDK 36、Android build-tools 36.1.0、NDK
28.2.13676358、AGP 8.11.1 与 Gradle 8.14；wrapper JAR SHA-256 为
`7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172`，发行包
Gradle distribution SHA-256 为
`efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1`；脚本会把
工具链、wrapper、提交与 epoch 记录在 APK 哈希旁。

## Signed APK comparison / 签名 APK 对比

Android signing changes the archive. For F-Droid upstream-binary verification:

1. Rebuild the unsigned APK from the public tag in the documented toolchain.
2. Obtain the published signed APK and certificate fingerprint.
3. Use current F-Droid verification tooling to remove/normalize the signature
   layer and compare the unsigned payload; use `diffoscope` when it differs.
4. Record tag, commit, toolchain image/digests, SHA-256 values, certificate, and
   comparison result in the release record.
5. Never copy the upstream keystore into fdroiddata or CI.

Android 签名会改变归档。F-Droid 上游二进制验证应从公开 tag 重建未签名包，
核对公开 APK 与证书，用 F-Droid 当前验证工具归一化签名层后比较；有差异时使用
`diffoscope`。发布记录必须保存 tag、commit、工具链、哈希、证书与比较结果，
且绝不能把上游 keystore 放入 fdroiddata 或 CI。

## Known sources of drift / 常见差异来源

- a different Flutter engine, Android build-tools, NDK, Java, or Gradle cache;
- a changed `pubspec.lock` or generated Drift/l10n output;
- a changed `third_party/sqlite/sqlite3.c` or `sqlite3.h` amalgamation;
- absolute build paths embedded by native tooling;
- source-tree timestamps or VCS metadata;
- non-clean generated plugin registrants left by integration tests.

The release command intentionally does not pass `--no-pub`. Flutter uses that
release-mode dependency-injection pass to regenerate the ignored Android plugin
registrant without dev-only `integration_test`, while retaining the runtime
plugins. Dependency versions remain pinned by the preceding
`flutter pub get --enforce-lockfile` step.

发行命令有意不传 `--no-pub`，因为 Flutter 需要在 release 模式重新生成排除
`integration_test` 的插件注册文件；依赖版本仍由前一步
`flutter pub get --enforce-lockfile` 锁定。

When comparison fails, keep both APKs, run `zipinfo -v`, compare decompressed
trees, then use `diffoscope`. Fix the source of nondeterminism; never weaken the
gate to compare only selected files.

比较失败时应保留两份 APK，依次检查 `zipinfo -v`、解压目录和 `diffoscope`。
必须消除不确定来源，不能把门槛降级为只比较部分文件。

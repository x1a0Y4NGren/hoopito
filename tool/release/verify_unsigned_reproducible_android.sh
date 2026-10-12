#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
expected_flutter_version="3.41.9"
expected_flutter_revision="00b0c91f06209d9e4a41f71b7a512d6eb3b9c694"
expected_java_version="17.0.20+8"
expected_compile_sdk="36"
expected_target_sdk="36"
expected_build_tools="36.1.0"
expected_ndk="28.2.13676358"

if ! git -C "$repo_root" diff --quiet; then
  echo "The reproducibility source tree has unstaged changes." >&2
  exit 2
fi
if ! git -C "$repo_root" diff --cached --quiet; then
  echo "The reproducibility source tree has staged changes." >&2
  exit 2
fi
if [[ -n "$(git -C "$repo_root" status --porcelain=v1 --untracked-files=all)" ]]; then
  echo "Commit all source and metadata changes before reproducibility verification." >&2
  exit 2
fi

lock_file="$repo_root/pubspec.lock"
if ! git -C "$repo_root" ls-files --error-unmatch -- pubspec.lock >/dev/null 2>&1; then
  echo "pubspec.lock must be tracked before reproducibility verification." >&2
  exit 2
fi
if [[ ! -s "$lock_file" ]]; then
  echo "pubspec.lock is missing or empty." >&2
  exit 2
fi
lock_sha256="$(sha256sum "$lock_file" | awk '{print $1}')"
source_date_epoch="$(git -C "$repo_root" show -s --format=%ct HEAD)"
if [[ ! "$source_date_epoch" =~ ^[0-9]+$ ]]; then
  echo "Unable to derive a numeric SOURCE_DATE_EPOCH from HEAD." >&2
  exit 2
fi

android_sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$android_sdk_root" ]]; then
  echo "ANDROID_SDK_ROOT (or ANDROID_HOME) must be set." >&2
  exit 2
fi
export ANDROID_SDK_ROOT="$android_sdk_root"

# This gate is intentionally run once on the host before either build. The
# per-build snapshots below then prove that both source trees used the same
# runner and unchanged toolchain.
bash "$repo_root/tool/release/prepare_android_toolchain.sh"

scratch="$(mktemp -d)"
# Flutter 3.41.9 embeds the absolute URI of its generated Dart plugin
# registrant in libapp.so, and native plugin build IDs also include their build
# directory. Build both clean archives sequentially at one documented path so
# those otherwise-unavoidable toolchain inputs are identical.
canonical_source="${HOOPITO_REPRODUCIBLE_ROOT:-/tmp/hoopito-reproducible-source}"
canonical_name="$(basename "$canonical_source")"
if [[ "$canonical_source" != /* ]]; then
  echo "HOOPITO_REPRODUCIBLE_ROOT must be an absolute path." >&2
  exit 2
fi
if [[ "$canonical_name" != "hoopito-reproducible-source" ]]; then
  echo "HOOPITO_REPRODUCIBLE_ROOT must end in hoopito-reproducible-source." >&2
  exit 2
fi
if [[ -e "$canonical_source" ]]; then
  echo "The canonical reproducibility workspace already exists: $canonical_source" >&2
  exit 2
fi
owns_canonical=false
cleanup() {
  if [[ "$owns_canonical" == true && -e "$canonical_source" ]]; then
    rm -rf -- "$canonical_source"
  fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT
reference_toolchain="$scratch/reference-toolchain"
mkdir -p "$reference_toolchain"

runner_os="$(uname -s)"
runner_arch="$(uname -m)"
runner_host="$(hostname)"
runner_name="${RUNNER_NAME:-local}"
runner_id="${GITHUB_RUN_ID:-local}"
runner_attempt="${GITHUB_RUN_ATTEMPT:-local}"
runner_fingerprint="$runner_os|$runner_arch|$runner_host|$runner_name|$runner_id|$runner_attempt"

flutter --version --machine > "$reference_toolchain/FLUTTER_TOOLCHAIN.json"
if ! grep -Fq "\"frameworkVersion\": \"$expected_flutter_version\"" \
    "$reference_toolchain/FLUTTER_TOOLCHAIN.json" || \
   ! grep -Fq "\"frameworkRevision\": \"$expected_flutter_revision\"" \
    "$reference_toolchain/FLUTTER_TOOLCHAIN.json"; then
  echo "Flutter $expected_flutter_version at revision $expected_flutter_revision is required." >&2
  exit 2
fi

java -version > "$reference_toolchain/JAVA_TOOLCHAIN.txt" 2>&1
if ! grep -Fq "$expected_java_version" "$reference_toolchain/JAVA_TOOLCHAIN.txt"; then
  echo "Java $expected_java_version is required." >&2
  cat "$reference_toolchain/JAVA_TOOLCHAIN.txt" >&2
  exit 2
fi
if ! grep -Eq 'Temurin|Eclipse Adoptium' "$reference_toolchain/JAVA_TOOLCHAIN.txt"; then
  echo "Temurin Java is required for reproducibility verification." >&2
  cat "$reference_toolchain/JAVA_TOOLCHAIN.txt" >&2
  exit 2
fi

android_sdk_real="$(cd "$ANDROID_SDK_ROOT" && pwd -P)"
for component in \
  "platforms/android-$expected_compile_sdk" \
  "build-tools/$expected_build_tools" \
  "ndk/$expected_ndk"; do
  if [[ ! -d "$android_sdk_real/$component" ]]; then
    echo "Pinned Android SDK component is missing: $component" >&2
    exit 2
  fi
done

wrapper_sha256="$(sha256sum "$repo_root/android/gradle/wrapper/gradle-wrapper.jar" | awk '{print $1}')"
if [[ "$wrapper_sha256" != "7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172" ]]; then
  echo "Gradle wrapper SHA-256 mismatch: $wrapper_sha256" >&2
  exit 2
fi
if ! grep -Fq \
  'distributionSha256Sum=efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1' \
  "$repo_root/android/gradle/wrapper/gradle-wrapper.properties"; then
  echo "Gradle wrapper distribution checksum is missing or incorrect." >&2
  exit 2
fi

cat > "$reference_toolchain/ANDROID_TOOLCHAIN.txt" <<EOF
compileSdk=$expected_compile_sdk
targetSdk=$expected_target_sdk
buildTools=$expected_build_tools
ndk=$expected_ndk
sdkRoot=$android_sdk_real
gradleVersion=8.14
gradleWrapperSha256=$wrapper_sha256
gradleDistributionSha256=efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1
EOF

printf '%s\n' "$runner_fingerprint" > "$reference_toolchain/RUNNER_IDENTITY.txt"
printf '%s\n' "$lock_sha256" > "$reference_toolchain/PUBSPEC_LOCK_SHA256"

capture_build_toolchain() {
  local destination="$1"
  local current_fingerprint
  current_fingerprint="$(uname -s)|$(uname -m)|$(hostname)|${RUNNER_NAME:-local}|${GITHUB_RUN_ID:-local}|${GITHUB_RUN_ATTEMPT:-local}"
  if [[ "$current_fingerprint" != "$runner_fingerprint" ]]; then
    echo "The two APKs were not built on the same runner." >&2
    return 1
  fi
  mkdir -p "$destination"
  flutter --version --machine > "$destination/FLUTTER_TOOLCHAIN.json"
  java -version > "$destination/JAVA_TOOLCHAIN.txt" 2>&1
  cp "$reference_toolchain/ANDROID_TOOLCHAIN.txt" "$destination/ANDROID_TOOLCHAIN.txt"
  printf '%s\n' "$runner_fingerprint" > "$destination/RUNNER_IDENTITY.txt"
  printf '%s\n' "$lock_sha256" > "$destination/PUBSPEC_LOCK_SHA256"
  for name in FLUTTER_TOOLCHAIN.json JAVA_TOOLCHAIN.txt ANDROID_TOOLCHAIN.txt RUNNER_IDENTITY.txt; do
    if ! cmp --silent "$reference_toolchain/$name" "$destination/$name"; then
      echo "Toolchain changed between the two builds: $name" >&2
      return 1
    fi
  done
}

assert_lock_unchanged() {
  local source="$1"
  local actual
  actual="$(sha256sum "$source/pubspec.lock" | awk '{print $1}')"
  if [[ "$actual" != "$lock_sha256" ]]; then
    echo "flutter pub get changed the committed pubspec.lock in $source." >&2
    echo "expected=$lock_sha256 actual=$actual" >&2
    return 1
  fi
}

build_once() {
  local label="$1"
  local apk_destination="$2"
  mkdir -p "$canonical_source"
  owns_canonical=true
  git -C "$repo_root" archive --format=tar HEAD | tar -xf - -C "$canonical_source"
  capture_build_toolchain "$scratch/toolchain-$label"
  assert_lock_unchanged "$canonical_source"
  (
    cd "$canonical_source"
    export SOURCE_DATE_EPOCH="$source_date_epoch"
    flutter pub get --enforce-lockfile
    assert_lock_unchanged "$canonical_source"
    dart --packages=.dart_tool/package_config.json tool/release/verify_sqlite_source.dart
    # Do not use --no-pub here. Flutter's release-mode dependency injection
    # regenerates GeneratedPluginRegistrant without dev-only plugins.
    HOOPITO_ALLOW_UNSIGNED_RELEASE=true \
      flutter build apk --release
  )
  local built_apk="$canonical_source/build/app/outputs/flutter-apk/app-release.apk"
  test -s "$built_apk"
  assert_lock_unchanged "$canonical_source"
  cp "$built_apk" "$apk_destination"
  rm -rf -- "$canonical_source"
  owns_canonical=false
}

apk_a="$scratch/app-release-a.apk"
apk_b="$scratch/app-release-b.apk"
build_once "a" "$apk_a"
build_once "b" "$apk_b"

if ! cmp --silent "$apk_a" "$apk_b"; then
  sha256sum "$apk_a" "$apk_b"
  diagnostics="$repo_root/build/reproducible-diagnostics"
  rm -rf "$diagnostics"
  mkdir -p "$diagnostics/unpacked-a" "$diagnostics/unpacked-b"
  cp "$apk_a" "$diagnostics/app-release-a.apk"
  cp "$apk_b" "$diagnostics/app-release-b.apk"
  unzip -q "$apk_a" -d "$diagnostics/unpacked-a"
  unzip -q "$apk_b" -d "$diagnostics/unpacked-b"
  (
    cd "$diagnostics/unpacked-a"
    find . -type f -print0 | sort -z | xargs -0 sha256sum
  ) > "$diagnostics/entries-a.sha256"
  (
    cd "$diagnostics/unpacked-b"
    find . -type f -print0 | sort -z | xargs -0 sha256sum
  ) > "$diagnostics/entries-b.sha256"
  diff -u \
    "$diagnostics/entries-a.sha256" \
    "$diagnostics/entries-b.sha256" \
    > "$diagnostics/entry-diff.txt" || true
  rm -rf "$diagnostics/unpacked-a" "$diagnostics/unpacked-b"
  echo "Unsigned release APKs differ between clean source builds." >&2
  echo "Diagnostics written to $diagnostics." >&2
  exit 1
fi

output="$repo_root/build/reproducible"
mkdir -p "$output"
cp "$apk_a" "$output/app-release.apk"
cp "$reference_toolchain/FLUTTER_TOOLCHAIN.json" "$output/FLUTTER_TOOLCHAIN.json"
cp "$reference_toolchain/JAVA_TOOLCHAIN.txt" "$output/JAVA_TOOLCHAIN.txt"
cp "$reference_toolchain/ANDROID_TOOLCHAIN.txt" "$output/ANDROID_TOOLCHAIN.txt"
cat > "$output/RUNNER_IDENTITY.txt" <<EOF
sameRunner=true
os=$runner_os
arch=$runner_arch
hostname=$runner_host
runnerName=$runner_name
runId=$runner_id
runAttempt=$runner_attempt
fingerprint=$runner_fingerprint
EOF
cat > "$output/REPRODUCIBILITY.txt" <<EOF
commit=$(git -C "$repo_root" rev-parse HEAD)
sourceDateEpoch=$source_date_epoch
pubspecLockSha256=$lock_sha256
canonicalBuildRoot=$canonical_source
apkComparison=byte-identical
sameRunner=true
EOF
(
  cd "$output"
  sha256sum app-release.apk > SHA256SUMS
)
echo "Reproducible unsigned APK: $(cat "$output/SHA256SUMS")"

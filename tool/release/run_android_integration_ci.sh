#!/usr/bin/env bash
set -euo pipefail

# android-emulator-runner starts a new shell for each script input line.
# Keep branching and failure propagation in this one Bash invocation.
if [[ "$#" != 1 ]]; then
  echo 'Usage: run_android_integration_ci.sh <24|36>' >&2
  exit 2
fi
api_level="$1"
case "$api_level" in
  24|36) ;;
  *) echo "Unsupported CI Android API level: $api_level" >&2; exit 2 ;;
esac
device="${ANDROID_SERIAL:-emulator-5554}"

if [[ "$api_level" == 24 && "${GITHUB_ACTIONS:-}" == true ]]; then
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  adb="$sdk/platform-tools/adb"
  if [[ "$sdk" != /* || ! -x "$adb" ]]; then
    echo "Android SDK adb is unavailable at $adb" >&2
    exit 1
  fi

  # Flutter invokes the SDK's absolute adb path. Stage the shim beside it so
  # both renames are atomic and the original binary keeps its library paths.
  staged="$(mktemp "$adb.hoopito.XXXXXXXX")"
  export HOOPITO_CI_ADB_ORIGINAL="$staged.original"
  export HOOPITO_CI_ADB_LOG="$staged.log"
  export HOOPITO_CI_ADB_FAILED_FALLBACK="$staged.failed"
  export HOOPITO_CI_ADB_DEVICE="$device"

  restore_adb() {
    local result=$?
    if [[ -e "$HOOPITO_CI_ADB_ORIGINAL" || -L "$HOOPITO_CI_ADB_ORIGINAL" ]]; then
      if ! mv -f -- "$HOOPITO_CI_ADB_ORIGINAL" "$adb"; then
        echo "Could not restore Android SDK adb from $HOOPITO_CI_ADB_ORIGINAL" >&2
        if [[ "$result" == 0 ]]; then result=1; fi
      fi
    fi
    if [[ -f "$HOOPITO_CI_ADB_LOG" ]]; then
      cat -- "$HOOPITO_CI_ADB_LOG" >&2 || true
    fi
    if [[ "$result" == 0 && -f "$HOOPITO_CI_ADB_FAILED_FALLBACK" ]]; then
      result="$(cat -- "$HOOPITO_CI_ADB_FAILED_FALLBACK")"
    fi
    rm -f -- "$staged" "$HOOPITO_CI_ADB_LOG" "$HOOPITO_CI_ADB_FAILED_FALLBACK" || true
    exit "$result"
  }
  trap restore_adb EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  install -m 0755 "$(dirname -- "${BASH_SOURCE[0]}")/ci_android_adb.py" "$staged"
  mv -- "$adb" "$HOOPITO_CI_ADB_ORIGINAL"
  mv -- "$staged" "$adb"
fi

flutter test integration_test/main_loop_test.dart -d "$device"
flutter test integration_test/v2_file_recovery_test.dart -d "$device"
flutter test integration_test/continuous_series_test.dart -d "$device"
if [[ "$api_level" == 36 ]]; then
  flutter test integration_test/player_comparison_flow_test.dart -d "$device"
  flutter test integration_test/command_performance_test.dart -d "$device"
fi

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

flutter test integration_test/main_loop_test.dart -d "$device"
flutter test integration_test/v2_file_recovery_test.dart -d "$device"
if [[ "$api_level" == 36 ]]; then
  flutter test integration_test/player_comparison_flow_test.dart -d "$device"
  flutter test integration_test/command_performance_test.dart -d "$device"
fi

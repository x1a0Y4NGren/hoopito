"""Exercise the emulator action's per-line invocation with a fake Flutter CLI."""

import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def action_script():
    lines = (ROOT / '.github/workflows/flutter-ci.yml').read_text().splitlines()
    start = next(i for i, line in enumerate(lines) if 'uses: ReactiveCircus/android-emulator-runner@' in line)
    index = next(i for i in range(start, len(lines)) if lines[i].lstrip().startswith('script:'))
    value = lines[index].split('script:', 1)[1].strip()
    if value != '|':
        return value
    indent = len(lines[index]) - len(lines[index].lstrip())
    content = []
    for line in lines[index + 1:]:
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        content.append(line[indent + 2:])
    return '\n'.join(content)


@unittest.skipUnless(os.name == 'posix' and shutil.which('bash'), 'Requires a POSIX Bash; run in Linux/WSL')
class AndroidIntegrationCiTest(unittest.TestCase):
    def run_action(self, api_level, fail_target=None, device=None, *, adb_status=0,
                   sdk_root=False, ci=True, adb_symlink=False):
        with tempfile.TemporaryDirectory(prefix='hoopito-ci-shell-') as temporary:
            path = Path(temporary)
            calls = path / 'calls.txt'
            adb = path / 'sdk' / 'platform-tools' / 'adb'
            adb.parent.mkdir(parents=True)
            original = '#!/usr/bin/env bash\nprintf "original adb\\n"\nexit "$CI_TEST_ADB_STATUS"\n'
            native_adb = adb.with_name('adb-real') if adb_symlink else adb
            native_adb.write_text(original)
            native_adb.chmod(0o755)
            if adb_symlink:
                adb.symlink_to(native_adb.name)
            path_adb = path / 'adb'
            path_adb.write_text('#!/usr/bin/env bash\necho "PATH adb was selected" >&2\nexit 99\n')
            path_adb.chmod(0o755)
            fake_flutter = path / 'flutter'
            fake_flutter.write_text(
                '#!/usr/bin/env bash\n'
                'printf "%s\\n" "$*" >> "$CI_TEST_CALLS"\n'
                'if [[ -n "${CI_TEST_FAIL_TARGET:-}" && "$2" == "$CI_TEST_FAIL_TARGET" ]]; then exit 42; fi\n'
                'if [[ -n "${HOOPITO_CI_ADB_ORIGINAL:-}" ]]; then echo "adb guard active"; fi\n'
                '"${ANDROID_HOME:-$ANDROID_SDK_ROOT}/platform-tools/adb" -s "$4" install -t -r "a file.apk"\n'
            )
            fake_flutter.chmod(0o755)
            environment = {**os.environ, 'PATH': f'{path}:{os.environ["PATH"]}',
                           'CI_TEST_CALLS': str(calls), 'CI_TEST_FAIL_TARGET': fail_target or '',
                           'GITHUB_ACTIONS': str(ci).lower(), 'CI_TEST_ADB_STATUS': str(adb_status)}
            environment.pop('ANDROID_HOME', None)
            environment.pop('ANDROID_SDK_ROOT', None)
            environment['ANDROID_SDK_ROOT' if sdk_root else 'ANDROID_HOME'] = str(adb.parent.parent)
            environment.pop('ANDROID_SERIAL', None)
            if device:
                environment['ANDROID_SERIAL'] = device
            script = action_script().replace('${{ matrix.api-level }}', str(api_level))
            # Match parseScript and sh -c in the pinned emulator action.
            for command in [line.strip() for line in re.split(r'\r\n|\n|\r', script)
                            if line.strip() and not line.strip().startswith('#')]:
                result = subprocess.run(['sh', '-c', command], cwd=ROOT, env=environment,
                                        capture_output=True, text=True)
                if result.returncode:
                    break
            self.assertEqual(adb.read_text(), original)
            self.assertTrue(os.access(adb, os.X_OK))
            if adb_symlink:
                self.assertEqual(os.readlink(adb), native_adb.name)
            self.assertEqual(set(adb.parent.iterdir()), {adb, native_adb})
            return result, calls.read_text().splitlines() if calls.exists() else []

    def test_api24_runs_common_flows_without_api36_only_tests(self):
        result, calls = self.run_action(24)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('adb guard active'), 3)
        self.assertEqual(calls, [
            'test integration_test/main_loop_test.dart -d emulator-5554',
            'test integration_test/v2_file_recovery_test.dart -d emulator-5554',
            'test integration_test/continuous_series_test.dart -d emulator-5554',
        ])

    def test_api24_uses_the_absolute_sdk_root_adb_instead_of_path(self):
        result, calls = self.run_action(24, sdk_root=True, adb_symlink=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('adb guard active'), 3)
        self.assertNotIn('PATH adb was selected', result.stderr)
        self.assertEqual(len(calls), 3)

    def test_local_api24_does_not_install_the_guard(self):
        result, _ = self.run_action(24, ci=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('adb guard active', result.stdout)

    def test_api36_runs_all_five_flows_in_order(self):
        result, calls = self.run_action(36)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('adb guard active', result.stdout)
        self.assertEqual(calls, [
            'test integration_test/main_loop_test.dart -d emulator-5554',
            'test integration_test/v2_file_recovery_test.dart -d emulator-5554',
            'test integration_test/continuous_series_test.dart -d emulator-5554',
            'test integration_test/player_comparison_flow_test.dart -d emulator-5554',
            'test integration_test/command_performance_test.dart -d emulator-5554',
        ])

    def test_api24_ordinary_adb_failure_is_preserved_and_sdk_adb_is_restored(self):
        result, calls = self.run_action(24, adb_status=124)
        self.assertEqual(result.returncode, 124)
        self.assertIn('adb guard active', result.stdout)
        self.assertNotIn('--no-streaming', result.stderr)
        self.assertEqual(len(calls), 1)

    def test_common_flow_failure_stops_remaining_tests(self):
        result, calls = self.run_action(36, 'integration_test/main_loop_test.dart')
        self.assertEqual(result.returncode, 42)
        self.assertEqual(len(calls), 1)

    def test_api36_flow_failure_preserves_failure_and_stops_benchmark(self):
        result, calls = self.run_action(36, 'integration_test/player_comparison_flow_test.dart')
        self.assertEqual(result.returncode, 42)
        self.assertEqual(len(calls), 4)

    def test_series_failure_stops_later_flows_on_both_supported_apis(self):
        for api_level in (24, 36):
            with self.subTest(api_level=api_level):
                result, calls = self.run_action(
                    api_level, 'integration_test/continuous_series_test.dart'
                )
                self.assertEqual(result.returncode, 42)
                self.assertEqual(calls, [
                    'test integration_test/main_loop_test.dart -d emulator-5554',
                    'test integration_test/v2_file_recovery_test.dart -d emulator-5554',
                    'test integration_test/continuous_series_test.dart -d emulator-5554',
                ])

    def test_unknown_api_fails_before_invoking_flutter(self):
        result, calls = self.run_action(35)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_uses_the_emulator_action_device_environment(self):
        result, calls = self.run_action(24, device='emulator-5560')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(call.endswith('-d emulator-5560') for call in calls))


@unittest.skipUnless(os.name == 'posix' and shutil.which('stdbuf'), 'Requires GNU stdbuf')
class AdbInstallGuardTest(unittest.TestCase):
    def run_timed_install(self, fallback_status, *, fallback_output="Performing Push Install", invoke_cli=False):
        from tool.release.ci_android_adb import run_install

        with tempfile.TemporaryDirectory(prefix='hoopito-adb-timeout-') as temporary:
            adb = Path(temporary) / 'adb'
            calls = adb.with_suffix('.jsonl')
            adb.write_text(
                '#!/usr/bin/env python3\n'
                'import json, sys, time\n'
                'from pathlib import Path\n'
                'args = sys.argv[1:]\n'
                'with Path(__file__).with_suffix(".jsonl").open("a") as log:\n'
                '    print(json.dumps(args), file=log)\n'
                'if "install" not in args:\n'
                '    print("diagnostic", flush=True)\n'
                'elif "--no-streaming" not in args:\n'
                '    print("Performing Streamed Install", flush=True)\n'
                '    time.sleep(10)\n'
                'else:\n'
                f'    print({fallback_output!r}, flush=True)\n'
                + ('    time.sleep(10)\n' if fallback_status is None else f'    sys.exit({fallback_status})\n')
            )
            adb.chmod(0o755)
            args = ['-s', 'emulator-5554', 'install', '-t', '-r', 'a file.apk']
            if invoke_cli:
                log_path = Path(temporary) / 'guard.log'
                env = {
                    **os.environ,
                    'HOOPITO_CI_ADB_ORIGINAL': str(adb),
                    'HOOPITO_CI_ADB_DEVICE': 'emulator-5554',
                    'HOOPITO_CI_ADB_LOG': str(log_path),
                    'HOOPITO_CI_ADB_FAILED_FALLBACK': str(log_path.with_suffix('.failed')),
                }
                command = [
                    sys.executable, '-B', '-c',
                    'from functools import partial; from tool.release import ci_android_adb as guard; '
                    'guard.run_install = partial(guard.run_install, timeout=0.5); raise SystemExit(guard.main())',
                    *args,
                ]
                result, retry = [
                    subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=10)
                    for _ in range(2)
                ]
                log = log_path.read_text()
            else:
                output = io.StringIO()
                result, retry = run_install(str(adb), args, output, timeout=0.5)
                log = output.getvalue()
            recorded_calls = [json.loads(line) for line in calls.read_text().splitlines()]
            return result, retry, log, recorded_calls

    def test_verified_timeout_records_diagnostics_then_retries_once(self):
        result, used_fallback, log, calls = self.run_timed_install(0)
        self.assertTrue(used_fallback)
        self.assertEqual(result.returncode, 0)
        self.assertIn('Performing Streamed Install', log)
        self.assertIn('timed out after 0.5s', log)
        self.assertIn('Performing Push Install', log)
        self.assertEqual(calls, [
            ['-s', 'emulator-5554', 'install', '-t', '-r', 'a file.apk'],
            ['version'],
            ['-s', 'emulator-5554', 'get-state'],
            ['-s', 'emulator-5554', 'features'],
            ['-s', 'emulator-5554', 'shell', 'df', '/data'],
            ['-s', 'emulator-5554', 'logcat', '-d', '-t', '100'],
            ['-s', 'emulator-5554', 'install', '--no-streaming', '-t', '-r', 'a file.apk'],
        ])

    def test_failed_fallback_is_returned_without_another_attempt(self):
        result, used_fallback, _, calls = self.run_timed_install(43)
        self.assertTrue(used_fallback)
        self.assertEqual(result.returncode, 43)
        self.assertEqual(sum('--no-streaming' in call for call in calls), 1)

    def test_adb_failure_line_with_exit_zero_cannot_be_masked_by_flutter_retry(self):
        result, retry, _, calls = self.run_timed_install(
            0, fallback_output='Failure [INSTALL_FAILED_INTERNAL_ERROR]', invoke_cli=True
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, 'Failure [INSTALL_FAILED_INTERNAL_ERROR]\n')
        self.assertEqual(retry.returncode, 1)
        self.assertIn('recovery already failed', retry.stderr)
        self.assertEqual(sum('install' in call for call in calls), 2)

    def test_fallback_install_is_also_bounded(self):
        result, used_fallback, log, calls = self.run_timed_install(None)
        self.assertTrue(used_fallback)
        self.assertIsNone(result)
        self.assertEqual(log.count('timed out after 0.5s'), 2)
        self.assertEqual(sum('--no-streaming' in call for call in calls), 1)


if __name__ == '__main__':
    unittest.main()

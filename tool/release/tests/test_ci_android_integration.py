"""Exercise the emulator action's per-line invocation with a fake Flutter CLI."""

import os
import re
import shutil
import subprocess
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
    def run_action(self, api_level, fail_target=None, device=None):
        with tempfile.TemporaryDirectory(prefix='hoopito-ci-shell-') as temporary:
            path = Path(temporary)
            calls = path / 'calls.txt'
            fake_flutter = path / 'flutter'
            fake_flutter.write_text(
                '#!/usr/bin/env bash\n'
                'printf "%s\\n" "$*" >> "$CI_TEST_CALLS"\n'
                'if [[ -n "${CI_TEST_FAIL_TARGET:-}" && "$2" == "$CI_TEST_FAIL_TARGET" ]]; then exit 42; fi\n'
            )
            fake_flutter.chmod(0o755)
            environment = {**os.environ, 'PATH': f'{path}:{os.environ["PATH"]}',
                           'CI_TEST_CALLS': str(calls), 'CI_TEST_FAIL_TARGET': fail_target or ''}
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
            return result, calls.read_text().splitlines() if calls.exists() else []

    def test_api24_runs_common_flows_without_api36_only_tests(self):
        result, calls = self.run_action(24)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [
            'test integration_test/main_loop_test.dart -d emulator-5554',
            'test integration_test/v2_file_recovery_test.dart -d emulator-5554',
        ])

    def test_api36_runs_all_four_flows_in_order(self):
        result, calls = self.run_action(36)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [
            'test integration_test/main_loop_test.dart -d emulator-5554',
            'test integration_test/v2_file_recovery_test.dart -d emulator-5554',
            'test integration_test/player_comparison_flow_test.dart -d emulator-5554',
            'test integration_test/command_performance_test.dart -d emulator-5554',
        ])

    def test_common_flow_failure_stops_remaining_tests(self):
        result, calls = self.run_action(36, 'integration_test/main_loop_test.dart')
        self.assertEqual(result.returncode, 42)
        self.assertEqual(len(calls), 1)

    def test_api36_flow_failure_preserves_failure_and_stops_benchmark(self):
        result, calls = self.run_action(36, 'integration_test/player_comparison_flow_test.dart')
        self.assertEqual(result.returncode, 42)
        self.assertEqual(len(calls), 3)

    def test_unknown_api_fails_before_invoking_flutter(self):
        result, calls = self.run_action(35)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_uses_the_emulator_action_device_environment(self):
        result, calls = self.run_action(24, device='emulator-5560')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(call.endswith('-d emulator-5560') for call in calls))


if __name__ == '__main__':
    unittest.main()

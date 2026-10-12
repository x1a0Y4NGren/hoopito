"""Synthetic evidence checks; these tests never connect to an Android device."""

import copy
import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


SPEC = importlib.util.spec_from_file_location(
    'measure_entry_startup', Path(__file__).resolve().parents[1] / 'measure_entry_startup.py',
)
measurement = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(measurement)


def frame(index, timestamp, build=1000, raster=2000, total=4000):
    return {
        'type': 'frame', 'index': index, 'frame_number': index + 1,
        'build_start_us': timestamp, 'build_us': build, 'raster_us': raster, 'total_us': total,
    }


def fixture():
    frames = [frame(index, timestamp) for index, timestamp in enumerate((50, 150, 200, 300, 400, 500, 501))]
    return {
        'frames': frames,
        'summary': {
            'type': 'summary', 'schema': 1, 'profile': True, 'diagnostic': True,
            'started_at_us': 100, 'frame_count': len(frames), 'flush_ms': 1200,
            'marks': [
                {'phase': phase, 'time_us': timestamp}
                for phase, timestamp in (
                    ('initializing', 100), ('playing_standard', 200),
                    ('settled', 300), ('reveal', 400), ('finished', 500),
                )
            ],
        },
    }


def handoff_fixture():
    probe = fixture()
    probe['summary']['marks'].insert(1, {'phase': 'handoff', 'time_us': 150})
    return probe


def records(probe):
    return [*probe['frames'], probe['summary']]


def log(records_to_write):
    return 'unrelated log line\n' + '\n'.join(
        'I/flutter: ' + measurement.PREFIX + json.dumps(record) for record in records_to_write
    )


class ProbeParsingTest(unittest.TestCase):
    def test_reads_legacy_brand_logs_without_changing_the_probe(self):
        probe = fixture()
        legacy_log = log(records(probe)).replace(measurement.PREFIX, measurement.LEGACY_PREFIX)
        self.assertEqual(measurement.parse_records(legacy_log), probe)

    def test_waits_for_summary_then_parses_complete_probe(self):
        probe = fixture()
        self.assertIsNone(measurement.parse_records(log(probe['frames'])))
        self.assertEqual(measurement.parse_records(log(records(probe))), probe)

    def test_preserves_optional_schema_one_diagnostics(self):
        probe = fixture()
        probe['summary'].update({
            'preparation_us': 1234,
            'fallback_reason': None,
            'preparation': {
                'image': {'elapsed_us': 900, 'outcome': 'ready'},
                'mesh': {'elapsed_us': 334, 'outcome': 'fallback'},
            },
        })
        self.assertEqual(measurement.parse_records(log(records(probe))), probe)

    def test_accepts_handoff_before_motion_and_rejects_late_or_duplicate_handoff(self):
        probe = handoff_fixture()
        self.assertEqual(measurement.parse_records(log(records(probe))), probe)
        late = fixture()
        late['summary']['marks'].insert(2, {'phase': 'handoff', 'time_us': 250})
        duplicate = handoff_fixture()
        duplicate['summary']['marks'].insert(2, {'phase': 'handoff', 'time_us': 180})
        for invalid in (late, duplicate):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                measurement.parse_records(log(records(invalid)))

    def test_preserves_preparation_spans_without_changing_frame_samples(self):
        probe = fixture()
        spans = [{
            'type': 'preparation_span', 'stage': 'image_asset',
            'started_at_us': 110, 'ended_at_us': 180, 'elapsed_us': 70,
        }]
        parsed = measurement.parse_records(log([*spans, *records(probe)]))
        self.assertEqual(parsed['preparation_spans'], spans)
        self.assertEqual(parsed['frames'], probe['frames'])
        self.assertEqual(measurement.aggregate([parsed], 16.7),
                         measurement.aggregate([probe], 16.7))

    def test_rejects_missing_duplicate_or_trailing_frame(self):
        probe = fixture()
        for invalid in (
            [*probe['frames'][1:], probe['summary']],
            [probe['frames'][0], *probe['frames'][:-1], probe['summary']],
            [probe['summary'], *probe['frames']],
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                measurement.parse_records(log(invalid))

    def test_rejects_wrong_mode_bypassed_motion_and_unordered_marks(self):
        for mutation in ('profile', 'diagnostic', 'schema', 'playing', 'finish', 'unordered'):
            probe = fixture()
            summary = probe['summary']
            if mutation in ('profile', 'diagnostic'):
                summary[mutation] = False
            elif mutation == 'schema':
                summary['schema'] = 2
            elif mutation == 'playing':
                summary['marks'][1]['phase'] = 'disabled'
            elif mutation == 'finish':
                summary['marks'].pop()
            else:
                summary['marks'][2]['time_us'] = 50
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                measurement.parse_records(log(records(probe)))

    def test_rejects_empty_probe_negative_duration_and_multiple_summaries(self):
        probe = fixture()
        empty = copy.deepcopy(probe)
        empty['frames'] = []
        empty['summary']['frame_count'] = 0
        negative = copy.deepcopy(probe)
        negative['frames'][0]['raster_us'] = -1
        for invalid in (records(empty), records(negative), [*records(probe), probe['summary']]):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                measurement.parse_records(log(invalid))


class FrameSummaryTest(unittest.TestCase):
    def test_phase_boundaries_include_first_frame_and_exclude_post_finish(self):
        phases = measurement.phase_frames(fixture())
        expected = {
            'initializing': [0, 1], 'playing_standard': [2], 'settled': [3],
            'reveal': [4, 5], 'startup': [0, 1, 2, 3, 4, 5],
            'visual': [2, 3, 4, 5], 'presented': [2, 3, 4, 5], 'post_finish': [6],
        }
        self.assertEqual({key: [value['index'] for value in values] for key, values in phases.items()}, expected)

    def test_presented_includes_static_preparation_without_changing_visual_or_startup(self):
        phases = measurement.phase_frames(handoff_fixture())
        expected = {
            'initializing': [0], 'handoff': [1], 'playing_standard': [2],
            'settled': [3], 'reveal': [4, 5], 'startup': [0, 1, 2, 3, 4, 5],
            'visual': [2, 3, 4, 5], 'presented': [1, 2, 3, 4, 5], 'post_finish': [6],
        }
        self.assertEqual({key: [value['index'] for value in values] for key, values in phases.items()}, expected)

    def test_mixed_sources_report_handoff_and_legacy_fallback_explicitly(self):
        report = measurement.aggregate([handoff_fixture(), fixture()], 16.7)
        self.assertEqual(report['budget_phase'], 'presented')
        self.assertEqual(report['presented_runs'], {'handoff': 1, 'legacy_visual_fallback': 1})
        self.assertEqual(report['phases']['visual']['frame_count'], 8)
        self.assertEqual(report['phases']['presented']['frame_count'], 9)
        self.assertEqual(report['phases']['startup']['frame_count'], 12)
        self.assertIn('legacy', report['presented_method'])

    def test_percentiles_and_strict_budget_treat_build_and_raster_separately(self):
        frames = [
            frame(0, 0, 16700, 16701, 20000),
            frame(1, 1, 20000, 20000, 30000),
            frame(2, 2, 1000, 1000, 2000),
        ]
        summary = measurement.summarize_frames(frames, 16.7)
        self.assertEqual(summary['build']['p50_ms'], 16.7)
        self.assertEqual(summary['build']['p95_ms'], 20)
        self.assertEqual(summary['build']['max_ms'], 20)
        self.assertEqual(summary['build']['over_budget_count'], 1)
        self.assertEqual(summary['raster']['over_budget_count'], 2)
        self.assertEqual(summary['build_or_raster_over_budget_count'], 2)

    def test_aggregate_retains_every_run_and_nulls_for_empty_phase(self):
        report = measurement.aggregate([fixture(), fixture()], 16.7)
        self.assertEqual(report['runs'], 2)
        self.assertEqual(len(report['per_run']), 2)
        self.assertEqual(report['phases']['startup']['frame_count'], 12)
        self.assertEqual(report['phases']['visual']['frame_count'], 8)
        self.assertIsNone(measurement.summarize_frames([], 16.7)['build']['max_ms'])


class InstalledApkTest(unittest.TestCase):
    def test_accepts_only_matching_installed_universal_apk(self):
        device = measurement.Device(types.SimpleNamespace(user=10, package=measurement.PACKAGE))
        sha256 = 'b' * 64
        device.run = Mock(side_effect=['package:/data/app/example/base.apk', sha256 + '  /data/app/example/base.apk'])
        self.assertEqual(device.verify_installed_apk(sha256), {'path': '/data/app/example/base.apk', 'sha256': sha256})
        self.assertEqual(device.run.call_args_list[0].args, ('shell', 'pm', 'path', '--user', '10', measurement.PACKAGE))

    def test_rejects_mismatch_missing_or_split_apk(self):
        for output in (
            ['',],
            ['package:/base.apk\npackage:/split.apk'],
            ['package:/base.apk', 'a' * 64 + '  /base.apk'],
        ):
            device = measurement.Device(types.SimpleNamespace(user=10, package=measurement.PACKAGE))
            device.run = Mock(side_effect=output)
            with self.subTest(output=output), self.assertRaises(RuntimeError):
                device.verify_installed_apk('b' * 64)


class MeasurementGatesTest(unittest.TestCase):
    def run_measurement(self, probes, *flags, incomplete_log=None):
        """Run the real CLI/file reporting, replacing only Android operations."""
        def cold_start(index):
            probe = copy.deepcopy(probes[index - 1])
            probe['launch'] = {
                'run': index, 'previous_pids': [], 'pid': 1000 + index,
                'force_stop_verified': True, 'am_start': 'Status: ok',
                'focused_window': measurement.PACKAGE, 'utc': '2026-10-05T00:00:00+00:00',
            }
            return probe, log(records(probe)) + '\n'

        active = False

        def android_response(*arguments, **kwargs):
            nonlocal active
            if arguments[:2] == ('shell', 'ps'):
                return 'USER PID NAME\n' + (
                    f'u10_a1 1001 {measurement.PACKAGE}' if active else ''
                )
            if arguments[:3] == ('shell', 'am', 'force-stop'):
                active = False
                return ''
            if arguments[:2] == ('shell', 'date'):
                return '10-05 00:00:00.000'
            if arguments[:3] == ('shell', 'am', 'start'):
                active = True
                return 'Status: ok'
            if arguments == ('shell', 'dumpsys', 'window'):
                return f'mCurrentFocus=Window{{synthetic {measurement.PACKAGE}}}'
            if arguments[0] == 'logcat':
                return incomplete_log
            raise AssertionError(f'Unexpected Android command: {arguments}')

        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / 'profile.apk'
            apk.write_bytes(b'synthetic profile APK fixture; never installed')
            output = Path(directory) / 'evidence'
            arguments = [
                'measure_entry_startup.py', '--runs', str(len(probes)),
                '--apk', str(apk), '--output', str(output), '--source-commit', 'a' * 40,
                *flags,
            ]
            with (
                patch.object(sys, 'argv', arguments),
                patch.object(measurement.Device, 'validate', return_value={'serial': 'synthetic'}),
                patch.object(measurement.Device, 'verify_installed_apk', return_value={
                    'path': '/data/app/synthetic/base.apk', 'sha256': 'b' * 64,
                }),
                contextlib.ExitStack() as device_operations,
                contextlib.redirect_stdout(io.StringIO()),
                contextlib.redirect_stderr(io.StringIO()),
            ):
                if incomplete_log is None:
                    device_operations.enter_context(patch.object(
                        measurement.Device, 'cold_start', side_effect=cold_start,
                    ))
                else:
                    device_operations.enter_context(patch.object(
                        measurement.Device, 'run', side_effect=android_response,
                    ))
                    device_operations.enter_context(patch.object(
                        measurement.time, 'monotonic', side_effect=[0, 0, 100],
                    ))
                    device_operations.enter_context(patch.object(measurement.time, 'sleep'))
                try:
                    exit_code = measurement.main()
                except SystemExit as error:
                    exit_code = error.code
            files = {path.name: path.read_text(encoding='utf-8') for path in output.glob('*')}
        return exit_code, files

    def test_all_standard_runs_pass_both_gates_at_budget_boundary(self):
        probe = fixture()
        for sample in probe['frames']:
            sample['build_us'] = sample['raster_us'] = 50000
            sample['total_us'] = 80000
        for sample in probe['frames'][2:6]:
            sample['build_us'] = sample['raster_us'] = 16700
        code, files = self.run_measurement([probe, probe], '--require-standard', '--enforce-budget')
        self.assertEqual(code, 0)
        report = json.loads(files['aggregate.json'])
        self.assertTrue(report['gates']['passed'])
        self.assertEqual(report['gates']['failures'], [])
        self.assertEqual(report['motion_modes'], {'standard': 2, 'reduced': 0})
        self.assertEqual(report['phases']['visual']['build']['p95_ms'], 16.7)
        self.assertEqual(report['phases']['visual']['raster']['p95_ms'], 16.7)
        self.assertEqual(report['phases']['visual']['total']['p95_ms'], 80)
        self.assertEqual(report['budget_phase'], 'visual')
        self.assertEqual(report['presented_runs'], {'handoff': 0, 'legacy_visual_fallback': 2})

    def test_slow_static_preparation_fails_presented_budget_and_preserves_every_run(self):
        for metric in ('build', 'raster'):
            probe = handoff_fixture()
            probe['frames'][1][metric + '_us'] = 16701
            with self.subTest(metric=metric):
                code, files = self.run_measurement([probe, handoff_fixture()], '--require-standard', '--enforce-budget')
                self.assertEqual(code, 1)
                self.assertEqual(set(files), {
                    'provenance.json', 'aggregate.json', 'run-01.json', 'run-01.log',
                    'run-02.json', 'run-02.log',
                })
                report = json.loads(files['aggregate.json'])
                self.assertEqual(report['status'], 'gate_failed')
                self.assertEqual(report['budget_phase'], 'presented')
                self.assertEqual(report['phases']['visual'][metric]['p95_ms'], 1 if metric == 'build' else 2)
                self.assertEqual(report['phases']['presented'][metric]['p95_ms'], 16.701)
                self.assertEqual(report['gates']['failures'], [{
                    'gate': 'presented_budget', 'metric': metric, 'p95_ms': 16.701, 'budget_ms': 16.7,
                }])
                self.assertEqual(json.loads(files['run-01.json'])['frames'], probe['frames'])
                self.assertEqual(measurement.parse_records(files['run-01.log'])['frames'], probe['frames'])

    def test_handoff_budget_boundary_includes_preparation_and_preserves_motion_range(self):
        probe = handoff_fixture()
        probe['frames'][0]['build_us'] = probe['frames'][0]['raster_us'] = 90000
        probe['frames'][6]['build_us'] = probe['frames'][6]['raster_us'] = 90000
        for sample in probe['frames'][1:6]:
            sample['build_us'] = sample['raster_us'] = 16700
        code, files = self.run_measurement([probe], '--require-standard', '--enforce-budget')
        self.assertEqual(code, 0)
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['budget_phase'], 'presented')
        self.assertEqual(report['phases']['presented']['frame_count'], 5)
        self.assertEqual(report['phases']['presented']['raster']['p95_ms'], 16.7)
        self.assertEqual(report['phases']['startup']['raster']['max_ms'], 90)
        self.assertEqual(report['phases']['post_finish']['raster']['max_ms'], 90)

    def test_missing_presented_samples_fail_and_keep_raw_evidence(self):
        probe = handoff_fixture()
        probe['frames'] = [frame(0, 50), frame(1, 501)]
        probe['summary']['frame_count'] = 2
        code, files = self.run_measurement([probe], '--enforce-budget')
        self.assertEqual(code, 1)
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['phases']['presented']['frame_count'], 0)
        self.assertEqual(report['gates']['failures'], [
            {'gate': 'presented_budget', 'metric': 'build', 'p95_ms': None, 'budget_ms': 16.7},
            {'gate': 'presented_budget', 'metric': 'raster', 'p95_ms': None, 'budget_ms': 16.7},
        ])
        self.assertEqual(json.loads(files['run-01.json'])['frames'], probe['frames'])
        self.assertEqual(measurement.parse_records(files['run-01.log'])['frames'], probe['frames'])

    def test_mixed_reduced_run_fails_after_saving_every_run_and_final_result(self):
        reduced = fixture()
        reduced['summary']['marks'][1]['phase'] = 'playing_reduced'
        reduced['summary']['fallback_reason'] = 'image_preparation_budget_exceeded'
        code, files = self.run_measurement([reduced, fixture()], '--require-standard')
        self.assertEqual(code, 1)
        self.assertEqual(set(files), {
            'provenance.json', 'aggregate.json', 'run-01.json', 'run-01.log',
            'run-02.json', 'run-02.log',
        })
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['runs'], 2)
        self.assertEqual(len(report['per_run']), 2)
        self.assertEqual(report['motion_modes'], {'standard': 1, 'reduced': 1})
        self.assertFalse(report['gates']['passed'])
        self.assertEqual(report['gates']['failures'], [{
            'gate': 'standard_motion', 'run': 1, 'playing_phases': ['playing_reduced'],
        }])
        saved = json.loads(files['run-01.json'])
        self.assertEqual(saved['frames'], reduced['frames'])
        self.assertEqual(saved['summary'], reduced['summary'])
        self.assertEqual(measurement.parse_records(files['run-01.log'])['summary'], reduced['summary'])

    def test_incomplete_probe_preserves_raw_log_and_explicit_failure_result(self):
        raw_log = log(fixture()['frames']) + '\ntrailing device diagnostic\n'
        code, files = self.run_measurement(
            [fixture()], '--require-standard', '--enforce-budget', incomplete_log=raw_log,
        )
        self.assertEqual(code, 1)
        self.assertEqual(files['run-01.log'], raw_log)
        self.assertNotIn('run-01.json', files)
        error = json.loads(files['run-01.error.json'])
        self.assertEqual(error['run'], 1)
        self.assertEqual(error['error_type'], 'TimeoutError')
        self.assertIn('No complete Profile probe', error['message'])
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['status'], 'collection_failed')
        self.assertEqual(report['requested_runs'], 1)
        self.assertEqual(report['runs'], 0)
        self.assertFalse(report['gates']['passed'])
        self.assertEqual(report['collection_error'], error)

    def test_invalid_handoff_preserves_complete_raw_log_before_collection_failure(self):
        probe = fixture()
        probe['summary']['marks'].insert(2, {'phase': 'handoff', 'time_us': 250})
        raw_log = log(records(probe)) + '\ntrailing device diagnostic\n'
        code, files = self.run_measurement([probe], '--enforce-budget', incomplete_log=raw_log)
        self.assertEqual(code, 1)
        self.assertEqual(files['run-01.log'], raw_log)
        self.assertNotIn('run-01.json', files)
        error = json.loads(files['run-01.error.json'])
        self.assertEqual(error['error_type'], 'ValueError')
        self.assertIn('handoff', error['message'])
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['status'], 'collection_failed')
        self.assertEqual(report['collection_error'], error)

    def test_budget_failure_reports_build_and_raster_independently(self):
        for metric in ('build', 'raster'):
            probe = fixture()
            probe['frames'][2][metric + '_us'] = 16701
            with self.subTest(metric=metric):
                code, files = self.run_measurement([probe], '--enforce-budget')
                self.assertEqual(code, 1)
                self.assertIn('run-01.json', files)
                self.assertIn('run-01.log', files)
                report = json.loads(files['aggregate.json'])
                self.assertFalse(report['gates']['passed'])
                self.assertEqual(report['gates']['failures'], [{
                    'gate': 'visual_budget', 'metric': metric, 'p95_ms': 16.701, 'budget_ms': 16.7,
                }])

    def test_budget_gate_uses_existing_custom_budget(self):
        probe = fixture()
        probe['frames'][2]['raster_us'] = 20000
        code, files = self.run_measurement([probe], '--enforce-budget', '--budget-ms', '20')
        self.assertEqual(code, 0)
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['budget_ms'], 20)
        self.assertTrue(report['gates']['passed'])

    def test_standard_gate_rejects_run_with_both_motion_modes(self):
        probe = fixture()
        probe['summary']['marks'].insert(2, {'phase': 'playing_reduced', 'time_us': 250})
        code, files = self.run_measurement([probe], '--require-standard')
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(files['aggregate.json'])['gates']['failures'], [{
            'gate': 'standard_motion', 'run': 1,
            'playing_phases': ['playing_standard', 'playing_reduced'],
        }])

    def test_standard_gate_rejects_skip_after_standard_playing_mark(self):
        probe = fixture()
        probe['summary']['marks'].insert(2, {'phase': 'skip', 'time_us': 250})
        code, files = self.run_measurement([probe], '--require-standard')
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(files['aggregate.json'])['gates']['failures'], [{
            'gate': 'standard_motion', 'run': 1, 'playing_phases': ['playing_standard'],
            'disqualifying_phases': ['skip'],
        }])
        legacy_code, _ = self.run_measurement([probe])
        self.assertEqual(legacy_code, 0)

    def test_standard_gate_rejects_mesh_fallback_after_standard_playing_mark(self):
        probe = fixture()
        probe['summary']['marks'].insert(2, {'phase': 'mesh_fallback', 'time_us': 250})
        code, files = self.run_measurement([probe], '--require-standard')
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(files['aggregate.json'])['gates']['failures'], [{
            'gate': 'standard_motion', 'run': 1, 'playing_phases': ['playing_standard'],
            'disqualifying_phases': ['mesh_fallback'],
        }])
        legacy_code, _ = self.run_measurement([probe])
        self.assertEqual(legacy_code, 0)

    def test_rejects_nonfinite_timeout_and_budget_before_collection(self):
        for option in ('--timeout', '--budget-ms'):
            for value in ('nan', 'inf', '-inf'):
                with self.subTest(option=option, value=value):
                    code, files = self.run_measurement(
                        [fixture()], '--enforce-budget', f'{option}={value}',
                    )
                    self.assertEqual(code, 2)
                    self.assertEqual(files, {})

    def test_budget_gate_rejects_missing_visible_samples(self):
        probe = fixture()
        probe['frames'] = [frame(0, 50), frame(1, 501)]
        probe['summary']['frame_count'] = 2
        code, files = self.run_measurement([probe], '--enforce-budget')
        self.assertEqual(code, 1)
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['phases']['visual']['frame_count'], 0)
        self.assertEqual(report['gates']['failures'], [
            {'gate': 'visual_budget', 'metric': 'build', 'p95_ms': None, 'budget_ms': 16.7},
            {'gate': 'visual_budget', 'metric': 'raster', 'p95_ms': None, 'budget_ms': 16.7},
        ])

    def test_legacy_invocation_collects_reduced_over_budget_runs_without_enforcement(self):
        reduced = fixture()
        reduced['summary']['marks'][1]['phase'] = 'playing_reduced'
        reduced['frames'][2]['build_us'] = 90000
        code, files = self.run_measurement([reduced])
        self.assertIn(code, (None, 0))
        report = json.loads(files['aggregate.json'])
        self.assertEqual(report['motion_modes'], {'standard': 0, 'reduced': 1})
        self.assertEqual(report['phases']['visual']['build']['p95_ms'], 90)
        self.assertEqual(len(report['per_run']), 1)


if __name__ == '__main__':
    unittest.main()

"""Offline repeated-batch checks; no Android device or APK is modified."""

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    'compare_entry_startup_runs', Path(__file__).resolve().parents[1] / 'compare_entry_startup_runs.py',
)
comparison = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(comparison)


def probe(index, raster_ms):
    return {
        'summary': {
            'type': 'summary', 'schema': 1, 'profile': True, 'diagnostic': True,
            'frame_count': 4,
            'marks': [{'phase': phase, 'time_us': timestamp} for phase, timestamp in (
                ('initializing', 10), ('handoff', 100), ('playing_standard', 200),
                ('reveal', 300), ('finished', 400),
            )],
        },
        'frames': [{'type': 'frame', 'index': frame_index, 'frame_number': frame_index + 1,
                    'build_start_us': timestamp, 'build_us': 1000,
                    'raster_us': raster_ms * 1000, 'total_us': 50000}
                   for frame_index, timestamp in enumerate((50, 100, 250, 401))],
        'launch': {'run': index, 'pid': 100 + index, 'previous_pids': [], 'force_stop_verified': True},
    }


def write_json(path, data):
    path.write_text(json.dumps(data), encoding='utf-8')


def batch(path, values):
    path.mkdir()
    provenance = {
        'source_commit': 'a' * 40, 'profile_apk_sha256': 'b' * 64,
        'verified_installed_apk': {'sha256': 'b' * 64}, 'recording_during_measurement': False,
        'device': {'serial': 'emulator-5562', 'android_user': 10, 'api': 36, 'abi': 'x86_64',
                   'size': 'Physical size: 1080x1920', 'density': 'Physical density: 420',
                   'model': 'sdk_gphone64_x86_64'},
    }
    write_json(path / 'provenance.json', provenance)
    write_json(path / 'aggregate.json', {
        'provenance': provenance, 'requested_runs': len(values), 'budget_ms': 16.7,
        'collection_error': None, 'phases': {'presented': {'raster': {'p95_ms': -999}}},
        'gates': {'passed': True},
    })
    for index, value in enumerate(values, 1):
        write_json(path / f'run-{index:02}.json', probe(index, value))
    return path


class CompareBatchesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.a = batch(self.root / 'a', [20, 20])
        self.b = batch(self.root / 'b', [20, 20])

    def mutate(self, path, filename, callback):
        data = json.loads((path / filename).read_text(encoding='utf-8'))
        callback(data)
        write_json(path / filename, data)

    def test_consistent_failure_is_not_a_budget_pass_and_metrics_are_recomputed(self):
        result = comparison.compare_batches([self.a, self.b], 0)
        self.assertFalse(result['all_batches_within_budget'])
        self.assertTrue(result['variation_diagnostic']['within_requested_limit'])
        self.assertFalse(result['variation_diagnostic']['release_gate'])
        self.assertEqual(result['raster_p95_repetition']['values_ms'], [20, 20])
        report = result['batches'][0]['report']
        self.assertEqual(report['phases']['presented']['frame_count'], 4)
        self.assertEqual(report['phases']['startup']['frame_count'], 6)
        self.assertEqual(report['phases']['post_finish']['frame_count'], 2)
        self.assertEqual(len(result['batches'][0]['inputs']), 4)

    def test_variable_pass_does_not_implicitly_establish_stability(self):
        c = batch(self.root / 'c', [10, 10])
        d = batch(self.root / 'd', [15, 15])
        result = comparison.compare_batches([c, d])
        self.assertTrue(result['all_batches_within_budget'])
        self.assertIsNone(result['variation_diagnostic']['within_requested_limit'])
        self.assertEqual(result['raster_p95_repetition']['relative_range_percent'], 40)
        diagnostic = comparison.compare_batches([c, d], 10)
        self.assertFalse(diagnostic['variation_diagnostic']['within_requested_limit'])
        self.assertTrue(diagnostic['all_batches_within_budget'])

    def test_rejects_mismatched_identity_budget_or_batch_size(self):
        for field in ('source_commit', 'profile_apk_sha256', 'serial', 'density', 'budget_ms', 'requested_runs'):
            with self.subTest(field=field):
                path = batch(self.root / field, [20, 20])
                if field in ('budget_ms', 'requested_runs'):
                    self.mutate(path, 'aggregate.json', lambda data: data.update({field: 3}))
                else:
                    for filename in ('provenance.json', 'aggregate.json'):
                        def change(data):
                            value = data.get('provenance', data)
                            if field in ('serial', 'density'):
                                value['device'][field] = 'different'
                            elif field == 'source_commit':
                                value[field] = 'c' * 40
                            else:
                                value[field] = 'c' * 64
                                value['verified_installed_apk']['sha256'] = 'c' * 64
                        self.mutate(path, filename, change)
                with self.assertRaises(ValueError):
                    comparison.compare_batches([self.a, path])

    def test_rejects_partial_extra_failed_and_empty_batches(self):
        for mutation in ('missing', 'extra', 'error', 'recording', 'provenance', 'count', 'no_frames'):
            with self.subTest(mutation=mutation):
                path = batch(self.root / mutation, [20, 20])
                if mutation == 'missing':
                    (path / 'run-02.json').unlink()
                elif mutation == 'extra':
                    write_json(path / 'run-03.json', probe(3, 20))
                elif mutation == 'error':
                    self.mutate(path, 'aggregate.json', lambda data: data.update(collection_error={'message': 'failed'}))
                elif mutation == 'recording':
                    self.mutate(path, 'provenance.json', lambda data: data.update(recording_during_measurement=True))
                elif mutation == 'provenance':
                    self.mutate(path, 'aggregate.json', lambda data: data['provenance'].update(source_commit='c' * 40))
                elif mutation == 'count':
                    self.mutate(path, 'run-01.json', lambda data: data['summary'].update(frame_count=50))
                else:
                    self.mutate(path, 'run-01.json', lambda data: data.update(frames=[]))
                with self.assertRaises(ValueError):
                    comparison.compare_batches([self.a, path])

    def test_rejects_legacy_reduced_skipped_fallback_or_unverified_cold_start(self):
        for mutation in ('handoff', 'reduced', 'skip', 'mesh_fallback', 'cold', 'pid'):
            with self.subTest(mutation=mutation):
                path = batch(self.root / mutation, [20, 20])
                def change(data):
                    marks = data['summary']['marks']
                    if mutation == 'handoff':
                        marks.pop(1)
                    elif mutation == 'reduced':
                        marks[2]['phase'] = 'playing_reduced'
                    elif mutation in ('skip', 'mesh_fallback'):
                        marks.insert(3, {'phase': mutation, 'time_us': 250})
                    elif mutation == 'cold':
                        data['launch']['force_stop_verified'] = False
                    else:
                        data['launch']['pid'] = 102
                self.mutate(path, 'run-01.json', change)
                with self.assertRaises(ValueError):
                    comparison.compare_batches([self.a, path])

    def test_rejects_duplicate_directory_too_few_batches_and_invalid_diagnostic_limit(self):
        for directories, limit in (([self.a], None), ([self.a, self.a], None),
                                   ([self.a, self.b], -1), ([self.a, self.b], float('nan'))):
            with self.subTest(directories=directories, limit=limit), self.assertRaises(ValueError):
                comparison.compare_batches(directories, limit)

    def test_zero_duration_batches_have_defined_variation(self):
        c = batch(self.root / 'zero_c', [0, 0])
        d = batch(self.root / 'zero_d', [0, 0])
        self.assertEqual(comparison.compare_batches([c, d])['raster_p95_repetition']['relative_range_percent'], 0)

    def test_malformed_json_objects_fail_closed(self):
        for mutation in ('root', 'frames', 'summary', 'launch', 'spans'):
            with self.subTest(mutation=mutation):
                path = batch(self.root / mutation, [20, 20])
                raw = probe(1, 20)
                if mutation == 'root':
                    raw = []
                elif mutation == 'spans':
                    raw['preparation_spans'] = [None]
                else:
                    raw[mutation] = None
                write_json(path / 'run-01.json', raw)
                with self.assertRaises(ValueError):
                    comparison.compare_batches([self.a, path])

    def test_cli_writes_complete_failed_report_before_optional_budget_exit(self):
        output = self.root / 'result.json'
        with contextlib.redirect_stdout(io.StringIO()):
            status = comparison.main([str(self.a), str(self.b), '--output', str(output), '--enforce-budget'])
        self.assertEqual(status, 1)
        self.assertEqual(json.loads(output.read_text())['status'], 'compared')
        self.assertEqual(len(json.loads(output.read_text())['batches']), 2)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            comparison.main([str(self.a), str(self.b), '--output', str(output)])

    def test_cli_records_invalid_evidence_without_replacing_input(self):
        self.mutate(self.a, 'run-01.json', lambda data: data['summary'].update(frame_count=40))
        original = (self.a / 'run-01.json').read_bytes()
        output = self.root / 'invalid.json'
        with contextlib.redirect_stdout(io.StringIO()):
            status = comparison.main([str(self.a), str(self.b), '--output', str(output)])
        self.assertEqual(status, 2)
        self.assertEqual(json.loads(output.read_text())['status'], 'comparison_invalid')
        self.assertEqual((self.a / 'run-01.json').read_bytes(), original)


if __name__ == '__main__':
    unittest.main()

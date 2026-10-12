"""Evidence classification checks; no Android device or build is used."""

import copy
import hashlib
import importlib.util
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path


TOOL = Path(__file__).resolve().parents[1] / 'observe_automatic_backup.py'
SPEC = importlib.util.spec_from_file_location('observe_automatic_backup', TOOL)
observer = importlib.util.module_from_spec(SPEC)
if TOOL.exists():
    SPEC.loader.exec_module(observer)

TREE = 'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FHoopTraceV2Synthetic%20'


def baseline():
    return {
        'serial': 'emulator-5554', 'user': 10, 'user_name': 'HoopTraceSynthetic',
        'uid': 1010223, 'source_commit': 'a' * 40, 'apk_sha256': 'b' * 64,
        'android_epoch_start': 100000, 'android_epoch_end': 100001,
        'uptime_seconds': 10000, 'boot_id': 'synthetic-boot',
        'settings': {
            'backup.automatic.enabled': True, 'backup.automatic.dirty': True,
            'backup.automatic.dirtySince': '1970-01-02T03:46:40.000Z',
            'backup.automatic.dirtyRevision': 7,
            'backup.automatic.directory': TREE,
            'backup.automatic.lastBackupAt': '1970-01-01T00:00:00.000Z',
            'backup.automatic.lastBackupPath': TREE + '/document/old.json',
        },
        'work': {'id': 'work-id', 'interval_duration': 86400000,
                 'period_count': 1, 'run_attempt_count': 0, 'state': 0,
                 'generation': 0, 'required_network_type': 0},
        'tables': {'matches': {'count': 1, 'sha256': 'unchanged'},
                   'active_sessions': {'count': 0, 'sha256': 'empty'},
                   'app_settings_non_backup': {'count': 2, 'sha256': 'same'}},
        'persisted_write_grant': True, 'provider_files': [],
        'worker_log_lines': [], 'foreground_app': False,
    }


def successful_after(before, brand='hoopito'):
    after = copy.deepcopy(before)
    after.update(android_epoch_start=186401, android_epoch_end=186402,
                 uptime_seconds=96401)
    after['work']['period_count'] = 2
    after['settings']['backup.automatic.dirty'] = False
    after['settings'].pop('backup.automatic.dirtySince')
    after['settings']['backup.automatic.lastBackupAt'] = '1970-01-03T03:46:40.000Z'
    name = f'{brand}-auto-19700103-034640.json'
    after['settings']['backup.automatic.lastBackupPath'] = TREE + '/document/' + name
    after['provider_files'] = [{'display_name': name, 'sha256': 'c' * 64,
                                'json_envelope_valid': True}]
    after['worker_log_lines'] = [
        '186399.000 1 1 D WM-WorkerWrapper: Starting work for '
        'io.github.x1a0y4ngren.hooptrace.AutomaticBackupWorker',
        '186401.000 1 2 I WM-WorkerWrapper: Worker result SUCCESS for Work '
        '[ id=work-id, tags={ io.github.x1a0y4ngren.hooptrace.AutomaticBackupWorker } ]',
    ]
    return after


class ObserverEvidenceTest(unittest.TestCase):
    def test_new_and_legacy_backup_names_both_prove_a_natural_write(self):
        before = baseline()
        for brand in ('hoopito', 'hooptrace'):
            with self.subTest(brand=brand):
                report = self.verify(before, successful_after(before, brand),
                                     restored_sha256='c' * 64)
                self.assertEqual(report['status'], 'passed')

    def test_stable_host_copy_closes_files_before_windows_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / 'original.sqlite'
            connection = sqlite3.connect(original)
            try:
                connection.execute('CREATE TABLE synthetic(value TEXT)')
                connection.execute("INSERT INTO synthetic VALUES ('fixed-row')")
                connection.commit()
            finally:
                connection.close()
            payload = original.read_bytes()

            class ReadOnlyAdb:
                def private(self, filename, optional=False):
                    return None if filename.endswith('-wal') else payload

            output = root / 'copy.sqlite'
            observer.stable_database(ReadOnlyAdb(), 'app_flutter/hooptrace.sqlite', output)
            connection = sqlite3.connect(output)
            try:
                self.assertEqual(connection.execute('SELECT value FROM synthetic').fetchall(),
                                 [('fixed-row',)])
            finally:
                connection.close()
            output.rename(root / 'closed.sqlite')
            self.assertFalse(any(root.glob('hoopito-observer-*')))

    def test_natural_early_noop_success_does_not_hide_later_backup(self):
        before = baseline()
        after = successful_after(before)
        after['worker_log_lines'].insert(0, after['worker_log_lines'][-1]
                                        .replace('186401.000', '100010.000'))
        report = self.verify(before, after, restored_sha256='c' * 64)
        self.assertEqual(report['status'], 'passed')
        self.assertEqual(report['worker_success_epoch'], 186401)

    def test_revoked_retry_then_success_fails_even_when_final_counter_is_zero(self):
        before = baseline()
        before['persisted_write_grant'] = False
        before['settings']['backup.automatic.dirtySince'] = '1970-01-01T00:00:00.000Z'
        after = copy.deepcopy(before)
        after.update(android_epoch_start=100100, android_epoch_end=100101,
                     uptime_seconds=10100)
        after['work']['period_count'] = 2
        success = successful_after(before)['worker_log_lines'][-1]
        after['worker_log_lines'] = [success.replace('186401.000', '100010.000')
                                    .replace('SUCCESS', 'RETRY'),
                                    success.replace('186401.000', '100100.000')]
        report = observer.compare_snapshots(before, after, mode='revoked',
                                             revocation_verified=True)
        self.assertEqual(report['status'], 'failed')
        self.assertIn('retried', ' '.join(report['failures']))

    def test_complete_natural_evidence_with_exact_restore_hash_passes(self):
        before = baseline()
        after = successful_after(before)
        report = observer.compare_snapshots(before, after, mode='natural',
                                             unforced_interval=True,
                                             restored_sha256='c' * 64)
        self.assertEqual(report['status'], 'passed')
        self.assertTrue(report['natural_schedule_observed'])
        self.assertEqual(report['worker_outcome'], 'write_observed')

    def test_a_reboot_leaves_natural_observation_pending(self):
        before = baseline()
        after = successful_after(before)
        after['boot_id'] = 'another-boot'
        self.assertEqual(self.verify(before, after)['status'], 'pending')

    def test_an_old_worker_success_log_cannot_satisfy_new_observation(self):
        before = baseline()
        after = successful_after(before)
        after['worker_log_lines'][1] = after['worker_log_lines'][1].replace('186401.000', '99999.000')
        self.assertEqual(self.verify(before, after)['status'], 'pending')

    def verify(self, before, after, **options):
        return observer.compare_snapshots(before, after, mode='natural',
                                          unforced_interval=True, **options)

    def test_short_interval_stays_pending_even_with_a_new_file(self):
        before = baseline()
        after = successful_after(before)
        after.update(android_epoch_start=100100, android_epoch_end=100101,
                     uptime_seconds=10100)
        self.assertEqual(self.verify(before, after)['status'], 'pending')

    def test_successful_natural_worker_still_requires_actual_restore_evidence(self):
        before = baseline()
        report = self.verify(before, successful_after(before))
        self.assertEqual(report['status'], 'pending')
        self.assertIn('production codec restore evidence', ' '.join(report['pending']))

    def test_forced_or_unattested_interval_cannot_pass_natural(self):
        before = baseline()
        report = observer.compare_snapshots(before, successful_after(before),
                                             mode='natural', unforced_interval=False)
        self.assertEqual(report['status'], 'pending')
        self.assertFalse(report['natural_schedule_observed'])

    def test_changed_business_data_fails_even_if_backup_succeeded(self):
        before = baseline()
        after = successful_after(before)
        after['tables']['matches']['sha256'] = 'changed'
        self.assertEqual(self.verify(before, after)['status'], 'failed')

    def test_clock_jump_cannot_pass_twenty_four_hours(self):
        before = baseline()
        after = successful_after(before)
        after['uptime_seconds'] = 10100
        report = self.verify(before, after)
        self.assertEqual(report['status'], 'failed')
        self.assertIn('clock', ' '.join(report['failures']))

    def test_worker_success_without_matching_file_is_pending(self):
        before = baseline()
        after = successful_after(before)
        after['provider_files'] = []
        report = self.verify(before, after)
        self.assertEqual(report['status'], 'pending')
        self.assertFalse(report['natural_schedule_observed'])

    def test_replaced_work_or_apk_fails_provenance(self):
        before = baseline()
        for key, value in [('apk_sha256', 'different'), ('work', {'id': 'other'})]:
            with self.subTest(key=key):
                after = successful_after(before)
                after[key] = value
                self.assertEqual(self.verify(before, after)['status'], 'failed')

    def test_revoked_due_worker_requires_real_grant_revocation_evidence(self):
        before = baseline()
        before['persisted_write_grant'] = False
        before['settings']['backup.automatic.dirtySince'] = '1970-01-01T00:00:00.000Z'
        after = copy.deepcopy(before)
        after.update(android_epoch_start=100010, android_epoch_end=100011,
                     uptime_seconds=10010)
        after['work']['period_count'] = 2
        after['worker_log_lines'] = [successful_after(before)['worker_log_lines'][1]
                                    .replace('186401.000', '100010.000')]
        pending = observer.compare_snapshots(before, after, mode='revoked')
        self.assertEqual(pending['status'], 'pending')
        report = observer.compare_snapshots(before, after, mode='revoked',
                                             revocation_verified=True)
        self.assertEqual(report['status'], 'passed')
        self.assertFalse(report['natural_schedule_observed'])
        self.assertEqual(report['worker_outcome'], 'inferred_missing_authorization')

    def test_revoked_worker_retry_or_changed_success_time_does_not_pass(self):
        before = baseline()
        before['persisted_write_grant'] = False
        before['settings']['backup.automatic.dirtySince'] = '1970-01-01T00:00:00.000Z'
        after = copy.deepcopy(before)
        after.update(android_epoch_start=100010, android_epoch_end=100011,
                     uptime_seconds=10010)
        after['work']['run_attempt_count'] = 1
        after['settings']['backup.automatic.lastBackupAt'] = '1970-01-02T03:46:50.000Z'
        report = observer.compare_snapshots(before, after, mode='revoked',
                                             revocation_verified=True)
        self.assertEqual(report['status'], 'failed')

    def test_owner_write_grant_is_scoped_to_exact_tree(self):
        text = '* UID 1010223 holds:\n UriPermission{a ' + TREE + ' [user 10]}\n persisted=0x3\n'
        self.assertTrue(observer.has_persisted_write_grant(text, TREE))
        self.assertFalse(observer.has_persisted_write_grant(text, TREE + 'Other'))
        self.assertFalse(observer.has_persisted_write_grant(text.replace('0x3', '0x1'), TREE))

    def test_provider_checksum_and_bytes_are_validated(self):
        data = {'matches': [], 'appSettings': []}
        manifest = {'appName': 'HoopTrace', 'appVersion': '2.0.0+4',
                    'formatVersion': 2, 'schemaVersion': 3,
                    'exportedAt': '2026-10-05T00:00:00.000Z',
                    'recordCounts': {'matches': 0, 'appSettings': 0}}
        signed = json.dumps({'manifest': manifest, 'data': data},
                            ensure_ascii=False, separators=(',', ':')).encode()
        manifest['checksum'] = hashlib.sha256(signed).hexdigest()
        payload = json.dumps({'manifest': manifest, 'data': data},
                             ensure_ascii=False, separators=(',', ':')).encode()
        result = observer.validate_json_envelope(payload)
        self.assertTrue(result['json_envelope_valid'])
        damaged = payload.replace(b'"matches":[]', b'"matches":[{}]')
        with self.assertRaises(ValueError):
            observer.validate_json_envelope(damaged)

    def test_manifest_accepts_both_brand_names_and_rejects_other_apps(self):
        data = {'matches': []}
        for brand in ('Hoopito', 'HoopTrace', 'AnotherApp'):
            with self.subTest(brand=brand):
                manifest = {'appName': brand, 'appVersion': '2.0.0+4',
                            'formatVersion': 2, 'schemaVersion': 3,
                            'exportedAt': '2026-10-12T00:00:00.000Z',
                            'recordCounts': {'matches': 0}}
                manifest['checksum'] = observer.sha256(observer.encode({
                    'manifest': manifest, 'data': data,
                }))
                payload = observer.encode({'manifest': manifest, 'data': data})
                if brand == 'AnotherApp':
                    with self.assertRaises(ValueError):
                        observer.validate_json_envelope(payload)
                else:
                    self.assertTrue(observer.validate_json_envelope(payload)['json_envelope_valid'])

    def test_output_rejects_repo_paths_and_existing_evidence(self):
        with self.assertRaises(ValueError):
            observer.check_output(TOOL.parent / 'must-not-write-evidence')
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                observer.check_output(Path(directory))


if __name__ == '__main__':
    unittest.main()

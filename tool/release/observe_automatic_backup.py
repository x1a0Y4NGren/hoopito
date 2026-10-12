"""Read-only observations of synthetic Android automatic-backup acceptance.

Snapshot reads the installed APK, stable app/WorkManager SQLite copies, scoped
logs and grants, and a fresh acceptance-receiver SAF listing. It never starts
the app/worker, changes clocks, injects due metadata, revokes grants, or roots
the device. Verify classifies saved evidence; a short wait remains pending.
All device data and output must stay outside Git checkouts.
"""

import argparse
from contextlib import closing
import hashlib
import json
import re
import sqlite3
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = 'io.github.x1a0y4ngren.hooptrace'
RECEIVER = PACKAGE + '.acceptance_receiver'
WORKER = PACKAGE + '.AutomaticBackupWorker'
WORK_NAME = 'hooptrace.automatic-backup'
BUSINESS_TABLES = (
    'matches', 'match_participants', 'match_clocks', 'active_sessions',
    'match_events', 'shot_locations', 'players', 'rule_templates',
    'possession_segments', 'audit_logs', 'player_analytics_snapshots',
)
PREFIX = 'backup.automatic.'
DAY_SECONDS = 86400


def sha256(value):
    return hashlib.sha256(value).hexdigest()


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode('utf-8')


def check_output(output):
    output = output.resolve()
    checkouts = [ROOT]
    listing = subprocess.check_output(['git', 'worktree', 'list', '--porcelain'], cwd=ROOT)
    checkouts.extend(Path(line[9:]).resolve() for line in listing.decode().splitlines()
                     if line.startswith('worktree '))
    if any(output.is_relative_to(checkout) for checkout in checkouts):
        raise ValueError('Evidence output must be outside every repository checkout')
    if output.exists():
        raise ValueError(f'Evidence already exists; choose a new output: {output}')
    return output


def utc_epoch(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()


def has_persisted_write_grant(scoped_grants, tree):
    for block in re.split(r'(?=\s*UriPermission\{)', scoped_grants):
        match = re.search(r'UriPermission\{\S+\s+(\S+)\s', block)
        persisted = re.search(r'\bpersisted(?:ModeFlags)?=(0x[0-9a-fA-F]+)', block)
        if match and match[1] == tree and persisted and int(persisted[1], 16) & 2:
            return True
    return False


def validate_json_envelope(payload):
    if len(payload) > 32 * 1024 * 1024:
        raise ValueError('Backup exceeds the shared 32 MiB limit')
    document = json.loads(payload)
    manifest, data = document['manifest'], document['data']
    if (manifest['appName'] not in ('Hoopito', 'HoopTrace')
            or (manifest['formatVersion'], manifest['schemaVersion']) != (2, 3)):
        raise ValueError('Expected Hoopito or legacy HoopTrace JSON format 2 / schema 3')
    source_manifest = {key: manifest[key] for key in (
        'appName', 'appVersion', 'formatVersion', 'schemaVersion', 'exportedAt', 'recordCounts',
    )}
    if sha256(encode({'manifest': source_manifest, 'data': data})) != manifest['checksum']:
        raise ValueError('Backup envelope checksum mismatch')
    if not isinstance(data, dict) or set(data) != set(manifest['recordCounts']):
        raise ValueError('Backup table names and record counts disagree')
    total = 0
    for table, rows in data.items():
        if not isinstance(rows, list) or len(rows) != manifest['recordCounts'][table]:
            raise ValueError(f'Backup row count mismatch: {table}')
        if len(rows) > 100000 or not all(isinstance(row, dict) for row in rows):
            raise ValueError(f'Invalid or oversized backup table: {table}')
        total += len(rows)
    if total > 200000:
        raise ValueError('Backup exceeds the shared 200000 total-row limit')
    return {'json_envelope_valid': True, 'record_counts': manifest['recordCounts'],
            'exported_at': manifest['exportedAt'], 'production_restore_verified': False}


class Adb:
    def __init__(self, executable, serial, user):
        self.executable, self.serial, self.user = str(executable), serial, str(user)

    def read(self, *arguments, optional=False):
        process = subprocess.run([self.executable, '-s', self.serial, *arguments],
                                 capture_output=True, timeout=30)
        if process.returncode:
            if optional and b'No such file or directory' in process.stderr + process.stdout:
                return None
            raise ValueError('Read-only adb command failed: ' + ' '.join(arguments) + '\n' +
                             process.stderr.decode('utf-8', errors='replace'))
        return process.stdout

    def text(self, *arguments):
        return self.read(*arguments).decode('utf-8', errors='replace').strip()

    def private(self, filename, package=PACKAGE, optional=False):
        return self.read('exec-out', 'run-as', package, '--user', self.user,
                         'cat', filename, optional=optional)


def stable_database(adb, device_path, output):
    """Read base+WAL twice unchanged, then consolidate only on the host."""
    paths = [device_path, device_path + '-wal']
    for _attempt in range(3):
        first = [adb.private(path, optional=index > 0) for index, path in enumerate(paths)]
        second = [adb.private(path, optional=index > 0) for index, path in enumerate(paths)]
        if first != second:
            continue
        with tempfile.TemporaryDirectory(prefix='hoopito-observer-', dir=output.parent) as scratch:
            local = Path(scratch) / 'database.sqlite'
            local.write_bytes(first[0])
            if first[1] is not None:
                local.with_name(local.name + '-wal').write_bytes(first[1])
            # Writable host scratch permits SQLite to rebuild SHM. Device files
            # never receive a checkpoint, connection, lock or write.
            with closing(sqlite3.connect(local)) as connection:
                connection.execute('PRAGMA query_only=ON')
                if connection.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                    raise ValueError(f'SQLite integrity_check failed: {device_path}')
                if connection.execute('PRAGMA foreign_key_check').fetchall():
                    raise ValueError(f'SQLite foreign_key_check failed: {device_path}')
                with closing(sqlite3.connect(output)) as destination:
                    connection.backup(destination)
        return {'device_path': device_path, 'stable_read_pairs': 2,
                'base_sha256': sha256(first[0]),
                'wal_sha256': sha256(first[1]) if first[1] is not None else None,
                'snapshot_sha256': sha256(output.read_bytes())}
    raise ValueError(f'Database changed across three bounded reads; retry later: {device_path}')


def app_database_summary(path):
    with closing(sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True)) as connection:
        connection.row_factory = sqlite3.Row
        if connection.execute('PRAGMA user_version').fetchone()[0] != 3:
            raise ValueError('Expected app database schema 3')
        tables = {}
        for table in BUSINESS_TABLES:
            rows = [dict(row) for row in connection.execute(
                f'SELECT rowid AS _rowid_, * FROM "{table}" ORDER BY rowid')]
            tables[table] = {'count': len(rows), 'sha256': sha256(encode(rows))}
        settings = [dict(row) for row in connection.execute(
            'SELECT rowid AS _rowid_, * FROM app_settings ORDER BY rowid')]
        non_backup = [row for row in settings if not row['key'].startswith(PREFIX)]
        tables['app_settings_non_backup'] = {'count': len(non_backup), 'sha256': sha256(encode(non_backup))}
        return tables, {row['key']: json.loads(row['value_json']) for row in settings
                        if row['key'].startswith(PREFIX)}


def work_database_summary(path):
    with closing(sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True)) as connection:
        connection.row_factory = sqlite3.Row
        rows = connection.execute(
            'SELECT w.* FROM WorkSpec w JOIN WorkName n ON n.work_spec_id=w.id '
            'WHERE n.name=? AND w.worker_class_name=? AND w.state NOT IN (2,3,5)',
            (WORK_NAME, WORKER)).fetchall()
        if len(rows) != 1:
            raise ValueError('Expected exactly one live unique automatic-backup WorkSpec')
        return {key: ({'bytes': len(value), 'sha256': sha256(value)}
                      if isinstance(value, bytes) else value) for key, value in dict(rows[0]).items()}


def uid_grants(text, uid):
    selected, recording = [], False
    for line in text.splitlines():
        if re.search(r'\* UID \d+ holds:', line):
            recording = f'* UID {uid} holds:' in line
        if recording:
            selected.append(line)
    return '\n'.join(selected)


def provider_files(adb, tree, epoch, output):
    raw = adb.private('files/latest-proof.json', package=RECEIVER)
    proof = json.loads(raw)
    if proof.get('tree') != tree or 'inspection' not in proof:
        raise ValueError('Receiver must freshly inspect the exact configured synthetic SAF tree')
    age = epoch - int(proof['capture_id']) / 1000
    if not -10 <= age <= 300:
        raise ValueError('Receiver listing is stale; inspect the synthetic folder again before snapshot')
    if len(proof['files']) > 50:
        raise ValueError('Too many provider files for bounded synthetic observation')
    (output / 'provider-proof.json').write_bytes(raw)
    result = []
    for item in proof['files']:
        name, private_name = item['display_name'], item['private_filename']
        if not re.fullmatch(r'(?:hoopito|hooptrace)-(auto|backup)-[A-Za-z0-9._-]+\.json', name):
            raise ValueError('Receiver listed an unexpected backup filename')
        if Path(private_name).name != private_name or '/' in private_name or '\\' in private_name or '..' in private_name:
            raise ValueError('Unsafe receiver private filename')
        payload = adb.private('files/received/' + private_name, package=RECEIVER)
        if len(payload) != item['bytes'] or sha256(payload) != item['sha256']:
            raise ValueError('Receiver copy byte count or SHA-256 mismatch')
        if item.get('provider_size') != len(payload) or item.get('provider_mime') != 'application/json':
            raise ValueError('Receiver provider size or MIME mismatch')
        summary = validate_json_envelope(payload)
        (output / name).write_bytes(payload)
        result.append({**item, **summary})
    return result


def snapshot(args):
    output = check_output(args.output)
    if args.user <= 0 or not args.synthetic_user_name or not args.serial:
        raise ValueError('An explicitly named synthetic secondary Android user and serial are required')
    if not re.fullmatch(r'[0-9a-fA-F]{40}', args.source_commit):
        raise ValueError('--source-commit must be the actual APK source commit')
    if not re.fullmatch(r'[0-9a-fA-F]{64}', args.expected_apk_sha256):
        raise ValueError('--expected-apk-sha256 must identify the installed candidate')
    adb = Adb(args.adb, args.serial, args.user)
    users = adb.text('shell', 'pm', 'list', 'users')
    if not re.search(r'UserInfo\{' + str(args.user) + ':' + re.escape(args.synthetic_user_name) + r':', users):
        raise ValueError('Android user id/name does not match the declared synthetic user')
    if adb.text('shell', 'am', 'get-current-user') != str(args.user):
        raise ValueError('Synthetic user must be the current user for provider inspection')
    epoch = int(adb.text('shell', 'date', '+%s'))
    uptime = float(adb.text('shell', 'cat', '/proc/uptime').split()[0])
    boot_id = adb.text('shell', 'cat', '/proc/sys/kernel/random/boot_id')
    uid = int(adb.text('exec-out', 'run-as', PACKAGE, '--user', str(args.user), 'id', '-u'))
    if uid // 100000 != args.user:
        raise ValueError('run-as UID is outside the declared synthetic user')
    paths = adb.text('shell', 'pm', 'path', '--user', str(args.user), PACKAGE).splitlines()
    apk_files = []
    for line in paths:
        if not line.startswith('package:') or not line[8:].startswith('/data/app/') or not line.endswith('.apk'):
            raise ValueError('Unexpected installed APK path')
        apk_files.append({'path': line[8:], 'sha256': sha256(adb.read('exec-out', 'cat', line[8:]))})
    base = next((item for item in apk_files if item['path'].endswith('/base.apk')), None)
    if base is None or base['sha256'] != args.expected_apk_sha256.lower():
        raise ValueError('Installed base.apk does not match the expected APK SHA-256')
    output.mkdir(parents=True)
    try:
        app_copy = stable_database(adb, 'app_flutter/hooptrace.sqlite', output / 'app.sqlite')
        work_copy = stable_database(adb, 'no_backup/androidx.work.workdb', output / 'work.sqlite')
        tables, settings = app_database_summary(output / 'app.sqlite')
        tree = settings.get(PREFIX + 'directory', '')
        decoded_tree = unquote(tree)
        if not decoded_tree.startswith((
                'content://com.android.externalstorage.documents/tree/primary:Documents/HoopitoV2Synthetic',
                'content://com.android.externalstorage.documents/tree/primary:Documents/HoopTraceV2Synthetic')):
            raise ValueError('Only the explicitly configured synthetic Documents tree is allowed')
        files = provider_files(adb, tree, epoch, output)
        grants = uid_grants(adb.text('shell', 'dumpsys', 'activity', 'permissions'), uid)
        activity = [line.strip() for line in adb.text('shell', 'dumpsys', 'activity', 'activities').splitlines()
                    if 'topResumedActivity=' in line or 'mResumedActivity:' in line]
        log_lines = [line for line in adb.text('logcat', '-d', f'--uid={uid}', '-v', 'epoch').splitlines()
                     if WORKER in line and ('Starting work' in line or 'Worker result ' in line)]
        (output / 'grants.txt').write_text(grants, encoding='utf-8')
        (output / 'worker-log.txt').write_text('\n'.join(log_lines) + '\n', encoding='utf-8')
        report = {
            'format_version': 1, 'synthetic_only': True, 'serial': args.serial, 'user': args.user,
            'user_name': args.synthetic_user_name, 'uid': uid,
            'source_commit': args.source_commit.lower(), 'apk_sha256': base['sha256'],
            'apk_files': apk_files, 'android_epoch_start': epoch,
            'android_epoch_end': int(adb.text('shell', 'date', '+%s')),
            'uptime_seconds': uptime, 'boot_id': boot_id,
            'host_captured_at_utc': datetime.now(timezone.utc).isoformat(),
            'app_database_capture': app_copy, 'work_database_capture': work_copy,
            'tables': tables, 'settings': settings, 'work': work_database_summary(output / 'work.sqlite'),
            'persisted_write_grant': has_persisted_write_grant(grants, tree),
            'foreground_lines': activity,
            'foreground_app': any(PACKAGE + '/' in line and f'u{args.user} ' in line for line in activity),
            'provider_files': files, 'worker_log_lines': log_lines,
            'observer_sha256': sha256(Path(__file__).read_bytes()),
            'mutations': [],
        }
        (output / 'snapshot.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        return {'status': 'captured', 'snapshot': str(output / 'snapshot.json'),
                'android_epoch': epoch, 'dirty': settings.get(PREFIX + 'dirty'),
                'period_count': report['work'].get('period_count')}
    except Exception:
        # Preserve partial evidence outside the checkout for an honest failure.
        (output / 'INCOMPLETE.txt').write_text('Snapshot failed; do not use partial files as acceptance.\n', encoding='utf-8')
        raise


def worker_result_epochs(before, after, result):
    work_id = before['work']['id']
    epochs = []
    for line in after['worker_log_lines']:
        match = re.match(r'\s*(\d+(?:\.\d+)?)\s', line)
        if (match and f'Worker result {result}' in line and WORKER in line and
                re.search(r'\bid=' + re.escape(work_id) + r'[,\s\]]', line) and
                before['android_epoch_end'] <= float(match[1]) <= after['android_epoch_end']):
            epochs.append(float(match[1]))
    return epochs


def worker_success(before, after):
    epochs = worker_result_epochs(before, after, 'SUCCESS')
    last = after['settings'].get(PREFIX + 'lastBackupAt')
    if last:
        backup_at = utc_epoch(last)
        matching = [epoch for epoch in epochs if 0 <= epoch - backup_at <= 600]
        if matching:
            return max(matching)
    return max(epochs, default=None)


def compare_snapshots(before, after, mode, unforced_interval=False,
                      restored_sha256=None, revocation_verified=False):
    failures, pending = [], []
    report = {'mode': mode, 'natural_schedule_observed': False,
              'worker_outcome': 'unobserved', 'failures': failures, 'pending': pending}
    for key in ('serial', 'user', 'user_name', 'uid', 'source_commit', 'apk_sha256'):
        if before[key] != after[key]:
            failures.append(f'Observation provenance changed: {key}')
    if before['tables'] != after['tables']:
        failures.append('Business rows, insertion order, derived snapshots or non-backup settings changed')
    for value in (before, after):
        if value['foreground_app']:
            failures.append('Hoopito was in the foreground at a snapshot')
        if value['tables']['active_sessions']['count']:
            failures.append('An active match existed during observation')
    if before['work']['id'] != after['work']['id']:
        failures.append('Unique WorkSpec was replaced')
    if before['boot_id'] != after['boot_id']:
        pending.append('Device rebooted; bounded observer cannot prove unaltered clock across boots')
    epoch_elapsed = after['android_epoch_start'] - before['android_epoch_start']
    uptime_elapsed = after['uptime_seconds'] - before['uptime_seconds']
    report['android_elapsed_seconds'] = epoch_elapsed
    report['uptime_elapsed_seconds'] = uptime_elapsed
    if before['boot_id'] == after['boot_id'] and abs(epoch_elapsed - uptime_elapsed) > 10:
        failures.append('Android clock elapsed time disagrees with monotonic uptime')
    old, new = before['settings'], after['settings']
    tree = old.get(PREFIX + 'directory')
    if (not old.get(PREFIX + 'enabled') or not old.get(PREFIX + 'dirty') or not tree or
            not old.get(PREFIX + 'dirtySince')):
        failures.append('Baseline must have enabled, configured, anchored dirty backup state')
    dirty_epoch = utc_epoch(old[PREFIX + 'dirtySince']) if old.get(PREFIX + 'dirtySince') else None
    for key in ('directory', 'directoryLabel', 'enabled', 'dirtyRevision', 'retentionLimit'):
        if old.get(PREFIX + key) != new.get(PREFIX + key):
            failures.append(f'Backup observation input changed: {key}')
    if any(value['work'].get('interval_duration') != DAY_SECONDS * 1000 for value in (before, after)):
        failures.append('WorkManager interval is not 24 hours')
    if before['work'].get('generation') != after['work'].get('generation'):
        failures.append('WorkManager request generation changed')
    completed = (after['work'].get('period_count', 0) > before['work'].get('period_count', 0)
                 and after['work'].get('state') == 0 and after['work'].get('run_attempt_count') == 0)
    success_epoch = worker_success(before, after)
    if not completed or success_epoch is None:
        pending.append('Need completed unique WorkSpec period and matching scoped Worker SUCCESS log')
    report['worker_success_epoch'] = success_epoch
    if mode == 'natural':
        if not unforced_interval:
            pending.append('Declare interval with no job forcing, clock/due injection, app launch or match finish')
        if epoch_elapsed < DAY_SECONDS or uptime_elapsed < DAY_SECONDS:
            pending.append('Natural observation has not elapsed 24 actual Android/uptime hours')
        if dirty_epoch is not None and not 0 <= before['android_epoch_start'] - dirty_epoch <= 300:
            failures.append('Natural baseline dirty anchor must be a fresh ordinary change, not backdated metadata')
        if not before['persisted_write_grant'] or not after['persisted_write_grant']:
            failures.append('Natural write observation requires its persisted SAF write grant')
        old_files = {(item['display_name'], item['sha256']) for item in before['provider_files']}
        new_files = [item for item in after['provider_files']
                     if (item['display_name'], item['sha256']) not in old_files
                     and item['display_name'].startswith(('hoopito-auto-', 'hooptrace-auto-'))]
        path_name = unquote(new.get(PREFIX + 'lastBackupPath', '')).rsplit('/', 1)[-1]
        matching = [item for item in new_files if item['display_name'] == path_name and item.get('json_envelope_valid')]
        last = utc_epoch(new[PREFIX + 'lastBackupAt']) if new.get(PREFIX + 'lastBackupAt') else None
        if not (matching and not new.get(PREFIX + 'dirty') and PREFIX + 'dirtySince' not in new and
                old.get(PREFIX + 'lastBackupAt') != new.get(PREFIX + 'lastBackupAt') and
                last is not None and dirty_epoch is not None and last >= dirty_epoch + DAY_SECONDS):
            pending.append('Need new matching valid automatic JSON, advanced lastBackupAt and cleared dirty anchor')
        elif success_epoch is not None and not 0 <= success_epoch - last <= 600:
            failures.append('Backup timestamp does not belong to the observed Worker completion window')
        report['backup_sha256'] = matching[0]['sha256'] if len(matching) == 1 else None
        observation_pending = list(pending)
        if restored_sha256 != report['backup_sha256'] or restored_sha256 is None:
            pending.append('Need production codec restore evidence for the exact new backup SHA-256')
        report['natural_schedule_observed'] = not failures and not observation_pending
        if report['natural_schedule_observed']:
            report['worker_outcome'] = 'write_observed'
    elif mode == 'revoked':
        if not revocation_verified:
            pending.append('Need actual own-grant release proof, including valid before and absent after')
        if before['persisted_write_grant'] or after['persisted_write_grant']:
            failures.append('Revoked observation still has a persisted SAF write grant')
        if dirty_epoch is not None and before['android_epoch_start'] < dirty_epoch + DAY_SECONDS:
            failures.append('Revoked Worker baseline is not due; no-op success cannot prove grant refusal')
        if old != new:
            failures.append('Backup metadata changed under the revoked grant')
        if {(item['display_name'], item['sha256']) for item in before['provider_files']} != {
                (item['display_name'], item['sha256']) for item in after['provider_files']}:
            failures.append('Provider backup files changed under the revoked grant')
        if (after['work'].get('run_attempt_count', 0) > before['work'].get('run_attempt_count', 0)
                or worker_result_epochs(before, after, 'RETRY')):
            failures.append('Worker retried; missing-authorization skip has not been established')
        if not failures and not pending:
            report['worker_outcome'] = 'inferred_missing_authorization'
    else:
        raise ValueError('Unknown observation mode')
    report['status'] = 'failed' if failures else ('pending' if pending else 'passed')
    return report


def verify(args):
    output = check_output(args.output)
    before = json.loads(args.baseline.read_text(encoding='utf-8'))
    after = json.loads(args.after.read_text(encoding='utf-8'))
    restored = None
    attachments = {}
    if args.restore_proof:
        proof = json.loads(args.restore_proof.read_text(encoding='utf-8'))
        if (proof.get('source_commit') != before['source_commit'] or
                not all(proof.get(key) is True for key in ('decode_and_validate', 'restore', 'round_trip'))):
            raise ValueError('Restore proof must identify source and actual codec validation/restore/round-trip')
        for field in ('log', 'test_source'):
            path = Path(proof[field + '_path'])
            if sha256(path.read_bytes()) != proof[field + '_sha256']:
                raise ValueError(f'Restore proof {field} hash mismatch')
        restored = proof['backup_sha256']
        attachments['restore_proof_sha256'] = sha256(args.restore_proof.read_bytes())
    revoked = False
    if args.revocation_proof:
        proof = json.loads(args.revocation_proof.read_text(encoding='utf-8'))
        tree = before['settings'][PREFIX + 'directory']
        revoked = (proof.get('tree_uri') == tree and
                   has_persisted_write_grant(proof.get('before', ''), tree) and
                   not has_persisted_write_grant(proof.get('after', ''), tree) and
                   f"UID={before['uid']}" in proof.get('release_helper_log', '') and
                   tree in proof.get('release_helper_log', ''))
        if not revoked:
            raise ValueError('Actual scoped own-grant revocation evidence does not match the snapshot')
        attachments['revocation_proof_sha256'] = sha256(args.revocation_proof.read_bytes())
    report = compare_snapshots(before, after, args.mode, args.unforced_interval,
                               restored, revoked)
    report.update(attachments)
    report.update(baseline_sha256=sha256(args.baseline.read_bytes()),
                  after_sha256=sha256(args.after.read_bytes()),
                  source_commit=before['source_commit'], apk_sha256=before['apk_sha256'])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    capture = actions.add_parser('snapshot', help='Read synthetic device state without mutations')
    capture.add_argument('--adb', type=Path, default=Path('D:/Android/Sdk/platform-tools/adb.exe'))
    capture.add_argument('--serial', required=True)
    capture.add_argument('--user', type=int, default=10)
    capture.add_argument('--synthetic-user-name', required=True)
    capture.add_argument('--source-commit', required=True)
    capture.add_argument('--expected-apk-sha256', required=True)
    capture.add_argument('--output', type=Path, required=True)
    comparison = actions.add_parser('verify', help='Classify existing snapshots; never trigger a job')
    comparison.add_argument('--baseline', type=Path, required=True)
    comparison.add_argument('--after', type=Path, required=True)
    comparison.add_argument('--mode', choices=['natural', 'revoked'], required=True)
    comparison.add_argument('--unforced-interval', action='store_true',
                            help='Attest no forcing, clock/due injection, app launch or match finish between snapshots')
    comparison.add_argument('--restore-proof', type=Path)
    comparison.add_argument('--revocation-proof', type=Path)
    comparison.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        report = snapshot(args) if args.action == 'snapshot' else verify(args)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 1 if report['status'] == 'failed' else (2 if report['status'] == 'pending' else 0)
    except (ValueError, KeyError, OSError, sqlite3.Error, subprocess.SubprocessError) as error:
        parser.exit(1, f'Observation error: {error}\n')


if __name__ == '__main__':
    raise SystemExit(main())

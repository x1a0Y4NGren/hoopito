"""Generate a synthetic schema-2 file with the released v1 command service.

Uses only existing dependencies and an already compiled SQLite library. Does
not run pub, native hooks, Flutter or Gradle, access signing credentials, or
connect to a device. Output must be outside the checkout and must not exist.
"""

import argparse
from contextlib import closing
import hashlib
import io
import json
import platform
import shutil
import sqlite3
import subprocess
import tempfile
import zipfile
from pathlib import Path
from urllib.parse import urljoin


ROOT = Path(__file__).resolve().parents[2]
SOURCE_REF = 'v1.0.0'
SOURCE_COMMIT = 'd8d2937a2d9543c1f0125a1d2d6c4de59f36046e'


def git(*arguments):
    return subprocess.check_output(['git', *arguments], cwd=ROOT)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(database, baseline_path, expected_schema):
    baseline = json.loads(baseline_path.read_text(encoding='utf-8'))
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True)) as connection:
        connection.row_factory = sqlite3.Row
        if connection.execute('PRAGMA user_version').fetchone()[0] != expected_schema:
            raise ValueError(f'Expected schema {expected_schema}')
        if connection.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('SQLite integrity_check failed')
        if connection.execute('PRAGMA foreign_key_check').fetchall():
            raise ValueError('SQLite foreign_key_check failed')
        for table, expected_rows in baseline['tables'].items():
            # Names are fixture schema constants, never arbitrary query input.
            if table not in {'matches', 'players', 'match_participants', 'match_clocks',
                             'active_sessions', 'match_events', 'shot_locations',
                             'rule_templates', 'possession_segments', 'audit_logs', 'app_settings'}:
                raise ValueError(f'Unexpected baseline table: {table}')
            actual = [dict(row) for row in connection.execute(
                f'SELECT rowid AS _rowid_, * FROM "{table}" ORDER BY rowid'
            )]
            if table in ('app_settings', 'rule_templates'):
                # Bootstrap may seed preferences/built-in templates, but may
                # not alter any original fixture row or its durable order.
                key = 'key' if table == 'app_settings' else 'id'
                identifiers = {expected[key] for expected in expected_rows}
                actual = [row for row in actual if row[key] in identifiers]
            if actual != expected_rows:
                raise ValueError(f'Original rows or durable insertion order changed: {table}')
    return {'schema': expected_schema, 'canonical_tables_unchanged': len(baseline['tables']),
            'integrity_check': 'ok', 'foreign_key_check': 'ok'}


def prepare(output, dart, sqlite_library, package_config):
    output = output.resolve()
    if output.is_relative_to(ROOT):
        raise ValueError('Fixture output must be outside the checkout')
    if output.exists():
        raise ValueError(f'Fixture output already exists: {output}')
    source_commit = git('rev-parse', f'{SOURCE_REF}^{{commit}}').decode().strip()
    if source_commit != SOURCE_COMMIT:
        raise ValueError('v1.0.0 tag no longer matches the recorded release source')
    if not dart.is_file() or not sqlite_library.is_file() or not package_config.is_file():
        raise ValueError('Existing Dart executable, package config and compiled SQLite are required')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f'.{output.name}-', dir=output.parent) as scratch:
        staging = Path(scratch)
        source = staging / 'v1-source'
        source.mkdir()
        with zipfile.ZipFile(io.BytesIO(git('archive', '--format=zip', SOURCE_REF, 'lib'))) as archive:
            archive.extractall(source)
        config = json.loads(package_config.read_text(encoding='utf-8'))
        for package in config['packages']:
            if package['name'] in ('hoopito', 'hooptrace'):
                # The authentic archived v1 source still imports hooptrace.
                # Bind the current project's dependencies to that old name
                # only inside this isolated historical fixture compiler.
                package['name'] = 'hooptrace'
                package['rootUri'] = source.as_uri() + '/'
            else:
                package['rootUri'] = urljoin(
                    package_config.resolve().as_uri(), package['rootUri'],
                )
        isolated_config = staging / 'package_config.json'
        isolated_config.write_text(json.dumps(config), encoding='utf-8')
        target = {'Windows': 'windows', 'Linux': 'linux', 'Darwin': 'macos'}[platform.system()]
        architecture = 'arm64' if platform.machine().lower() in ('aarch64', 'arm64') else 'x64'
        native_assets = staging / 'native_assets.json'
        native_assets.write_text(json.dumps({
            'format-version': [1, 0, 0],
            'native-assets': {f'{target}_{architecture}': {
                'package:sqlite3/src/ffi/libsqlite3.g.dart': ['absolute', str(sqlite_library.resolve())],
            }},
        }), encoding='utf-8')
        generator = staging / 'generate_fixture.dart'
        shutil.copyfile(ROOT / 'tool/release/generate_v1_upgrade_fixture.dart', generator)
        generated = staging / 'fixture'
        generated.mkdir()
        # gen_kernel accepts the asset map; passing it to the VM directly does
        # not. Calling the compiler snapshot explicitly bypasses pub/hooks.
        sdk = dart.resolve().parent.parent
        runtime = dart.parent / ('dartaotruntime.exe' if platform.system() == 'Windows' else 'dartaotruntime')
        kernel = staging / 'generate_fixture.dill'
        subprocess.run([
            str(runtime), str(sdk / 'bin/snapshots/gen_kernel_aot.dart.snapshot'),
            f'--platform={sdk / "lib/_internal/vm_platform_strong.dill"}',
            f'--packages={isolated_config}', f'--native-assets={native_assets}',
            f'--output={kernel}', str(generator),
        ], cwd=staging, check=True)
        subprocess.run([str(dart), str(kernel), str(generated)], cwd=staging, check=True)
        baseline_path = generated / 'baseline.json'
        baseline = json.loads(baseline_path.read_text(encoding='utf-8'))
        baseline.update({
            'source_ref': SOURCE_REF, 'source_commit': source_commit,
            'schema_snapshot_sha256': hashlib.sha256(git(
                'show', f'{SOURCE_REF}:drift_schemas/drift_schema_v2.json',
            )).hexdigest(),
            'generator_sha256': digest(generator),
            'database_sha256': digest(generated / 'hooptrace.sqlite'),
            'sqlite_library_sha256': digest(sqlite_library),
            'dart_version': subprocess.check_output([str(dart), '--version'], text=True).strip(),
        })
        baseline_path.write_text(json.dumps(baseline, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        verify(generated / 'hooptrace.sqlite', baseline_path, 2)
        generated.replace(output)
    return baseline


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--dart', type=Path)
    parser.add_argument('--sqlite-library', type=Path)
    parser.add_argument('--package-config', type=Path, default=ROOT / '.dart_tool/package_config.json')
    parser.add_argument('--verify', type=Path)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--expected-schema', type=int, choices=[2, 3], default=3)
    args = parser.parse_args()
    try:
        if args.verify:
            if args.output or not args.baseline:
                raise ValueError('--verify requires --baseline and cannot be combined with --output')
            print(json.dumps(verify(args.verify, args.baseline, args.expected_schema)))
            return
        if not args.output:
            raise ValueError('--output is required for fixture generation')
        dart = args.dart or Path(shutil.which('dart') or '')
        if not dart.is_file() or dart.suffix.lower() in ('.bat', '.cmd'):
            # The actual VM bypasses pub/hooks and avoids batch-shell quoting.
            local = (ROOT / 'android/local.properties').read_text(encoding='utf-8')
            sdk = next(line.split('=', 1)[1].replace('\\\\', '/')
                       for line in local.splitlines() if line.startswith('flutter.sdk='))
            dart = Path(sdk) / 'bin/cache/dart-sdk/bin/dart.exe'
        libraries = list((ROOT / '.dart_tool/hooks_runner/shared/sqlite3/build').glob('*/*'))
        library_name = {'Windows': 'sqlite3.dll', 'Linux': 'libsqlite3.so',
                        'Darwin': 'libsqlite3.dylib'}[platform.system()]
        sqlite_library = args.sqlite_library or next(
            (path for path in libraries if path.name == library_name),
            Path('missing-compiled-sqlite'),
        )
        baseline = prepare(args.output, dart, sqlite_library, args.package_config)
        print(json.dumps({'output': str(args.output.resolve()), 'source_commit': baseline['source_commit'],
                          'schema': baseline['schema'], 'sha256': baseline['database_sha256'],
                          'commands': len(baseline['commands'])}))
    except (ValueError, OSError, subprocess.CalledProcessError, StopIteration) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()

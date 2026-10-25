import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';

import '../../test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('backup metadata survives repeated domain and setting upserts', () async {
    final database = createTestDatabase();
    await _seedMetadata(database);
    await database.ensureBackupDirtyTriggers();
    final rules = RuleTemplateRepository(database);
    await rules.ensureBuiltIns();
    await rules.ensureBuiltIns();
    expect(await _value(database, 'dirtyRevision'), 15);
    expect(await _value(database, 'dirty'), isTrue);
    expect(await _value(database, 'dirtySince'), _anchor);

    for (final mode in [
      InsertMode.insert,
      InsertMode.insertOrReplace,
      InsertMode.insertOrIgnore,
    ]) {
      final before = await _value(database, 'dirtyRevision') as int;
      final id = mode.name;
      await database
          .into(database.players)
          .insert(
            PlayerRow(id: id, nickname: id, createdAt: DateTime.utc(2026)),
            mode: mode,
          );
      await database
          .into(database.players)
          .insertOnConflictUpdate(
            PlayerRow(
              id: id,
              nickname: 'Updated $id',
              createdAt: DateTime.utc(2026),
            ),
          );
      expect(await _value(database, 'dirtyRevision'), before + 2);
      expect(await _value(database, 'dirtySince'), _anchor);
      if (mode != InsertMode.insert) {
        await database
            .into(database.players)
            .insert(
              PlayerRow(
                id: id,
                nickname: 'Repeated $id',
                createdAt: DateTime.utc(2026),
              ),
              mode: mode,
            );
        expect(
          await _value(database, 'dirtyRevision'),
          before + (mode == InsertMode.insertOrReplace ? 3 : 2),
        );
        expect(await _value(database, 'dirtySince'), _anchor);
      }
    }

    for (final value in ['"en"', '"zh"']) {
      final before = await _value(database, 'dirtyRevision') as int;
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSetting(
              key: 'language',
              valueJson: value,
              updatedAt: DateTime.utc(2026),
            ),
          );
      expect(await _value(database, 'dirtyRevision'), before + 1);
      expect(await _value(database, 'dirtySince'), _anchor);
    }
    final before = await _value(database, 'dirtyRevision');
    await database.customStatement(
      "UPDATE app_settings SET value_json = 'false' WHERE key = 'backup.automatic.dirty'",
    );
    await database.customStatement(
      "DELETE FROM app_settings WHERE key = 'backup.automatic.dirtySince'",
    );
    await expectLater(
      database.transaction(() async {
        await rules.ensureBuiltIns();
        throw StateError('transaction failure');
      }),
      throwsStateError,
    );
    expect(await _value(database, 'dirtyRevision'), before);
    expect(await _value(database, 'dirty'), isFalse);
    expect(
      await (database.select(database.appSettings)
            ..where((row) => row.key.equals('backup.automatic.dirtySince')))
          .getSingleOrNull(),
      isNull,
    );
    expect(await _value(database, 'directory'), '/synthetic/approved');
  });

  test(
    'startup repairs old file triggers before writing built-in rules',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hoopito-old-dirty-trigger-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/synthetic.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      try {
        await RuleTemplateRepository(first).ensureBuiltIns();
        await first
            .into(first.players)
            .insert(
              PlayerRow(
                id: 'synthetic-player',
                nickname: 'Jordan',
                createdAt: DateTime.utc(2026),
              ),
            );
        await _seedMetadata(first);
        // Persist the exact conflict-sensitive trigger shipped before the fix.
        // A new process must repair it before startup's rule UPSERT fires it.
        await first.customStatement('''
        CREATE TRIGGER backup_dirty_rule_templates_update
        AFTER UPDATE ON rule_templates
        WHEN EXISTS(SELECT 1 FROM app_settings
          WHERE key = 'backup.automatic.enabled' AND value_json = 'true')
        BEGIN
          INSERT OR IGNORE INTO app_settings(key, value_json, updated_at)
            VALUES('backup.automatic.dirtyRevision', '0', unixepoch());
          INSERT OR IGNORE INTO app_settings(key, value_json, updated_at)
            VALUES('backup.automatic.dirtySince', '"2026-10-01T00:00:00.000Z"', unixepoch());
          UPDATE app_settings SET value_json = CAST(CAST(value_json AS INTEGER) + 1 AS TEXT)
            WHERE key = 'backup.automatic.dirtyRevision';
          INSERT OR REPLACE INTO app_settings(key, value_json, updated_at)
            VALUES('backup.automatic.dirty', 'true', unixepoch());
        END
      ''');
      } finally {
        await first.close();
      }

      final reopened = openAppDatabaseAt(file);
      await reopened.assertCompatible();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(reopened),
          startupAutomaticBackupProvider.overrideWith((ref) => () async {}),
        ],
      );
      final initialized = Completer<AsyncValue<DatabaseBootstrapState>>();
      final startup = container.listen(databaseStartupProvider, (_, next) {
        if (!initialized.isCompleted && (next.hasValue || next.hasError)) {
          initialized.complete(next);
        }
      }, fireImmediately: true);
      try {
        expect((await initialized.future).requireValue.isReady, isTrue);
        expect(
          (await reopened.select(reopened.players).get()).single.nickname,
          'Jordan',
        );
        expect(await _value(reopened, 'enabled'), isTrue);
        expect(await _value(reopened, 'directory'), '/synthetic/approved');
        expect(await _value(reopened, 'dirtyRevision'), 11);
        expect(await _value(reopened, 'dirtySince'), _anchor);
        expect(await _value(reopened, 'dirty'), isTrue);
        expect(
          (await reopened.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        expect(
          (await reopened.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          3,
        );
      } finally {
        startup.close();
        container.dispose();
        await reopened.close();
      }
    },
  );
}

const _anchor = '2026-10-01T00:00:00.000Z';

Future<void> _seedMetadata(AppDatabase database) async {
  for (final entry in <String, Object>{
    'enabled': true,
    'directory': '/synthetic/approved',
    'dirtyRevision': 7,
    'dirty': false,
    'dirtySince': _anchor,
  }.entries) {
    await database
        .into(database.appSettings)
        .insert(
          AppSetting(
            key: 'backup.automatic.${entry.key}',
            valueJson: jsonEncode(entry.value),
            updatedAt: DateTime.utc(2026),
          ),
        );
  }
}

Future<Object?> _value(AppDatabase database, String suffix) async {
  final row = await (database.select(
    database.appSettings,
  )..where((row) => row.key.equals('backup.automatic.$suffix'))).getSingle();
  return jsonDecode(row.valueJson);
}

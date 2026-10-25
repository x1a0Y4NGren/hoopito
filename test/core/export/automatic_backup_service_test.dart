import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:path/path.dart' as path;

import '../../test_helpers/test_database.dart';

void main() {
  group('AutomaticBackupService', () {
    late AppDatabase database;
    late _MemoryBackupStorage storage;
    late AutomaticBackupService service;

    setUp(() {
      database = createTestDatabase();
      storage = _MemoryBackupStorage();
      service = AutomaticBackupService(
        database,
        JsonBackupCodec(
          database,
          appVersion: '0.1.0+1',
          now: () => DateTime.utc(2026, 8, 21, 9, 5, 7),
        ),
        storage: storage,
        now: () => DateTime.utc(2026, 8, 21, 9, 5, 7),
      );
    });

    test(
      'is disabled by default and cannot enable without a directory',
      () async {
        expect(await service.isEnabled(), isFalse);
        expect(
          service.enable,
          throwsA(isA<BackupDirectoryNotConfiguredException>()),
        );
      },
    );

    test('configures a user-approved directory before enabling', () async {
      storage.availableDirectories.add('/approved');

      await service.configureDirectory(
        '/approved',
        displayName: 'Approved backups',
      );
      await service.enable();

      final state = await service.loadState();
      expect(state.enabled, isTrue);
      expect(state.directory, '/approved');
      expect(state.directoryLabel, 'Approved backups');
      expect(storage.files, hasLength(1));
      expect(
        storage.files.single.fileName,
        'hoopito-backup-20260821-090507.json',
      );
      expect(
        jsonDecode(utf8.decode(storage.files.single.bytes)),
        isA<Map<String, dynamic>>(),
      );
    });

    test('enable keeps a mutation during its baseline write dirty', () async {
      final mutatingStorage = _MutatingBackupStorage(database);
      service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '0.1.0+1'),
        storage: mutatingStorage,
      );
      mutatingStorage.availableDirectories.add('/approved');
      await service.configureDirectory('/approved');

      await service.enable();

      expect((await service.loadState()).dirty, isTrue);
      expect(
        (await database.select(database.players).get()).single.id,
        'enable-window-player',
      );
    });

    test('runNow writes a complete backup and records last success', () async {
      storage.availableDirectories.add('/approved');
      await service.configureDirectory('/approved');

      final path = await service.runNow();

      expect(path, '/approved/hoopito-backup-20260821-090507.json');
      final state = await service.loadState();
      expect(state.enabled, isFalse);
      expect(state.lastBackupAt, DateTime.utc(2026, 8, 21, 9, 5, 7));
      expect(state.lastBackupPath, path);
    });

    test(
      'match finish writes an immediate retained automatic backup',
      () async {
        storage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();

        final destination = await service.runAfterMatchFinish();

        expect(destination, isNotNull);
        expect(storage.files, hasLength(2));
        expect(
          storage.files.last.fileName,
          'hoopito-auto-20260821-090507.json',
        );
        expect((await service.loadState()).dirty, isFalse);
      },
    );

    test(
      'reports storage write failures without recording a success',
      () async {
        storage.availableDirectories.add('/approved');
        storage.writeError = FileSystemException('Permission denied');
        await service.configureDirectory('/approved');

        expect(service.runNow, throwsA(isA<AutomaticBackupWriteException>()));
        expect((await service.loadState()).lastBackupAt, isNull);
      },
    );

    test(
      'disables and clears an unsupported legacy directory reference',
      () async {
        const legacyPath = '/storage/emulated/0/HoopitoTest';
        storage.availableDirectories.add(legacyPath);
        await service.configureDirectory(legacyPath);
        await service.enable();
        storage.acceptReferences = false;

        final state = await service.loadState();

        expect(state.enabled, isFalse);
        expect(state.directory, isNull);
        expect(state.directoryLabel, isNull);
        expect(await service.runIfEnabled(), isNull);
      },
    );

    test(
      'disable prevents runIfEnabled and reset clears imported metadata',
      () async {
        storage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();
        await service.disable();
        storage.files.clear();

        expect(await service.runIfEnabled(), isNull);
        await service.resetAfterRestore();
        final state = await service.loadState();
        expect(state.enabled, isFalse);
        expect(state.directory, isNull);
      },
    );

    test(
      'IO storage never overwrites a backup with the same filename',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'hoopito-backup-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        const ioStorage = IoAutomaticBackupStorage();

        final first = await ioStorage.write(
          directory: directory.path,
          fileName: 'backup.json',
          bytes: Uint8List.fromList([1]),
        );
        final second = await ioStorage.write(
          directory: directory.path,
          fileName: 'backup.json',
          bytes: Uint8List.fromList([2]),
        );

        expect(second, isNot(first));
        expect(await File(first).readAsBytes(), [1]);
        expect(await File(second).readAsBytes(), [2]);
      },
    );

    test('IO retention refuses a backup-looking parent traversal', () async {
      final root = await Directory.systemTemp.createTemp(
        'hoopito-retention-guard-',
      );
      addTearDown(() => root.delete(recursive: true));
      final approved = await Directory(
        path.join(root.path, 'approved'),
      ).create();
      final outside = File(path.join(root.path, 'hoopito-auto-outside.json'));
      await outside.writeAsString('keep');

      await const IoAutomaticBackupStorage().deleteFile(
        directory: approved.path,
        fileName: path.join(
          'hoopito-auto-nested',
          '..',
          '..',
          'hoopito-auto-outside.json',
        ),
      );

      expect(await outside.exists(), isTrue);
    });

    test('marks changed data dirty and runs the first due backup', () async {
      var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
      service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
        storage: storage,
        now: () => current,
      );
      storage.availableDirectories.add('/approved');
      await service.configureDirectory('/approved');
      await service.enable();
      await service.markDirty();
      current = current.add(const Duration(hours: 24));

      final destination = await service.runIfDue();

      expect(destination, '/approved/hoopito-auto-20260822-090507.json');
      expect((await service.loadState()).dirty, isFalse);
    });

    test(
      'persists the first dirtySince and starts the due interval there',
      () async {
        var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
        service = AutomaticBackupService(
          database,
          JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
          storage: storage,
          now: () => current,
        );
        storage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();

        current = current.add(const Duration(hours: 1));
        await service.markDirty();
        final firstDirty = await service.loadState();
        expect(firstDirty.dirtySince, current);

        current = current.add(const Duration(hours: 1));
        await service.markDirty();
        expect((await service.loadState()).dirtySince, firstDirty.dirtySince);

        // lastBackupAt is already 24 hours old here, but the dirty period is
        // only 23 hours old and therefore must not run yet.
        current = firstDirty.dirtySince!.add(const Duration(hours: 23));
        expect(await service.runIfDue(), isNull);
        current = firstDirty.dirtySince!.add(const Duration(hours: 24));
        expect(await service.runIfDue(), isNotNull);
      },
    );

    test(
      'persisted domain writes automatically mark backup state dirty',
      () async {
        expect((await service.loadState()).dirty, isFalse);
        storage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();

        await database
            .into(database.players)
            .insert(
              PlayerRow(
                id: 'dirty-player',
                nickname: 'Dirty',
                createdAt: DateTime.utc(2026, 8, 21),
                preferredSide: null,
                note: null,
              ),
            );
        final afterInsert = await service.loadState();
        expect(afterInsert.dirty, isTrue);
        expect(afterInsert.dirtyRevision, greaterThan(0));
        final triggerWrittenSetting =
            await (database.select(database.appSettings)..where(
                  (setting) =>
                      setting.key.equals('backup.automatic.dirtyRevision'),
                ))
                .getSingle();
        expect(triggerWrittenSetting.updatedAt.year, 2026);

        await (database.update(database.players)
              ..where((player) => player.id.equals('dirty-player')))
            .write(const PlayersCompanion(note: Value('changed')));
        final afterUpdate = await service.loadState();
        expect(
          afterUpdate.dirtyRevision,
          greaterThan(afterInsert.dirtyRevision),
        );

        await (database.delete(
          database.players,
        )..where((player) => player.id.equals('dirty-player'))).go();
        expect(
          (await service.loadState()).dirtyRevision,
          greaterThan(afterUpdate.dirtyRevision),
        );
      },
    );

    test(
      'domain triggers persist one UTC dirtySince until a successful backup',
      () async {
        storage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();

        Future<String?> readDirtySinceJson() async {
          final row =
              await (database.select(database.appSettings)..where(
                    (setting) =>
                        setting.key.equals('backup.automatic.dirtySince'),
                  ))
                  .getSingleOrNull();
          return row == null ? null : jsonDecode(row.valueJson) as String;
        }

        expect(await readDirtySinceJson(), isNull);
        await database
            .into(database.players)
            .insert(
              PlayerRow(
                id: 'trigger-player-1',
                nickname: 'Trigger One',
                createdAt: DateTime.utc(2026, 8, 21),
                preferredSide: null,
                note: null,
              ),
            );
        final first = await readDirtySinceJson();
        expect(first, isNotNull);
        final firstDate = DateTime.parse(first!);
        expect(firstDate.isUtc, isTrue);

        await database
            .into(database.players)
            .insert(
              PlayerRow(
                id: 'trigger-player-2',
                nickname: 'Trigger Two',
                createdAt: DateTime.utc(2026, 8, 21),
                preferredSide: null,
                note: null,
              ),
            );
        expect(await readDirtySinceJson(), first);

        await service.runNow();
        expect(await readDirtySinceJson(), isNull);
      },
    );

    test(
      'non-automatic app setting insert update and delete mark backup dirty',
      () async {
        // Leave a stale definition in place to prove ensureBackupDirtyTriggers
        // replaces trigger SQL rather than accepting CREATE IF NOT EXISTS.
        await database.customStatement('''
          CREATE TRIGGER backup_dirty_app_settings_insert
          AFTER INSERT ON app_settings
          WHEN NEW.key NOT LIKE 'backup.automatic.%'
          BEGIN
            INSERT OR REPLACE INTO app_settings(key, value_json, updated_at)
              VALUES('backup.automatic.dirty', 'true', unixepoch());
          END
        ''');
        storage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();
        await service.runNow();

        Future<Object?> readValue(String key) async {
          final row = await (database.select(
            database.appSettings,
          )..where((setting) => setting.key.equals(key))).getSingleOrNull();
          return row == null ? null : jsonDecode(row.valueJson);
        }

        final cleanRevision =
            (await readValue('backup.automatic.dirtyRevision')) as int?;
        await database
            .into(database.appSettings)
            .insert(
              AppSetting(
                key: 'theme',
                valueJson: jsonEncode('dark'),
                updatedAt: DateTime.utc(2026, 8, 21),
              ),
            );
        final insertedRevision =
            (await readValue('backup.automatic.dirtyRevision')) as int;
        expect(insertedRevision, greaterThan(cleanRevision ?? 0));
        expect(await readValue('backup.automatic.dirty'), isTrue);
        expect(await readValue('backup.automatic.dirtySince'), isA<String>());

        await (database.update(
          database.appSettings,
        )..where((setting) => setting.key.equals('theme'))).write(
          AppSettingsCompanion(
            valueJson: Value(jsonEncode('light')),
            updatedAt: Value(DateTime.utc(2026, 8, 21, 1)),
          ),
        );
        final updatedRevision =
            (await readValue('backup.automatic.dirtyRevision')) as int;
        expect(updatedRevision, greaterThan(insertedRevision));

        await (database.delete(
          database.appSettings,
        )..where((setting) => setting.key.equals('theme'))).go();
        final deletedRevision =
            (await readValue('backup.automatic.dirtyRevision')) as int;
        expect(deletedRevision, greaterThan(updatedRevision));
        expect(await readValue('backup.automatic.dirty'), isTrue);
      },
    );

    test(
      'legacy dirty state re-reads metadata while anchoring dirtySince',
      () async {
        await database.batch((batch) {
          batch.insertAll(database.appSettings, [
            AppSetting(
              key: 'backup.automatic.enabled',
              valueJson: jsonEncode(true),
              updatedAt: DateTime.utc(2026, 8, 21),
            ),
            AppSetting(
              key: 'backup.automatic.directory',
              valueJson: jsonEncode('/approved'),
              updatedAt: DateTime.utc(2026, 8, 21),
            ),
            AppSetting(
              key: 'backup.automatic.dirty',
              valueJson: jsonEncode(true),
              updatedAt: DateTime.utc(2026, 8, 21),
            ),
            AppSetting(
              key: 'backup.automatic.dirtyRevision',
              valueJson: jsonEncode(1),
              updatedAt: DateTime.utc(2026, 8, 21),
            ),
          ]);
        });
        await database.customStatement('''
          CREATE TRIGGER simulate_concurrent_backup_mutation
          AFTER INSERT ON app_settings
          WHEN NEW.key = 'backup.automatic.dirtySince'
          BEGIN
            UPDATE app_settings
              SET value_json = '2'
              WHERE key = 'backup.automatic.dirtyRevision';
          END
        ''');

        final state = await service.loadState();

        expect(state.dirty, isTrue);
        expect(state.dirtyRevision, 2);
        expect(state.dirtySince, isNotNull);
      },
    );

    test(
      'runIfDue requires enabled, configured, dirty, and a 24-hour gap',
      () async {
        var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
        service = AutomaticBackupService(
          database,
          JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
          storage: storage,
          now: () => current,
        );
        storage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.markDirty();
        expect(await service.runIfDue(), isNull);
        await service.enable();
        await service.markDirty();
        expect(await service.runIfDue(), isNull);
        current = current.add(const Duration(hours: 24));
        expect(await service.runIfDue(), isNotNull);
      },
    );

    test('failed due backup keeps dirty state', () async {
      var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
      service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
        storage: storage,
        now: () => current,
      );
      storage.availableDirectories.add('/approved');
      await service.configureDirectory('/approved');
      await service.enable();
      await service.markDirty();
      current = current.add(const Duration(hours: 24));
      storage.writeError = FileSystemException('Permission denied');

      expect(service.runIfDue, throwsA(isA<AutomaticBackupWriteException>()));
      expect((await service.loadState()).dirty, isTrue);
    });

    test(
      'retention clamps to 1..50 and deletes only automatic backups',
      () async {
        var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
        final retentionStorage = _RetentionMemoryBackupStorage();
        service = AutomaticBackupService(
          database,
          JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
          storage: retentionStorage,
          now: () => current,
        );
        retentionStorage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();
        await service.setRetentionLimit(999);
        expect((await service.loadState()).retentionLimit, 50);
        await service.setRetentionLimit(0);
        expect((await service.loadState()).retentionLimit, 1);
        await service.setRetentionLimit(10);
        for (var index = 0; index < 10; index++) {
          retentionStorage.files.add(
            _WrittenBackup(
              'hoopito-auto-202608${(index + 1).toString().padLeft(2, '0')}-090507.json',
              Uint8List(0),
            ),
          );
        }
        retentionStorage.files.add(
          _WrittenBackup('hoopito-backup-manual.json', Uint8List(0)),
        );
        retentionStorage.files.add(
          _WrittenBackup('hoopito-pre-restore.json', Uint8List(0)),
        );
        await service.markDirty();
        current = current.add(const Duration(hours: 24));

        await service.runIfDue();

        final automatic = retentionStorage.files
            .map((file) => file.fileName)
            .where((name) => name.startsWith('hoopito-auto-'))
            .toList();
        expect(automatic, hasLength(10));
        expect(retentionStorage.deleted, ['hoopito-auto-20260801-090507.json']);
        expect(
          retentionStorage.files.any(
            (file) => file.fileName == 'hoopito-backup-manual.json',
          ),
          isTrue,
        );
        expect(
          retentionStorage.files.any(
            (file) => file.fileName == 'hoopito-pre-restore.json',
          ),
          isTrue,
        );
      },
    );

    test('concurrent due runs share one write', () async {
      var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
      final concurrentStorage = _BlockingBackupStorage();
      service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
        storage: concurrentStorage,
        now: () => current,
      );
      concurrentStorage.availableDirectories.add('/approved');
      await service.configureDirectory('/approved');
      await service.enable();
      await service.markDirty();
      current = current.add(const Duration(hours: 24));
      final first = service.runIfDue();
      final second = service.runIfDue();
      concurrentStorage.release();

      expect(await Future.wait([first, second]), hasLength(2));
      expect(concurrentStorage.writeCount, 2);
    });

    test('separate service instances share one database-backed run', () async {
      var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
      final concurrentStorage = _BlockingBackupStorage();
      service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '1.0.0+2', now: () => current),
        storage: concurrentStorage,
        now: () => current,
      );
      final secondService = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '1.0.0+2', now: () => current),
        storage: concurrentStorage,
        now: () => current,
      );
      concurrentStorage.availableDirectories.add('/approved');
      await service.configureDirectory('/approved');
      await service.enable();
      await service.markDirty();
      current = current.add(const Duration(hours: 24));

      final first = service.runIfDue();
      await _eventually(() => concurrentStorage.writeCount == 2);
      final second = secondService.runIfDue();
      concurrentStorage.release();

      final destinations = await Future.wait([first, second]);
      expect(destinations.toSet(), hasLength(1));
      expect(concurrentStorage.writeCount, 2);
    });

    test('a change made during a backup remains dirty afterward', () async {
      var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
      final concurrentStorage = _BlockingBackupStorage();
      service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
        storage: concurrentStorage,
        now: () => current,
      );
      concurrentStorage.availableDirectories.add('/approved');
      await service.configureDirectory('/approved');
      await service.enable();
      await service.markDirty();
      current = current.add(const Duration(hours: 24));

      final backup = service.runIfDue();
      await _eventually(() => concurrentStorage.writeCount == 2);
      await service.markDirty();
      concurrentStorage.release();
      await backup;

      expect((await service.loadState()).dirty, isTrue);
    });

    test(
      'match finish exports a fresh snapshot after waiting for an old backup',
      () async {
        var current = DateTime.utc(2026, 8, 21, 9, 5, 7);
        final concurrentStorage = _BlockingBackupStorage();
        service = AutomaticBackupService(
          database,
          JsonBackupCodec(database, appVersion: '0.1.0+1', now: () => current),
          storage: concurrentStorage,
          now: () => current,
        );
        concurrentStorage.availableDirectories.add('/approved');
        await service.configureDirectory('/approved');
        await service.enable();
        await service.markDirty();
        current = current.add(const Duration(hours: 24));

        final oldBackup = service.runIfDue();
        await _eventually(() => concurrentStorage.writeCount == 2);
        final finish = service.runAfterMatchFinish();
        await _eventuallyAsync(
          () async => (await service.loadState()).dirtyRevision >= 2,
        );
        await database
            .into(database.players)
            .insert(
              PlayerRow(
                id: 'finish-player',
                nickname: 'Finish',
                createdAt: current,
                preferredSide: null,
                note: null,
              ),
            );

        concurrentStorage.release();
        await Future.wait([oldBackup, finish]);

        expect(concurrentStorage.writeCount, 3);
        final freshPayload =
            jsonDecode(utf8.decode(concurrentStorage.files.last.bytes))
                as Map<String, dynamic>;
        final players =
            (freshPayload['data'] as Map<String, dynamic>)['players']
                as List<dynamic>;
        expect(
          players.any(
            (row) => (row as Map<String, dynamic>)['id'] == 'finish-player',
          ),
          isTrue,
        );
      },
    );
  });
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(predicate(), isTrue);
}

Future<void> _eventuallyAsync(Future<bool> Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(await predicate(), isTrue);
}

class _MemoryBackupStorage
    implements AutomaticBackupStorage, AutomaticBackupReferencePolicy {
  final availableDirectories = <String>{};
  final files = <_WrittenBackup>[];
  Object? writeError;
  bool acceptReferences = true;

  @override
  bool acceptsDirectoryReference(String reference) => acceptReferences;

  @override
  Future<bool> directoryExists(String path) async {
    return availableDirectories.contains(path);
  }

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final error = writeError;
    if (error != null) throw error;
    files.add(_WrittenBackup(fileName, bytes));
    return '$directory/$fileName';
  }
}

class _WrittenBackup {
  const _WrittenBackup(this.fileName, this.bytes);

  final String fileName;
  final Uint8List bytes;
}

class _RetentionMemoryBackupStorage extends _MemoryBackupStorage
    implements BackupRetentionStorage {
  final deleted = <String>[];

  @override
  Future<List<String>> listFiles({required String directory}) async {
    return files.map((file) => file.fileName).toList(growable: false);
  }

  @override
  Future<void> deleteFile({
    required String directory,
    required String fileName,
  }) async {
    deleted.add(fileName);
    files.removeWhere((file) => file.fileName == fileName);
  }
}

class _BlockingBackupStorage extends _MemoryBackupStorage {
  final _release = Completer<void>();
  int writeCount = 0;

  void release() => _release.complete();

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async {
    writeCount++;
    if (writeCount > 1) await _release.future;
    files.add(_WrittenBackup(fileName, bytes));
    return '$directory/$fileName';
  }
}

class _MutatingBackupStorage extends _MemoryBackupStorage {
  _MutatingBackupStorage(this.database);

  final AppDatabase database;
  var _mutated = false;

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final destination = await super.write(
      directory: directory,
      fileName: fileName,
      bytes: bytes,
    );
    if (!_mutated) {
      _mutated = true;
      await database
          .into(database.players)
          .insert(
            PlayerRow(
              id: 'enable-window-player',
              nickname: 'Enable Window',
              createdAt: DateTime.utc(2026, 8, 21),
              preferredSide: null,
              note: null,
            ),
          );
    }
    return destination;
  }
}

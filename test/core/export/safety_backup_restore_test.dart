import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../test_helpers/test_database.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late JsonBackupCodec codec;
  late _Gateway gateway;
  late _ControlledStorage storage;
  late ExportCoordinator coordinator;
  late DateTime now;

  setUp(() async {
    final incoming = await _backupWithPlayer('incoming');
    directory = await Directory.systemTemp.createTemp(
      'hoopito-safety-restore-',
    );
    addTearDown(() => directory.delete(recursive: true));
    database = AppDatabase(
      NativeDatabase(File(path.join(directory.path, 'test.sqlite'))),
    );
    addTearDown(database.close);
    now = DateTime.utc(2026, 9, 24);
    codec = JsonBackupCodec(database, appVersion: '2.0.0', now: () => now);
    await _seedPlayer(database, 'local');
    gateway = _Gateway();
    storage = _ControlledStorage(
      IoSafetyBackupStorage(
        resolveDirectory: () async =>
            Directory(path.join(directory.path, 'safety')),
      ),
    );
    coordinator = ExportCoordinator(
      database,
      codec,
      gateway: gateway,
      automaticBackup: AutomaticBackupService(database, codec),
      safetyBackups: SafetyBackupStore(codec, storage: storage),
    );
    gateway.payload = incoming;
  });

  test(
    'disk failure aborts replacement and preserves previous snapshots',
    () async {
      final previous = await coordinator.safetyBackups.save(
        await codec.export(),
      );
      storage.failWrite = true;

      await expectLater(
        coordinator.restorePickedBackup(),
        throwsA(isA<SafetyBackupWriteException>()),
      );
      expect(
        (await database.select(database.players).get()).single.id,
        'local',
      );
      expect((await coordinator.listSafetyBackups()).single.id, previous.id);
      expect(gateway.shares, 0);
    },
  );

  test(
    'failed replacement rolls back all database deletes and retains old backups',
    () async {
      final first = await coordinator.safetyBackups.save(await codec.export());
      now = now.add(const Duration(seconds: 1));
      final second = await coordinator.safetyBackups.save(await codec.export());
      now = now.add(const Duration(seconds: 1));
      await database.customStatement('''
      CREATE TRIGGER reject_incoming BEFORE INSERT ON players
      WHEN NEW.id = 'incoming'
      BEGIN SELECT RAISE(ABORT, 'forced replacement failure'); END
    ''');

      await expectLater(
        coordinator.restorePickedBackup(),
        throwsA(isA<BackupRestoreException>()),
      );
      expect(
        (await database.select(database.players).get()).single.id,
        'local',
      );
      final backups = await coordinator.safetyBackups.list();
      expect(backups, hasLength(3));
      expect(
        backups.map((backup) => backup.id),
        containsAll([first.id, second.id]),
      );
    },
  );

  test(
    'rollback saves current data and keeps the latest two recovery points',
    () async {
      await coordinator.restorePickedBackup();
      final original = (await coordinator.listSafetyBackups()).single;
      now = now.add(const Duration(seconds: 1));

      await coordinator.restoreSafetyBackup(original);

      expect(
        (await database.select(database.players).get()).single.id,
        'local',
      );
      final backups = await coordinator.listSafetyBackups();
      expect(backups, hasLength(2));
      final beforeRollback = codec.decodeAndValidate(
        await coordinator.safetyBackups.read(backups.first),
      );
      expect(beforeRollback.players.single.id, 'incoming');
      now = now.add(const Duration(seconds: 1));
      await coordinator.restoreSafetyBackup(backups.first);
      expect(
        (await database.select(database.players).get()).single.id,
        'incoming',
      );
      expect(await coordinator.listSafetyBackups(), hasLength(2));
    },
  );

  test('a corrupted selected snapshot cannot mutate current data', () async {
    await coordinator.restorePickedBackup();
    final snapshot = (await coordinator.listSafetyBackups()).single;
    await File(
      path.join(directory.path, 'safety', snapshot.fileName),
    ).writeAsString('{}');

    await expectLater(
      coordinator.restoreSafetyBackup(snapshot),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      (await database.select(database.players).get()).single.id,
      'incoming',
    );
    expect(await coordinator.listSafetyBackups(), isEmpty);
  });

  test('rollback refuses to remove an active local match', () async {
    final snapshot = await coordinator.safetyBackups.save(await codec.export());
    await database
        .into(database.matches)
        .insert(
          MatchesCompanion.insert(
            id: 'active-match',
            lifecycle: const Value('active'),
            ruleTemplateJson: '{}',
            createdAt: now,
          ),
        );
    await database
        .into(database.activeSessions)
        .insert(
          ActiveSessionsCompanion.insert(
            matchId: 'active-match',
            claimedAtUtc: Value(now),
          ),
        );

    await expectLater(
      coordinator.restoreSafetyBackup(snapshot),
      throwsA(isA<BackupRestoreBlockedException>()),
    );
    expect(
      (await database.select(database.activeSessions).get()).single.matchId,
      'active-match',
    );
    expect(await coordinator.listSafetyBackups(), hasLength(1));
  });

  test(
    'write reservation blocks another connection throughout snapshot save',
    () async {
      final other = sqlite.sqlite3.open(
        path.join(directory.path, 'test.sqlite'),
      );
      addTearDown(other.close);
      var attempted = false;
      storage.duringWrite = () async {
        attempted = true;
        expect(
          () => other.execute(
            "INSERT INTO players(id, nickname, created_at) VALUES('racing', 'Racing', 0)",
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
        // The reservation itself has not introduced any coordination setting.
        expect(other.select('SELECT * FROM app_settings'), isEmpty);
      };

      await coordinator.restorePickedBackup();

      expect(attempted, isTrue);
      expect(
        (await database.select(database.players).get()).single.id,
        'incoming',
      );
      final safety = (await coordinator.listSafetyBackups()).single;
      expect(
        codec
            .decodeAndValidate(await coordinator.safetyBackups.read(safety))
            .players
            .single
            .id,
        'local',
      );
      other.execute(
        "INSERT INTO players(id, nickname, created_at) VALUES('after', 'After', 0)",
      );
      expect(
        (await database.select(database.players).get()).map(
          (player) => player.id,
        ),
        contains('after'),
      );
    },
  );

  test(
    'capacity failure prevents the share gateway from receiving a backup',
    () async {
      final boundedCodec = JsonBackupCodec(
        database,
        appVersion: '2.0.0',
        maxPayloadBytes: 8,
      );
      final bounded = ExportCoordinator(
        database,
        boundedCodec,
        gateway: gateway,
        automaticBackup: AutomaticBackupService(database, boundedCodec),
      );

      await expectLater(
        bounded.shareJsonBackup(subject: 'backup'),
        throwsA(isA<BackupCapacityException>()),
      );
      expect(gateway.shares, 0);
    },
  );
}

Future<void> _seedPlayer(AppDatabase database, String id) => database
    .into(database.players)
    .insert(
      PlayerRow(id: id, nickname: id, createdAt: DateTime.utc(2026, 9, 24)),
    );

Future<String> _backupWithPlayer(String id) =>
    withTestDatabase((database) async {
      await _seedPlayer(database, id);
      return JsonBackupCodec(database, appVersion: '2.0.0').export();
    });

class _Gateway implements ExportGateway {
  String? payload;
  int shares = 0;

  @override
  Future<ExportArtifact?> pickBackup({String? dialogTitle}) async =>
      payload == null
      ? null
      : ExportArtifact.text(
          fileName: 'incoming.json',
          mimeType: 'application/json',
          contents: payload!,
        );

  @override
  Future<BackupDirectorySelection?> pickDirectory({
    String? dialogTitle,
  }) async => null;

  @override
  Future<void> share(
    List<ExportArtifact> artifacts, {
    required String subject,
  }) async {
    shares++;
  }
}

class _ControlledStorage implements SafetyBackupStorage {
  _ControlledStorage(this.disk);
  final SafetyBackupStorage disk;
  bool failWrite = false;
  Future<void> Function()? duringWrite;

  @override
  Future<void> delete(String fileName) => disk.delete(fileName);
  @override
  Future<List<String>> listFiles() => disk.listFiles();
  @override
  Future<void> publish(String temporaryName, String fileName) =>
      disk.publish(temporaryName, fileName);
  @override
  Future<Uint8List> read(String fileName, {required int maxBytes}) =>
      disk.read(fileName, maxBytes: maxBytes);
  @override
  Future<void> writeAndFlush(String fileName, Uint8List bytes) async {
    if (failWrite) throw const FileSystemException('forced disk write failure');
    await duringWrite?.call();
    await disk.writeAndFlush(fileName, bytes);
  }
}

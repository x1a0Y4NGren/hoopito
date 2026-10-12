import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/export/safety_backup_store.dart';
import 'package:path/path.dart' as path;

import '../../test_helpers/test_database.dart';

void main() {
  late Directory directory;
  late JsonBackupCodec codec;
  late IoSafetyBackupStorage disk;
  late SafetyBackupStore store;
  late DateTime exportedAt;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hoopito-safety-store-');
    addTearDown(() => directory.delete(recursive: true));
    exportedAt = DateTime.utc(2026, 9, 24);
    codec = JsonBackupCodec(
      createTestDatabase(),
      appVersion: '2.0.0',
      now: () => exportedAt,
    );
    disk = IoSafetyBackupStorage(resolveDirectory: () async => directory);
    store = SafetyBackupStore(codec, storage: disk);
  });

  test(
    'publishes only a complete verified snapshot and survives reopening',
    () async {
      final source = await codec.export();
      final snapshot = await store.save(source);
      final reopened = SafetyBackupStore(
        codec,
        storage: IoSafetyBackupStorage(resolveDirectory: () async => directory),
      );

      expect(await reopened.read(snapshot), source);
      final listed = await reopened.list();
      expect(listed.single.id, snapshot.id);
      expect(listed.single.exportedAt, DateTime.utc(2026, 9, 24));
      expect(listed.single.payloadBytes, utf8.encode(source).length);
      expect(await disk.listFiles(), [snapshot.fileName]);
    },
  );

  test(
    'disk write failure leaves the previous recoverable file intact',
    () async {
      final previous = await store.save(await codec.export());
      final obstruction = File(path.join(directory.path, 'not-a-directory'));
      await obstruction.writeAsString('occupied');
      final failing = SafetyBackupStore(
        codec,
        storage: IoSafetyBackupStorage(
          resolveDirectory: () async => Directory(obstruction.path),
        ),
      );

      await expectLater(
        failing.save(await codec.export()),
        throwsA(isA<SafetyBackupWriteException>()),
      );
      expect((await store.list()).single.id, previous.id);
      expect(await store.read(previous), isNotEmpty);
    },
  );

  test(
    'corrupted readback never publishes or removes older snapshots',
    () async {
      final previous = await store.save(await codec.export());
      final failing = SafetyBackupStore(
        codec,
        storage: _ReadbackStorage(disk, corrupted: true),
      );

      await expectLater(
        failing.save(await codec.export()),
        throwsA(isA<SafetyBackupWriteException>()),
      );
      expect(await disk.listFiles(), [previous.fileName]);
      expect((await store.list()).single.id, previous.id);
    },
  );

  test(
    'atomic publication failure leaves no recoverable partial file',
    () async {
      final failing = SafetyBackupStore(
        codec,
        storage: _ReadbackStorage(disk, failPublish: true),
      );

      await expectLater(
        failing.save(await codec.export()),
        throwsA(isA<SafetyBackupWriteException>()),
      );
      expect(await disk.listFiles(), isEmpty);
      expect(await store.list(), isEmpty);
    },
  );

  test('readback of a different valid backup is rejected', () async {
    final database = codec.database;
    final original = await codec.export();
    await database
        .into(database.players)
        .insert(
          PlayerRow(
            id: 'unexpected',
            nickname: 'Unexpected',
            createdAt: exportedAt,
          ),
        );
    final different = await codec.export();
    final failing = SafetyBackupStore(
      codec,
      storage: _ReadbackStorage(disk, substituted: different),
    );

    await expectLater(
      failing.save(original),
      throwsA(isA<SafetyBackupWriteException>()),
    );
    expect(await store.list(), isEmpty);
  });

  test(
    'retention is deferred until called after a successful replacement',
    () async {
      final first = await store.save(await codec.export());
      exportedAt = exportedAt.add(const Duration(seconds: 1));
      final second = await store.save(await codec.export());
      exportedAt = exportedAt.add(const Duration(seconds: 1));
      final third = await store.save(await codec.export());

      expect(await store.list(), hasLength(3));
      await store.retainLatest();
      expect((await store.list()).map((backup) => backup.id), [
        third.id,
        second.id,
      ]);
      expect(
        await File(path.join(directory.path, first.fileName)).exists(),
        isFalse,
      );
    },
  );

  test('corrupt and temporary files are not offered for recovery', () async {
    final snapshot = await store.save(await codec.export());
    await File(
      path.join(directory.path, snapshot.fileName),
    ).writeAsString('{}');
    await File(
      path.join(directory.path, '${snapshot.fileName}.tmp'),
    ).writeAsString(await codec.export());

    expect(await store.list(), isEmpty);
    await expectLater(
      store.read(snapshot),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('oversized snapshot read reports bytes before decoding', () async {
    final snapshot = await store.save(await codec.export());
    final smallCodec = JsonBackupCodec(
      codec.database,
      appVersion: '2.0.0',
      maxPayloadBytes: 8,
    );
    final bounded = SafetyBackupStore(smallCodec, storage: disk);

    await expectLater(
      bounded.read(snapshot),
      throwsA(
        isA<BackupCapacityException>()
            .having(
              (error) => error.limitKind,
              'limitKind',
              BackupCapacityLimit.payloadBytes,
            )
            .having(
              (error) => error.measured,
              'measured',
              snapshot.payloadBytes,
            )
            .having((error) => error.limit, 'limit', 8),
      ),
    );
  });
}

class _ReadbackStorage implements SafetyBackupStorage {
  _ReadbackStorage(
    this.disk, {
    this.corrupted = false,
    this.failPublish = false,
    this.substituted,
  });

  final SafetyBackupStorage disk;
  final bool corrupted;
  final bool failPublish;
  final String? substituted;

  @override
  Future<void> delete(String fileName) => disk.delete(fileName);

  @override
  Future<List<String>> listFiles() => disk.listFiles();

  @override
  Future<void> publish(String temporaryName, String fileName) async {
    if (failPublish) throw const FileSystemException('forced rename failure');
    await disk.publish(temporaryName, fileName);
  }

  @override
  Future<Uint8List> read(String fileName, {required int maxBytes}) async {
    final bytes = await disk.read(fileName, maxBytes: maxBytes);
    if (fileName.endsWith('.tmp')) {
      if (corrupted) return Uint8List.fromList(utf8.encode('{}'));
      if (substituted != null) {
        return Uint8List.fromList(utf8.encode(substituted!));
      }
    }
    return bytes;
  }

  @override
  Future<void> writeAndFlush(String fileName, Uint8List bytes) =>
      disk.writeAndFlush(fileName, bytes);
}

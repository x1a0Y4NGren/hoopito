import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/device_automatic_backup_storage.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/export/safety_backup_store.dart';
import 'package:hoopito/core/settings/motion_preference_cache.dart';
import 'package:path/path.dart' as path;

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'new exports use Hoopito and restore legacy HoopTrace manifests',
    () async {
      final source = await withTestDatabase((database) async {
        await database
            .into(database.players)
            .insert(
              PlayerRow(
                id: 'legacy-player',
                nickname: 'Bean',
                createdAt: DateTime.utc(2026),
              ),
            );
        return JsonBackupCodec(database, appVersion: '2.0.0').export();
      });
      final document = jsonDecode(source) as Map<String, dynamic>;
      final manifest = document['manifest'] as Map<String, dynamic>;
      expect(manifest['appName'], 'Hoopito');

      // Build the historical envelope independently; its checksum includes the
      // original app name, so accepting a legacy name must still validate it.
      manifest['appName'] = 'HoopTrace';
      final unsignedManifest = Map<String, dynamic>.from(manifest)
        ..remove('checksum');
      manifest['checksum'] = sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'manifest': unsignedManifest,
                'data': document['data'],
              }),
            ),
          )
          .toString();
      final restored = createTestDatabase();
      await JsonBackupCodec(
        restored,
        appVersion: '2.0.0',
      ).restore(jsonEncode(document));
      expect(
        (await restored.select(restored.players).get()).single.nickname,
        'Bean',
      );

      manifest['appName'] = 'UnrelatedApp';
      final unsupportedManifest = Map<String, dynamic>.from(manifest)
        ..remove('checksum');
      manifest['checksum'] = sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'manifest': unsupportedManifest,
                'data': document['data'],
              }),
            ),
          )
          .toString();
      expect(
        () => JsonBackupCodec(
          restored,
          appVersion: '2.0.0',
        ).decodeAndValidate(jsonEncode(document)),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );

  test(
    'safety recovery lists old snapshots alongside new Hoopito snapshots',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hoopito-compatibility-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final codec = JsonBackupCodec(createTestDatabase(), appVersion: '2.0.0');
      final source = await codec.export();
      const legacyName = 'hooptrace-safety-backup-20261001-legacy.json';
      await File(path.join(directory.path, legacyName)).writeAsString(source);
      final store = SafetyBackupStore(
        codec,
        storage: IoSafetyBackupStorage(resolveDirectory: () async => directory),
      );
      final latest = await store.save(source);
      expect(latest.fileName, startsWith('hoopito-safety-backup-'));
      final snapshots = await store.list();
      expect(
        snapshots.map((snapshot) => snapshot.fileName),
        containsAll([legacyName, latest.fileName]),
      );
      expect(
        await store.read(
          snapshots.singleWhere((snapshot) => snapshot.fileName == legacyName),
        ),
        source,
      );
    },
  );

  test(
    'mixed-brand retention removes the oldest automatic backup only',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hoopito-retention-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const oldest = 'hooptrace-auto-20261001-120000.json';
      const recent = 'hoopito-auto-20261002-120000.json';
      const newest = 'hooptrace-auto-20261003-120000.json';
      const manual = 'hooptrace-backup-20261001-120000.json';
      for (final name in [oldest, recent, newest, manual]) {
        await File(path.join(directory.path, name)).writeAsString('{}');
      }
      final database = createTestDatabase();
      final storage = DeviceAutomaticBackupStorage(useAndroidSaf: false);
      final service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '2.0.0'),
        storage: storage,
      );
      await service.configureDirectory(directory.path);
      await service.setRetentionLimit(2);
      final destination = await service.runNow();
      expect(path.basename(destination), startsWith('hoopito-backup-'));
      expect(await File(path.join(directory.path, oldest)).exists(), isFalse);
      for (final name in [recent, newest, manual]) {
        expect(await File(path.join(directory.path, name)).exists(), isTrue);
      }
      await expectLater(
        storage.write(
          directory: directory.path,
          fileName: '../hoopito-auto-escape.json',
          bytes: Uint8List(0),
        ),
        throwsA(isA<AutomaticBackupWriteException>()),
      );
    },
  );

  test('startup arguments accept the current name and legacy aliases', () {
    for (final prefix in ['hoopito', 'hooptrace']) {
      expect(
        motionPreferenceFromEntrypointArguments([
          '--$prefix-entry-motion=reduced',
        ]),
        MotionPreference.reduced,
      );
      expect(
        entryAnimationEnabledFromEntrypointArguments([
          '--$prefix-entry-animation=disabled',
        ]),
        isFalse,
      );
    }
  });
}

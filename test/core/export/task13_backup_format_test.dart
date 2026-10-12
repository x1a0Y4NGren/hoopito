import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('export rejects payloads above the import byte limit', () async {
    final database = createTestDatabase();
    await expectLater(
      JsonBackupCodec(
        database,
        appVersion: '1.0.0',
        maxPayloadBytes: 8,
      ).export(),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('export rejects excess table and total rows', () async {
    final database = createTestDatabase();
    for (final id in ['one', 'two']) {
      await database
          .into(database.players)
          .insert(
            PlayerRow(
              id: id,
              nickname: id,
              createdAt: DateTime.utc(2026, 8, 24),
            ),
          );
    }
    await database
        .into(database.appSettings)
        .insert(
          AppSetting(
            key: 'example',
            valueJson: 'true',
            updatedAt: DateTime.utc(2026),
          ),
        );
    await expectLater(
      JsonBackupCodec(
        database,
        appVersion: '1.0.0',
        maxRowsPerTable: 1,
      ).export(),
      throwsA(isA<BackupValidationException>()),
    );
    await expectLater(
      JsonBackupCodec(database, appVersion: '1.0.0', maxTotalRows: 2).export(),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('1.1 exports declare backup format 2 independently', () async {
    final database = createTestDatabase();

    final source = await JsonBackupCodec(
      database,
      appVersion: '1.0.0',
      now: () => DateTime.utc(2026, 8, 24),
    ).export();
    final document = jsonDecode(source) as Map<String, dynamic>;
    final manifest = document['manifest'] as Map<String, dynamic>;

    expect(manifest['formatVersion'], 2);
    expect(manifest['schemaVersion'], database.schemaVersion);
  });

  test('rejects legacy and future backup formats before mutation', () async {
    final database = createTestDatabase();
    final codec = JsonBackupCodec(database, appVersion: '1.0.0');
    final exported = await codec.export();

    final legacy = jsonDecode(exported) as Map<String, dynamic>;
    (legacy['manifest'] as Map<String, dynamic>).remove('formatVersion');
    await expectLater(
      codec.restore(jsonEncode(legacy)),
      throwsA(isA<BackupFormatException>()),
    );

    final future = jsonDecode(exported) as Map<String, dynamic>;
    (future['manifest'] as Map<String, dynamic>)['formatVersion'] = 3;
    await expectLater(
      codec.restore(jsonEncode(future)),
      throwsA(
        isA<UnsupportedBackupFormatException>()
            .having((error) => error.formatVersion, 'formatVersion', 3)
            .having(
              (error) => error.supportedFormatVersion,
              'supportedFormatVersion',
              2,
            ),
      ),
    );
  });

  test('rejects oversized payloads and declared table counts early', () async {
    final database = createTestDatabase();
    final exported = await JsonBackupCodec(
      database,
      appVersion: '1.0.0',
    ).export();

    await expectLater(
      JsonBackupCodec(
        database,
        appVersion: '1.0.0',
        maxPayloadBytes: 8,
      ).restore(exported),
      throwsA(isA<BackupValidationException>()),
    );

    final excessiveCounts = jsonDecode(exported) as Map<String, dynamic>;
    final manifest = excessiveCounts['manifest'] as Map<String, dynamic>;
    final counts = manifest['recordCounts'] as Map<String, dynamic>;
    counts['matches'] = 2;
    await expectLater(
      JsonBackupCodec(
        database,
        appVersion: '1.0.0',
        maxRowsPerTable: 1,
      ).restore(jsonEncode(excessiveCounts)),
      throwsA(isA<BackupValidationException>()),
    );
  });
}

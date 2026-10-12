import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('format 2 exports twelve groups and fills missing snapshots', () async {
    final database = createTestDatabase();
    await _seedFinishedMatch(database);
    await database.ensureBackupDirtyTriggers();
    await database
        .into(database.appSettings)
        .insert(
          AppSetting(
            key: 'backup.automatic.enabled',
            valueJson: 'true',
            updatedAt: DateTime.utc(2026, 8, 28, 11),
          ),
        );
    final codec = JsonBackupCodec(
      database,
      appVersion: '1.1.0+3',
      now: () => DateTime.utc(2026, 8, 28, 12),
    );

    final first = await codec.export();
    final second = await codec.export();
    final json = jsonDecode(first) as Map<String, dynamic>;
    final manifest = json['manifest'] as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;

    expect(first, second);
    expect(manifest['formatVersion'], 2);
    expect(manifest['schemaVersion'], 3);
    expect(data, hasLength(12));
    expect(data['playerAnalyticsSnapshots'], hasLength(1));
    expect(codec.decodeAndValidate(first).snapshots, hasLength(1));
    expect(
      (await database.select(database.playerAnalyticsSnapshots).get()),
      hasLength(1),
    );
    expect(
      await (database.select(database.appSettings)..where(
            (row) => row.key.isIn(const [
              'backup.automatic.dirty',
              'backup.automatic.dirtySince',
              'backup.automatic.dirtyRevision',
            ]),
          ))
          .get(),
      isEmpty,
    );
  });

  test('schema 1 and mismatched format/schema pairs stay blocked', () async {
    final database = createTestDatabase();
    final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
    final exported = await codec.export();

    for (final pair in const [
      (format: 1, schema: 1),
      (format: 1, schema: 3),
      (format: 2, schema: 2),
    ]) {
      final document = jsonDecode(exported) as Map<String, dynamic>;
      final manifest = document['manifest'] as Map<String, dynamic>;
      manifest['formatVersion'] = pair.format;
      manifest['schemaVersion'] = pair.schema;
      _refreshChecksum(document);
      expect(
        () => codec.decodeAndValidate(jsonEncode(document)),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test(
    'format 1 schema 2 restores canonical rows and rebuilds snapshots',
    () async {
      final legacy = await withTestDatabase((source) async {
        await _seedFinishedMatch(source);
        final current = await JsonBackupCodec(
          source,
          appVersion: '1.0.0',
        ).export();
        return _asLegacyFormatOne(current);
      });
      final destination = createTestDatabase();
      final codec = JsonBackupCodec(destination, appVersion: '1.1.0+3');

      final validated = codec.decodeAndValidate(legacy);
      expect(validated.snapshots, isEmpty);
      await codec.restore(legacy);

      final snapshots = await destination
          .select(destination.playerAnalyticsSnapshots)
          .get();
      expect(snapshots, hasLength(1));
      expect(snapshots.single.playerScore, 2);
    },
  );

  test('missing or invalid derived rows are discarded and rebuilt', () async {
    final exported = await withTestDatabase((source) async {
      await _seedFinishedMatch(source);
      return JsonBackupCodec(source, appVersion: '1.1.0+3').export();
    });
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (document) {
        final data = document['data'] as Map<String, dynamic>;
        (data['playerAnalyticsSnapshots'] as List<dynamic>).clear();
        final manifest = document['manifest'] as Map<String, dynamic>;
        final counts = manifest['recordCounts'] as Map<String, dynamic>;
        counts['playerAnalyticsSnapshots'] = 0;
      },
      (document) {
        final data = document['data'] as Map<String, dynamic>;
        final snapshot =
            (data['playerAnalyticsSnapshots'] as List<dynamic>).single
                as Map<String, dynamic>;
        snapshot['calculatorVersion'] = 999;
        snapshot['playerScore'] = 999;
      },
      (document) {
        final data = document['data'] as Map<String, dynamic>;
        final snapshot =
            (data['playerAnalyticsSnapshots'] as List<dynamic>).single
                as Map<String, dynamic>;
        snapshot['sourceSha256'] = 'not-a-digest';
      },
      (document) {
        final data = document['data'] as Map<String, dynamic>;
        final snapshots = data['playerAnalyticsSnapshots'] as List<dynamic>;
        snapshots.add(
          Map<String, dynamic>.from(snapshots.single as Map<String, dynamic>),
        );
        final manifest = document['manifest'] as Map<String, dynamic>;
        final counts = manifest['recordCounts'] as Map<String, dynamic>;
        counts['playerAnalyticsSnapshots'] = 2;
      },
    ]) {
      final document = jsonDecode(exported) as Map<String, dynamic>;
      mutate(document);
      _refreshChecksum(document);
      await withTestDatabase((destination) async {
        await JsonBackupCodec(
          destination,
          appVersion: '1.1.0+3',
        ).restore(jsonEncode(document));
        final snapshot =
            (await destination
                    .select(destination.playerAnalyticsSnapshots)
                    .get())
                .single;
        expect(snapshot.playerScore, 2);
        expect(snapshot.calculatorVersion, 1);
        expect(snapshot.sourceSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
      });
    }
  });

  test('merge rebuilds snapshots after canonical ID remapping', () async {
    final source = await withTestDatabase((database) async {
      await _seedFinishedMatch(database);
      return JsonBackupCodec(database, appVersion: '1.1.0+3').export();
    });
    final destination = createTestDatabase();
    await destination
        .into(destination.players)
        .insert(
          PlayerRow(
            id: 'player-1',
            nickname: 'Local conflict',
            createdAt: DateTime.utc(2026, 8, 27),
          ),
        );

    final result = await BackupMergeService(
      destination,
      JsonBackupCodec(destination, appVersion: '1.1.0+3'),
    ).merge(source);

    final mappedPlayerId = result.idMap['players']!['player-1']!;
    expect(mappedPlayerId, isNot('player-1'));
    expect(result.idMap, isNot(contains('playerAnalyticsSnapshots')));
    expect(result.rebuiltAnalyticsSnapshotCount, 1);
    final snapshot =
        (await destination.select(destination.playerAnalyticsSnapshots).get())
            .single;
    expect(snapshot.playerId, mappedPlayerId);
    expect(snapshot.sourceSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
  });

  test('snapshot rebuild failure rolls back the complete merge', () async {
    final source = await withTestDatabase((database) async {
      await _seedFinishedMatch(database);
      return JsonBackupCodec(database, appVersion: '1.1.0+3').export();
    });
    final destination = createTestDatabase();
    await destination.customStatement('''
      CREATE TRIGGER reject_snapshot_rebuild
      BEFORE INSERT ON player_analytics_snapshots
      BEGIN
        SELECT RAISE(ABORT, 'forced snapshot rebuild failure');
      END;
    ''');

    await expectLater(
      BackupMergeService(
        destination,
        JsonBackupCodec(destination, appVersion: '1.1.0+3'),
      ).merge(source),
      throwsA(isA<BackupMergeException>()),
    );

    expect(await destination.select(destination.matches).get(), isEmpty);
    expect(await destination.select(destination.players).get(), isEmpty);
    expect(
      await destination.select(destination.playerAnalyticsSnapshots).get(),
      isEmpty,
    );
  });
}

Future<void> _seedFinishedMatch(AppDatabase database) async {
  final playedAt = DateTime.utc(2026, 8, 28, 9);
  await database.batch((batch) {
    batch.insert(
      database.players,
      PlayerRow(id: 'player-1', nickname: 'Ace', createdAt: playedAt),
    );
    batch.insert(
      database.matches,
      Matche(
        id: 'match-1',
        lifecycle: 'finished',
        recordingMode: 'simple',
        trackingCoverage: 'scoresOnly',
        ruleTemplateJson: jsonEncode({
          'id': 'rule-1',
          'name': 'Race to 11',
          'scoreButtons': [1, 2, 3],
          'targetScore': 11,
          'timeLimitSeconds': null,
          'winByTwo': true,
          'foulLimit': null,
          'possessionHintEnabled': false,
          'customEventTypes': <String>[],
        }),
        createdAt: playedAt,
        startedAt: playedAt,
        endedAt: playedAt.add(const Duration(minutes: 8)),
        timerEnabled: false,
        note: null,
      ),
    );
    batch.insertAll(database.matchParticipants, [
      MatchParticipant(
        id: 'participant-red',
        matchId: 'match-1',
        side: 'red',
        nameSnapshot: 'Ace',
        playerProfileId: 'player-1',
      ),
      const MatchParticipant(
        id: 'participant-blue',
        matchId: 'match-1',
        side: 'blue',
        nameSnapshot: 'Blue',
        playerProfileId: null,
      ),
    ]);
    batch.insert(
      database.matchEvents,
      MatchEventRow(
        id: 'event-1',
        matchId: 'match-1',
        type: 'score',
        side: 'red',
        points: 2,
        outcome: 'made',
        occurredAt: playedAt.add(const Duration(seconds: 1)),
        note: null,
        matchClockPositionSeconds: null,
        customLabel: null,
        isDeleted: false,
      ),
    );
  });
}

String _asLegacyFormatOne(String source) {
  final document = jsonDecode(source) as Map<String, dynamic>;
  final manifest = document['manifest'] as Map<String, dynamic>;
  final counts = manifest['recordCounts'] as Map<String, dynamic>;
  final data = document['data'] as Map<String, dynamic>;
  manifest['formatVersion'] = 1;
  manifest['schemaVersion'] = 2;
  counts.remove('playerAnalyticsSnapshots');
  data.remove('playerAnalyticsSnapshots');
  _refreshChecksum(document);
  return jsonEncode(document);
}

void _refreshChecksum(Map<String, dynamic> document) {
  final manifest = document['manifest'] as Map<String, dynamic>;
  final checksumSource = Map<String, dynamic>.from(manifest)
    ..remove('checksum');
  final encoded = jsonEncode({
    'manifest': checksumSource,
    'data': document['data'],
  });
  manifest['checksum'] = sha256.convert(utf8.encode(encoded)).toString();
}

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/entities/match_series.dart'
    show SeriesStartContext;
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import '../../test_helpers/test_database.dart';

StartMatchCommand start({
  String? profile,
  bool timerEnabled = false,
  ClockMode clockMode = ClockMode.countUp,
  int? regulationSeconds,
  DateTime? startedAt,
}) => StartMatchCommand(
  timerEnabled: timerEnabled,
  clockMode: clockMode,
  regulationSeconds: regulationSeconds,
  startedAt: startedAt,
  createdAt: startedAt,
  redPlayerProfileId: profile,
  matchId: 'game',
  commandId: 'start',
  redName: 'A',
  blueName: 'B',
  ruleTemplate: const RuleTemplate(
    id: 'free',
    name: 'Free',
    scoreButtons: [1, 2, 3],
  ),
  recordingMode: RecordingMode.simple,
  seriesContext: const SeriesStartContext(
    seriesId: 'group',
    expectedRevision: 0,
    gameNumber: 1,
    create: true,
  ),
);
String resign(Map<String, dynamic> document) {
  final manifest = document['manifest'] as Map<String, dynamic>;
  final header = Map<String, dynamic>.from(manifest)..remove('checksum');
  manifest['checksum'] = sha256
      .convert(
        utf8.encode(jsonEncode({'manifest': header, 'data': document['data']})),
      )
      .toString();
  return jsonEncode(document);
}

void main() {
  for (final mode in ClockMode.values) {
    test(
      'merge pauses active series $mode clock and repeats without rows',
      () async {
        final source = createTestDatabase();
        final target = createTestDatabase();
        addTearDown(source.close);
        addTearDown(target.close);
        final startedAt = DateTime.utc(2026, 11, 2, 10);
        await MatchCommandService(source).start(
          start(
            timerEnabled: true,
            clockMode: mode,
            regulationSeconds: mode == ClockMode.countdown ? 600 : null,
            startedAt: startedAt,
          ),
        );
        final text = await JsonBackupCodec(
          source,
          appVersion: 'test',
          now: () => startedAt.add(const Duration(seconds: 37)),
        ).export();
        final service = BackupMergeService(target);
        await service.merge(text);
        final clock = (await target.select(target.matchClocks).get()).single;
        expect(clock.runningSinceUtc, isNull);
        expect(clock.accumulatedSeconds, 37);
        expect(
          (await target.select(target.matches).get()).single.lifecycle,
          'abandoned',
        );
        expect(
          (await target.select(target.matchSeries).get()).single.lifecycle,
          'closed',
        );
        expect(await target.select(target.activeSessions).get(), isEmpty);
        expect((await service.merge(text)).changed, isFalse);
        expect(await target.select(target.matches).get(), hasLength(1));
      },
    );
  }
  final invalidDefaults = <String, void Function(Map<String, dynamic>)>{
    'unknown possession policy': (setup) =>
        (setup['ruleTemplate'] as Map)['possessionPolicy'] = 'bogus',
    'disabled countdown': (setup) => setup.addAll({
      'clockMode': 'countdown',
      'timerEnabled': false,
      'regulationSeconds': 60,
    }),
    'missing countdown duration': (setup) => setup.addAll({
      'clockMode': 'countdown',
      'timerEnabled': true,
      'regulationSeconds': null,
    }),
    'sub-minute countdown': (setup) => setup.addAll({
      'clockMode': 'countdown',
      'timerEnabled': true,
      'regulationSeconds': 1,
    }),
    'fractional-minute countdown': (setup) => setup.addAll({
      'clockMode': 'countdown',
      'timerEnabled': true,
      'regulationSeconds': 61,
    }),
    'excessive countdown': (setup) => setup.addAll({
      'clockMode': 'countdown',
      'timerEnabled': true,
      'regulationSeconds': 10860,
    }),
  };
  for (final duration in [60, 180 * 60]) {
    test(
      'restored series can start next countdown at $duration seconds',
      () async {
        final source = createTestDatabase();
        final target = createTestDatabase();
        addTearDown(source.close);
        addTearDown(target.close);
        await MatchCommandService(source).start(
          start(
            timerEnabled: true,
            clockMode: ClockMode.countdown,
            regulationSeconds: duration,
          ),
        );
        await MatchCommandService(source).finish(
          FinishMatchCommand(
            matchId: 'game',
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        await JsonBackupCodec(
          target,
          appVersion: 'test',
        ).restore(await JsonBackupCodec(source, appVersion: 'test').export());
        final next = await MatchSeriesRepository(target).prepareNext('group');
        await MatchCommandService(target).start(next);
        final clock = await (target.select(
          target.matchClocks,
        )..where((row) => row.matchId.equals(next.matchId))).getSingle();
        expect(clock.mode, 'countdown');
        expect(clock.regulationSeconds, duration);
        expect(clock.runningSinceUtc, isNotNull);
      },
    );
  }
  for (final entry in invalidDefaults.entries) {
    test(
      'rejects series defaults with ${entry.key} before replacement',
      () async {
        final source = createTestDatabase();
        final target = createTestDatabase();
        addTearDown(source.close);
        addTearDown(target.close);
        await MatchCommandService(source).start(start());
        final document =
            jsonDecode(
                  await JsonBackupCodec(source, appVersion: 'test').export(),
                )
                as Map<String, dynamic>;
        final row = (document['data']['matchSeries'] as List).single as Map;
        final setup =
            jsonDecode(row['defaultSetupJson'] as String)
                as Map<String, dynamic>;
        entry.value(setup);
        row['defaultSetupJson'] = jsonEncode(setup);
        await expectLater(
          JsonBackupCodec(target, appVersion: 'test').restore(resign(document)),
          throwsA(isA<BackupValidationException>()),
        );
        expect(await target.select(target.matchSeries).get(), isEmpty);
        expect(await target.select(target.matches).get(), isEmpty);
      },
    );
  }
  test(
    'replace round-trips active series; merge closes source without claiming active slot',
    () async {
      final source = createTestDatabase();
      await MatchCommandService(source).start(start());
      final exportedAt = DateTime.now().toUtc();
      final text = await JsonBackupCodec(
        source,
        appVersion: 'test',
        now: () => exportedAt,
      ).export();
      final target = createTestDatabase();
      await JsonBackupCodec(target, appVersion: 'test').restore(text);
      expect(
        (await target.select(target.matchSeries).get()).single.lifecycle,
        'open',
      );
      expect(
        (await target.select(target.seriesMatches).get()).single.matchId,
        'game',
      );
      final merged = createTestDatabase();
      final service = BackupMergeService(merged);
      await service.merge(text);
      final group = (await merged.select(merged.matchSeries).get()).single;
      expect(group.lifecycle, 'closed');
      expect(
        group.closedAt!.millisecondsSinceEpoch,
        (exportedAt.millisecondsSinceEpoch ~/ 1000) * 1000,
      );
      expect(group.revision, 2);
      expect(await merged.select(merged.activeSessions).get(), isEmpty);
      expect(
        (await merged.select(merged.matches).get()).single.lifecycle,
        'abandoned',
      );
      expect((await service.merge(text)).changed, isFalse);
    },
  );
  test(
    'conflicting group remaps match graph and command receipt; repeat is idempotent',
    () async {
      final source = createTestDatabase();
      await MatchCommandService(source).start(start());
      final text = await JsonBackupCodec(source, appVersion: 'test').export();
      final target = createTestDatabase();
      await JsonBackupCodec(target, appVersion: 'test').restore(text);
      final result = await BackupMergeService(target).merge(text);
      final groupId = result.idMap['matchSeries']!['group']!;
      final matchId = result.idMap['matches']!['game']!;
      expect(groupId, isNot('group'));
      expect(matchId, isNot('game'));
      expect(
        (await target.select(target.seriesMatches).get())
            .map((row) => row.seriesId)
            .toSet(),
        {'group', groupId},
      );
      final auditId = result.idMap['auditLogs']!['start'];
      final receipt = (await (target.select(
        target.auditLogs,
      )..where((row) => row.id.equals(auditId!))).getSingle());
      final before = jsonDecode(receipt.beforeJson) as Map<String, dynamic>;
      final payload = before['payload'] as Map<String, dynamic>;
      expect((payload['seriesContext'] as Map)['seriesId'], groupId);
      expect(payload['matchId'], matchId);
      expect(payload['commandId'], auditId);
      expect(
        before['fingerprint'],
        sha256
            .convert(
              utf8.encode(
                jsonEncode({'commandType': before['commandType'], ...payload}),
              ),
            )
            .toString(),
      );
      expect((await BackupMergeService(target).merge(text)).changed, isFalse);
      expect(
        (await target.select(target.activeSessions).get()).single.matchId,
        'game',
      );
    },
  );
  test(
    'swapped games and deleted profiles retain fixed snapshots through restore',
    () async {
      final source = createTestDatabase();
      await source
          .into(source.players)
          .insert(
            PlayerRow(id: 'player', nickname: 'A', createdAt: DateTime.now()),
          );
      await MatchCommandService(source).start(start(profile: 'player'));
      await MatchCommandService(source).finish(
        FinishMatchCommand(
          matchId: 'game',
          endedAt: DateTime.now(),
          confirmFinalScore: true,
        ),
      );
      final next = await MatchSeriesRepository(
        source,
      ).prepareNext('group', swapSides: true);
      await MatchCommandService(source).start(next);
      await source.delete(source.players).go();
      final text = await JsonBackupCodec(source, appVersion: 'test').export();
      final target = createTestDatabase();
      await JsonBackupCodec(target, appVersion: 'test').restore(text);
      final series = (await target.select(target.matchSeries).get()).single;
      expect(series.slotAPlayerProfileId, isNull);
      expect(series.slotAName, 'A');
      expect(
        (await target.select(target.seriesMatches).get())
            .map((row) => row.slotASide)
            .toSet(),
        {'red', 'blue'},
      );
      expect(
        (await target.select(target.matchParticipants).get()).every(
          (row) => row.playerProfileId == null,
        ),
        isTrue,
      );
    },
  );
  test(
    'a series revision conflict clones an otherwise identical finished match graph',
    () async {
      final source = createTestDatabase();
      await MatchCommandService(source).start(start());
      await MatchCommandService(source).finish(
        FinishMatchCommand(
          matchId: 'game',
          endedAt: DateTime.now(),
          confirmFinalScore: true,
        ),
      );
      await MatchSeriesRepository(
        source,
      ).close(seriesId: 'group', expectedRevision: 1, intentId: 'close');
      final text = await JsonBackupCodec(source, appVersion: 'test').export();
      final target = createTestDatabase();
      await JsonBackupCodec(target, appVersion: 'test').restore(text);
      await target.customStatement(
        "UPDATE match_series SET revision = revision + 1, lifecycle_intents_json = '{}' WHERE id = 'group'",
      );
      final result = await BackupMergeService(target).merge(text);
      expect(result.idMap['matches']!['game'], isNot('game'));
      expect(await target.select(target.matches).get(), hasLength(2));
      expect(await target.select(target.seriesMatches).get(), hasLength(2));
      expect((await BackupMergeService(target).merge(text)).changed, isFalse);
    },
  );

  test(
    'a completed match can independently link a temporary series participant',
    () async {
      final source = createTestDatabase();
      await MatchCommandService(source).start(start());
      await MatchCommandService(source).finish(
        FinishMatchCommand(
          matchId: 'game',
          endedAt: DateTime.now(),
          confirmFinalScore: true,
        ),
      );
      await source
          .into(source.players)
          .insert(
            PlayerRow(id: 'linked', nickname: 'A', createdAt: DateTime.now()),
          );
      await source.customStatement(
        "UPDATE match_participants SET player_profile_id='linked' WHERE side='red'",
      );
      final text = await JsonBackupCodec(source, appVersion: 'test').export();
      for (final merge in [false, true]) {
        final target = createTestDatabase();
        if (merge) {
          await BackupMergeService(target).merge(text);
        } else {
          await JsonBackupCodec(target, appVersion: 'test').restore(text);
        }
        expect(
          (await target.select(target.matchSeries).get())
              .single
              .slotAPlayerProfileId,
          isNull,
        );
        expect(
          (await target.select(target.matchParticipants).get())
              .firstWhere((p) => p.side == 'red')
              .playerProfileId,
          'linked',
        );
      }
    },
  );
  test(
    'editing a member or its prior deterministic copy forks the whole series',
    () async {
      final source = createTestDatabase();
      await MatchCommandService(source).start(start());
      await MatchCommandService(source).finish(
        FinishMatchCommand(
          matchId: 'game',
          endedAt: DateTime.now(),
          confirmFinalScore: true,
        ),
      );
      await MatchSeriesRepository(
        source,
      ).close(seriesId: 'group', expectedRevision: 1, intentId: 'close');
      final text = await JsonBackupCodec(source, appVersion: 'test').export();
      final target = createTestDatabase();
      final service = BackupMergeService(target);
      await service.merge(text);
      await target.customStatement(
        "UPDATE matches SET note='local edit' WHERE id='game'",
      );
      final copy = await service.merge(text);
      expect(copy.idMap['matchSeries']!['group'], isNot('group'));
      expect((await service.merge(text)).changed, isFalse);
      // Alter only a child. The copy's group and match rows remain identical.
      await target.customStatement(
        "UPDATE audit_logs SET reason='edited audit' WHERE match_id=?",
        [copy.idMap['matches']!['game']],
      );
      final next = await service.merge(text);
      expect(
        next.idMap['matchSeries']!['group'],
        isNot(copy.idMap['matchSeries']!['group']),
      );
      expect(await target.select(target.matchSeries).get(), hasLength(3));
      expect(await target.select(target.seriesMatches).get(), hasLength(3));
      expect((await service.merge(text)).changed, isFalse);
    },
  );
  test(
    'malformed memberships and fixed identities fail before replace',
    () async {
      final source = createTestDatabase();
      await MatchCommandService(source).start(start());
      final text = await JsonBackupCodec(source, appVersion: 'test').export();
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (data) =>
            (data['seriesMatches'] as List).single['seriesId'] = 'missing',
        (data) => (data['seriesMatches'] as List).single['gameNumber'] = 2,
        (data) => (data['seriesMatches'] as List).single['slotASide'] = 'blue',
        (data) => (data['matchSeries'] as List).single['slotAPlayerProfileId'] =
            'missing',
      ]) {
        final document = jsonDecode(text) as Map<String, dynamic>;
        mutation(document['data'] as Map<String, dynamic>);
        final target = createTestDatabase();
        await expectLater(
          JsonBackupCodec(target, appVersion: 'test').restore(resign(document)),
          throwsA(isA<BackupValidationException>()),
        );
        expect(await target.select(target.matches).get(), isEmpty);
      }
    },
  );
  test(
    'series counts participate in capacity and insert failure rolls back',
    () async {
      final source = createTestDatabase();
      await MatchCommandService(source).start(start());
      final text = await JsonBackupCodec(source, appVersion: 'test').export();
      final target = createTestDatabase();
      final doc = jsonDecode(text) as Map<String, dynamic>;
      ((doc['manifest'] as Map)['recordCounts'] as Map)['matchSeries'] = 3;
      expect(
        () => JsonBackupCodec(
          target,
          appVersion: 'test',
          maxRowsPerTable: 2,
        ).decodeAndValidate(resign(doc)),
        throwsA(isA<BackupCapacityException>()),
      );
      await target.customStatement(
        "CREATE TRIGGER reject_series BEFORE INSERT ON series_matches BEGIN SELECT RAISE(ABORT, 'test'); END",
      );
      await expectLater(
        BackupMergeService(target).merge(text),
        throwsA(isA<BackupMergeException>()),
      );
      expect(await target.select(target.matches).get(), isEmpty);
      expect(await target.select(target.matchSeries).get(), isEmpty);
    },
  );
}

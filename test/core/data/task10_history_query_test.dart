import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/repositories/match_lifecycle_repository.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/entities/match_history_entry.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'history page is bounded, stable, and excludes active matches',
    () async {
      await withTestDatabase((database) async {
        final repository = MatchRepository(database);
        final base = DateTime.utc(2026, 1, 1);
        for (var index = 0; index < 5; index++) {
          final createdAt = base.add(Duration(days: index));
          await _saveMatch(
            database,
            id: 'match-$index',
            createdAt: createdAt,
            lifecycle: index == 4
                ? MatchLifecycle.active
                : MatchLifecycle.finished,
          );
          await repository.saveEvent(
            MatchEvent.score(
              id: 'match-$index-score',
              matchId: 'match-$index',
              side: TeamSide.red,
              points: index + 1,
              occurredAt: createdAt,
            ),
          );
        }

        final first = await repository.queryHistory(limit: 2);
        final second = await repository.queryHistory(offset: 2, limit: 2);

        expect(first.entries.map((entry) => entry.id), ['match-3', 'match-2']);
        expect(second.entries.map((entry) => entry.id), ['match-1', 'match-0']);
        expect(
          first.entries.every(
            (entry) => entry.lifecycle != MatchLifecycle.active,
          ),
          isTrue,
        );
        expect(first.hasMore, isTrue);
        expect(first.nextOffset, 2);
        expect(second.hasMore, isFalse);
        expect(second.nextOffset, null);
        expect(first.entries.first.redScore, 4);
      });
    },
  );

  test(
    'uses match id as the deterministic tie breaker for equal playedAt',
    () async {
      await withTestDatabase((database) async {
        final repository = MatchRepository(database);
        final playedAt = DateTime.utc(2026, 1, 10);
        for (final id in ['same-a', 'same-z']) {
          await _saveMatch(
            database,
            id: id,
            createdAt: playedAt,
            lifecycle: MatchLifecycle.finished,
          );
        }

        final page = await repository.queryHistory(limit: 1);
        expect(page.entries.map((entry) => entry.id), ['same-z']);
        expect(page.nextOffset, 1);
        final next = await repository.queryHistory(
          offset: page.nextOffset!,
          limit: 1,
        );
        expect(next.entries.map((entry) => entry.id), ['same-a']);
      });
    },
  );

  test(
    'history query never exposes draft, active, or abandoned lifecycles',
    () async {
      await withTestDatabase((database) async {
        final repository = MatchRepository(database);
        for (final lifecycle in [
          MatchLifecycle.draft,
          MatchLifecycle.active,
          MatchLifecycle.abandoned,
          MatchLifecycle.finished,
          MatchLifecycle.archived,
        ]) {
          await _saveMatch(
            database,
            id: 'lifecycle-${lifecycle.name}',
            createdAt: DateTime.utc(2026, 1, 20),
            lifecycle: lifecycle,
          );
        }

        for (final lifecycle in [
          MatchLifecycle.draft,
          MatchLifecycle.active,
          MatchLifecycle.abandoned,
        ]) {
          final page = await repository.queryHistory(
            filter: MatchHistoryFilter(lifecycle: lifecycle),
          );
          expect(page.entries, isEmpty, reason: lifecycle.name);
        }

        final mixed = await repository.queryHistory(
          filter: const MatchHistoryFilter(
            lifecycles: {MatchLifecycle.finished, MatchLifecycle.abandoned},
          ),
        );
        expect(mixed.entries.map((entry) => entry.lifecycle), [
          MatchLifecycle.finished,
        ]);
      });
    },
  );

  test(
    'history filters participant profile, date, rule, mode, lifecycle, and archive',
    () async {
      await withTestDatabase((database) async {
        final repository = MatchRepository(database);
        await database
            .into(database.players)
            .insert(
              PlayersCompanion.insert(
                id: 'profile-red',
                nickname: 'Profile Search Name',
                createdAt: DateTime.utc(2025),
              ),
            );
        await _saveMatch(
          database,
          id: 'match-kept',
          createdAt: DateTime.utc(2026, 2, 5),
          lifecycle: MatchLifecycle.finished,
          recordingMode: RecordingMode.detailed,
          ruleId: 'rule-target',
          ruleName: 'Target Rule',
          redProfileId: 'profile-red',
        );
        await _saveMatch(
          database,
          id: 'match-archived',
          createdAt: DateTime.utc(2026, 2, 6),
          lifecycle: MatchLifecycle.archived,
          recordingMode: RecordingMode.detailed,
          ruleId: 'rule-target',
          ruleName: 'Target Rule',
        );
        await _saveMatch(
          database,
          id: 'match-other',
          createdAt: DateTime.utc(2026, 3, 1),
          lifecycle: MatchLifecycle.finished,
          ruleId: 'rule-other',
          ruleName: 'Other Rule',
        );

        final filtered = await repository.queryHistory(
          filter: MatchHistoryFilter(
            search: 'profile search',
            from: DateTime.utc(2026, 2, 1),
            to: DateTime.utc(2026, 2, 28),
            ruleId: 'rule-target',
            recordingMode: RecordingMode.detailed,
            lifecycle: MatchLifecycle.finished,
            archived: false,
          ),
        );

        expect(filtered.entries.map((entry) => entry.id), ['match-kept']);
        expect(filtered.entries.single.redPlayerProfileId, 'profile-red');
        expect(filtered.entries.single.ruleId, 'rule-target');
        expect(filtered.entries.single.recordingMode, RecordingMode.detailed);
        expect(filtered.entries.single.lifecycle, MatchLifecycle.finished);
      });
    },
  );

  test(
    'history page uses one bounded query rather than one detail query per row',
    () async {
      await withTestDatabase((database) async {
        final repository = _CountingMatchRepository(database);
        final base = DateTime.utc(2026, 4, 1);
        for (var index = 0; index < 1000; index++) {
          await _saveMatch(
            database,
            id: 'fixture-$index',
            createdAt: base.add(Duration(seconds: index)),
            lifecycle: MatchLifecycle.finished,
          );
        }

        final stopwatch = Stopwatch()..start();
        final page = await repository.queryHistory(limit: 20);
        stopwatch.stop();

        expect(page.entries, hasLength(20));
        expect(page.hasMore, isTrue);
        expect(repository.detailCalls, 0);
        // Keep this deliberately generous to avoid making the test machine
        // dependent while still catching an accidental O(rows) detail query.
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(milliseconds: 500)),
          reason: '1000-match first page took ${stopwatch.elapsed}',
        );
      });
    },
  );

  test(
    '1000-match first page stays under 500ms with events and locations',
    () async {
      await withTestDatabase((database) async {
        final repository = _CountingMatchRepository(database);
        final base = DateTime.utc(2026, 6, 1);
        for (var index = 0; index < 1000; index++) {
          await _saveMatch(
            database,
            id: 'event-fixture-$index',
            createdAt: base.add(Duration(seconds: index)),
            lifecycle: MatchLifecycle.finished,
          );
        }
        await database.batch((batch) {
          for (var index = 0; index < 1000; index++) {
            final matchId = 'event-fixture-$index';
            final madeId = '$matchId-made';
            batch.insert(
              database.matchEvents,
              MatchEventsCompanion.insert(
                id: madeId,
                matchId: matchId,
                type: MatchEventType.fieldGoal.name,
                side: const drift.Value('red'),
                points: const drift.Value(2),
                outcome: const drift.Value('made'),
                occurredAt: base.add(Duration(seconds: index)),
              ),
            );
            batch.insert(
              database.matchEvents,
              MatchEventsCompanion.insert(
                id: '$matchId-missed',
                matchId: matchId,
                type: MatchEventType.fieldGoal.name,
                side: const drift.Value('blue'),
                outcome: const drift.Value('missed'),
                occurredAt: base.add(Duration(seconds: index, milliseconds: 1)),
              ),
            );
            batch.insert(
              database.shotLocations,
              ShotLocationsCompanion.insert(
                id: '$matchId-location',
                matchId: matchId,
                eventId: madeId,
                x: 0.5,
                y: 0.5,
                isConfirmed: const drift.Value(true),
              ),
            );
          }
        });

        final stopwatch = Stopwatch()..start();
        final page = await repository.queryHistory(limit: 20);
        stopwatch.stop();

        expect(page.entries, hasLength(20));
        expect(page.entries.first.redScore, 2);
        expect(page.entries.first.shotAttemptCount, 2);
        expect(page.entries.first.locatedShotCount, 1);
        expect(repository.detailCalls, 0);
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(milliseconds: 500)),
          reason:
              '1000 matches x 2 events + 1 location first page took ${stopwatch.elapsed}',
        );
      });
    },
  );

  test(
    'history order index is recreated idempotently for an existing v2 database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hoopito-history-index-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}hooptrace.sqlite',
      );

      final first = await openNativeAppDatabaseAt(file);
      await first.close();
      final raw = sqlite3.sqlite3.open(file.path);
      raw.execute('DROP INDEX IF EXISTS matches_history_played_order');
      raw.close();

      final reopened = await openNativeAppDatabaseAt(file);
      addTearDown(reopened.close);
      await MatchRepository(reopened).queryHistory();
      final indexes = await reopened
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        contains('matches_history_played_order'),
      );
    },
  );

  test(
    'archive, unarchive, and confirmed delete have lifecycle and cascade semantics',
    () async {
      await withTestDatabase((database) async {
        final repository = MatchRepository(database);
        final lifecycle = MatchLifecycleRepository(database);
        await _saveMatch(
          database,
          id: 'match-archive',
          createdAt: DateTime.utc(2026, 5),
          lifecycle: MatchLifecycle.finished,
        );
        await database
            .into(database.matchEvents)
            .insert(
              MatchEventsCompanion.insert(
                id: 'archive-event',
                matchId: 'match-archive',
                type: MatchEventType.score.name,
                side: const drift.Value('red'),
                points: const drift.Value(2),
                occurredAt: DateTime.utc(2026, 5),
              ),
            );
        await database
            .into(database.auditLogs)
            .insert(
              AuditLogsCompanion.insert(
                id: 'archive-audit',
                matchId: 'match-archive',
                targetId: 'archive-event',
                action: 'create',
                beforeJson: '{}',
                afterJson: '{}',
                createdAt: DateTime.utc(2026, 5),
              ),
            );

        await lifecycle.archive('match-archive');
        expect(
          (await database.select(database.matches).getSingle()).lifecycle,
          MatchLifecycle.archived.name,
        );
        expect(
          (await repository.queryHistory(
            filter: const MatchHistoryFilter(archived: true),
          )).entries.map((entry) => entry.id),
          ['match-archive'],
        );

        await lifecycle.unarchive('match-archive');
        expect(
          (await database.select(database.matches).getSingle()).lifecycle,
          MatchLifecycle.finished.name,
        );

        expect(
          () => lifecycle.permanentlyDelete('match-archive', confirmed: false),
          throwsA(isA<ArgumentError>()),
        );
        await lifecycle.permanentlyDelete('match-archive', confirmed: true);
        expect(await database.select(database.matches).get(), isEmpty);
        expect(await database.select(database.matchEvents).get(), isEmpty);
        expect(await database.select(database.auditLogs).get(), isEmpty);
      });
    },
  );
}

Future<void> _saveMatch(
  AppDatabase database, {
  required String id,
  required DateTime createdAt,
  required MatchLifecycle lifecycle,
  RecordingMode recordingMode = RecordingMode.simple,
  String ruleId = 'rule-default',
  String ruleName = 'Default Rule',
  String? redProfileId,
}) async {
  final rule = RuleTemplate(
    id: ruleId,
    name: ruleName,
    scoreButtons: const [1, 2, 3],
  );
  await database
      .into(database.matches)
      .insert(
        MatchesCompanion.insert(
          id: id,
          lifecycle: drift.Value(lifecycle.name),
          recordingMode: drift.Value(recordingMode.name),
          ruleTemplateJson: jsonEncodeRule(rule),
          createdAt: createdAt,
          startedAt: drift.Value(createdAt),
          endedAt:
              lifecycle == MatchLifecycle.finished ||
                  lifecycle == MatchLifecycle.archived
              ? drift.Value(createdAt.add(const Duration(minutes: 5)))
              : const drift.Value.absent(),
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.matchParticipants, [
      MatchParticipantsCompanion.insert(
        id: '$id-red',
        matchId: id,
        side: TeamSide.red.name,
        nameSnapshot: 'Red $id',
        playerProfileId: drift.Value(redProfileId),
      ),
      MatchParticipantsCompanion.insert(
        id: '$id-blue',
        matchId: id,
        side: TeamSide.blue.name,
        nameSnapshot: 'Blue $id',
      ),
    ]);
  });
}

String jsonEncodeRule(RuleTemplate rule) {
  return '{"id":"${rule.id}","name":"${rule.name}","scoreButtons":[1,2,3],"targetScore":null,"timeLimitSeconds":null,"winByTwo":false,"foulLimit":null,"possessionHintEnabled":false,"possessionPolicy":"manual","customEventTypes":[]}';
}

class _CountingMatchRepository extends MatchRepository {
  _CountingMatchRepository(super.database);

  var detailCalls = 0;

  @override
  Future<MatchDetail?> getMatchDetail(String matchId) {
    detailCalls++;
    return super.getMatchDetail(matchId);
  }
}

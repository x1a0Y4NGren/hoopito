import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_lifecycle_repository.dart';
import 'package:hoopito/core/data/repositories/player_career_repository.dart';
import 'package:hoopito/core/domain/analytics/player_career_aggregate.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'career aggregate counts linked finished and archived matches only',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-1');
        await _insertMatch(database, 'finished', MatchLifecycle.finished);
        await _insertParticipant(
          database,
          'finished-red',
          'finished',
          TeamSide.red,
          playerId: 'player-1',
        );
        await _insertScore(
          database,
          'finished-red-score',
          'finished',
          TeamSide.red,
          2,
        );
        await _insertScore(
          database,
          'finished-blue-score',
          'finished',
          TeamSide.blue,
          1,
        );

        await _insertMatch(database, 'archived', MatchLifecycle.archived);
        await _insertParticipant(
          database,
          'archived-blue',
          'archived',
          TeamSide.blue,
          playerId: 'player-1',
        );
        await _insertScore(
          database,
          'archived-red-score',
          'archived',
          TeamSide.red,
          1,
        );
        await _insertScore(
          database,
          'archived-blue-score',
          'archived',
          TeamSide.blue,
          3,
        );

        await _insertMatch(database, 'abandoned', MatchLifecycle.abandoned);
        await _insertParticipant(
          database,
          'abandoned-red',
          'abandoned',
          TeamSide.red,
          playerId: 'player-1',
        );
        await _insertScore(
          database,
          'abandoned-red-score',
          'abandoned',
          TeamSide.red,
          99,
        );

        final aggregate = await PlayerCareerRepository(
          database,
        ).getByPlayerId('player-1');

        expect(aggregate.matches, 2);
        expect(aggregate.wins, 2);
        expect(aggregate.totalPoints, 5);
        expect(aggregate.averagePoints, 2.5);
        expect(aggregate.averageMargin, 1.5);
      });
    },
  );

  test('archiving and unarchiving do not change career totals', () async {
    await withTestDatabase((database) async {
      await _insertPlayer(database, 'player-1');
      await _insertMatch(database, 'match-1', MatchLifecycle.finished);
      await _insertParticipant(
        database,
        'match-1-red',
        'match-1',
        TeamSide.red,
        playerId: 'player-1',
      );
      await _insertScore(database, 'match-1-score', 'match-1', TeamSide.red, 4);

      final careers = PlayerCareerRepository(database);
      final lifecycle = MatchLifecycleRepository(database);
      final before = await careers.getByPlayerId('player-1');
      await lifecycle.archive('match-1');
      final archived = await careers.getByPlayerId('player-1');
      await lifecycle.unarchive('match-1');
      final restored = await careers.getByPlayerId('player-1');

      expect(archived, before);
      expect(restored, before);
      expect(
        (await database.select(database.matches).getSingle()).lifecycle,
        MatchLifecycle.finished.name,
      );
    });
  });

  test(
    'lifecycle transitions reject active matches and unconfirmed deletion',
    () async {
      await withTestDatabase((database) async {
        await _insertMatch(database, 'active', MatchLifecycle.active);
        final lifecycle = MatchLifecycleRepository(database);

        await expectLater(
          lifecycle.archive('active'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          lifecycle.permanentlyDelete('active', confirmed: true),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          lifecycle.permanentlyDelete('active', confirmed: false),
          throwsA(isA<ArgumentError>()),
        );
      });
    },
  );

  test(
    'career watch refreshes after participant linking and permanent deletion cascades',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-1');
        await _insertMatch(database, 'match-1', MatchLifecycle.finished);
        await _insertParticipant(
          database,
          'match-1-red',
          'match-1',
          TeamSide.red,
        );
        await _insertScore(
          database,
          'match-1-score',
          'match-1',
          TeamSide.red,
          2,
        );

        final careers = PlayerCareerRepository(database);
        final values = <PlayerCareerAggregate>[];
        final subscription = careers
            .watchByPlayerId('player-1')
            .listen(values.add);
        addTearDown(subscription.cancel);

        await _eventually(() => values.any((value) => value.matches == 0));
        await (database.update(
          database.matchParticipants,
        )..where((row) => row.id.equals('match-1-red'))).write(
          const MatchParticipantsCompanion(playerProfileId: Value('player-1')),
        );
        await _eventually(() => values.any((value) => value.matches == 1));
        final emissionCountBeforeDeletion = values.length;

        await database
            .into(database.shotLocations)
            .insert(
              ShotLocationsCompanion.insert(
                id: 'match-1-location',
                matchId: 'match-1',
                eventId: 'match-1-score',
                x: 0.5,
                y: 0.5,
                isConfirmed: const Value(true),
              ),
            );
        await database
            .into(database.possessionSegments)
            .insert(
              PossessionSegmentsCompanion.insert(
                id: 'match-1-possession',
                matchId: 'match-1',
                side: TeamSide.red.name,
                startedAtEventId: 'match-1-score',
              ),
            );
        await database
            .into(database.auditLogs)
            .insert(
              AuditLogsCompanion.insert(
                id: 'match-1-audit',
                matchId: 'match-1',
                targetId: 'match-1-score',
                action: 'edit',
                beforeJson: '{}',
                afterJson: '{}',
                createdAt: DateTime.utc(2026),
              ),
            );

        await MatchLifecycleRepository(
          database,
        ).permanentlyDelete('match-1', confirmed: true);
        await _eventually(
          () => values
              .skip(emissionCountBeforeDeletion)
              .any((value) => value.matches == 0),
        );

        expect(
          await careers.getByPlayerId('player-1'),
          PlayerCareerAggregate.empty('player-1'),
        );
        expect(await (database.select(database.matchEvents)).get(), isEmpty);
        expect(await (database.select(database.shotLocations)).get(), isEmpty);
        expect(
          await (database.select(database.possessionSegments)).get(),
          isEmpty,
        );
        expect(await (database.select(database.auditLogs)).get(), isEmpty);
      });
    },
  );

  test(
    'query windows use inclusive UTC boundaries and retain archived games',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'subject');
        await _insertPlayer(database, 'opponent-a');
        await _insertPlayer(database, 'opponent-b');
        await _insertMatch(
          database,
          'boundary',
          MatchLifecycle.finished,
          playedAt: DateTime.utc(2026, 8, 17),
        );
        await _insertParticipant(
          database,
          'boundary-subject',
          'boundary',
          TeamSide.red,
          playerId: 'subject',
        );
        await _insertParticipant(
          database,
          'boundary-opponent',
          'boundary',
          TeamSide.blue,
          playerId: 'opponent-a',
        );
        await _insertScore(database, 'boundary-r', 'boundary', TeamSide.red, 2);
        await _insertScore(
          database,
          'boundary-b',
          'boundary',
          TeamSide.blue,
          1,
        );

        await _insertMatch(
          database,
          'outside',
          MatchLifecycle.archived,
          playedAt: DateTime.utc(2026, 8, 16, 22, 59),
        );
        await _insertParticipant(
          database,
          'outside-subject',
          'outside',
          TeamSide.red,
          playerId: 'subject',
        );
        await _insertParticipant(
          database,
          'outside-opponent',
          'outside',
          TeamSide.blue,
          playerId: 'opponent-a',
        );
        await _insertScore(database, 'outside-r', 'outside', TeamSide.red, 9);

        await _insertMatch(
          database,
          'future',
          MatchLifecycle.finished,
          playedAt: DateTime.utc(2026, 8, 24, 0, 1),
        );
        await _insertParticipant(
          database,
          'future-subject',
          'future',
          TeamSide.red,
          playerId: 'subject',
        );
        await _insertParticipant(
          database,
          'future-opponent',
          'future',
          TeamSide.blue,
          playerId: 'opponent-a',
        );
        await _insertScore(database, 'future-r', 'future', TeamSide.red, 100);

        final repository = PlayerCareerRepository(database);
        final within = await repository.getByPlayerId(
          'subject',
          query: PlayerCareerQuery(
            window: PlayerCareerWindow.sevenDays,
            asOfUtc: DateTime.utc(2026, 8, 24),
          ),
        );
        expect(within.matches, 1);
        expect(within.totalPoints, 2);
        expect(within.zoneHeatmap, isEmpty);
      });
    },
  );

  test('head-to-head filters by opponent profile id, not nickname', () async {
    await withTestDatabase((database) async {
      await _insertPlayer(database, 'subject');
      await _insertPlayer(database, 'opponent-a');
      await _insertPlayer(database, 'opponent-b');
      await _insertMatch(database, 'versus-a', MatchLifecycle.finished);
      await _insertParticipant(
        database,
        'versus-a-subject',
        'versus-a',
        TeamSide.red,
        playerId: 'subject',
      );
      await _insertParticipant(
        database,
        'versus-a-player',
        'versus-a',
        TeamSide.blue,
        playerId: 'opponent-a',
      );
      await _insertScore(database, 'versus-a-r', 'versus-a', TeamSide.red, 4);

      await _insertMatch(database, 'versus-b', MatchLifecycle.finished);
      await _insertParticipant(
        database,
        'versus-b-subject',
        'versus-b',
        TeamSide.red,
        playerId: 'subject',
      );
      await _insertParticipant(
        database,
        'versus-b-player',
        'versus-b',
        TeamSide.blue,
        playerId: 'opponent-b',
      );
      await _insertScore(database, 'versus-b-r', 'versus-b', TeamSide.red, 7);

      final aggregate = await PlayerCareerRepository(database).getByPlayerId(
        'subject',
        query: const PlayerCareerQuery(opponentPlayerId: 'opponent-b'),
      );
      expect(aggregate.matches, 1);
      expect(aggregate.totalPoints, 7);
    });
  });

  test(
    'career shooting follows match scoring and only trusts recorded attempts',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'subject');
        await _insertMatch(
          database,
          'detailed',
          MatchLifecycle.finished,
          trackingCoverage: TrackingCoverage.shotAttempts,
        );
        await _insertParticipant(
          database,
          'detailed-subject',
          'detailed',
          TeamSide.red,
          playerId: 'subject',
        );
        await _insertParticipant(
          database,
          'detailed-opponent',
          'detailed',
          TeamSide.blue,
        );
        await _insertShot(
          database,
          'fg-made',
          'detailed',
          TeamSide.red,
          EventKind.fieldGoal,
          ShotOutcome.made,
          2,
        );
        await _insertShot(
          database,
          'fg-missed',
          'detailed',
          TeamSide.red,
          EventKind.fieldGoal,
          ShotOutcome.missed,
          0,
        );
        await _insertShot(
          database,
          'ft-made',
          'detailed',
          TeamSide.red,
          EventKind.freeThrow,
          ShotOutcome.made,
          1,
        );
        await _insertLocation(
          database,
          'fg-made-location',
          'detailed',
          'fg-made',
        );

        final aggregate = await PlayerCareerRepository(
          database,
        ).getByPlayerId('subject');
        expect(aggregate.totalPoints, 3);
        expect(aggregate.fieldGoalMade, 1);
        expect(aggregate.fieldGoalAttempts, 2);
        expect(aggregate.freeThrowMade, 1);
        expect(aggregate.freeThrowAttempts, 1);
        expect(aggregate.shootingTrend.single.isTrustworthy, isTrue);
        expect(aggregate.shootingTrend.single.recordedShootingPercentage, .5);
        expect(aggregate.shootingTrend.single.freeThrowPercentage, 1);
        expect(aggregate.zoneHeatmap.values, [1]);
        expect(aggregate.recentChange, const PlayerCareerRecentChange.empty());
        expect(() => aggregate.shootingTrend.clear(), throwsUnsupportedError);
        expect(() => aggregate.zoneHeatmap.clear(), throwsUnsupportedError);
      });
    },
  );
}

Future<void> _insertPlayer(AppDatabase database, String id) {
  return database
      .into(database.players)
      .insert(
        PlayersCompanion.insert(
          id: id,
          nickname: id,
          createdAt: DateTime.utc(2026),
        ),
      );
}

Future<void> _insertMatch(
  AppDatabase database,
  String id,
  MatchLifecycle lifecycle, {
  DateTime? playedAt,
  TrackingCoverage trackingCoverage = TrackingCoverage.scoresOnly,
}) {
  final date = playedAt ?? DateTime.utc(2026);
  return database
      .into(database.matches)
      .insert(
        MatchesCompanion.insert(
          id: id,
          lifecycle: Value(lifecycle.name),
          trackingCoverage: Value(trackingCoverage.name),
          ruleTemplateJson:
              '{"id":"free","name":"Free","scoreButtons":[1,2,3]}',
          createdAt: date,
          startedAt: Value(date),
          endedAt: Value(date.add(const Duration(hours: 1))),
        ),
      );
}

Future<void> _insertShot(
  AppDatabase database,
  String id,
  String matchId,
  TeamSide side,
  EventKind type,
  ShotOutcome outcome,
  int points,
) {
  return database
      .into(database.matchEvents)
      .insert(
        MatchEventsCompanion.insert(
          id: id,
          matchId: matchId,
          type: type.name,
          side: Value(side.name),
          points: Value(points),
          outcome: Value(outcome.name),
          occurredAt: DateTime.utc(2026),
        ),
      );
}

Future<void> _insertLocation(
  AppDatabase database,
  String id,
  String matchId,
  String eventId,
) {
  return database
      .into(database.shotLocations)
      .insert(
        ShotLocationsCompanion.insert(
          id: id,
          matchId: matchId,
          eventId: eventId,
          x: 0.5,
          y: 0.08,
          isConfirmed: const Value(true),
        ),
      );
}

Future<void> _insertParticipant(
  AppDatabase database,
  String id,
  String matchId,
  TeamSide side, {
  String? playerId,
}) {
  return database
      .into(database.matchParticipants)
      .insert(
        MatchParticipantsCompanion.insert(
          id: id,
          matchId: matchId,
          side: side.name,
          nameSnapshot: side.name,
          playerProfileId: Value(playerId),
        ),
      );
}

Future<void> _insertScore(
  AppDatabase database,
  String id,
  String matchId,
  TeamSide side,
  int points,
) {
  return database
      .into(database.matchEvents)
      .insert(
        MatchEventsCompanion.insert(
          id: id,
          matchId: matchId,
          type: MatchEventType.score.name,
          side: Value(side.name),
          points: Value(points),
          occurredAt: DateTime.utc(2026),
        ),
      );
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(predicate(), isTrue);
}

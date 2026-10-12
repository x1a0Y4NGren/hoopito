import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_comparison_repository.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('lists only linked finished or archived matches newest first', () async {
    final database = createTestDatabase();
    await _seedPlayers(database);
    await _seedMatch(
      database,
      id: 'older',
      playedAt: DateTime.utc(2026, 8, 10),
      lifecycle: 'finished',
      opponentId: 'opponent-a',
      opponentName: 'Opponent A at game time',
    );
    await _seedMatch(
      database,
      id: 'newer',
      playedAt: DateTime.utc(2026, 8, 20),
      lifecycle: 'archived',
      opponentId: 'opponent-b',
      opponentName: 'Opponent B at game time',
    );
    await _seedMatch(
      database,
      id: 'active',
      playedAt: DateTime.utc(2026, 8, 25),
      lifecycle: 'active',
      opponentId: 'opponent-a',
    );
    await _seedMatch(
      database,
      id: 'temporary-subject',
      playedAt: DateTime.utc(2026, 8, 24),
      lifecycle: 'finished',
      opponentId: 'opponent-a',
      linkedSubject: false,
    );

    final matches = await PlayerComparisonRepository(
      database,
    ).listEligibleMatches('player-main');

    expect(matches.map((match) => match.matchId), ['newer', 'older']);
    expect(matches.first.opponentPlayerId, 'opponent-b');
    expect(matches.first.opponentNameSnapshot, 'Opponent B at game time');
  });

  test('compares two distinct matches for the same profile', () async {
    final database = createTestDatabase();
    await _seedPlayers(database);
    await _seedMatch(
      database,
      id: 'baseline',
      playedAt: DateTime.utc(2026, 8, 10),
      lifecycle: 'finished',
      opponentId: 'opponent-a',
      playerScore: 8,
      opponentScore: 11,
      trackingCoverage: 'scoresOnly',
    );
    await _seedMatch(
      database,
      id: 'current',
      playedAt: DateTime.utc(2026, 8, 20),
      lifecycle: 'archived',
      opponentId: 'opponent-b',
      playerScore: 11,
      opponentScore: 7,
      trackingCoverage: 'shotAttempts',
    );
    final repository = PlayerComparisonRepository(database);

    final report = await repository.compare(
      const MatchPairComparisonRequest(
        playerId: 'player-main',
        baselineMatchId: 'baseline',
        currentMatchId: 'current',
      ),
    );

    expect(report.baseline.matchIds, ['baseline']);
    expect(report.current.matchIds, ['current']);
    expect(report.baseline.pointsFor, 8);
    expect(report.current.pointsFor, 11);
    expect(report.evidenceFor(PlayerComparisonMetric.points)?.delta, 3);
    expect(report.evidenceFor(PlayerComparisonMetric.result)?.delta, 2);
    expect(
      report.evidenceFor(PlayerComparisonMetric.fieldGoalPercentage)?.trend,
      ComparisonTrend.unavailable,
    );
    await expectLater(
      repository.compare(
        const MatchPairComparisonRequest(
          playerId: 'player-main',
          baselineMatchId: 'baseline',
          currentMatchId: 'baseline',
        ),
      ),
      throwsA(isA<PlayerComparisonException>()),
    );
  });

  test(
    'comparison is one consistent snapshot while a correction queues',
    () async {
      final database = createTestDatabase();
      await _seedPlayers(database);
      await _seedMatch(
        database,
        id: 'baseline',
        playedAt: DateTime.utc(2026, 8, 10),
        lifecycle: 'finished',
        opponentId: 'opponent-a',
        playerScore: 8,
      );
      await _seedMatch(
        database,
        id: 'current',
        playedAt: DateTime.utc(2026, 8, 20),
        lifecycle: 'finished',
        opponentId: 'opponent-a',
        playerScore: 11,
      );
      final repository = PlayerComparisonRepository(database);

      final comparison = repository.compare(
        const MatchPairComparisonRequest(
          playerId: 'player-main',
          baselineMatchId: 'baseline',
          currentMatchId: 'current',
        ),
      );
      final correction =
          (database.update(database.matchEvents)
                ..where((row) => row.id.equals('current-red-score')))
              .write(const MatchEventsCompanion(points: Value(12)));

      final report = await comparison;
      await correction;
      expect(report.current.pointsFor, 11);
    },
  );

  test(
    'uses adjacent half-open UTC windows and stable opponent filters',
    () async {
      final database = createTestDatabase();
      await _seedPlayers(database);
      await _seedMatch(
        database,
        id: 'before-baseline',
        playedAt: DateTime.utc(2026, 8, 14, 23, 59, 59),
        lifecycle: 'finished',
        opponentId: 'opponent-a',
      );
      await _seedMatch(
        database,
        id: 'baseline-lower-boundary',
        playedAt: DateTime.utc(2026, 8, 15),
        lifecycle: 'finished',
        opponentId: 'opponent-a',
      );
      await _seedMatch(
        database,
        id: 'baseline-other-opponent',
        playedAt: DateTime.utc(2026, 8, 21, 23, 59, 59),
        lifecycle: 'finished',
        opponentId: 'opponent-b',
      );
      await _seedMatch(
        database,
        id: 'current-lower-boundary',
        playedAt: DateTime.utc(2026, 8, 22),
        lifecycle: 'finished',
        opponentId: 'opponent-a',
      );
      await _seedMatch(
        database,
        id: 'current-other-opponent',
        playedAt: DateTime.utc(2026, 8, 28, 23, 59, 59),
        lifecycle: 'finished',
        opponentId: 'opponent-b',
      );
      await _seedMatch(
        database,
        id: 'at-as-of',
        playedAt: DateTime.utc(2026, 8, 29),
        lifecycle: 'finished',
        opponentId: 'opponent-a',
      );
      final repository = PlayerComparisonRepository(database);

      final report = await repository.compare(
        AdjacentWindowComparisonRequest(
          playerId: 'player-main',
          window: PlayerComparisonWindow.sevenDays,
          asOfUtc: DateTime.utc(2026, 8, 29),
          opponentPlayerId: 'opponent-a',
        ),
      );

      expect(report.baseline.matchIds, ['baseline-lower-boundary']);
      expect(report.current.matchIds, ['current-lower-boundary']);
      expect(report.baseline.startUtc, DateTime.utc(2026, 8, 15));
      expect(report.baseline.endUtc, DateTime.utc(2026, 8, 22));
      expect(report.current.startUtc, DateTime.utc(2026, 8, 22));
      expect(report.current.endUtc, DateTime.utc(2026, 8, 29));
      await expectLater(
        repository.compare(
          AdjacentWindowComparisonRequest(
            playerId: 'player-main',
            window: PlayerComparisonWindow.sevenDays,
            asOfUtc: DateTime.utc(2026, 8, 29),
            opponentPlayerId: ' ',
          ),
        ),
        throwsA(isA<PlayerComparisonException>()),
      );
    },
  );

  test('archived corrections rebuild and deleted matches disappear', () async {
    final database = createTestDatabase();
    await _seedPlayers(database);
    await _seedMatch(
      database,
      id: 'archived',
      playedAt: DateTime.utc(2026, 8, 25),
      lifecycle: 'archived',
      opponentId: 'opponent-a',
      playerScore: 2,
    );
    final repository = PlayerComparisonRepository(database);
    final request = AdjacentWindowComparisonRequest(
      playerId: 'player-main',
      window: PlayerComparisonWindow.sevenDays,
      asOfUtc: DateTime.utc(2026, 8, 29),
    );

    expect((await repository.compare(request)).current.pointsFor, 2);
    await database
        .into(database.matchEvents)
        .insert(
          MatchEventRow(
            id: 'archived-correction',
            matchId: 'archived',
            type: 'score',
            side: 'red',
            points: 1,
            outcome: 'made',
            occurredAt: DateTime.utc(2026, 8, 25, 0, 1),
            note: null,
            matchClockPositionSeconds: null,
            customLabel: null,
            isDeleted: false,
          ),
        );
    expect((await repository.compare(request)).current.pointsFor, 3);

    await (database.delete(
      database.matches,
    )..where((row) => row.id.equals('archived'))).go();
    expect((await repository.compare(request)).current.isEmpty, isTrue);
  });
}

Future<void> _seedPlayers(AppDatabase database) async {
  await database.batch((batch) {
    batch.insertAll(database.players, [
      PlayerRow(
        id: 'player-main',
        nickname: 'Main',
        createdAt: DateTime.utc(2026),
      ),
      PlayerRow(
        id: 'opponent-a',
        nickname: 'Opponent A now',
        createdAt: DateTime.utc(2026),
      ),
      PlayerRow(
        id: 'opponent-b',
        nickname: 'Opponent B now',
        createdAt: DateTime.utc(2026),
      ),
    ]);
  });
}

Future<void> _seedMatch(
  AppDatabase database, {
  required String id,
  required DateTime playedAt,
  required String lifecycle,
  required String opponentId,
  String? opponentName,
  bool linkedSubject = true,
  int playerScore = 2,
  int opponentScore = 1,
  String trackingCoverage = 'shotAttempts',
}) async {
  await database.batch((batch) {
    batch.insert(
      database.matches,
      Matche(
        id: id,
        lifecycle: lifecycle,
        recordingMode: 'detailed',
        trackingCoverage: trackingCoverage,
        ruleTemplateJson: '{}',
        createdAt: playedAt,
        startedAt: playedAt,
        endedAt: lifecycle == 'active'
            ? null
            : playedAt.add(const Duration(minutes: 8)),
        timerEnabled: false,
        note: null,
      ),
    );
    batch.insertAll(database.matchParticipants, [
      MatchParticipant(
        id: '$id-red',
        matchId: id,
        side: 'red',
        nameSnapshot: linkedSubject ? 'Main at game time' : 'Temporary',
        playerProfileId: linkedSubject ? 'player-main' : null,
      ),
      MatchParticipant(
        id: '$id-blue',
        matchId: id,
        side: 'blue',
        nameSnapshot: opponentName ?? 'Opponent at game time',
        playerProfileId: opponentId,
      ),
    ]);
    batch.insertAll(database.matchEvents, [
      MatchEventRow(
        id: '$id-red-score',
        matchId: id,
        type: playerScore == 0 ? 'miss' : 'score',
        side: 'red',
        points: playerScore,
        outcome: playerScore == 0 ? 'missed' : 'made',
        occurredAt: playedAt.add(const Duration(seconds: 1)),
        note: null,
        matchClockPositionSeconds: null,
        customLabel: null,
        isDeleted: false,
      ),
      MatchEventRow(
        id: '$id-blue-score',
        matchId: id,
        type: opponentScore == 0 ? 'miss' : 'score',
        side: 'blue',
        points: opponentScore,
        outcome: opponentScore == 0 ? 'missed' : 'made',
        occurredAt: playedAt.add(const Duration(seconds: 2)),
        note: null,
        matchClockPositionSeconds: null,
        customLabel: null,
        isDeleted: false,
      ),
    ]);
  });
}

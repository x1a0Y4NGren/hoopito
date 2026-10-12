import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';
import 'package:hoopito/features/players/player_comparison_controller.dart';

void main() {
  test(
    'defaults to the newest two eligible matches and can swap them',
    () async {
      final requests = <PlayerComparisonRequest>[];
      final controller = PlayerComparisonController(
        playerId: 'player-1',
        asOfUtc: DateTime.utc(2026, 8, 29),
        listMatches: (_) async => [
          _match('newest', DateTime.utc(2026, 8, 28), 'opponent-b', '北辰'),
          _match('older', DateTime.utc(2026, 8, 20), 'opponent-a', '阿岚'),
          _match('oldest', DateTime.utc(2026, 8, 10), 'opponent-a', '阿岚旧名'),
        ],
        compare: (request) async {
          requests.add(request);
          return _report(request);
        },
      );
      addTearDown(controller.dispose);

      await _waitUntil(() => !controller.isLoading);

      expect(controller.baselineMatchId, 'older');
      expect(controller.currentMatchId, 'newest');
      expect(controller.matches.map((match) => match.matchId), [
        'newest',
        'older',
        'oldest',
      ]);
      expect(controller.opponents.map((value) => value.playerId), [
        'opponent-b',
        'opponent-a',
      ]);
      expect(controller.opponents.last.nameSnapshot, '阿岚');
      expect(requests.single, isA<MatchPairComparisonRequest>());

      controller.swapMatches();
      await _waitUntil(() => !controller.isLoading);
      expect(controller.baselineMatchId, 'newest');
      expect(controller.currentMatchId, 'older');

      controller.setBaselineMatch('older');
      await _waitUntil(() => !controller.isLoading);
      expect(controller.baselineMatchId, 'older');
      expect(controller.currentMatchId, 'newest');
    },
  );

  test(
    'window changes keep one fixed as-of instant and opponent profile ID',
    () async {
      final asOfUtc = DateTime.utc(2026, 8, 29, 9, 30);
      final requests = <PlayerComparisonRequest>[];
      final controller = PlayerComparisonController(
        playerId: 'player-1',
        asOfUtc: asOfUtc,
        listMatches: (_) async => [
          _match('newest', DateTime.utc(2026, 8, 28), 'opponent-a', '阿岚'),
        ],
        compare: (request) async {
          requests.add(request);
          return _report(request);
        },
      );
      addTearDown(controller.dispose);
      await _waitUntil(() => !controller.isLoading);
      expect(controller.hasEnoughMatchesForPair, isFalse);

      controller.setMode(PlayerComparisonMode.adjacentWindow);
      await _waitUntil(() => !controller.isLoading);
      controller.setWindow(PlayerComparisonWindow.ninetyDays);
      await _waitUntil(() => !controller.isLoading);
      controller.setOpponent('opponent-a');
      await _waitUntil(() => !controller.isLoading);

      final request = requests.last as AdjacentWindowComparisonRequest;
      expect(request.asOfUtc, asOfUtc);
      expect(request.window, PlayerComparisonWindow.ninetyDays);
      expect(request.opponentPlayerId, 'opponent-a');
    },
  );

  test('retry recovers from load errors', () async {
    var attempt = 0;
    final controller = PlayerComparisonController(
      playerId: 'player-1',
      asOfUtc: DateTime.utc(2026, 8, 29),
      listMatches: (_) async {
        attempt++;
        if (attempt == 1) throw StateError('offline');
        return [
          _match('newest', DateTime.utc(2026, 8, 28), null, '临时对手'),
          _match('older', DateTime.utc(2026, 8, 20), null, '旧对手'),
        ];
      },
      compare: (request) async => _report(request),
    );
    addTearDown(controller.dispose);
    await _waitUntil(() => !controller.isLoading);
    expect(controller.error, isA<StateError>());

    controller.retry();
    await _waitUntil(() => !controller.isLoading);
    expect(controller.error, isNull);
    expect(controller.report, isNotNull);
  });

  test(
    'late comparison results cannot replace the current selection',
    () async {
      final first = Completer<PlayerComparisonReport>();
      final second = Completer<PlayerComparisonReport>();
      var call = 0;
      final controller = PlayerComparisonController(
        playerId: 'player-1',
        asOfUtc: DateTime.utc(2026, 8, 29),
        listMatches: (_) async => [
          _match('newest', DateTime.utc(2026, 8, 28), null, 'New'),
          _match('older', DateTime.utc(2026, 8, 20), null, 'Old'),
        ],
        compare: (request) {
          call++;
          return call == 1 ? first.future : second.future;
        },
      );
      addTearDown(controller.dispose);
      await _waitUntil(() => call == 1);

      controller.setMode(PlayerComparisonMode.adjacentWindow);
      await _waitUntil(() => call == 2);
      second.complete(
        _taggedReport(PlayerComparisonMode.adjacentWindow, 'current-window'),
      );
      await _waitUntil(() => !controller.isLoading);
      first.complete(
        _taggedReport(PlayerComparisonMode.matchPair, 'stale-pair'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.report?.mode, PlayerComparisonMode.adjacentWindow);
      expect(controller.report?.current.matchIds, ['current-window']);
    },
  );
}

PlayerComparisonMatch _match(
  String id,
  DateTime playedAt,
  String? opponentId,
  String opponentName,
) => PlayerComparisonMatch(
  matchId: id,
  playedAtUtc: playedAt,
  opponentPlayerId: opponentId,
  opponentNameSnapshot: opponentName,
  playerScore: 11,
  opponentScore: 8,
);

PlayerComparisonReport _report(PlayerComparisonRequest request) =>
    _taggedReport(
      request is MatchPairComparisonRequest
          ? PlayerComparisonMode.matchPair
          : PlayerComparisonMode.adjacentWindow,
      request is MatchPairComparisonRequest
          ? request.currentMatchId
          : 'current-window',
    );

PlayerComparisonReport _taggedReport(PlayerComparisonMode mode, String id) {
  final start = DateTime.utc(2026, 8, 1);
  return PlayerComparisonReportBuilder().build(
    mode: mode,
    baseline: PlayerComparisonSample.empty(
      startUtc: start,
      endUtc: start.add(const Duration(days: 7)),
    ),
    current: PlayerComparisonSample(
      startUtc: start.add(const Duration(days: 7)),
      endUtc: start.add(const Duration(days: 14)),
      matchIds: [id],
      wins: 1,
      pointsFor: 11,
      pointsAgainst: 8,
      fieldGoalMade: 5,
      fieldGoalAttempts: 10,
      freeThrowMade: 1,
      freeThrowAttempts: 2,
      trustworthyAttemptMatchCount: 1,
      confirmedLocationCount: 0,
      locatableAttemptCount: 0,
      zoneDistribution: const {},
    ),
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var index = 0; index < 100; index++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for controller state.');
}

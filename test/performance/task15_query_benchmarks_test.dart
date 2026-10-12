import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/match_view_data_mapper.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';

import '../test_helpers/test_database.dart';

const _fixtureMatchCount = 1000;
const _fixtureEventCount = 10000;
const _queryTarget = Duration(milliseconds: 500);
const _ruleSnapshot =
    '{"id":"free","name":"Free","scoreButtons":[1,2,3],'
    '"targetScore":null,"timeLimitSeconds":null,"winByTwo":false,'
    '"foulLimit":null,"possessionHintEnabled":false,'
    '"customEventTypes":[]}';

void main() {
  test(
    '1000-match first page and 10000-event fixture replay stay below 500ms',
    () async {
      await withTestDatabase((database) async {
        await _seedPerformanceFixture(database);
        final repository = MatchRepository(database);

        final historyWatch = Stopwatch()..start();
        final firstPage = await repository.queryHistory(limit: 20);
        historyWatch.stop();

        final replayWatch = Stopwatch()..start();
        final detail = await repository.getMatchDetail('match-0000');
        final replay = replayDataFromDetail(detail!);
        replayWatch.stop();

        debugPrint(
          'TASK15_QUERY_BENCHMARK '
          'history_first_page_ms=${historyWatch.elapsedMicroseconds / 1000} '
          'replay_projection_ms=${replayWatch.elapsedMicroseconds / 1000} '
          'matches=$_fixtureMatchCount events=$_fixtureEventCount',
        );

        expect(firstPage.entries, hasLength(20));
        expect(firstPage.hasMore, isTrue);
        expect(replay.events, hasLength(1009));
        expect(
          historyWatch.elapsed,
          lessThan(_queryTarget),
          reason:
              'history first page took ${historyWatch.elapsedMilliseconds}ms',
        );
        expect(
          replayWatch.elapsed,
          lessThan(_queryTarget),
          reason: 'replay projection took ${replayWatch.elapsedMilliseconds}ms',
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _seedPerformanceFixture(AppDatabase database) async {
  final base = DateTime.utc(2026, 1, 1);
  final matches = <Matche>[];
  final participants = <MatchParticipant>[];
  final events = <MatchEventRow>[];
  for (var matchIndex = 0; matchIndex < _fixtureMatchCount; matchIndex++) {
    final matchId = 'match-${matchIndex.toString().padLeft(4, '0')}';
    final startedAt = base.add(Duration(minutes: matchIndex));
    matches.add(
      Matche(
        id: matchId,
        lifecycle: 'finished',
        recordingMode: 'simple',
        trackingCoverage: 'scoresOnly',
        ruleTemplateJson: _ruleSnapshot,
        createdAt: startedAt,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 8)),
        timerEnabled: false,
        note: null,
      ),
    );
    participants.addAll([
      MatchParticipant(
        id: '$matchId-red',
        matchId: matchId,
        side: 'red',
        nameSnapshot: 'Red $matchIndex',
      ),
      MatchParticipant(
        id: '$matchId-blue',
        matchId: matchId,
        side: 'blue',
        nameSnapshot: 'Blue $matchIndex',
      ),
    ]);
    final eventCount = matchIndex == 0 ? 1009 : 9;
    for (var eventIndex = 0; eventIndex < eventCount; eventIndex++) {
      events.add(
        MatchEventRow(
          id: '$matchId-event-$eventIndex',
          matchId: matchId,
          type: 'score',
          side: eventIndex.isEven ? 'red' : 'blue',
          points: 1,
          outcome: 'made',
          occurredAt: startedAt.add(Duration(milliseconds: eventIndex)),
          note: null,
          matchClockPositionSeconds: null,
          customLabel: null,
          isDeleted: false,
        ),
      );
    }
  }
  expect(matches, hasLength(_fixtureMatchCount));
  expect(events, hasLength(_fixtureEventCount));

  await database.batch((batch) {
    batch.insertAll(database.matches, matches);
    batch.insertAll(database.matchParticipants, participants);
    batch.insertAll(database.matchEvents, events);
  });
}

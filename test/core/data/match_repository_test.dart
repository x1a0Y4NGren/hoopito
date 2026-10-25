import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart' hide ShotLocation;
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('match repository stores and reads score events', () async {
    final database = createTestDatabase();

    final repository = MatchRepository(database);
    await repository.createMinimalMatch(
      id: 'match-1',
      redName: 'Red',
      blueName: 'Blue',
      createdAt: DateTime.utc(2026),
    );
    await repository.addEvent(
      MatchEvent.score(
        id: 'event-1',
        matchId: 'match-1',
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026),
      ),
    );

    final events = await repository.watchEvents('match-1').first;
    expect(events.single.points, 2);
    expect(events.single.side, TeamSide.red);
  });

  test(
    'match repository row mapper fails clearly when score row is invalid',
    () {
      final row = MatchEventRow(
        id: 'invalid-score',
        matchId: 'match-1',
        type: MatchEventType.score.name,
        side: null,
        points: 0,
        outcome: null,
        matchClockPositionSeconds: null,
        occurredAt: DateTime.utc(2026),
        note: null,
        customLabel: null,
        isDeleted: false,
      );

      expect(
        () => MatchRepository.mapEventRow(row),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Invalid persisted score event invalid-score'),
          ),
        ),
      );
    },
  );

  test(
    'database rejects persisted score rows without side and points',
    () async {
      final database = createTestDatabase();

      final repository = MatchRepository(database);
      await repository.createMinimalMatch(
        id: 'match-1',
        redName: 'Red',
        blueName: 'Blue',
        createdAt: DateTime.utc(2026),
      );
      final invalidInsert = database
          .into(database.matchEvents)
          .insert(
            MatchEventsCompanion.insert(
              id: 'invalid-score',
              matchId: 'match-1',
              type: MatchEventType.score.name,
              occurredAt: DateTime.utc(2026),
            ),
          );
      // Existing v1 databases and raw imports are additionally guarded by the
      // repository mapper, but new writes should fail at SQLite level.
      await expectLater(invalidInsert, throwsException);
    },
  );

  test('stores complete pre-match information', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    final match = _match(
      id: 'match-full',
      createdAt: DateTime.utc(2026, 7, 10, 8),
      startedAt: DateTime.utc(2026, 7, 10, 8, 5),
      timerEnabled: true,
      note: 'Final court',
    );

    await repository.saveMatch(match);

    final detail = await repository.getMatchDetail(match.id);
    expect(detail, isNotNull);
    expect(detail!.match.id, match.id);
    expect(detail.match.status, MatchStatus.active);
    expect(detail.match.redName, 'Red Dragons');
    expect(detail.match.blueName, 'Blue Waves');
    expect(detail.match.startedAt, match.startedAt);
    expect(detail.match.timerEnabled, isTrue);
    expect(detail.match.note, 'Final court');
    expect(detail.match.ruleTemplateSnapshot.name, 'Race to 11');
    expect(detail.match.ruleTemplateSnapshot.scoreButtons, [1, 2, 3]);
    expect(detail.match.ruleTemplateSnapshot.targetScore, 11);
    expect(detail.match.ruleTemplateSnapshot.timeLimitSeconds, 600);
    expect(detail.match.ruleTemplateSnapshot.winByTwo, isTrue);
    expect(detail.match.ruleTemplateSnapshot.foulLimit, 5);
    expect(detail.match.ruleTemplateSnapshot.customEventTypes, ['steal']);
  });

  test('upserts events and shot locations without duplicating them', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    await repository.saveMatch(_match(id: 'match-1'));
    final occurredAt = DateTime.utc(2026, 7, 10, 9);
    final original = MatchEvent.score(
      id: 'event-1',
      matchId: 'match-1',
      side: TeamSide.red,
      points: 2,
      occurredAt: occurredAt,
    );
    final updated = MatchEvent(
      id: 'event-1',
      matchId: 'match-1',
      type: MatchEventType.score,
      side: TeamSide.blue,
      points: 3,
      occurredAt: occurredAt.add(const Duration(seconds: 1)),
      note: 'corrected',
    );

    await repository.saveEvent(original);
    await repository.saveEvent(updated);
    await repository.saveShotLocation(
      ShotLocation(
        id: 'shot-1',
        matchId: 'match-1',
        eventId: 'event-1',
        point: CourtPoint(x: 0.2, y: 0.3),
        isConfirmed: false,
      ),
    );
    await repository.saveShotLocation(
      ShotLocation(
        id: 'shot-1',
        matchId: 'match-1',
        eventId: 'event-1',
        point: CourtPoint(x: 0.8, y: 0.7),
        isConfirmed: true,
      ),
    );

    final detail = (await repository.getMatchDetail('match-1'))!;
    expect(detail.events, hasLength(1));
    expect(detail.events.single.side, TeamSide.blue);
    expect(detail.events.single.points, 3);
    expect(detail.events.single.note, 'corrected');
    expect(detail.shotLocations, hasLength(1));
    expect(detail.shotLocations.single.point.x, 0.8);
    expect(detail.shotLocations.single.point.y, 0.7);
    expect(detail.shotLocations.single.isConfirmed, isTrue);
  });

  test('saves an event and its shot location atomically', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    await repository.saveMatch(_match(id: 'match-1'));
    final event = MatchEvent.score(
      id: 'event-1',
      matchId: 'match-1',
      side: TeamSide.red,
      points: 2,
      occurredAt: DateTime.utc(2026, 7, 10, 9),
    );

    await repository.saveEventWithShotLocation(
      event,
      shotLocation: ShotLocation(
        id: 'shot-1',
        matchId: 'match-1',
        eventId: event.id,
        point: CourtPoint(x: 0.4, y: 0.6),
        isConfirmed: true,
      ),
    );

    final detail = (await repository.getMatchDetail('match-1'))!;
    expect(detail.events.map((item) => item.id), ['event-1']);
    expect(detail.shotLocations.map((item) => item.eventId), ['event-1']);
  });

  test('replaces a match snapshot without retaining an undone event', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    await repository.saveMatch(_match(id: 'match-1'));
    final occurredAt = DateTime.utc(2026, 7, 10, 9);
    final firstEvent = MatchEvent.score(
      id: 'event-1',
      matchId: 'match-1',
      side: TeamSide.red,
      points: 2,
      occurredAt: occurredAt,
    );
    final undoneEvent = MatchEvent(
      id: 'event-2',
      matchId: 'match-1',
      type: MatchEventType.miss,
      side: TeamSide.blue,
      points: 0,
      occurredAt: occurredAt.add(const Duration(seconds: 1)),
    );
    final firstLocation = ShotLocation(
      id: 'shot-1',
      matchId: 'match-1',
      eventId: firstEvent.id,
      point: CourtPoint(x: 0.2, y: 0.3),
      isConfirmed: true,
    );
    final undoneLocation = ShotLocation(
      id: 'shot-2',
      matchId: 'match-1',
      eventId: undoneEvent.id,
      point: CourtPoint(x: 0.8, y: 0.7),
      isConfirmed: true,
    );
    await repository.replaceMatchSnapshot(
      'match-1',
      events: [firstEvent, undoneEvent],
      shotLocations: [firstLocation, undoneLocation],
    );
    final updatedFirstEvent = MatchEvent(
      id: firstEvent.id,
      matchId: firstEvent.matchId,
      type: firstEvent.type,
      side: firstEvent.side,
      points: firstEvent.points,
      occurredAt: firstEvent.occurredAt,
      note: 'kept after undo',
    );

    await repository.replaceMatchSnapshot(
      'match-1',
      events: [updatedFirstEvent],
      shotLocations: [firstLocation],
    );

    final detail = (await repository.getMatchDetail('match-1'))!;
    expect(detail.events.map((event) => event.id), ['event-1']);
    expect(detail.events.single.note, 'kept after undo');
    expect(detail.shotLocations.map((location) => location.id), ['shot-1']);
  });

  test('finishes a match and reads complete replay statistics', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    final startedAt = DateTime.utc(2026, 7, 10, 9);
    final endedAt = startedAt.add(const Duration(minutes: 12, seconds: 30));
    await repository.saveMatch(
      _match(id: 'match-1', createdAt: startedAt, startedAt: startedAt),
    );
    final events = [
      MatchEvent.score(
        id: 'red-score',
        matchId: 'match-1',
        side: TeamSide.red,
        points: 2,
        occurredAt: startedAt,
      ),
      MatchEvent(
        id: 'blue-score',
        matchId: 'match-1',
        type: MatchEventType.score,
        side: TeamSide.blue,
        points: 3,
        occurredAt: startedAt.add(const Duration(seconds: 1)),
      ),
      MatchEvent(
        id: 'red-miss',
        matchId: 'match-1',
        type: MatchEventType.miss,
        side: TeamSide.red,
        points: 0,
        occurredAt: startedAt.add(const Duration(seconds: 2)),
      ),
      MatchEvent(
        id: 'red-foul',
        matchId: 'match-1',
        type: MatchEventType.foul,
        side: TeamSide.red,
        points: 0,
        occurredAt: startedAt.add(const Duration(seconds: 3)),
      ),
      MatchEvent(
        id: 'deleted-blue-foul',
        matchId: 'match-1',
        type: MatchEventType.foul,
        side: TeamSide.blue,
        points: 0,
        occurredAt: startedAt.add(const Duration(seconds: 4)),
        isDeleted: true,
      ),
    ];
    for (final event in events) {
      await repository.saveEvent(event);
    }
    await repository.saveShotLocation(
      ShotLocation(
        id: 'shot-1',
        matchId: 'match-1',
        eventId: 'red-score',
        point: CourtPoint(x: 0.5, y: 0.5),
        isConfirmed: true,
      ),
    );

    await repository.finishMatch('match-1', endedAt: endedAt);

    final detail = (await repository.getMatchDetail('match-1'))!;
    expect(detail.match.status, MatchStatus.finished);
    expect(detail.match.endedAt, endedAt);
    expect(detail.redScore, 2);
    expect(detail.blueScore, 3);
    expect(detail.redFouls, 1);
    expect(detail.blueFouls, 0);
    expect(detail.winner, TeamSide.blue);
    expect(detail.duration, const Duration(minutes: 12, seconds: 30));
    expect(detail.locatedShotCount, 1);
    expect(detail.shotAttemptCount, 3);
    expect(detail.shotLocationCompleteness, closeTo(1 / 3, 0.0001));
    expect(detail.events, hasLength(5));
    expect(detail.shotLocations, hasLength(1));
  });

  test('lists and watches history in most-recent-first order', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    final older = DateTime.utc(2026, 7, 9, 10);
    final newer = DateTime.utc(2026, 7, 10, 10);
    await repository.saveMatch(
      _match(id: 'older', createdAt: older, startedAt: older),
    );
    await repository.finishMatch(
      'older',
      endedAt: older.add(const Duration(minutes: 5)),
    );
    await repository.saveMatch(
      _match(id: 'newer', createdAt: newer, startedAt: newer),
    );
    await repository.saveEvent(
      MatchEvent.score(
        id: 'newer-score',
        matchId: 'newer',
        side: TeamSide.red,
        points: 2,
        occurredAt: newer,
      ),
    );
    await repository.finishMatch(
      'newer',
      endedAt: newer.add(const Duration(minutes: 7)),
    );

    final listed = await repository.listHistory();
    final watched = await repository.watchHistory().first;

    for (final history in [listed, watched]) {
      expect(history.map((item) => item.id), ['newer', 'older']);
      expect(history.first.playedAt, newer);
      expect(history.first.redName, 'Red Dragons');
      expect(history.first.blueName, 'Blue Waves');
      expect(history.first.redScore, 2);
      expect(history.first.blueScore, 0);
      expect(history.first.winner, TeamSide.red);
      expect(history.first.ruleName, 'Race to 11');
      expect(history.first.duration, const Duration(minutes: 7));
      expect(history.first.shotLocationCompleteness, 0);
    }
  });

  test('returns null for a missing match', () async {
    final database = createTestDatabase();

    expect(await MatchRepository(database).getMatchDetail('missing'), isNull);
  });
}

Match _match({
  required String id,
  DateTime? createdAt,
  DateTime? startedAt,
  bool timerEnabled = false,
  String? note,
}) {
  return Match(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 7, 10),
    startedAt: startedAt,
    status: MatchStatus.active,
    redName: 'Red Dragons',
    blueName: 'Blue Waves',
    ruleTemplateSnapshot: const RuleTemplate(
      id: 'race-11',
      name: 'Race to 11',
      scoreButtons: [1, 2, 3],
      targetScore: 11,
      timeLimitSeconds: 600,
      winByTwo: true,
      foulLimit: 5,
      customEventTypes: ['steal'],
    ),
    timerEnabled: timerEnabled,
    note: note,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/match_view_data_mapper.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/possession_segment.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';

void main() {
  test('maps persisted match detail into read-only replay data', () {
    final startedAt = DateTime.utc(2026, 7, 10, 10);
    final detail = MatchDetail(
      match: Match(
        id: 'match-1',
        createdAt: startedAt,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 4)),
        status: MatchStatus.finished,
        redName: '红方',
        blueName: '蓝方',
        ruleTemplateSnapshot: const RuleTemplate(
          id: 'free',
          name: '自由计分',
          scoreButtons: [1, 2, 3],
        ),
      ),
      events: [
        MatchEvent.score(
          id: 'score-1',
          matchId: 'match-1',
          side: TeamSide.red,
          points: 2,
          occurredAt: startedAt.add(const Duration(seconds: 12)),
        ),
      ],
      shotLocations: [
        ShotLocation(
          id: 'shot-1',
          matchId: 'match-1',
          eventId: 'score-1',
          point: CourtPoint(x: 0.2, y: 0.7),
          isConfirmed: true,
        ),
      ],
      redScore: 2,
      blueScore: 0,
      redFouls: 0,
      blueFouls: 0,
      shotAttemptCount: 1,
      locatedShotCount: 1,
    );

    final replay = replayDataFromDetail(detail);

    expect(replay.duration, const Duration(minutes: 4));
    expect(replay.events.single.kind, ReplayEventKind.score);
    expect(replay.events.single.elapsed, const Duration(seconds: 12));
    expect(replay.events.single.shotPoint?.x, 0.2);
    expect(replay.events.single.shotPoint?.y, 0.7);
    expect(replay.analytics?.madeShotCount, 1);
    expect(replay.analytics?.scoringFlow.single.eventId, 'score-1');
  });

  test(
    'preserves soft-deleted events and confirmed locations for replay review',
    () {
      final startedAt = DateTime.utc(2026, 7, 10, 10);
      final detail = MatchDetail(
        match: Match(
          id: 'match-1',
          createdAt: startedAt,
          startedAt: startedAt,
          status: MatchStatus.finished,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplateSnapshot: const RuleTemplate(
            id: 'free',
            name: 'Free scoring',
            scoreButtons: [1, 2, 3],
          ),
        ),
        events: [
          MatchEvent(
            id: 'deleted-score',
            matchId: 'match-1',
            type: MatchEventType.score,
            side: TeamSide.red,
            points: 2,
            occurredAt: startedAt.add(const Duration(seconds: 12)),
            isDeleted: true,
          ),
        ],
        shotLocations: [
          ShotLocation(
            id: 'deleted-shot',
            matchId: 'match-1',
            eventId: 'deleted-score',
            point: CourtPoint(x: 0.2, y: 0.7),
            isConfirmed: true,
          ),
        ],
        redScore: 0,
        blueScore: 0,
        redFouls: 0,
        blueFouls: 0,
        shotAttemptCount: 0,
        locatedShotCount: 0,
      );

      final replay = replayDataFromDetail(detail);

      expect(replay.events, hasLength(1));
      expect(replay.events.single.isDeleted, isTrue);
      expect(replay.events.single.locationId, 'deleted-shot');
      expect(replay.events.single.rawKind, MatchEventType.score);
    },
  );

  test('maps canonical made and missed attempts into replay categories', () {
    final startedAt = DateTime.utc(2026, 7, 10, 10);
    MatchEvent attempt(String id, MatchEventType type, ShotOutcome outcome) {
      return MatchEvent(
        id: id,
        matchId: 'canonical-attempts',
        type: type,
        side: TeamSide.red,
        points: outcome == ShotOutcome.made ? 1 : 0,
        outcome: outcome,
        occurredAt: startedAt,
      );
    }

    final replay = replayDataFromDetail(
      MatchDetail(
        match: Match(
          id: 'canonical-attempts',
          createdAt: startedAt,
          startedAt: startedAt,
          status: MatchStatus.finished,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplateSnapshot: const RuleTemplate(
            id: 'free',
            name: 'Free scoring',
            scoreButtons: [1, 2, 3],
          ),
        ),
        events: [
          attempt(
            'made-field-goal',
            MatchEventType.fieldGoal,
            ShotOutcome.made,
          ),
          attempt(
            'missed-field-goal',
            MatchEventType.fieldGoal,
            ShotOutcome.missed,
          ),
          attempt(
            'made-free-throw',
            MatchEventType.freeThrow,
            ShotOutcome.made,
          ),
          attempt(
            'missed-free-throw',
            MatchEventType.freeThrow,
            ShotOutcome.missed,
          ),
        ],
        shotLocations: const [],
        redScore: 2,
        blueScore: 0,
        redFouls: 0,
        blueFouls: 0,
        shotAttemptCount: 4,
        locatedShotCount: 0,
      ),
    );

    expect(replay.events.map((event) => event.kind), [
      ReplayEventKind.score,
      ReplayEventKind.miss,
      ReplayEventKind.score,
      ReplayEventKind.miss,
    ]);
    expect(replay.analytics?.recordedShootingPercentage, isNull);
    expect(replay.analytics?.shootingPercentageIsTrustworthy, isFalse);
  });

  test('keeps raw event facts needed by replay editors', () {
    final startedAt = DateTime.utc(2026, 7, 10, 10);
    final occurredAt = startedAt.add(const Duration(seconds: 31));
    final replay = replayDataFromDetail(
      MatchDetail(
        match: Match(
          id: 'raw-replay',
          createdAt: startedAt,
          startedAt: startedAt,
          status: MatchStatus.finished,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplateSnapshot: const RuleTemplate(
            id: 'free',
            name: 'Free scoring',
            scoreButtons: [1, 2, 3],
          ),
        ),
        events: [
          MatchEvent(
            id: 'raw-event',
            matchId: 'raw-replay',
            type: MatchEventType.custom,
            side: TeamSide.blue,
            points: 0,
            occurredAt: occurredAt,
            note: 'review this',
            outcome: ShotOutcome.notApplicable,
            matchClockPositionSeconds: 44,
            customLabel: 'timeout',
          ),
        ],
        shotLocations: const [],
        redScore: 0,
        blueScore: 0,
        redFouls: 0,
        blueFouls: 0,
        shotAttemptCount: 0,
        locatedShotCount: 0,
      ),
    );

    final event = replay.events.single;
    expect(event.rawKind, MatchEventType.custom);
    expect(event.eventType, MatchEventType.custom);
    expect(event.outcome, ShotOutcome.notApplicable);
    expect(event.customLabel, 'timeout');
    expect(event.occurredAt, occurredAt);
    expect(event.matchClockPositionSeconds, 44);
    expect(event.note, 'review this');
  });

  test('maps possession source and closed/open replay boundaries', () {
    final startedAt = DateTime.utc(2026, 7, 10, 10);
    final replay = replayDataFromDetail(
      MatchDetail(
        match: Match(
          id: 'possession-replay',
          createdAt: startedAt,
          startedAt: startedAt,
          status: MatchStatus.active,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplateSnapshot: const RuleTemplate(
            id: 'free',
            name: 'Free scoring',
            scoreButtons: [1, 2, 3],
          ),
        ),
        events: [
          MatchEvent(
            id: 'manual-start',
            matchId: 'possession-replay',
            type: MatchEventType.possession,
            side: TeamSide.red,
            points: 0,
            note: '裁判指定',
            occurredAt: startedAt.add(const Duration(seconds: 5)),
          ),
          MatchEvent.score(
            id: 'made-score',
            matchId: 'possession-replay',
            side: TeamSide.red,
            points: 1,
            occurredAt: startedAt.add(const Duration(seconds: 20)),
          ),
        ],
        shotLocations: const [],
        possessionSegments: [
          const PossessionSegment(
            id: 'manual-segment',
            matchId: 'possession-replay',
            side: TeamSide.red,
            startedAtEventId: 'manual-start',
            endedAtEventId: 'made-score',
            reason: '裁判指定',
            source: PossessionSource.manual,
          ),
          const PossessionSegment(
            id: 'suggested-segment',
            matchId: 'possession-replay',
            side: TeamSide.blue,
            startedAtEventId: 'made-score',
            reason: 'made:switchAfterMade;event:made-score',
            source: PossessionSource.suggested,
          ),
        ],
        redScore: 1,
        blueScore: 0,
        redFouls: 0,
        blueFouls: 0,
        shotAttemptCount: 1,
        locatedShotCount: 0,
      ),
    );

    expect(replay.isFinished, isFalse);
    expect(replay.possessionSegments, hasLength(2));
    expect(replay.possessionSegments[0].source, PossessionSource.manual);
    expect(replay.possessionSegments[0].reason, '裁判指定');
    expect(replay.possessionSegments[0].startedAt, const Duration(seconds: 5));
    expect(replay.possessionSegments[0].endedAt, const Duration(seconds: 20));
    expect(replay.possessionSegments[1].source, PossessionSource.suggested);
    expect(replay.possessionSegments[1].startedAt, const Duration(seconds: 20));
    expect(replay.possessionSegments[1].endedAt, isNull);
  });

  test('drops possession segments with missing or reversed boundaries', () {
    final startedAt = DateTime.utc(2026, 7, 10, 10);
    final replay = replayDataFromDetail(
      MatchDetail(
        match: Match(
          id: 'invalid-possession-replay',
          createdAt: startedAt,
          startedAt: startedAt,
          status: MatchStatus.active,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplateSnapshot: const RuleTemplate(
            id: 'free',
            name: 'Free scoring',
            scoreButtons: [1, 2, 3],
          ),
        ),
        events: [
          MatchEvent.score(
            id: 'early',
            matchId: 'invalid-possession-replay',
            side: TeamSide.red,
            points: 1,
            occurredAt: startedAt.add(const Duration(seconds: 5)),
          ),
          MatchEvent.score(
            id: 'late',
            matchId: 'invalid-possession-replay',
            side: TeamSide.blue,
            points: 1,
            occurredAt: startedAt.add(const Duration(seconds: 20)),
          ),
        ],
        shotLocations: const [],
        possessionSegments: const [
          PossessionSegment(
            id: 'missing-start',
            matchId: 'invalid-possession-replay',
            side: TeamSide.red,
            startedAtEventId: 'missing',
            source: PossessionSource.manual,
          ),
          PossessionSegment(
            id: 'missing-end',
            matchId: 'invalid-possession-replay',
            side: TeamSide.red,
            startedAtEventId: 'early',
            endedAtEventId: 'missing',
            source: PossessionSource.manual,
          ),
          PossessionSegment(
            id: 'reversed',
            matchId: 'invalid-possession-replay',
            side: TeamSide.blue,
            startedAtEventId: 'late',
            endedAtEventId: 'early',
            source: PossessionSource.suggested,
          ),
        ],
        redScore: 1,
        blueScore: 1,
        redFouls: 0,
        blueFouls: 0,
        shotAttemptCount: 2,
        locatedShotCount: 0,
      ),
    );

    expect(replay.possessionSegments, isEmpty);
    expect(replay.analytics!.possessionCount, 0);
  });
}

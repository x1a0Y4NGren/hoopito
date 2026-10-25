import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_event_filter.dart';

void main() {
  test(
    'location selection stays edit-only while event review stays available',
    () {
      final controller = ReplayController(
        data: ReplayMatchData(
          matchId: 'selection-contract',
          redName: 'Red',
          blueName: 'Blue',
          redScore: 2,
          blueScore: 0,
          duration: const Duration(seconds: 12),
          events: [
            ReplayEventData(
              id: 'event-1',
              kind: ReplayEventKind.score,
              side: TeamSide.red,
              points: 2,
              elapsed: const Duration(seconds: 12),
              locationId: 'location-1',
              shotPoint: CourtPoint(x: 0.3, y: 0.4),
            ),
          ],
        ),
        onMoveShotLocation: (_, _, _) async {},
      );

      controller.selectLocation('location-1');
      expect(controller.selectedEventId, isNull);

      controller.selectEvent('event-1');
      expect(controller.selectedEventId, 'event-1');

      controller.clearSelection();
      controller.setEditing(true);
      controller.selectLocation('location-1');
      expect(controller.selectedEventId, 'event-1');
    },
  );

  test('maps located scores and filters timeline without mutating data', () {
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'match-1',
        redName: '红队',
        blueName: '蓝队',
        redScore: 2,
        blueScore: 1,
        duration: const Duration(minutes: 8, seconds: 9),
        events: [
          ReplayEventData(
            id: 'score-red',
            kind: ReplayEventKind.score,
            side: TeamSide.red,
            points: 2,
            elapsed: const Duration(seconds: 12),
            shotPoint: CourtPoint(x: 0.25, y: 0.6),
          ),
          const ReplayEventData(
            id: 'foul-blue',
            kind: ReplayEventKind.foul,
            side: TeamSide.blue,
            elapsed: Duration(seconds: 20),
          ),
        ],
      ),
    );

    expect(controller.shotLocations, hasLength(1));
    expect(controller.shotLocations.single.eventId, 'score-red');
    expect(controller.shotLocations.single.side, TeamSide.red);
    expect(controller.shotLocations.single.isLocked, isTrue);

    controller.setKindFilter(ReplayKindFilter.fouls);
    controller.setSideFilter(ReplaySideFilter.blue);

    expect(controller.visibleEvents.map((event) => event.id), ['foul-blue']);
    expect(controller.data.events, hasLength(2));
  });

  test('composes side, raw kind, outcome, point, and deleted filters', () {
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'match-filter',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 3,
        blueScore: 0,
        duration: Duration.zero,
        events: [
          ReplayEventData(
            id: 'made-red',
            kind: ReplayEventKind.score,
            rawKind: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 3,
            outcome: ShotOutcome.made,
            elapsed: Duration.zero,
          ),
          ReplayEventData(
            id: 'deleted-red',
            kind: ReplayEventKind.score,
            rawKind: EventKind.score,
            side: TeamSide.red,
            points: 1,
            outcome: ShotOutcome.made,
            isDeleted: true,
            elapsed: const Duration(seconds: 1),
          ),
          const ReplayEventData(
            id: 'miss-blue',
            kind: ReplayEventKind.miss,
            rawKind: EventKind.freeThrow,
            side: TeamSide.blue,
            points: 0,
            outcome: ShotOutcome.missed,
            elapsed: Duration(seconds: 2),
          ),
        ],
      ),
    );

    controller.setEventFilter(
      const ReplayEventFilter(
        sides: {TeamSide.red},
        kinds: {EventKind.fieldGoal, EventKind.score},
        outcomes: {ShotOutcome.made},
        points: {3},
        includeDeleted: false,
      ),
    );

    expect(controller.visibleEvents.map((event) => event.id), ['made-red']);
    expect(controller.data.events, hasLength(3));

    controller.setEventFilter(
      const ReplayEventFilter(includeDeleted: true, points: {1}),
    );
    expect(controller.visibleEvents.map((event) => event.id), ['deleted-red']);
  });

  test('preserves the filter when replay data is replaced', () {
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'match-filter-replace',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 0,
        blueScore: 0,
        duration: Duration.zero,
        events: [
          const ReplayEventData(
            id: 'blue-event',
            kind: ReplayEventKind.other,
            side: TeamSide.blue,
            elapsed: Duration.zero,
          ),
        ],
      ),
    );
    controller.setEventFilter(const ReplayEventFilter(sides: {TeamSide.red}));

    controller.replaceData(
      ReplayMatchData(
        matchId: 'match-filter-replace',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 0,
        blueScore: 0,
        duration: Duration.zero,
        events: [
          const ReplayEventData(
            id: 'red-event',
            kind: ReplayEventKind.other,
            side: TeamSide.red,
            elapsed: Duration.zero,
          ),
        ],
      ),
    );

    expect(controller.visibleEvents.map((event) => event.id), ['red-event']);
  });
}

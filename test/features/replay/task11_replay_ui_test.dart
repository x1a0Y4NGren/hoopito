import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/audit/audit_diff.dart';
import 'package:hoopito/core/audit/audit_log_entry.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_event_filter.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/replay/widgets/replay_audit_sheet.dart';

void main() {
  test(
    'deleted events never become valid court markers and filters compose',
    () {
      final controller = ReplayController(
        data: ReplayMatchData(
          matchId: 'replay-filter',
          redName: 'Red',
          blueName: 'Blue',
          redScore: 2,
          blueScore: 0,
          duration: Duration.zero,
          events: [
            ReplayEventData(
              id: 'made',
              kind: ReplayEventKind.score,
              rawKind: EventKind.fieldGoal,
              side: TeamSide.red,
              points: 2,
              outcome: ShotOutcome.made,
              shotPoint: CourtPoint(x: 0.2, y: 0.3),
              elapsed: Duration.zero,
            ),
            ReplayEventData(
              id: 'missed',
              kind: ReplayEventKind.miss,
              rawKind: EventKind.fieldGoal,
              side: TeamSide.red,
              outcome: ShotOutcome.missed,
              shotPoint: CourtPoint(x: 0.4, y: 0.5),
              elapsed: Duration(seconds: 1),
            ),
            ReplayEventData(
              id: 'deleted',
              kind: ReplayEventKind.score,
              rawKind: EventKind.fieldGoal,
              side: TeamSide.red,
              points: 1,
              outcome: ShotOutcome.made,
              shotPoint: CourtPoint(x: 0.6, y: 0.7),
              isDeleted: true,
              elapsed: Duration(seconds: 2),
            ),
          ],
        ),
      );

      expect(controller.shotLocations.map((location) => location.eventId), [
        'made',
        'missed',
      ]);

      controller.setEventFilter(
        const ReplayEventFilterForTest(
          sides: {TeamSide.red},
          outcomes: {ShotOutcome.missed},
          points: {0},
          includeDeleted: false,
        ).value,
      );
      expect(controller.shotLocations.map((location) => location.eventId), [
        'missed',
      ]);
    },
  );

  test(
    'replay edit actions expose correction, restore, and location commands',
    () async {
      ReplayEventCorrection? correction;
      String? restored;
      CourtPoint? correctedLocation;
      final controller = ReplayController(
        data: _match(isDeleted: true),
        onCorrectEvent: (value) async => correction = value,
        onRestoreEvent: (eventId, _) async => restored = eventId,
        onCorrectShotLocation: (_, point, _) async => correctedLocation = point,
      );

      controller.setEditing(true);
      controller.selectEvent('event-1');
      await controller.correctSelectedEvent(
        type: EventKind.freeThrow,
        side: TeamSide.blue,
        points: 1,
        outcome: ShotOutcome.made,
        note: 'corrected',
        matchClockPositionSeconds: 12,
        reason: 'video review',
      );
      await controller.correctSelectedShotLocation(
        CourtPoint(x: 0.7, y: 0.8),
        reason: 'location review',
      );
      await controller.restoreSelectedEvent(reason: 'restore review');

      expect(correction?.type, EventKind.freeThrow);
      expect(correction?.side, TeamSide.blue);
      expect(correction?.points, 1);
      expect(correction?.outcome, ShotOutcome.made);
      expect(correction?.note, 'corrected');
      expect(correction?.matchClockPositionSeconds, 12);
      expect(correction?.reason, 'video review');
      expect(restored, 'event-1');
      expect(correctedLocation, isNotNull);
      expect(correctedLocation!.x, 0.7);
      expect(correctedLocation!.y, 0.8);
    },
  );

  testWidgets(
    'deleted event editor offers restore and keeps failures retryable',
    (tester) async {
      var restoreCalls = 0;
      final controller = ReplayController(
        data: _match(isDeleted: true),
        onRestoreEvent: (_, _) async {
          restoreCalls++;
          throw StateError('offline');
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: ReplayPage(controller: controller)),
      );
      await tester.tap(find.byKey(const Key('replay-edit-toggle')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('replay-event-event-1')));
      await tester.tap(find.byKey(const Key('replay-event-event-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('replay-editor-restore')), findsOneWidget);
      await tester.tap(find.byKey(const Key('replay-editor-restore')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认恢复'));
      await tester.pumpAndSettle();

      expect(restoreCalls, 1);
      expect(find.text('操作失败，请重试。'), findsOneWidget);
      expect(find.byKey(const Key('replay-editor-restore')), findsOneWidget);
    },
  );

  testWidgets(
    'audit sheet renders localized diff labels rather than internal names',
    (tester) async {
      final log = AuditLogEntry(
        id: 'audit-1',
        matchId: 'match-1',
        targetId: 'event-1',
        action: AuditAction.edit,
        createdAt: DateTime.utc(2026, 8, 24, 12, 30),
        reason: '录像复核',
        diff: const AuditDiff(
          before: {'points': 2, 'isDeleted': false},
          after: {'points': 3, 'isDeleted': false},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Material(child: ReplayAuditSheet(logs: [log])),
        ),
      );

      expect(find.textContaining('编辑'), findsWidgets);
      expect(find.textContaining('事件'), findsWidgets);
      expect(find.textContaining('分数'), findsWidgets);
      expect(find.textContaining('2 → 3'), findsOneWidget);
      expect(find.textContaining('edit'), findsNothing);
      expect(find.textContaining('points'), findsNothing);
    },
  );

  testWidgets('replay review remains usable at 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(home: ReplayPage(controller: _controllerForScale())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('replay-kind-all')), findsOneWidget);
    expect(find.byKey(const Key('replay-event-event-1')), findsOneWidget);
  });
}

ReplayController _controllerForScale() =>
    ReplayController(data: _match(isDeleted: false));

ReplayMatchData _match({required bool isDeleted}) {
  return ReplayMatchData(
    matchId: 'match-1',
    redName: 'Red',
    blueName: 'Blue',
    redScore: 2,
    blueScore: 0,
    duration: const Duration(minutes: 1),
    events: [
      ReplayEventData(
        id: 'event-1',
        kind: ReplayEventKind.score,
        rawKind: EventKind.fieldGoal,
        side: TeamSide.red,
        points: 2,
        outcome: ShotOutcome.made,
        elapsed: const Duration(seconds: 3),
        shotPoint: CourtPoint(x: 0.3, y: 0.4),
        locationId: 'location-1',
        isDeleted: isDeleted,
      ),
    ],
  );
}

/// Keeps this test's filter declaration readable while avoiding a production
/// alias that would make the public API harder to discover.
class ReplayEventFilterForTest {
  const ReplayEventFilterForTest({
    this.sides = const {},
    this.outcomes = const {},
    this.points = const {},
    this.includeDeleted = true,
  });

  final Set<TeamSide> sides;
  final Set<ShotOutcome?> outcomes;
  final Set<int> points;
  final bool includeDeleted;

  ReplayEventFilter get value => ReplayEventFilter(
    sides: sides,
    outcomes: outcomes,
    points: points,
    includeDeleted: includeDeleted,
  );
}

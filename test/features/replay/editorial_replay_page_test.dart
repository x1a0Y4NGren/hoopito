import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';

void main() {
  testWidgets('court marker selection synchronizes the editorial event rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );

    expect(find.byType(EditorialScaffold), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('replay-court-pane'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('replay-timeline-pane'))).width,
      ),
    );

    await tester.tap(find.byKey(const Key('replay-court-marker-event-1')));
    await tester.pump();

    expect(controller.selectedEventId, 'event-1');
    final court = tester.widget<CourtView>(find.byType(CourtView));
    expect(court.highlightedShotLocationId, 'location-1');
    final semantics = tester.getSemantics(
      find.byKey(const Key('replay-event-event-1')),
    );
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('editorial replay remains usable in dark mode at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: ReplayPage(controller: _controller()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EditorialScaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('replay-kind-all'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
    'edit-mode drag from a painted marker updates its pending point',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _editableController()
        ..setEditing(true)
        ..selectEvent('event-1');

      await tester.pumpWidget(
        MaterialApp(home: ReplayPage(controller: controller)),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('replay-court-marker-event-1')),
        findsNothing,
      );
      final courtFinder = find.byType(CourtView);
      final courtSize = tester.getSize(courtFinder);
      final marker =
          tester.getTopLeft(courtFinder) +
          HalfCourtGeometry.pointToOffset(
            CourtPoint(x: 0.32, y: 0.64),
            courtSize,
          );
      await tester.dragFrom(marker, const Offset(80, 0));
      await tester.pump();

      expect(controller.pendingShotLocation!.point.x, greaterThan(0.32));
    },
  );

  testWidgets('edge marker targets stay fully inside the painted court', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: _edgeController())),
    );
    await tester.pump();

    final courtFinder = find.byType(CourtView);
    final courtSize = tester.getSize(courtFinder);
    final courtOrigin = tester.getTopLeft(courtFinder);
    final paintedCourt = HalfCourtGeometry.courtRectForSize(
      courtSize,
    ).shift(courtOrigin);
    for (final eventId in ['corner-start', 'corner-end']) {
      final target = tester.getRect(
        find.byKey(Key('replay-court-marker-$eventId')),
      );
      // RenderBox coordinate subtraction may introduce sub-pixel rounding.
      expect(target.width, closeTo(48, 1e-9));
      expect(target.height, closeTo(48, 1e-9));
      expect(target.left, greaterThanOrEqualTo(paintedCourt.left));
      expect(target.top, greaterThanOrEqualTo(paintedCourt.top));
      expect(target.right, lessThanOrEqualTo(paintedCourt.right));
      expect(target.bottom, lessThanOrEqualTo(paintedCourt.bottom));
    }
  });

  testWidgets('identical shots have distinguishable marker semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: _edgeController())),
    );

    final first = tester
        .getSemantics(find.byKey(const Key('replay-court-marker-corner-start')))
        .getSemanticsData()
        .label;
    final second = tester
        .getSemantics(find.byKey(const Key('replay-court-marker-corner-end')))
        .getSemanticsData()
        .label;

    expect(first, contains('00:12'));
    expect(second, contains('00:34'));
    expect(first, isNot(second));
  });

  testWidgets('replay audit opens in the frozen editorial sheet', (
    tester,
  ) async {
    final base = _controller();
    final controller = ReplayController(
      data: base.data,
      loadAuditLogs: () async => [],
    );
    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('replay-audit-history')));
    await tester.pumpAndSettle();

    expect(find.byType(EditorialSheet), findsOneWidget);
  });

  testWidgets('replay edit opens in the frozen editorial sheet', (
    tester,
  ) async {
    final base = _controller();
    final controller = ReplayController(
      data: base.data,
      onUpdateEventNote: (_, _, _) async {},
    )..setEditing(true);
    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );

    await tester.ensureVisible(find.byKey(const Key('replay-event-event-1')));
    await tester.tap(find.byKey(const Key('replay-event-event-1')));
    await tester.pumpAndSettle();

    expect(find.byType(EditorialSheet), findsOneWidget);
  });
}

ReplayController _controller() => ReplayController(
  data: ReplayMatchData(
    matchId: 'editorial-replay',
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
        shotPoint: CourtPoint(x: 0.32, y: 0.64),
        locationId: 'location-1',
      ),
    ],
  ),
);

ReplayController _editableController() => ReplayController(
  data: _controller().data,
  onMoveShotLocation: (_, _, _) async {},
);

ReplayController _edgeController() => ReplayController(
  data: ReplayMatchData(
    matchId: 'edge-markers',
    redName: 'Red',
    blueName: 'Blue',
    redScore: 4,
    blueScore: 0,
    duration: const Duration(seconds: 34),
    events: [
      ReplayEventData(
        id: 'corner-start',
        kind: ReplayEventKind.score,
        side: TeamSide.red,
        points: 2,
        elapsed: const Duration(seconds: 12),
        locationId: 'location-start',
        shotPoint: CourtPoint(x: 0, y: 0),
      ),
      ReplayEventData(
        id: 'corner-end',
        kind: ReplayEventKind.score,
        side: TeamSide.red,
        points: 2,
        elapsed: const Duration(seconds: 34),
        locationId: 'location-end',
        shotPoint: CourtPoint(x: 1, y: 1),
      ),
    ],
  ),
);

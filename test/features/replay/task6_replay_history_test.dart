import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/history/history_controller.dart';
import 'package:hoopito/features/history/history_page.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';

void main() {
  testWidgets('timeline selects a stable event and highlights its location', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'highlight',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 2,
        blueScore: 0,
        duration: Duration.zero,
        events: [
          ReplayEventData(
            id: 'event-a',
            kind: ReplayEventKind.score,
            side: TeamSide.red,
            points: 2,
            elapsed: Duration.zero,
            locationId: 'location-a',
            shotPoint: CourtPoint(x: 0.3, y: 0.4),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('replay-event-event-a')));
    await tester.tap(find.byKey(const Key('replay-event-event-a')));
    await tester.pump();

    final court = tester.widget<CourtView>(find.byType(CourtView).first);
    expect(court.highlightedShotLocationId, 'location-a');
    final eventSemantics = tester.getSemantics(
      find.byKey(const Key('replay-event-event-a')),
    );
    expect(
      eventSemantics.getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
  });

  testWidgets(
    'compact replay gives the court priority and keeps filters reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(731, 411));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ReplayController(
        data: ReplayMatchData(
          matchId: 'wide',
          redName: 'Red',
          blueName: 'Blue',
          redScore: 2,
          blueScore: 1,
          duration: Duration.zero,
          events: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ReplayPage(controller: controller)),
      );
      await tester.pump();

      expect(find.byKey(const Key('replay-court-pane')), findsOneWidget);
      expect(find.byKey(const Key('replay-timeline-pane')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('replay-compact-filter-action')))
            .shortestSide,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history matches use editorial score rows without changing action boundaries',
    (tester) async {
      final controller = HistoryController(
        matches: [
          HistoryMatchSummary(
            matchId: 'paper',
            playedAt: DateTime(2026, 8, 25),
            redName: 'Red',
            blueName: 'Blue',
            redScore: 5,
            blueScore: 3,
            ruleName: '11 分制',
            duration: Duration.zero,
            locatedShots: 1,
            scoringEvents: 2,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryPage(
            controller: controller,
            onMatchTap: (_) {},
            onArchive: (_) async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EditorialScaffold), findsOneWidget);
      expect(find.byKey(const Key('history-date-2026-08-25')), findsOneWidget);
      expect(find.byKey(const Key('history-match-paper')), findsOneWidget);
      expect(find.byKey(const Key('history-actions-paper')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

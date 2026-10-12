import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('scoring route keeps primary targets inside a 1920 viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    final now = DateTime.utc(2026, 8, 25, 12);
    await MatchCommandService(database).start(
      StartMatchCommand(
        commandId: 'task5-layout-start',
        matchId: 'task5-layout',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        trackingCoverage: TrackingCoverage.scoresOnly,
        createdAt: now,
        startedAt: now,
      ),
    );

    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await _tapAction(tester, find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await tester.pumpAndSettle();

    final viewport = tester.binding.renderViews.first.size;
    for (final key in [
      const Key('blue-score-1'),
      const Key('blue-score-2'),
      const Key('blue-score-3'),
      const Key('red-score-1'),
      const Key('red-score-2'),
      const Key('red-score-3'),
      const Key('scoring-undo'),
      const Key('scoring-more'),
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$key left');
      expect(
        rect.right,
        lessThanOrEqualTo(viewport.width),
        reason: '$key right',
      );
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$key top');
      expect(
        rect.bottom,
        lessThanOrEqualTo(viewport.height),
        reason: '$key bottom',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unified scoring app flow persists actions and returns from final replay',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1095, 616));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });

      await tester.pumpWidget(
        HoopitoApp(database: database, showEntryAnimation: false),
      );
      await _pumpUntilFound(tester, find.byKey(homeStartScoringKey));
      await _tapAction(tester, find.byKey(homeStartScoringKey));
      await _pumpUntilFound(tester, find.byType(PregamePage));

      // Starting a match must not require either of the removed recording
      // controls. Pick a target rule so the end-to-end flow can finish.
      expect(find.byKey(const Key('pregame-recording-simple')), findsNothing);
      expect(
        find.byKey(const Key('pregame-tracking-scores-only')),
        findsNothing,
      );
      await _tapAction(tester, find.byKey(const Key('pregame-rule-template')));
      await tester.pumpAndSettle();
      final twentyOne = find.textContaining('21');
      expect(twentyOne, findsOneWidget);
      await _tapAction(tester, twentyOne);
      await tester.pumpAndSettle();
      final startMatch = find.byKey(const Key('pregame-start-match'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.ensureVisible(startMatch);
      await tester.pump();
      await _tapAction(tester, startMatch);
      await _pumpUntilFound(tester, find.byType(ScoringPage));
      await tester.pumpAndSettle();

      // Score-first: score, attach a court point, then undo the location and
      // the score as two separate actions.
      await _tapAction(tester, find.byKey(const Key('red-score-2')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('red-score-2-location')),
      );
      var activeEvents = await _activeEvents(database);
      expect(activeEvents, hasLength(1));
      expect(activeEvents.single.type, EventKind.fieldGoal.name);
      expect(activeEvents.single.side, TeamSide.red.name);
      expect(activeEvents.single.points, 2);
      expect(activeEvents.single.outcome, ShotOutcome.made.name);
      expect(await _score(database, TeamSide.red), 2);
      await tester.ensureVisible(find.byKey(const Key('scoring-court')));
      await tester.pump();
      final courtRect = tester.getRect(find.byKey(const Key('scoring-court')));
      final tapLocal = _courtTap(courtRect.size, .25, .25);
      await tester.tapAt(courtRect.topLeft + tapLocal);
      await _pumpUntil(
        tester,
        () async => await _confirmedLocationCount(database) == 1,
      );
      var locations = await database.select(database.shotLocations).get();
      expect(locations, hasLength(1));
      expect(locations.single.eventId, activeEvents.single.id);
      expect(locations.single.x, closeTo(0.25, 0.001));
      expect(locations.single.y, closeTo(0.25, 0.001));
      expect(locations.single.isConfirmed, isTrue);
      await _tapAction(tester, find.byKey(const Key('scoring-undo')));
      await _pumpUntil(
        tester,
        () async => await _confirmedLocationCount(database) == 0,
      );
      expect(await _activeScoringEventCount(database), 1);
      locations = await database.select(database.shotLocations).get();
      expect(locations.single.isConfirmed, isFalse);
      await _tapAction(tester, find.byKey(const Key('scoring-undo')));
      await _pumpUntil(
        tester,
        () async => await _activeScoringEventCount(database) == 0,
      );
      activeEvents = await _activeEvents(database);
      expect(activeEvents, isEmpty);
      final deletedEvents = await _matchEventsInRowOrder(database);
      expect(deletedEvents.single.isDeleted, isTrue);
      locations = await database.select(database.shotLocations).get();
      expect(locations.single.isConfirmed, isFalse);
      expect(await _score(database, TeamSide.red), 0);

      // Court-first: a gray point is selected before choosing the scoring
      // side, and the committed event/location is one atomic action.
      await tester.ensureVisible(find.byKey(const Key('scoring-court')));
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await _pumpUntilFound(tester, find.text('请选择蓝方或红方得分'));
      await _tapAction(tester, find.byKey(const Key('red-score-2')));
      await _pumpUntil(
        tester,
        () async =>
            await _activeScoringEventCount(database) == 1 &&
            await _confirmedLocationCount(database) == 1,
      );
      activeEvents = await _activeEvents(database);
      expect(activeEvents, hasLength(1));
      expect(activeEvents.single.type, EventKind.fieldGoal.name);
      expect(activeEvents.single.side, TeamSide.red.name);
      expect(activeEvents.single.points, 2);
      expect(activeEvents.single.outcome, ShotOutcome.made.name);
      expect(await _score(database, TeamSide.red), 2);
      locations = await database.select(database.shotLocations).get();
      final confirmedCourtLocation = locations.singleWhere(
        (location) => location.isConfirmed,
      );
      expect(confirmedCourtLocation.eventId, activeEvents.single.id);
      expect(confirmedCourtLocation.x, closeTo(0.5, 0.01));
      expect(confirmedCourtLocation.y, closeTo(0.5, 0.01));

      // The compact top foul chooser and every grouped More action must be
      // reachable while the normal score-first supplement is not blocking
      // ordinary actions.
      await _tapAction(tester, find.byKey(const Key('scoring-foul')));
      await _pumpUntilFound(tester, find.byKey(const Key('scoring-foul-red')));
      await _tapAction(tester, find.byKey(const Key('scoring-foul-red')));
      await _pumpUntil(
        tester,
        () async => await _activeScoringEventCount(database) == 2,
      );
      activeEvents = await _activeEvents(database);
      final fouls = activeEvents.where(
        (event) => event.type == EventKind.foul.name,
      );
      expect(fouls, hasLength(1));
      expect(fouls.single.side, TeamSide.red.name);
      expect(fouls.single.points, 0);
      await _tapAction(tester, find.byKey(const Key('blue-miss')));
      await _pumpUntil(
        tester,
        () async => await _activeScoringEventCount(database) == 3,
      );
      activeEvents = await _activeEvents(database);
      final misses = activeEvents.where(
        (event) =>
            event.type == EventKind.fieldGoal.name &&
            event.outcome == ShotOutcome.missed.name,
      );
      expect(misses, hasLength(1));
      expect(misses.single.side, TeamSide.blue.name);
      expect(misses.single.points, 0);

      await _tapAction(tester, find.byKey(const Key('scoring-more')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('scoring-more-sheet')),
      );
      await _tapAction(
        tester,
        find.byKey(const Key('more-red-free-throw-miss')),
        scrollSheet: true,
      );
      await _pumpUntilMissing(
        tester,
        find.byKey(const Key('scoring-more-sheet')),
      );
      activeEvents = await _activeEvents(database);
      final missedFreeThrows = activeEvents.where(
        (event) =>
            event.type == EventKind.freeThrow.name &&
            event.outcome == ShotOutcome.missed.name,
      );
      expect(missedFreeThrows, hasLength(1));
      expect(missedFreeThrows.single.side, TeamSide.red.name);
      expect(missedFreeThrows.single.points, 0);

      await _tapAction(tester, find.byKey(const Key('scoring-more')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('scoring-more-sheet')),
      );
      await _tapAction(
        tester,
        find.byKey(const Key('more-possession-blue')),
        scrollSheet: true,
      );
      await _pumpUntilMissing(
        tester,
        find.byKey(const Key('scoring-more-sheet')),
      );
      activeEvents = await _activeEvents(database);
      final possessions = activeEvents.where(
        (event) => event.type == EventKind.possession.name,
      );
      expect(possessions, hasLength(1));
      expect(possessions.single.side, TeamSide.blue.name);
      expect(possessions.single.points, 0);

      await _tapAction(tester, find.byKey(const Key('scoring-more')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('scoring-more-sheet')),
      );
      await _tapAction(
        tester,
        find.byKey(const Key('more-note')),
        scrollSheet: true,
      );
      await _pumpUntilFound(tester, find.byKey(const Key('text-entry-field')));
      await tester.enterText(
        find.byKey(const Key('text-entry-field')),
        'task5',
      );
      await _tapAction(tester, find.byKey(const Key('text-entry-confirm')));
      await _pumpUntilMissing(
        tester,
        find.byKey(const Key('scoring-more-sheet')),
      );
      activeEvents = await _activeEvents(database);
      final notes = activeEvents.where(
        (event) => event.type == EventKind.note.name,
      );
      expect(notes, hasLength(1));
      expect(notes.single.side, isNull);
      expect(notes.single.points, 0);
      expect(notes.single.note, 'task5');

      // Reach 20 without triggering the target decision, then resolve the
      // latest supplement before the final made free throw reaches 21.
      var expectedEvents = await _activeScoringEventCount(database);
      for (var index = 0; index < 6; index++) {
        await _tapAction(tester, find.byKey(const Key('red-score-3')));
        expectedEvents++;
        final expected = expectedEvents;
        await _pumpUntil(
          tester,
          () async => await _activeScoringEventCount(database) == expected,
        );
      }
      expect(await _score(database, TeamSide.red), 20);
      expect(await _score(database, TeamSide.blue), 0);
      await tester.ensureVisible(find.byKey(const Key('scoring-court')));
      await tester.pump();
      final finalCourt = tester.getRect(find.byKey(const Key('scoring-court')));
      final finalTapLocal = _courtTap(finalCourt.size, .75, .25);
      await tester.tapAt(finalCourt.topLeft + finalTapLocal);
      await _pumpUntil(
        tester,
        () async => await _confirmedLocationCount(database) == 2,
      );
      activeEvents = await _activeEvents(database);
      final latestScore = activeEvents.lastWhere(
        (event) => event.type == EventKind.fieldGoal.name,
      );
      locations = await database.select(database.shotLocations).get();
      final finalLocation = locations.singleWhere(
        (location) => location.eventId == latestScore.id,
      );
      expect(finalLocation.x, closeTo(0.75, 0.001));
      expect(finalLocation.y, closeTo(0.25, 0.001));
      expect(finalLocation.isConfirmed, isTrue);

      await _tapAction(tester, find.byKey(const Key('scoring-more')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('scoring-more-sheet')),
      );
      await _tapAction(
        tester,
        find.byKey(const Key('more-red-free-throw-made')),
        scrollSheet: true,
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('scoring-decision-finish')),
      );
      activeEvents = await _activeEvents(database);
      final madeFreeThrows = activeEvents.where(
        (event) =>
            event.type == EventKind.freeThrow.name &&
            event.outcome == ShotOutcome.made.name,
      );
      expect(madeFreeThrows, hasLength(1));
      expect(madeFreeThrows.single.side, TeamSide.red.name);
      expect(madeFreeThrows.single.points, 1);
      expect(await _score(database, TeamSide.red), 21);
      await _tapAction(
        tester,
        find.byKey(const Key('scoring-decision-finish')),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('scoring-finish-confirm')),
      );
      await _tapAction(tester, find.byKey(const Key('scoring-finish-confirm')));
      await _pumpUntilFound(tester, find.byType(MatchSummaryPage));

      final match = await database.select(database.matches).getSingle();
      expect(match.lifecycle, 'finished');

      await tester.binding.handlePopRoute();
      await _pumpUntilFound(tester, find.byType(HomePage));
    },
  );
}

// Select a point within the 15:14 painted court, independent of the page's
// letterboxing or header height. Geometry itself is tested in the court suite.
Offset _courtTap(Size viewport, double x, double y) {
  final courtWidth = viewport.width / viewport.height > 15 / 14
      ? viewport.height * 15 / 14
      : viewport.width;
  final courtHeight = courtWidth * 14 / 15;
  return Offset(
    (viewport.width - courtWidth) / 2 + courtWidth * x,
    (viewport.height - courtHeight) / 2 + courtHeight * y,
  );
}

Future<void> _tapAction(
  WidgetTester tester,
  Finder finder, {
  bool scrollSheet = false,
}) async {
  await tester.ensureVisible(finder);
  if (scrollSheet) {
    final viewport = tester.binding.renderViews.first.size;
    await tester.dragFrom(
      Offset(viewport.width / 2, viewport.height / 2),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      500,
      scrollable: find.descendant(
        of: find.byKey(const Key('scoring-more-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<int> _activeScoringEventCount(dynamic database) async {
  return (await _activeEvents(database)).length;
}

Future<List<dynamic>> _activeEvents(dynamic database) async {
  final rows = await _matchEventsInRowOrder(database);
  return rows.where((row) => row.isDeleted == false).toList();
}

Future<List<dynamic>> _matchEventsInRowOrder(dynamic database) async {
  final query = database.select(database.matchEvents);
  query.orderBy([
    (_) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
  ]);
  return query.get();
}

Future<int> _score(dynamic database, TeamSide side) async {
  final events = await _activeEvents(database);
  return events
      .where(
        (event) =>
            event.side == side.name &&
            (event.type == EventKind.score.name ||
                event.type == EventKind.fieldGoal.name ||
                event.type == EventKind.freeThrow.name) &&
            event.outcome == ShotOutcome.made.name,
      )
      .fold<int>(0, (total, event) => total + (event.points as int));
}

Future<int> _confirmedLocationCount(dynamic database) async {
  final rows = await database.select(database.shotLocations).get();
  return rows.where((row) => row.isConfirmed == true).length;
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  await _pumpUntil(tester, () async => finder.evaluate().isNotEmpty);
}

Future<void> _pumpUntilMissing(WidgetTester tester, Finder finder) async {
  await _pumpUntil(tester, () async => finder.evaluate().isEmpty);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Future<bool> Function() predicate,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (await predicate()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for integration condition.');
}

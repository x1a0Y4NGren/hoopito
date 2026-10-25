import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/features/history/history_controller.dart';
import 'package:hoopito/features/history/history_page.dart';

void main() {
  testWidgets('history groups compact score rows by local calendar date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = HistoryController(
      matches: [
        _summary('late', DateTime(2026, 8, 26, 20, 30)),
        _summary('early', DateTime(2026, 8, 26, 9, 15)),
        _summary('previous', DateTime(2026, 8, 25, 23, 45)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(controller: controller, onMatchTap: (_) {}),
      ),
    );

    expect(find.byType(EditorialScaffold), findsOneWidget);
    expect(find.byKey(const Key('history-date-2026-08-26')), findsOneWidget);
    expect(find.byKey(const Key('history-date-2026-08-25')), findsOneWidget);
    expect(find.byKey(const Key('history-card-late')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('history-match-late'))).height,
      lessThan(120),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'history editorial rows expose button semantics in $brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: HistoryPage(
              controller: HistoryController(
                matches: [_summary('semantic', DateTime(2026, 8, 26))],
              ),
              onMatchTap: (_) {},
            ),
          ),
        );

        expect(find.byType(EditorialScaffold), findsOneWidget);
        final semantics = tester.getSemantics(
          find.byKey(const Key('history-match-semantic')),
        );
        expect(semantics.flagsCollection.isButton, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('history filters open in the frozen editorial sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          controller: HistoryController(matches: const []),
          onMatchTap: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('history-advanced-filters')));
    await tester.pumpAndSettle();

    expect(find.byType(EditorialSheet), findsOneWidget);
  });

  testWidgets('history empty content uses the unified editorial state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          controller: HistoryController(matches: const []),
          onMatchTap: (_) {},
        ),
      ),
    );

    expect(find.byType(EditorialEmptyState), findsOneWidget);
  });

  testWidgets('large text stacks rows and keeps blue identity on the left', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: HistoryPage(
            controller: HistoryController(
              matches: [_summary('large-text', DateTime(2026, 8, 26))],
            ),
            onMatchTap: (_) {},
          ),
        ),
      ),
    );
    final row = find.byKey(const Key('history-match-large-text'));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(104));
    expect(
      tester.getCenter(find.text('Blue')).dx,
      lessThan(tester.getCenter(find.text('Red')).dx),
    );
    expect(
      tester.getRect(find.byKey(const Key('history-search'))).left,
      tester.getRect(row).left,
    );
  });

  testWidgets('recovery notices avoid card stacks and reflow at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: HistoryPage(
            controller: HistoryController(matches: const []),
            onMatchTap: (_) {},
            activeMatch: _summary('active', DateTime(2026, 8, 26)),
            onResumeActive: () {},
            importedIncompleteMatches: [
              _summary('imported', DateTime(2026, 8, 25)),
            ],
            onResumeImportedIncomplete: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(find.byKey(const Key('history-resume-imported-imported')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(find.text('Blue 7 : 11 Red'), findsNWidgets(2));
  });
}

HistoryMatchSummary _summary(String id, DateTime playedAt) =>
    HistoryMatchSummary(
      matchId: id,
      playedAt: playedAt,
      redName: 'Red',
      blueName: 'Blue',
      redScore: 11,
      blueScore: 7,
      ruleName: '11 points',
      duration: const Duration(minutes: 8),
      locatedShots: 5,
      scoringEvents: 8,
    );

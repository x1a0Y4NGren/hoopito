import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/orientation_shell.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('Hoopito app starts on home route', (tester) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(find.byKey(homeStartScoringKey), findsOneWidget);
    expect(find.text(l10n.replayHistory), findsWidgets);
    for (final key in const [
      Key('nav-matches'),
      Key('nav-history'),
      Key('nav-players'),
      Key('home-settings-shortcut'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
    expect(find.byKey(homeProjectShortcutKey), findsNothing);
    expect(find.byKey(homeHistoryShortcutKey), findsNothing);
    expect(find.byKey(homePlayersShortcutKey), findsNothing);
    expect(find.byKey(homeRulesShortcutKey), findsNothing);
  });

  testWidgets('start scoring route enters landscape scoring shell', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(homeStartScoringKey));
    await tester.pumpAndSettle();
    expect(find.byType(PregamePage), findsOneWidget);

    await _selectSimpleAndStart(tester);
    await tester.pumpAndSettle();

    expect(find.byType(OrientationShell), findsOneWidget);
  });

  testWidgets('score, replay and confirmed finish form a local data loop', (
    tester,
  ) async {
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

    await _tapVisible(tester, find.byKey(homeStartScoringKey));
    await _pumpUntilFound(tester, find.byType(PregamePage));
    await _selectSimpleAndStart(tester);
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await _tapVisible(tester, find.byKey(const Key('red-score-2')));
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('scoring-more')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('more-replay')));
    final sheetScrollable = find.descendant(
      of: find.byKey(const Key('scoring-more-sheet')),
      matching: find.byType(Scrollable),
    );
    final viewport = tester.binding.renderViews.first.size;
    await tester.dragFrom(
      Offset(viewport.width / 2, viewport.height / 2),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('more-replay')),
      500,
      scrollable: sheetScrollable,
    );
    await _tapVisible(tester, find.byKey(const Key('more-replay')));
    await _pumpUntilFound(tester, find.byType(ReplayPage));

    expect(find.byType(ReplayPage), findsOneWidget);
    expect(find.text(_l10n(tester).replayInProgress), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('replay-finish-match')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('replay-finish-confirm')),
    );
    expect(find.textContaining('2'), findsWidgets);
    await _tapVisible(tester, find.byKey(const Key('replay-finish-confirm')));
    await _pumpUntilFound(tester, find.byType(MatchSummaryPage));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('summary-replay')));
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await _pumpUntilFound(tester, find.text(_l10n(tester).replayFinished));
    expect(find.byType(ReplayPage), findsOneWidget);
    expect(find.text(_l10n(tester).replayFinished), findsOneWidget);
    expect(find.byKey(const Key('replay-finish-match')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for the expected widget.');
}

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
}

Future<void> _selectSimpleAndStart(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('pregame-start-match')),
    300,
    scrollable: find
        .descendant(
          of: find.byType(PregamePage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _tapVisible(tester, find.byKey(const Key('pregame-start-match')));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

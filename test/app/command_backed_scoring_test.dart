import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('production scoring route commits through command receipts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(3000, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    final feedbackPlatform = _CountingFeedbackPlatform(database);
    final feedback = ScoringFeedbackService(
      ScoringFeedbackPreferencesRepository(database),
      platform: feedbackPlatform,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      await database.close();
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          scoringFeedbackServiceProvider.overrideWithValue(feedback),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(homeStartScoringKey));

    await tester.tap(find.byKey(homeStartScoringKey));
    await _pumpUntilFound(tester, find.byType(PregamePage));
    await tester.scrollUntilVisible(
      find.byKey(const Key('pregame-start-match')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    final scoreButton = tester.widget<FilledButton>(
      find.byKey(const Key('red-score-2')),
    );
    scoreButton.onPressed!();
    await tester.pump();
    expect(find.text(_scoringMarkShotTitle(tester)), findsNothing);

    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      final commandReceipts = await (database.select(
        database.auditLogs,
      )..where((row) => row.action.equals('command'))).get();
      if (commandReceipts.length >= 2) break;
    }

    final commandReceipts = await (database.select(
      database.auditLogs,
    )..where((row) => row.action.equals('command'))).get();
    final events = await database.select(database.matchEvents).get();
    expect(commandReceipts.length, greaterThanOrEqualTo(2));
    expect(events, hasLength(1));
    expect(events.single.points, 2);
    expect(feedbackPlatform.hapticCalls, 1);
    expect(feedbackPlatform.eventCounts, [1]);
  });
}

String _scoringMarkShotTitle(WidgetTester tester) {
  final context = tester.element(find.byType(ScoringPage));
  return AppLocalizations.of(context)!.scoringMarkShotTitle;
}

class _CountingFeedbackPlatform implements ScoringFeedbackPlatform {
  _CountingFeedbackPlatform(this.database);

  final AppDatabase database;
  int hapticCalls = 0;
  final eventCounts = <int>[];

  @override
  Future<void> lightImpact() async {
    hapticCalls++;
    eventCounts.add((await database.select(database.matchEvents).get()).length);
  }

  @override
  Future<void> click() async {}
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder');
}

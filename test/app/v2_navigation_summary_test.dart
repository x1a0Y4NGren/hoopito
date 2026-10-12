import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('tabs and summary return retain history search', (tester) async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    await service.start(
      StartMatchCommand(
        matchId: 'v2-match',
        redName: 'Visitor',
        blueName: 'Friend',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        startedAt: DateTime.utc(2026),
      ),
    );
    await service.finish(
      FinishMatchCommand(
        matchId: 'v2-match',
        endedAt: DateTime.utc(2026, 1, 1, 1),
        confirmFinalScore: true,
      ),
    );
    final router = buildProviderAppRouter();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await until(tester, find.byKey(const Key('nav-history')));
    await tester.tap(find.byKey(const Key('nav-history')));
    await until(tester, find.byKey(const Key('history-search')));
    await tester.enterText(find.byKey(const Key('history-search')), 'Visitor');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('nav-players')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('history-search')))
          .controller!
          .text,
      'Visitor',
    );
    await tester.ensureVisible(find.byKey(const Key('history-match-v2-match')));
    await tester.tap(find.byKey(const Key('history-match-v2-match')));
    await until(tester, find.byType(MatchSummaryPage));
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('history-search')))
          .controller!
          .text,
      'Visitor',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cold summary links explicit profile and refreshes without renaming match',
    (tester) async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      final started = await service.start(
        StartMatchCommand(
          matchId: 'v2-link',
          redName: 'Temporary',
          blueName: 'Friend',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: 'Free',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          startedAt: DateTime.utc(2026),
        ),
      );
      await service.finish(
        FinishMatchCommand(
          matchId: 'v2-link',
          endedAt: DateTime.utc(2026, 1, 1, 1),
          confirmFinalScore: true,
        ),
      );
      await PlayerRepository(database).save(
        Player(
          id: 'profile',
          nickname: 'Canonical',
          createdAt: DateTime.utc(2026),
        ),
      );
      final participantId = started.match.participants
          .firstWhere((p) => p.nameSnapshot == 'Temporary')
          .id;
      final router = buildProviderAppRouter();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await database.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: router,
          ),
        ),
      );
      router.go('/matches/v2-link/summary');
      await until(tester, find.byType(MatchSummaryPage));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(ValueKey('summary-save-$participantId')),
      );
      await tester.tap(find.byKey(ValueKey('summary-save-$participantId')));
      await tester.pumpAndSettle();
      await until(tester, find.text('Canonical'));
      await tester.tap(find.text('Canonical'));
      await tester.pumpAndSettle();
      final row = await (database.select(
        database.matchParticipants,
      )..where((p) => p.id.equals(participantId))).getSingle();
      expect(row.playerProfileId, 'profile');
      expect(row.nameSnapshot, 'Temporary');
      await until(tester, find.byType(MatchSummaryPage));
      expect(find.byKey(ValueKey('summary-save-$participantId')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    // Drift subscriptions can wait on real event-loop work outside fake time.
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/features/players/player_comparison_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('career comparison entry opens the deep-linkable compare route', (
    tester,
  ) async {
    final database = createTestDatabase();
    await _seedComparisonFixture(database);
    final router = buildProviderAppRouter();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      router.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    router.go('/players/profile-player/analytics');
    await _pumpUntil(
      tester,
      find.byKey(const Key('player-comparison-profile-player')),
    );
    await tester.tap(find.byKey(const Key('player-comparison-profile-player')));
    await _pumpUntil(tester, find.text('球员比较'));
    await _pumpUntil(
      tester,
      find.byKey(const Key('comparison-baseline-selector')),
    );

    final route = GoRouterState.of(
      tester.element(find.byType(PlayerComparisonPage)),
    );
    expect(route.matchedLocation, '/players/profile-player/analytics/compare');
    expect(route.uri.path, '/players/profile-player/analytics/compare');
    expect(
      find.byKey(const Key('comparison-current-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('comparison-metric-points')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _seedComparisonFixture(AppDatabase database) async {
  final first = DateTime.utc(2026, 8, 10);
  final second = DateTime.utc(2026, 8, 20);
  await database.batch((batch) {
    batch.insertAll(database.players, [
      PlayerRow(id: 'profile-player', nickname: '飞鱼', createdAt: first),
      PlayerRow(id: 'opponent-player', nickname: '北辰', createdAt: first),
    ]);
    for (final fixture in [
      (id: 'match-a', at: first),
      (id: 'match-b', at: second),
    ]) {
      batch.insert(
        database.matches,
        Matche(
          id: fixture.id,
          lifecycle: 'finished',
          recordingMode: 'detailed',
          trackingCoverage: 'shotAttempts',
          ruleTemplateJson: '{}',
          createdAt: fixture.at,
          startedAt: fixture.at,
          endedAt: fixture.at.add(const Duration(minutes: 8)),
          timerEnabled: false,
          note: null,
        ),
      );
      batch.insertAll(database.matchParticipants, [
        MatchParticipant(
          id: '${fixture.id}-red',
          matchId: fixture.id,
          side: 'red',
          nameSnapshot: '飞鱼',
          playerProfileId: 'profile-player',
        ),
        MatchParticipant(
          id: '${fixture.id}-blue',
          matchId: fixture.id,
          side: 'blue',
          nameSnapshot: '北辰比赛时',
          playerProfileId: 'opponent-player',
        ),
      ]);
      batch.insertAll(database.matchEvents, [
        MatchEventRow(
          id: '${fixture.id}-red-score',
          matchId: fixture.id,
          type: 'score',
          side: 'red',
          points: fixture.id == 'match-a' ? 8 : 11,
          outcome: 'made',
          occurredAt: fixture.at.add(const Duration(seconds: 1)),
          note: null,
          matchClockPositionSeconds: null,
          customLabel: null,
          isDeleted: false,
        ),
        MatchEventRow(
          id: '${fixture.id}-blue-score',
          matchId: fixture.id,
          type: 'score',
          side: 'blue',
          points: fixture.id == 'match-a' ? 11 : 8,
          outcome: 'made',
          occurredAt: fixture.at.add(const Duration(seconds: 2)),
          note: null,
          matchClockPositionSeconds: null,
          customLabel: null,
          isDeleted: false,
        ),
      ]);
    }
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var index = 0; index < 150; index++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

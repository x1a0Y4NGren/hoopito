import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('history route wires archive action to the lifecycle port', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    final playedAt = DateTime.utc(2026, 8, 24, 12);
    await repository.createMinimalMatch(
      id: 'route-history-match',
      redName: '红方',
      blueName: '蓝方',
      createdAt: playedAt,
    );
    await repository.finishMatch('route-history-match', endedAt: playedAt);
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
    router.go('/history');
    await _pumpUntil(
      tester,
      find.byKey(const Key('history-match-route-history-match')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history-advanced-filters')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('history-match-route-history-match')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('history-actions-route-history-match')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('history-match-route-history-match')),
      findsNothing,
    );
    await tester.tap(find.text('已归档'));
    await _pumpUntil(
      tester,
      find.byKey(const Key('history-match-route-history-match')),
    );
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

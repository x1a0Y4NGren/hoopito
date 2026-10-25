import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('player list entry opens the profile-keyed career route', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    await repository.save(
      Player(
        id: 'career-route-player',
        nickname: '飞鱼',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final router = buildProviderAppRouter();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
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
    router.go('/players');
    await _pumpUntil(
      tester,
      find.byKey(const Key('player-row-career-route-player')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('飞鱼'));
    await _pumpUntil(tester, find.text('球员分析'));
    await _pumpUntil(tester, find.text('该周期暂无已完成比赛'));
    expect(find.text('该周期暂无已完成比赛'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('production pre-game route loads player profiles from provider', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = PlayerRepository(database);
    await repository.save(
      Player(
        id: 'route-player',
        nickname: 'Route Player',
        createdAt: DateTime.utc(2026, 8, 23),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });

    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-start-scoring')));
    await tester.tap(find.byKey(const Key('home-start-scoring')));
    await _pumpUntilFound(tester, find.byType(PregamePage));

    await tester.tap(find.byKey(const Key('pregame-red-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Route Player'), findsWidgets);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for the expected widget.');
}

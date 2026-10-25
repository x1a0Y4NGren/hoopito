import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('finished replay edits use the command-backed route adapter', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await _createFinishedMatch(database, 'route-edit');

    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final router = app.routerConfig! as GoRouter;
    router.go('/matches/route-edit/replay');
    await _pumpUntilFound(tester, find.byType(ReplayPage));

    tester
        .widget<TextButton>(find.byKey(const Key('replay-edit-toggle')))
        .onPressed!
        .call();
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('replay-event-route-edit-event')),
    );
    tester
        .widget<InkWell>(find.byKey(const Key('replay-event-route-edit-event')))
        .onTap!
        .call();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('replay-editor-note')),
      'command-backed note',
    );
    await tester.enterText(
      find.byKey(const Key('replay-editor-reason')),
      'route review',
    );
    tester
        .widget<FilledButton>(find.byKey(const Key('replay-editor-save')))
        .onPressed!
        .call();
    await tester.pumpAndSettle();

    final repository = MatchRepository(database);
    final detail = await repository.getMatchDetail('route-edit');
    expect(detail!.events.single.note, 'command-backed note');
    final audits = await repository.listAuditLogs('route-edit');
    expect(audits.single.action.name, 'edit');
    expect(audits.single.reason, 'route review');
  });
}

Future<void> _createFinishedMatch(AppDatabase database, String id) async {
  final repository = MatchRepository(database);
  final startedAt = DateTime.utc(2026, 8, 24, 10);
  await repository.createMinimalMatch(
    id: id,
    redName: 'Red',
    blueName: 'Blue',
    createdAt: startedAt,
  );
  await repository.saveEvent(
    MatchEvent(
      id: '$id-event',
      matchId: id,
      type: MatchEventType.score,
      side: TeamSide.red,
      points: 2,
      occurredAt: startedAt,
      note: 'initial',
    ),
  );
  await repository.finishMatch(id, endedAt: startedAt);
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for the expected widget.');
}

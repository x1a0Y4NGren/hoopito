import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain_match;
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  testWidgets('history resumes an imported incomplete match into scoring', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    await repository.saveMatch(
      _match('imported-route', MatchLifecycle.abandoned),
    );
    final router = buildProviderAppRouter();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await database.close();
    });

    await _pumpRouter(tester, router, database, '/history');
    await _pumpUntil(
      tester,
      find.byKey(const Key('history-imported-imported-route')),
    );
    await tester.pumpAndSettle();
    final resume = find.byKey(
      const Key('history-resume-imported-imported-route'),
    );
    await tester.ensureVisible(resume);
    await tester.pumpAndSettle();
    await tester.tap(resume.hitTestable());
    await _pumpUntil(tester, find.byType(ScoringPage));

    expect(find.byType(ScoringPage), findsOneWidget);
    expect(
      (await database.select(database.activeSessions).get()).single.matchId,
      'imported-route',
    );
  });

  testWidgets('imported resume conflict stays readable and keeps the banner', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    await repository.saveMatch(
      _match('imported-conflict', MatchLifecycle.abandoned),
    );
    await repository.saveMatch(_match('local-active', MatchLifecycle.active));
    await database
        .into(database.activeSessions)
        .insert(
          ActiveSessionsCompanion.insert(
            id: const Value('active'),
            matchId: 'local-active',
            claimedAtUtc: Value(DateTime.utc(2026, 8, 24, 12)),
          ),
        );
    final router = buildProviderAppRouter();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await database.close();
    });

    await _pumpRouter(tester, router, database, '/history');
    await _pumpUntil(
      tester,
      find.byKey(const Key('history-resume-imported-imported-conflict')),
    );
    await tester.pumpAndSettle();
    final resume = find.byKey(
      const Key('history-resume-imported-imported-conflict'),
    );
    await tester.ensureVisible(resume);
    await tester.pumpAndSettle();
    await tester.tap(resume.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('没能继续这场比赛，请先确认没有其他比赛正在进行。'), findsOneWidget);
    expect(
      find.byKey(const Key('history-imported-imported-conflict')),
      findsOneWidget,
    );
  });
}

domain_match.Match _match(String id, MatchLifecycle lifecycle) {
  final startedAt = DateTime.utc(2026, 8, 24, 11);
  return domain_match.Match(
    id: id,
    lifecycle: lifecycle,
    createdAt: startedAt,
    startedAt: startedAt,
    endedAt: lifecycle == MatchLifecycle.active ? null : startedAt,
    recordingMode: RecordingMode.detailed,
    trackingCoverage: TrackingCoverage.full,
    ruleTemplateSnapshot: const RuleTemplate(
      id: 'free',
      name: 'Free scoring',
      scoreButtons: [1, 2, 3],
    ),
    note: importedIncompleteNoteMarker,
    participants: [
      domain_match.MatchParticipant(
        id: '$id-red',
        matchId: id,
        side: TeamSide.red,
        nameSnapshot: 'Red',
      ),
      domain_match.MatchParticipant(
        id: '$id-blue',
        matchId: id,
        side: TeamSide.blue,
        nameSnapshot: 'Blue',
      ),
    ],
  );
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router,
  AppDatabase database,
  String path,
) async {
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
  router.go(path);
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

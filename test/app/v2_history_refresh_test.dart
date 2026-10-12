import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_history_entry.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/features/history/history_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  test(
    'history change notifications do not hydrate rows or react to settings',
    () async {
      final database = createTestDatabase();
      final repository = _CountingRepository(database);
      var changes = 0;
      final subscription = repository.watchHistoryChanges().listen(
        (_) => changes++,
      );
      addTearDown(() async {
        await subscription.cancel();
        await database.close();
      });
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'unrelated',
              valueJson: '"setting"',
              updatedAt: DateTime.utc(2026, 9, 1),
            ),
          );
      await Future<void>.delayed(Duration.zero);
      expect(changes, 0);
      await _seedFinished(
        MatchCommandService(database),
        'watched',
        DateTime.utc(2026, 9, 1),
      );
      await _until(() => changes > 0);
      expect(repository.limits, isEmpty);
      expect(repository.detailReads, 0);
    },
  );

  testWidgets(
    'retained history refreshes finish and score edits without losing its range or scroll',
    (tester) async {
      final database = createTestDatabase();
      final repository = _CountingRepository(database);
      final commands = MatchCommandService(database);
      await tester.runAsync(() async {
        for (var index = 0; index < 45; index++) {
          await _seedFinished(
            commands,
            'seed-$index',
            DateTime.utc(2026, 9, 1, 0, index),
          );
        }
      });
      final router = buildProviderAppRouter();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await database.close();
      });
      await tester.pumpWidget(_app(database, repository, router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-history')));
      await _pumpUntil(
        tester,
        () => _history(tester)?.controller.matches.length == 20,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('history-search')), 'Keep');
      final controller = _history(tester)!.controller;
      final filters = controller.filters.copyWith(
        recordingMode: 'simple',
        ruleName: 'Free',
        from: DateTime(2026, 9, 1),
      );
      controller.updateFilters(filters);
      await _pumpUntil(
        tester,
        () => !controller.isLoadingPage && controller.matches.length == 20,
      );
      await _runDatabaseAction(tester, () async {
        await controller.loadNextPage();
      });
      await tester.pumpAndSettle();
      expect(controller.matches.length, 40);
      final scrollable = find
          .descendant(
            of: find.byType(HistoryPage),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(300);
      await tester.pump();
      final scrollOffset = position.pixels;

      await tester.tap(find.byKey(const Key('nav-matches')));
      await tester.pumpAndSettle();
      await _runDatabaseAction(tester, () async {
        await _seedFinished(commands, 'new-finish', DateTime.utc(2026, 10, 1));
        await commands.correctEvent(
          CorrectMatchEventCommand(
            matchId: 'seed-39',
            eventId: 'seed-39-score',
            points: 3,
            reason: 'Fix score',
          ),
        );
      });
      await _pumpUntil(
        tester,
        () =>
            !controller.isLoadingPage &&
            controller.matches.first.matchId == 'new-finish' &&
            controller.matches
                    .firstWhere((row) => row.matchId == 'seed-39')
                    .redScore ==
                3,
      );
      expect(controller.matches.length, 40);
      expect(controller.filters, same(filters));
      expect(repository.limits, everyElement(lessThanOrEqualTo(20)));
      expect(
        repository.detailMatchIds.where((id) => id.startsWith('seed-')),
        isEmpty,
      );
      expect(controller.hasMore, isTrue);

      await tester.tap(find.byKey(const Key('nav-history')));
      await tester.pumpAndSettle();
      expect(_history(tester)!.controller, same(controller));
      expect(position.pixels, scrollOffset);
      position.jumpTo(0);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('history-search')))
            .controller!
            .text,
        'Keep',
      );
      await _runDatabaseAction(tester, () async {
        await controller.loadNextPage();
      });
      await tester.pumpAndSettle();
      expect(controller.matches.length, 46);
      expect(controller.matches.map((row) => row.matchId).toSet().length, 46);
      expect(controller.hasMore, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'backup restore refreshes retained completed and imported recovery lists',
    (tester) async {
      final database = createTestDatabase();
      final payload = (await tester.runAsync(() async {
        await _seedFinished(
          MatchCommandService(database),
          'old-finished',
          DateTime.utc(2026, 9, 1),
        );
        final source = createTestDatabase();
        try {
          final sourceCommands = MatchCommandService(source);
          await _seedFinished(
            sourceCommands,
            'restored-finished',
            DateTime.utc(2026, 9, 2),
          );
          await sourceCommands.start(
            _start(
              'restored-incomplete',
              DateTime.utc(2026, 9, 3),
              note: importedIncompleteNoteMarker,
            ),
          );
          await sourceCommands.abandon(
            AbandonMatchCommand(
              matchId: 'restored-incomplete',
              endedAt: DateTime.utc(2026, 9, 3, 0, 1),
            ),
          );
          return await JsonBackupCodec(source, appVersion: '2.0.0+4').export();
        } finally {
          await source.close();
        }
      }))!;
      final repository = _CountingRepository(database);
      final router = buildProviderAppRouter();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await database.close();
      });
      await tester.pumpWidget(_app(database, repository, router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-history')));
      await _pumpUntil(
        tester,
        () =>
            _history(tester)?.controller.matches.firstOrNull?.matchId ==
            'old-finished',
      );
      await tester.pumpAndSettle();
      final controller = _history(tester)!.controller;
      await tester.tap(find.byKey(const Key('nav-matches')));
      await tester.pumpAndSettle();

      await _runDatabaseAction(
        tester,
        () => JsonBackupCodec(database, appVersion: '2.0.0+4').restore(payload),
      );
      await _pumpUntil(
        tester,
        () =>
            controller.matches.firstOrNull?.matchId == 'restored-finished' &&
            _history(tester)?.importedIncompleteMatches.firstOrNull?.matchId ==
                'restored-incomplete',
      );
      await tester.tap(find.byKey(const Key('nav-history')));
      await tester.pumpAndSettle();
      expect(_history(tester)!.controller, same(controller));
      expect(controller.matches.map((row) => row.matchId), [
        'restored-finished',
      ]);
      expect(
        find.byKey(const Key('history-imported-restored-incomplete')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('history-match-old-finished')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

HistoryPage? _history(WidgetTester tester) {
  final page = find.byType(HistoryPage, skipOffstage: false);
  return page.evaluate().isEmpty ? null : tester.widget<HistoryPage>(page);
}

Widget _app(
  AppDatabase database,
  MatchRepository repository,
  GoRouter router,
) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWithValue(database),
    matchRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ),
);

Future<void> _seedFinished(
  MatchCommandService commands,
  String id,
  DateTime startedAt,
) async {
  await commands.start(_start(id, startedAt));
  await commands.record(
    RecordMatchEventCommand(
      matchId: id,
      eventId: '$id-score',
      side: TeamSide.red,
      points: 1,
      occurredAt: startedAt,
    ),
  );
  await commands.finish(
    FinishMatchCommand(
      matchId: id,
      endedAt: startedAt.add(const Duration(minutes: 1)),
      confirmFinalScore: true,
    ),
  );
}

StartMatchCommand _start(String id, DateTime startedAt, {String? note}) =>
    StartMatchCommand(
      matchId: id,
      redName: 'Keep Red',
      blueName: 'Keep Blue',
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      createdAt: startedAt,
      startedAt: startedAt,
      note: note,
    );

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail(
    'History did not refresh after a committed database change. Rows: ${_history(tester)?.controller.matches.map((row) => row.matchId).toList()}; recovery: ${_history(tester)?.importedIncompleteMatches.map((row) => row.matchId).toList()}',
  );
}

Future<void> _runDatabaseAction(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    unawaited(
      action().then(
        (_) => completed = true,
        onError: (Object error, StackTrace stack) {
          failure = error;
          failureStack = stack;
          completed = true;
        },
      ),
    );
  });
  await _pumpUntil(tester, () => completed);
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('History change notification did not arrive.');
}

class _CountingRepository extends MatchRepository {
  _CountingRepository(super.database);
  final limits = <int>[];
  final detailMatchIds = <String>[];
  int detailReads = 0;

  @override
  Future<MatchHistoryPage> queryHistory({
    MatchHistoryFilter filter = const MatchHistoryFilter(),
    int offset = 0,
    int limit = 20,
  }) {
    limits.add(limit);
    return super.queryHistory(filter: filter, offset: offset, limit: limit);
  }

  @override
  Future<MatchDetail?> getMatchDetail(String matchId) {
    detailReads++;
    detailMatchIds.add(matchId);
    return super.getMatchDetail(matchId);
  }
}

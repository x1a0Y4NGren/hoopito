import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/history/history_controller.dart';
import 'package:hoopito/features/history/history_page.dart';

void main() {
  testWidgets('shows recent match details and returns tapped match id', (
    tester,
  ) async {
    String? selectedId;
    final controller = HistoryController(
      matches: [
        HistoryMatchSummary(
          matchId: 'match-7',
          playedAt: DateTime(2026, 7, 9, 19, 30),
          redName: '烈火',
          blueName: '深海',
          redScore: 11,
          blueScore: 7,
          ruleName: '11 分制',
          duration: const Duration(minutes: 12, seconds: 8),
          locatedShots: 7,
          scoringEvents: 10,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          controller: controller,
          onMatchTap: (matchId) => selectedId = matchId,
        ),
      ),
    );

    expect(find.text('最近比赛'), findsOneWidget);
    expect(find.text('烈火'), findsOneWidget);
    expect(find.text('深海'), findsOneWidget);
    expect(find.text('7 : 11'), findsOneWidget);
    expect(find.textContaining('胜者：烈火'), findsOneWidget);
    expect(find.text('11 分制'), findsOneWidget);
    expect(find.text('12:08'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-match-match-7')));
    expect(selectedId, 'match-7');
  });

  testWidgets('shows an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          controller: HistoryController(matches: const []),
          onMatchTap: (_) {},
        ),
      ),
    );

    expect(find.text('暂无比赛记录'), findsOneWidget);
    expect(find.text('完成一场比赛后，记录会显示在这里。'), findsOneWidget);
  });

  testWidgets('optional home action provides an explicit exit', (tester) async {
    var homeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          controller: HistoryController(matches: const []),
          onMatchTap: (_) {},
          onHome: () => homeCalls++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('返回主页'));
    expect(homeCalls, 1);
  });

  testWidgets('adapts match list to portrait and landscape', (tester) async {
    final controller = HistoryController(
      matches: [
        HistoryMatchSummary(
          matchId: 'responsive',
          playedAt: DateTime(2026, 7, 9),
          redName: '红方',
          blueName: '蓝方',
          redScore: 3,
          blueScore: 2,
          ruleName: '自由计分',
          duration: const Duration(minutes: 2),
          locatedShots: 1,
          scoringEvents: 2,
        ),
      ],
    );

    for (final size in [const Size(390, 844), const Size(1000, 700)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryPage(controller: controller, onMatchTap: (_) {}),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const Key('history-match-responsive')))
            .height,
        greaterThanOrEqualTo(48),
      );
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('search field filters participants without leaving the page', (
    tester,
  ) async {
    final controller = HistoryController(
      matches: [
        _summary('fox', 'Red Fox', 'Blue Bear'),
        _summary('bird', 'Red Bird', 'Blue Bear'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(controller: controller, onMatchTap: (_) {}),
      ),
    );

    await tester.enterText(find.byKey(const Key('history-search')), 'bird');
    await tester.pump();

    expect(find.byKey(const Key('history-match-bird')), findsOneWidget);
    expect(find.byKey(const Key('history-match-fox')), findsNothing);
  });

  testWidgets('permanent delete is guarded by an explicit confirmation', (
    tester,
  ) async {
    var deleted = 0;
    final controller = HistoryController(matches: [_summary('delete-me')]);
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(
          controller: controller,
          onMatchTap: (_) {},
          onDelete: (_) async => deleted++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('history-actions-delete-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除比赛？'), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await tester.tap(find.byKey(const Key('history-actions-delete-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('advanced filters expose rule, mode and date controls', (
    tester,
  ) async {
    final controller = HistoryController(matches: [_summary('advanced')]);
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(controller: controller, onMatchTap: (_) {}),
      ),
    );

    await tester.tap(find.byKey(const Key('history-advanced-filters')));
    await tester.pumpAndSettle();
    expect(find.text('高级筛选'), findsOneWidget);
    expect(find.text('规则名称'), findsOneWidget);
    expect(find.text('记录模式'), findsOneWidget);
    expect(find.byKey(const Key('history-filter-clear-dates')), findsOneWidget);
    await tester.tap(find.byKey(const Key('history-filter-apply')));
    await tester.pumpAndSettle();
    expect(find.text('高级筛选'), findsNothing);
  });

  testWidgets(
    'system back dismisses advanced filters without disposing history',
    (tester) async {
      final controller = HistoryController(matches: [_summary('back-safe')]);
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryPage(controller: controller, onMatchTap: (_) {}),
        ),
      );

      await tester.tap(find.byKey(const Key('history-advanced-filters')));
      await tester.pumpAndSettle();
      expect(find.text('高级筛选'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HistoryPage), findsOneWidget);
      expect(find.text('高级筛选'), findsNothing);
    },
  );

  testWidgets('shows a retry action after a paged history load fails', (
    tester,
  ) async {
    final source = _RetryHistorySource();
    final controller = HistoryController(matches: const [], dataSource: source);
    await tester.pumpWidget(
      _localizedApp(HistoryPage(controller: controller, onMatchTap: (_) {})),
    );

    await controller.loadNextPage();
    await tester.pump();
    expect(find.byKey(const Key('history-load-error')), findsOneWidget);
    final errorState = tester.widget<EditorialErrorState>(
      find.byType(EditorialErrorState),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(HistoryPage)))!;
    expect(errorState.actionLabel, l10n.historyRetry);
    expect(errorState.onAction, isNotNull);

    await tester.tap(find.text(l10n.historyRetry));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-match-recovered')), findsOneWidget);
  });

  testWidgets('shows a footer retry action when a later history page fails', (
    tester,
  ) async {
    final source = _LaterPageRetryHistorySource();
    final controller = HistoryController(
      matches: const [],
      dataSource: source,
      pageSize: 1,
    );
    await tester.pumpWidget(
      _localizedApp(HistoryPage(controller: controller, onMatchTap: (_) {})),
    );

    await controller.loadNextPage();
    await tester.pump();
    expect(find.byKey(const Key('history-match-first')), findsOneWidget);

    await controller.loadNextPage();
    await tester.pump();
    expect(find.byKey(const Key('history-load-more-error')), findsOneWidget);
    expect(find.byKey(const Key('history-load-more-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-load-more-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-match-second')), findsOneWidget);
  });

  testWidgets('shows a localized error snackbar when a history action fails', (
    tester,
  ) async {
    final controller = HistoryController(matches: [_summary('failing-action')]);
    await tester.pumpWidget(
      _localizedApp(
        HistoryPage(
          controller: controller,
          onMatchTap: (_) {},
          onArchive: (_) async => throw StateError('archive failed'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('history-actions-failing-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();

    expect(find.text('操作失败，请重试。'), findsOneWidget);
  });

  testWidgets('renders the history page at 200 percent in English', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _localizedApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: HistoryPage(
            controller: HistoryController(matches: [_summary('english-scale')]),
            onMatchTap: (_) {},
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(HistoryPage)))!;
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 3; i++) {
      if (find
          .byKey(const Key('history-match-english-scale'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
    }
    await tester.ensureVisible(
      find.byKey(const Key('history-match-english-scale')),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.historyRule), findsOneWidget);
    expect(find.text(l10n.pregameElevenPoint), findsOneWidget);
    expect(find.text(l10n.historyDuration), findsOneWidget);
    expect(find.text(l10n.historyResult), findsOneWidget);
  });

  testWidgets(
    'offers a localized resume action for imported incomplete matches',
    (tester) async {
      var resumedId = '';
      await tester.pumpWidget(
        _localizedApp(
          HistoryPage(
            controller: HistoryController(matches: const []),
            onMatchTap: (_) {},
            importedIncompleteMatches: [
              _summary('imported-recovery', '红方', '蓝方', true),
            ],
            onResumeImportedIncomplete: (id) => resumedId = id,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('从备份导入的未完成比赛'), findsOneWidget);
      expect(find.text('继续这场比赛'), findsOneWidget);
      await tester.tap(find.text('继续这场比赛'));
      expect(resumedId, 'imported-recovery');
    },
  );

  testWidgets('shows and retries an imported incomplete query failure', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _localizedApp(
        HistoryPage(
          controller: HistoryController(matches: const []),
          onMatchTap: (_) {},
          importedIncompleteLoadError: true,
          onRetryImportedIncomplete: () => retries++,
        ),
      ),
    );

    expect(
      find.byKey(const Key('history-imported-load-error')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('history-imported-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('history-imported-retry')));
    expect(retries, 1);
  });
}

Widget _localizedApp(Widget child, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

HistoryMatchSummary _summary(
  String id, [
  String red = '红方',
  String blue = '蓝方',
  bool importedIncomplete = false,
]) => HistoryMatchSummary(
  matchId: id,
  playedAt: DateTime(2026, 7, 9),
  redName: red,
  blueName: blue,
  redScore: 11,
  blueScore: 7,
  ruleName: '11 分制',
  duration: const Duration(minutes: 2),
  locatedShots: 1,
  scoringEvents: 2,
  isImportedIncomplete: importedIncomplete,
);

class _RetryHistorySource extends HistoryDataSource {
  var calls = 0;

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    calls++;
    if (calls == 1) throw StateError('history unavailable');
    return HistoryPageResult(entries: [_summary('recovered')]);
  }
}

class _LaterPageRetryHistorySource extends HistoryDataSource {
  var calls = 0;

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    calls++;
    if (calls == 2) throw StateError('later page unavailable');
    if (calls == 3) {
      return HistoryPageResult(entries: [_summary('second')]);
    }
    return HistoryPageResult(entries: [_summary('first')], nextCursor: '1');
  }
}

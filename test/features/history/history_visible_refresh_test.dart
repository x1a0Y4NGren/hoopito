import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/features/history/history_controller.dart';
import 'package:hoopito/features/history/history_page.dart';

void main() {
  test(
    'visible refresh atomically replaces the loaded range in bounded pages',
    () async {
      final source = _ControlledSource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
        pageSize: 2,
      );
      addTearDown(controller.dispose);
      const filters = HistoryFilters(
        search: 'Keep',
        ruleName: 'Free',
        recordingMode: 'simple',
      );
      controller.updateFilters(filters);
      source.requests.last.complete(['old-4', 'old-3'], nextCursor: '2');
      await _until(() => !controller.isLoadingPage);
      final secondPage = controller.loadNextPage();
      source.requests.last.complete(['old-2', 'old-1'], nextCursor: '4');
      await secondPage;

      final refresh = controller.refreshVisible();
      expect(_ids(controller), ['old-4', 'old-3', 'old-2', 'old-1']);
      source.requests.last.complete(['new-4', 'new-3'], nextCursor: '2');
      await _until(() => source.requests.length == 4);
      expect(_ids(controller), ['old-4', 'old-3', 'old-2', 'old-1']);
      source.requests.last.complete(['new-2', 'new-1'], nextCursor: '4');
      await refresh;

      expect(_ids(controller), ['new-4', 'new-3', 'new-2', 'new-1']);
      expect(source.requests.map((request) => request.cursor), [
        null,
        '2',
        null,
        '2',
      ]);
      expect(source.requests.map((request) => request.limit), everyElement(2));
      expect(
        source.requests.map((request) => request.filters),
        everyElement(same(filters)),
      );
      final nextPage = controller.loadNextPage();
      expect(source.requests.last.cursor, '4');
      source.requests.last.complete(['older']);
      await nextPage;
      expect(controller.matches.length, 5);
      expect(controller.hasMore, isFalse);
    },
  );

  test(
    'a later page failure preserves all visible rows and supports retry',
    () async {
      final source = _ControlledSource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
        pageSize: 2,
      );
      addTearDown(controller.dispose);
      final initial = controller.loadNextPage();
      source.requests.last.complete(['old-4', 'old-3'], nextCursor: '2');
      await initial;
      final second = controller.loadNextPage();
      source.requests.last.complete(['old-2', 'old-1']);
      await second;

      final failedRefresh = controller.refreshVisible();
      source.requests.last.complete(['new-4', 'new-3'], nextCursor: '2');
      await _until(() => source.requests.length == 4);
      source.requests.last.result.completeError(StateError('offline'));
      await failedRefresh;
      expect(_ids(controller), ['old-4', 'old-3', 'old-2', 'old-1']);
      expect(controller.loadError, isA<StateError>());
      expect(controller.hasMore, isFalse);

      final retry = controller.refreshVisible();
      source.requests.last.complete(['new-4', 'new-3'], nextCursor: '2');
      await _until(() => source.requests.length == 6);
      source.requests.last.complete(['new-2', 'new-1']);
      await retry;
      expect(_ids(controller), ['new-4', 'new-3', 'new-2', 'new-1']);
      expect(controller.loadError, isNull);
    },
  );

  test(
    'refresh requests during a refresh merge into one subsequent request',
    () async {
      final source = _ControlledSource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
        pageSize: 1,
      );
      addTearDown(controller.dispose);
      final initial = controller.loadNextPage();
      source.requests.last.complete(['old']);
      await initial;
      final first = controller.refreshVisible();
      final second = controller.refreshVisible();
      final third = controller.refreshVisible();
      expect(source.requests.length, 2);
      source.requests.last.complete(['intermediate']);
      await _until(() => source.requests.length == 3);
      source.requests.last.complete(['latest']);
      await Future.wait([first, second, third]);
      expect(source.requests.length, 3);
      expect(source.maximumConcurrentRequests, 1);
      expect(_ids(controller), ['latest']);
    },
  );

  test('change during initial loading queues one visible refresh', () async {
    final source = _ControlledSource();
    final controller = HistoryController(matches: const [], dataSource: source);
    addTearDown(controller.dispose);
    final initial = controller.loadNextPage();
    final refresh = controller.refreshVisible();
    source.requests.last.complete(['old']);
    await _until(() => source.requests.length == 2);
    source.requests.last.complete(['latest']);
    await Future.wait([initial, refresh]);
    expect(_ids(controller), ['latest']);
    expect(source.maximumConcurrentRequests, 1);
  });

  test('filter changes invalidate an older visible refresh', () async {
    final source = _ControlledSource();
    final controller = HistoryController(
      matches: const [],
      dataSource: source,
      pageSize: 1,
    );
    addTearDown(controller.dispose);
    final initial = controller.loadNextPage();
    source.requests.last.complete(['old']);
    await initial;
    final refresh = controller.refreshVisible();
    controller.updateSearch('new');
    source.requests.last.complete(['stale']);
    await _until(() => source.requests.length == 3);
    expect(source.requests.last.filters.search, 'new');
    source.requests.last.complete(['filtered']);
    await refresh;
    expect(_ids(controller), ['filtered']);
    expect(controller.filters.search, 'new');
  });

  test(
    'manual refresh supersedes a visible refresh without concurrent loads',
    () async {
      final source = _ControlledSource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
        pageSize: 1,
      );
      addTearDown(controller.dispose);
      final initial = controller.loadNextPage();
      source.requests.last.complete(['old']);
      await initial;
      final visibleRefresh = controller.refreshVisible();
      final manualRefresh = controller.refresh();
      source.requests.last.complete(['stale']);
      await _until(() => source.requests.length == 3);
      source.requests.last.complete(['latest']);
      await Future.wait([visibleRefresh, manualRefresh]);
      expect(_ids(controller), ['latest']);
      expect(source.maximumConcurrentRequests, 1);
    },
  );

  test(
    'disposal completes refresh waiters and prevents queued reloads',
    () async {
      final source = _ControlledSource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
      );
      final first = controller.refreshVisible();
      final second = controller.refreshVisible();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      await Future.wait([first, second]);
      source.requests.last.complete(['late']);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 0);
      expect(source.requests.length, 1);
    },
  );

  testWidgets(
    'failed last-page refresh keeps rows and exposes a working retry',
    (tester) async {
      final source = _ControlledSource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
      final initial = controller.loadNextPage();
      source.requests.last.complete(['old']);
      await initial;
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryPage(controller: controller, onMatchTap: (_) {}),
        ),
      );
      final refresh = controller.refreshVisible();
      source.requests.last.result.completeError(StateError('unavailable'));
      await refresh;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-match-old')), findsOneWidget);
      final retry = find.byKey(const Key('history-load-more-retry'));
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      expect(source.requests.length, 3);
      source.requests.last.complete(['latest']);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-match-latest')), findsOneWidget);
      expect(find.byKey(const Key('history-load-more-error')), findsNothing);
    },
  );
}

List<String> _ids(HistoryController controller) =>
    controller.matches.map((match) => match.matchId).toList();

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected history operation did not run.');
}

class _Request {
  _Request(this.filters, this.limit, this.cursor);
  final HistoryFilters filters;
  final int limit;
  final String? cursor;
  final result = Completer<HistoryPageResult>();

  void complete(List<String> ids, {String? nextCursor}) => result.complete(
    HistoryPageResult(
      entries: ids
          .map(
            (id) => HistoryMatchSummary(
              matchId: id,
              playedAt: DateTime(2026, 7, 1),
              redName: 'Keep',
              blueName: 'Blue',
              redScore: 1,
              blueScore: 0,
              ruleName: 'Free',
              duration: Duration.zero,
              locatedShots: 0,
              scoringEvents: 0,
            ),
          )
          .toList(),
      nextCursor: nextCursor,
    ),
  );
}

class _ControlledSource extends HistoryDataSource {
  final requests = <_Request>[];
  int _concurrentRequests = 0;
  int maximumConcurrentRequests = 0;

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    final request = _Request(filters, limit, cursor);
    requests.add(request);
    _concurrentRequests++;
    if (_concurrentRequests > maximumConcurrentRequests) {
      maximumConcurrentRequests = _concurrentRequests;
    }
    try {
      return await request.result.future;
    } finally {
      _concurrentRequests--;
    }
  }
}

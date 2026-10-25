import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/features/history/history_controller.dart';

void main() {
  test('orders recent matches and derives winner and completeness', () {
    final controller = HistoryController(
      matches: [
        HistoryMatchSummary(
          matchId: 'older',
          playedAt: DateTime(2026, 7, 1),
          redName: '红 A',
          blueName: '蓝 A',
          redScore: 5,
          blueScore: 5,
          ruleName: '自由计分',
          duration: const Duration(minutes: 5),
          locatedShots: 0,
          scoringEvents: 0,
        ),
        HistoryMatchSummary(
          matchId: 'newer',
          playedAt: DateTime(2026, 7, 2),
          redName: '红 B',
          blueName: '蓝 B',
          redScore: 11,
          blueScore: 8,
          ruleName: '11 分制',
          duration: const Duration(minutes: 9),
          locatedShots: 8,
          scoringEvents: 10,
        ),
      ],
    );

    expect(controller.matches.first.matchId, 'newer');
    expect(controller.matches.first.winnerName, '红 B');
    expect(controller.matches.first.locationCompleteness, 0.8);
    expect(controller.matches.last.winnerName, isNull);
    expect(controller.matches.last.locationCompleteness, 0);
  });

  test('filters history by search, lifecycle, rule and date window', () {
    final controller = HistoryController(
      matches: [
        HistoryMatchSummary(
          matchId: 'archived',
          playedAt: DateTime(2026, 7, 3),
          redName: 'Red Fox',
          blueName: 'Blue Bear',
          redScore: 11,
          blueScore: 8,
          ruleName: 'Race to 11',
          duration: Duration.zero,
          locatedShots: 0,
          scoringEvents: 0,
          lifecycle: HistoryMatchLifecycle.archived,
        ),
        HistoryMatchSummary(
          matchId: 'finished',
          playedAt: DateTime(2026, 7, 5),
          redName: 'Red Fox',
          blueName: 'Blue Bird',
          redScore: 9,
          blueScore: 11,
          ruleName: 'Race to 11',
          duration: Duration.zero,
          locatedShots: 0,
          scoringEvents: 0,
        ),
      ],
    );

    controller.updateFilters(
      controller.filters.copyWith(
        search: 'bird',
        lifecycle: HistoryLifecycleFilter.finished,
        ruleName: 'Race to 11',
        from: DateTime(2026, 7, 4),
        to: DateTime(2026, 7, 6),
      ),
    );

    expect(controller.matches.map((match) => match.matchId), ['finished']);
  });

  test('loads the next cursor page from a bounded history source', () async {
    final source = _FakeHistorySource([
      HistoryPageResult(
        entries: [_summary('first', DateTime(2026, 7, 2))],
        nextCursor: 'next',
      ),
      HistoryPageResult(entries: [_summary('second', DateTime(2026, 7, 1))]),
    ]);
    final controller = HistoryController(
      matches: const [],
      dataSource: source,
      pageSize: 1,
    );

    expect(await controller.loadNextPage(), isTrue);
    expect(await controller.loadNextPage(), isFalse);
    expect(controller.matches.map((match) => match.matchId), [
      'first',
      'second',
    ]);
    expect(source.cursors, [null, 'next']);
  });

  test(
    'trusts server-side profile and date filtering for source-backed history',
    () async {
      final source = _ServerFilteredHistorySource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
      );

      controller.updateFilters(
        controller.filters.copyWith(
          search: 'profile-id',
          from: DateTime(2026, 8, 1),
          to: DateTime(2026, 8, 1),
        ),
      );
      await _eventually(() => !controller.isLoadingPage);

      expect(controller.matches.map((match) => match.matchId), ['server-hit']);
      expect(source.lastFilters.search, 'profile-id');
      expect(source.lastFilters.from, DateTime(2026, 8, 1));
    },
  );

  test(
    'refresh during an in-flight request reloads from the first cursor',
    () async {
      final source = _RefreshHistorySource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
      );

      final firstLoad = controller.loadNextPage();
      final refresh = controller.refresh();
      await Future.wait([firstLoad, refresh]);

      expect(source.cursors, [null, null]);
      expect(controller.matches.map((match) => match.matchId), ['latest']);
    },
  );

  test(
    'lifecycle mutations reset pagination and fill the removed row',
    () async {
      final source = _FakeHistorySource([
        HistoryPageResult(
          entries: [_summary('archived', DateTime(2026, 7, 2))],
          nextCursor: 'next',
        ),
        HistoryPageResult(
          entries: [_summary('replacement', DateTime(2026, 7, 1))],
        ),
      ]);
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
        pageSize: 1,
      );

      await controller.loadNextPage();
      await controller.archiveMatch('archived');

      expect(source.cursors, [null, null]);
      expect(controller.matches.map((match) => match.matchId), ['replacement']);
    },
  );

  test(
    'lifecycle actions are explicit and require a second delete confirmation',
    () async {
      final source = _FakeHistorySource([]);
      final controller = HistoryController(
        matches: [_summary('finished', DateTime(2026, 7, 1))],
        dataSource: source,
      );

      await controller.archiveMatch('finished');
      expect(source.archivedIds, ['finished']);
      expect(
        await controller.deleteMatch('finished', confirmed: false),
        isFalse,
      );
      expect(source.deletedIds, isEmpty);
      expect(await controller.deleteMatch('finished', confirmed: true), isTrue);
      expect(source.deletedIds, ['finished']);
    },
  );

  test('discards a stale in-flight page after a rapid search change', () async {
    final source = _SearchHistorySource();
    final controller = HistoryController(matches: const [], dataSource: source);

    final firstLoad = controller.loadNextPage();
    controller.updateSearch('second');
    await firstLoad;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(source.calls, 2);
    expect(controller.matches.map((match) => match.matchId), ['second']);
  });

  test(
    'does not notify or reload after disposal during a page request',
    () async {
      final source = _SearchHistorySource()..delay = 20;
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      final loading = controller.loadNextPage();
      expect(notifications, 1);
      controller.dispose();

      expect(await loading, isFalse);
      expect(source.calls, 1);
      expect(notifications, 1);
    },
  );

  test(
    'captures a page failure and clears it after a successful retry',
    () async {
      final source = _FailingHistorySource();
      final controller = HistoryController(
        matches: const [],
        dataSource: source,
      );

      expect(await controller.loadNextPage(), isFalse);
      expect(controller.loadError, isA<StateError>());

      source.shouldFail = false;
      await controller.refresh();
      expect(controller.loadError, isNull);
      expect(controller.matches.map((match) => match.matchId), ['recovered']);
    },
  );
}

Future<void> _eventually(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition was not met before timeout.');
}

HistoryMatchSummary _summary(String id, DateTime playedAt) =>
    HistoryMatchSummary(
      matchId: id,
      playedAt: playedAt,
      redName: 'Red',
      blueName: 'Blue',
      redScore: 1,
      blueScore: 0,
      ruleName: 'Free',
      duration: Duration.zero,
      locatedShots: 0,
      scoringEvents: 0,
    );

class _FakeHistorySource implements HistoryDataSource {
  _FakeHistorySource(this.pages);

  final List<HistoryPageResult> pages;
  final cursors = <String?>[];
  final archivedIds = <String>[];
  final unarchivedIds = <String>[];
  final deletedIds = <String>[];

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    cursors.add(cursor);
    if (pages.isEmpty) return const HistoryPageResult(entries: []);
    return pages.removeAt(0);
  }

  @override
  Future<void> archiveMatch(String matchId) async => archivedIds.add(matchId);

  @override
  Future<void> unarchiveMatch(String matchId) async =>
      unarchivedIds.add(matchId);

  @override
  Future<void> permanentlyDeleteMatch(String matchId) async =>
      deletedIds.add(matchId);
}

class _ServerFilteredHistorySource extends HistoryDataSource {
  late HistoryFilters lastFilters;

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    lastFilters = filters;
    return HistoryPageResult(
      entries: [
        HistoryMatchSummary(
          matchId: 'server-hit',
          playedAt: DateTime(2026, 1, 1),
          redName: 'Snapshot name does not match',
          blueName: 'Profile nickname is resolved in SQL',
          redScore: 1,
          blueScore: 0,
          ruleName: 'Free',
          duration: Duration.zero,
          locatedShots: 0,
          scoringEvents: 0,
        ),
      ],
    );
  }
}

class _RefreshHistorySource extends HistoryDataSource {
  final cursors = <String?>[];
  var calls = 0;

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    cursors.add(cursor);
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return HistoryPageResult(
      entries: [
        _summary(calls == 1 ? 'stale' : 'latest', DateTime(2026, 7, 1)),
      ],
    );
  }
}

class _SearchHistorySource implements HistoryDataSource {
  var calls = 0;
  int delay = 5;

  @override
  Future<void> archiveMatch(String matchId) async {}

  @override
  Future<void> unarchiveMatch(String matchId) async {}

  @override
  Future<void> permanentlyDeleteMatch(String matchId) async {}

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    calls++;
    await Future<void>.delayed(Duration(milliseconds: delay));
    final id = filters.search == 'second' ? 'second' : 'first';
    return HistoryPageResult(
      entries: [
        HistoryMatchSummary(
          matchId: id,
          playedAt: DateTime(2026, 7, 1),
          redName: id,
          blueName: 'Blue',
          redScore: 1,
          blueScore: 0,
          ruleName: 'Free',
          duration: Duration.zero,
          locatedShots: 0,
          scoringEvents: 0,
        ),
      ],
    );
  }
}

class _FailingHistorySource extends HistoryDataSource {
  bool shouldFail = true;

  @override
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  }) async {
    if (shouldFail) throw StateError('history unavailable');
    return HistoryPageResult(
      entries: [_summary('recovered', DateTime(2026, 7, 1))],
    );
  }
}

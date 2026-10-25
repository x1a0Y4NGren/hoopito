import 'dart:collection';
import 'dart:async';

import 'package:flutter/foundation.dart';

enum HistoryMatchLifecycle { active, finished, archived, abandoned, draft }

enum HistoryLifecycleFilter { finished, archived, all }

class HistoryFilters {
  const HistoryFilters({
    this.search = '',
    this.from,
    this.to,
    this.ruleName,
    this.recordingMode,
    this.lifecycle = HistoryLifecycleFilter.finished,
  });

  final String search;
  final DateTime? from;
  final DateTime? to;
  final String? ruleName;
  final String? recordingMode;
  final HistoryLifecycleFilter lifecycle;

  HistoryFilters copyWith({
    String? search,
    DateTime? from,
    DateTime? to,
    String? ruleName,
    String? recordingMode,
    HistoryLifecycleFilter? lifecycle,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearRuleName = false,
    bool clearRecordingMode = false,
  }) {
    return HistoryFilters(
      search: search ?? this.search,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      ruleName: clearRuleName ? null : ruleName ?? this.ruleName,
      recordingMode: clearRecordingMode
          ? null
          : recordingMode ?? this.recordingMode,
      lifecycle: lifecycle ?? this.lifecycle,
    );
  }
}

class HistoryMatchSummary {
  const HistoryMatchSummary({
    required this.matchId,
    required this.playedAt,
    required this.redName,
    required this.blueName,
    required this.redScore,
    required this.blueScore,
    required this.ruleName,
    required this.duration,
    required this.locatedShots,
    required this.scoringEvents,
    this.lifecycle = HistoryMatchLifecycle.finished,
    this.recordingMode,
    this.isImportedIncomplete = false,
  }) : assert(locatedShots >= 0),
       assert(scoringEvents >= 0);

  final String matchId;
  final DateTime playedAt;
  final String redName;
  final String blueName;
  final int redScore;
  final int blueScore;
  final String ruleName;
  final Duration duration;
  final int locatedShots;
  final int scoringEvents;
  final HistoryMatchLifecycle lifecycle;
  final String? recordingMode;
  final bool isImportedIncomplete;

  bool get isArchived => lifecycle == HistoryMatchLifecycle.archived;

  bool get isActive => lifecycle == HistoryMatchLifecycle.active;

  String? get winnerName {
    if (redScore == blueScore) return null;
    return redScore > blueScore ? redName : blueName;
  }

  double get locationCompleteness {
    if (scoringEvents == 0) return 0;
    return (locatedShots / scoringEvents).clamp(0, 1);
  }

  HistoryMatchSummary copyWith({HistoryMatchLifecycle? lifecycle}) {
    return HistoryMatchSummary(
      matchId: matchId,
      playedAt: playedAt,
      redName: redName,
      blueName: blueName,
      redScore: redScore,
      blueScore: blueScore,
      ruleName: ruleName,
      duration: duration,
      locatedShots: locatedShots,
      scoringEvents: scoringEvents,
      lifecycle: lifecycle ?? this.lifecycle,
      recordingMode: recordingMode,
      isImportedIncomplete: isImportedIncomplete,
    );
  }
}

class HistoryPageResult {
  const HistoryPageResult({required this.entries, this.nextCursor});

  final List<HistoryMatchSummary> entries;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// Bounded history access used by the UI. The repository adapter can replace
/// the current stream implementation without making the page perform a
/// per-row query. Lifecycle methods are intentionally explicit so destructive
/// deletion cannot happen as a side effect of filtering or pagination.
abstract class HistoryDataSource {
  Future<HistoryPageResult> loadPage({
    required HistoryFilters filters,
    required int limit,
    String? cursor,
  });

  Future<void> archiveMatch(String matchId) =>
      Future<void>.error(UnsupportedError('Archive is unavailable.'));

  Future<void> unarchiveMatch(String matchId) =>
      Future<void>.error(UnsupportedError('Unarchive is unavailable.'));

  Future<void> permanentlyDeleteMatch(String matchId) => Future<void>.error(
    UnsupportedError('Permanent deletion is unavailable.'),
  );
}

class HistoryController extends ChangeNotifier {
  HistoryController({
    required List<HistoryMatchSummary> matches,
    this.dataSource,
    this.pageSize = 20,
  }) : assert(pageSize > 0),
       _allMatches = List.of(matches),
       _filters = const HistoryFilters() {
    _sort();
  }

  final HistoryDataSource? dataSource;
  final int pageSize;
  final List<HistoryMatchSummary> _allMatches;
  HistoryFilters _filters;
  String? _nextCursor;
  bool _loadingPage = false;
  bool _hasLoadedSourcePage = false;
  int _requestGeneration = 0;
  bool _reloadPending = false;
  Completer<void>? _refreshCompleter;
  bool _visibleRefreshPending = false;
  Completer<void>? _visibleRefreshCompleter;
  bool _visibleRefreshFailed = false;
  bool _disposed = false;
  Object? _loadError;

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    final refreshCompleter = _refreshCompleter;
    _refreshCompleter = null;
    if (refreshCompleter != null && !refreshCompleter.isCompleted) {
      refreshCompleter.complete();
    }
    final visibleRefreshCompleter = _visibleRefreshCompleter;
    _visibleRefreshCompleter = null;
    if (visibleRefreshCompleter != null &&
        !visibleRefreshCompleter.isCompleted) {
      visibleRefreshCompleter.complete();
    }
    super.dispose();
  }

  HistoryFilters get filters => _filters;

  bool get isLoadingPage => _loadingPage;

  Object? get loadError => _loadError;

  bool get hasMore => _nextCursor != null || !_hasLoadedSourcePage;

  UnmodifiableListView<HistoryMatchSummary> get matches => UnmodifiableListView(
    _allMatches
        .where(
          dataSource == null ? _filters.matches : _filters.matchesLifecycleOnly,
        )
        .toList(growable: false),
  );

  UnmodifiableListView<HistoryMatchSummary> get allMatches =>
      UnmodifiableListView(_allMatches);

  void updateFilters(HistoryFilters filters) {
    if (_disposed) return;
    _filters = filters;
    if (dataSource != null) {
      _requestGeneration++;
      _allMatches.clear();
      _nextCursor = null;
      _hasLoadedSourcePage = false;
      if (_loadingPage) {
        _reloadPending = true;
      } else {
        unawaited(loadNextPage());
      }
    }
    notifyListeners();
  }

  void updateSearch(String search) {
    updateFilters(_filters.copyWith(search: search));
  }

  void resetFilters() {
    updateFilters(const HistoryFilters());
  }

  Future<bool> loadNextPage() async {
    final source = dataSource;
    if (_disposed ||
        source == null ||
        _loadingPage ||
        (_hasLoadedSourcePage && !hasMore)) {
      return false;
    }
    _loadingPage = true;
    _loadError = null;
    _visibleRefreshFailed = false;
    final generation = _requestGeneration;
    notifyListeners();
    try {
      final page = await source.loadPage(
        filters: _filters,
        limit: pageSize,
        cursor: _nextCursor,
      );
      if (_disposed || generation != _requestGeneration) return false;
      final seen = _allMatches.map((match) => match.matchId).toSet();
      for (final entry in page.entries) {
        if (seen.add(entry.matchId)) _allMatches.add(entry);
      }
      _nextCursor = page.nextCursor;
      _hasLoadedSourcePage = true;
      _sort();
      return page.hasMore;
    } on Object catch (error) {
      if (!_disposed && generation == _requestGeneration) {
        _loadError = error;
      }
      return false;
    } finally {
      _finishPageLoad();
    }
  }

  /// Replaces the already loaded range only after all bounded pages succeed.
  /// Requests received during a load merge into one subsequent refresh.
  Future<void> refreshVisible() {
    if (_disposed || dataSource == null) return Future<void>.value();
    _visibleRefreshPending = true;
    final completer = _visibleRefreshCompleter ??= Completer<void>();
    _drainPendingLoads();
    return completer.future;
  }

  Future<void> _refreshVisibleNow() async {
    final source = dataSource!;
    _visibleRefreshPending = false;
    _loadingPage = true;
    _loadError = null;
    _visibleRefreshFailed = false;
    final generation = _requestGeneration;
    final filters = _filters;
    final targetCount = _allMatches.length < pageSize
        ? pageSize
        : _allMatches.length;
    final refreshed = <HistoryMatchSummary>[];
    final seenIds = <String>{};
    final seenCursors = <String?>{};
    String? cursor;
    notifyListeners();
    try {
      do {
        if (!seenCursors.add(cursor)) {
          throw StateError('History pagination cursor did not advance.');
        }
        final page = await source.loadPage(
          filters: filters,
          limit: pageSize,
          cursor: cursor,
        );
        if (_disposed || generation != _requestGeneration) return;
        for (final entry in page.entries) {
          if (seenIds.add(entry.matchId)) refreshed.add(entry);
        }
        cursor = page.nextCursor;
      } while (cursor != null && refreshed.length < targetCount);
      _allMatches
        ..clear()
        ..addAll(refreshed);
      _nextCursor = cursor;
      _hasLoadedSourcePage = true;
      _sort();
    } on Object catch (error) {
      if (!_disposed && generation == _requestGeneration) {
        _loadError = error;
        _visibleRefreshFailed = true;
      }
    } finally {
      _finishPageLoad();
    }
  }

  Future<void> retryLoad() async {
    if (_visibleRefreshFailed) {
      await refreshVisible();
    } else {
      await loadNextPage();
    }
  }

  void _finishPageLoad() {
    _loadingPage = false;
    if (_disposed) return;
    notifyListeners();
    _drainPendingLoads();
  }

  void _drainPendingLoads() {
    if (_disposed || _loadingPage) return;
    if (_reloadPending) {
      _reloadPending = false;
      final refreshCompleter = _refreshCompleter;
      _refreshCompleter = null;
      unawaited(
        loadNextPage().then((_) {
          if (refreshCompleter != null && !refreshCompleter.isCompleted) {
            refreshCompleter.complete();
          }
        }),
      );
    } else if (_visibleRefreshPending) {
      unawaited(_refreshVisibleNow());
    } else {
      final completer = _visibleRefreshCompleter;
      _visibleRefreshCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    _requestGeneration++;
    _allMatches.clear();
    _nextCursor = null;
    _hasLoadedSourcePage = false;
    _loadError = null;
    notifyListeners();
    if (_loadingPage) {
      _reloadPending = true;
      final completer = _refreshCompleter ??= Completer<void>();
      return completer.future;
    }
    await loadNextPage();
  }

  Future<void> archiveMatch(String matchId) async {
    final source = dataSource;
    if (source == null) throw StateError('History data source is unavailable.');
    await source.archiveMatch(matchId);
    if (_disposed) return;
    _replaceLifecycle(matchId, HistoryMatchLifecycle.archived);
    await refresh();
  }

  Future<void> unarchiveMatch(String matchId) async {
    final source = dataSource;
    if (source == null) throw StateError('History data source is unavailable.');
    await source.unarchiveMatch(matchId);
    if (_disposed) return;
    _replaceLifecycle(matchId, HistoryMatchLifecycle.finished);
    await refresh();
  }

  Future<bool> deleteMatch(String matchId, {required bool confirmed}) async {
    if (!confirmed) return false;
    final source = dataSource;
    if (source == null) throw StateError('History data source is unavailable.');
    await source.permanentlyDeleteMatch(matchId);
    if (_disposed) return true;
    _allMatches.removeWhere((match) => match.matchId == matchId);
    notifyListeners();
    await refresh();
    return true;
  }

  void _replaceLifecycle(String matchId, HistoryMatchLifecycle lifecycle) {
    if (_disposed) return;
    final index = _allMatches.indexWhere((match) => match.matchId == matchId);
    if (index < 0) return;
    _allMatches[index] = _allMatches[index].copyWith(lifecycle: lifecycle);
    _sort();
    notifyListeners();
  }

  void _sort() {
    _allMatches.sort((a, b) {
      final date = b.playedAt.compareTo(a.playedAt);
      return date != 0 ? date : b.matchId.compareTo(a.matchId);
    });
  }
}

extension HistoryFiltersMatching on HistoryFilters {
  bool matchesLifecycleOnly(HistoryMatchSummary match) {
    if (match.isActive || match.lifecycle == HistoryMatchLifecycle.abandoned) {
      return false;
    }
    return switch (lifecycle) {
      HistoryLifecycleFilter.finished =>
        match.lifecycle == HistoryMatchLifecycle.finished,
      HistoryLifecycleFilter.archived =>
        match.lifecycle == HistoryMatchLifecycle.archived,
      HistoryLifecycleFilter.all =>
        match.lifecycle == HistoryMatchLifecycle.finished ||
            match.lifecycle == HistoryMatchLifecycle.archived,
    };
  }

  bool matches(HistoryMatchSummary match) {
    if (!matchesLifecycleOnly(match)) return false;
    final normalized = search.trim().toLowerCase();
    if (normalized.isNotEmpty &&
        !'${match.redName} ${match.blueName}'.toLowerCase().contains(
          normalized,
        )) {
      return false;
    }
    if (from != null && match.playedAt.isBefore(from!)) return false;
    if (to != null && match.playedAt.isAfter(to!)) return false;
    if (ruleName != null &&
        ruleName!.isNotEmpty &&
        match.ruleName != ruleName) {
      return false;
    }
    if (recordingMode != null && match.recordingMode != recordingMode) {
      return false;
    }
    return true;
  }
}

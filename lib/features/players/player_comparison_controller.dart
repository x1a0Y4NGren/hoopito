import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';

typedef PlayerComparisonMatchLoader =
    Future<List<PlayerComparisonMatch>> Function(String playerId);
typedef PlayerComparisonLoader =
    Future<PlayerComparisonReport> Function(PlayerComparisonRequest request);

class PlayerComparisonOpponent {
  const PlayerComparisonOpponent({
    required this.playerId,
    required this.nameSnapshot,
  });

  final String playerId;
  final String nameSnapshot;
}

class PlayerComparisonController extends ChangeNotifier {
  PlayerComparisonController({
    required this.playerId,
    required PlayerComparisonMatchLoader listMatches,
    required PlayerComparisonLoader compare,
    DateTime? asOfUtc,
  }) : _listMatches = listMatches,
       _compare = compare,
       asOfUtc = (asOfUtc ?? DateTime.now()).toUtc() {
    unawaited(_loadAll());
  }

  final String playerId;
  final DateTime asOfUtc;
  final PlayerComparisonMatchLoader _listMatches;
  final PlayerComparisonLoader _compare;

  List<PlayerComparisonMatch> _matches = const [];
  PlayerComparisonMode _mode = PlayerComparisonMode.matchPair;
  PlayerComparisonWindow _window = PlayerComparisonWindow.thirtyDays;
  String? _opponentPlayerId;
  String? _baselineMatchId;
  String? _currentMatchId;
  PlayerComparisonReport? _report;
  Object? _error;
  var _isLoading = true;
  var _generation = 0;
  var _disposed = false;

  List<PlayerComparisonMatch> get matches => _matches;
  PlayerComparisonMode get mode => _mode;
  PlayerComparisonWindow get window => _window;
  String? get opponentPlayerId => _opponentPlayerId;
  String? get baselineMatchId => _baselineMatchId;
  String? get currentMatchId => _currentMatchId;
  PlayerComparisonReport? get report => _report;
  Object? get error => _error;
  bool get isLoading => _isLoading;
  bool get hasEnoughMatchesForPair => _matches.length >= 2;

  List<PlayerComparisonOpponent> get opponents {
    final values = <String, PlayerComparisonOpponent>{};
    for (final match in _matches) {
      final opponentId = match.opponentPlayerId;
      if (opponentId == null) continue;
      values.putIfAbsent(
        opponentId,
        () => PlayerComparisonOpponent(
          playerId: opponentId,
          nameSnapshot: match.opponentNameSnapshot,
        ),
      );
    }
    return List.unmodifiable(values.values);
  }

  void setMode(PlayerComparisonMode value) {
    if (_mode == value) return;
    _mode = value;
    unawaited(_loadReport());
  }

  void setWindow(PlayerComparisonWindow value) {
    if (_window == value) return;
    _window = value;
    if (_mode == PlayerComparisonMode.adjacentWindow) {
      unawaited(_loadReport());
    } else {
      notifyListeners();
    }
  }

  void setOpponent(String? playerId) {
    if (_opponentPlayerId == playerId) return;
    _opponentPlayerId = playerId;
    if (_mode == PlayerComparisonMode.adjacentWindow) {
      unawaited(_loadReport());
    } else {
      notifyListeners();
    }
  }

  void setBaselineMatch(String matchId) {
    if (_baselineMatchId == matchId) return;
    if (_currentMatchId == matchId) {
      _currentMatchId = _baselineMatchId;
    }
    _baselineMatchId = matchId;
    if (_mode == PlayerComparisonMode.matchPair) unawaited(_loadReport());
  }

  void setCurrentMatch(String matchId) {
    if (_currentMatchId == matchId) return;
    if (_baselineMatchId == matchId) {
      _baselineMatchId = _currentMatchId;
    }
    _currentMatchId = matchId;
    if (_mode == PlayerComparisonMode.matchPair) unawaited(_loadReport());
  }

  void swapMatches() {
    if (_baselineMatchId == null || _currentMatchId == null) return;
    final previousBaseline = _baselineMatchId;
    _baselineMatchId = _currentMatchId;
    _currentMatchId = previousBaseline;
    if (_mode == PlayerComparisonMode.matchPair) unawaited(_loadReport());
  }

  void retry() => unawaited(_loadAll());

  Future<void> _loadAll() async {
    final generation = ++_generation;
    _beginLoad();
    try {
      final matches = await _listMatches(playerId);
      if (!_isCurrent(generation)) return;
      _matches = List.unmodifiable(matches);
      _reconcileMatchSelection();
      _reconcileOpponentSelection();
      final request = _request;
      final report = request == null ? null : await _compare(request);
      if (!_isCurrent(generation)) return;
      _report = report;
      _isLoading = false;
      notifyListeners();
    } on Object catch (error) {
      _finishWithError(generation, error);
    }
  }

  Future<void> _loadReport() async {
    final generation = ++_generation;
    final request = _request;
    _beginLoad();
    if (request == null) {
      if (!_isCurrent(generation)) return;
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final report = await _compare(request);
      if (!_isCurrent(generation)) return;
      _report = report;
      _isLoading = false;
      notifyListeners();
    } on Object catch (error) {
      _finishWithError(generation, error);
    }
  }

  PlayerComparisonRequest? get _request => switch (_mode) {
    PlayerComparisonMode.matchPair =>
      _baselineMatchId == null || _currentMatchId == null
          ? null
          : MatchPairComparisonRequest(
              playerId: playerId,
              baselineMatchId: _baselineMatchId!,
              currentMatchId: _currentMatchId!,
            ),
    PlayerComparisonMode.adjacentWindow => AdjacentWindowComparisonRequest(
      playerId: playerId,
      window: _window,
      asOfUtc: asOfUtc,
      opponentPlayerId: _opponentPlayerId,
    ),
  };

  void _reconcileMatchSelection() {
    final ids = _matches.map((match) => match.matchId).toSet();
    final stillValid =
        _baselineMatchId != null &&
        _currentMatchId != null &&
        _baselineMatchId != _currentMatchId &&
        ids.contains(_baselineMatchId) &&
        ids.contains(_currentMatchId);
    if (stillValid) return;
    _baselineMatchId = _matches.length >= 2 ? _matches[1].matchId : null;
    _currentMatchId = _matches.isNotEmpty ? _matches.first.matchId : null;
  }

  void _reconcileOpponentSelection() {
    if (_opponentPlayerId == null) return;
    if (!opponents.any((value) => value.playerId == _opponentPlayerId)) {
      _opponentPlayerId = null;
    }
  }

  void _beginLoad() {
    _isLoading = true;
    _error = null;
    _report = null;
    if (!_disposed) notifyListeners();
  }

  void _finishWithError(int generation, Object error) {
    if (!_isCurrent(generation)) return;
    _error = error;
    _isLoading = false;
    _report = null;
    notifyListeners();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

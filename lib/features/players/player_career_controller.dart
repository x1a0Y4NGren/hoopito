import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hoopito/core/domain/analytics/player_career_aggregate.dart';

typedef PlayerCareerLoader =
    Stream<PlayerCareerAggregate> Function(PlayerCareerQuery query);

/// Holds the active career query and its reactive aggregate.
///
/// The loader is injected so the presentation layer can be tested without
/// opening a database. Production wiring supplies the profile-keyed Drift
/// repository stream.
class PlayerCareerController extends ChangeNotifier {
  PlayerCareerController({
    required this.playerId,
    required PlayerCareerLoader loader,
    PlayerCareerQuery initialQuery = const PlayerCareerQuery(),
  }) : _loader = loader,
       _query = initialQuery {
    _subscribe();
  }

  final String playerId;
  final PlayerCareerLoader _loader;
  PlayerCareerQuery _query;
  StreamSubscription<PlayerCareerAggregate>? _subscription;
  PlayerCareerAggregate? _aggregate;
  Object? _error;
  var _isLoading = true;
  var _disposed = false;
  var _subscriptionGeneration = 0;

  PlayerCareerQuery get query => _query;
  PlayerCareerAggregate? get aggregate => _aggregate;
  Object? get error => _error;
  bool get isLoading => _isLoading;

  void setWindow(PlayerCareerWindow window) {
    if (_query.window == window) return;
    _setQuery(
      PlayerCareerQuery(
        window: window,
        opponentPlayerId: _query.opponentPlayerId,
        asOfUtc: _query.asOfUtc,
      ),
    );
  }

  void setOpponent(String? opponentPlayerId) {
    if (_query.opponentPlayerId == opponentPlayerId) return;
    _setQuery(
      PlayerCareerQuery(
        window: _query.window,
        opponentPlayerId: opponentPlayerId,
        asOfUtc: _query.asOfUtc,
      ),
    );
  }

  void reload() {
    _setQuery(_query);
  }

  void _setQuery(PlayerCareerQuery query) {
    _query = query;
    _aggregate = null;
    _error = null;
    _isLoading = true;
    notifyListeners();
    unawaited(_subscription?.cancel());
    _subscribe();
  }

  void _subscribe() {
    final generation = ++_subscriptionGeneration;
    try {
      _subscription = _loader(_query).listen(
        (aggregate) {
          if (_disposed || generation != _subscriptionGeneration) return;
          _aggregate = aggregate;
          _error = null;
          _isLoading = false;
          notifyListeners();
        },
        onError: (Object error, StackTrace _) {
          if (_disposed || generation != _subscriptionGeneration) return;
          _error = error;
          _isLoading = false;
          notifyListeners();
        },
      );
    } on Object catch (error) {
      if (_disposed || generation != _subscriptionGeneration) return;
      _error = error;
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscriptionGeneration++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

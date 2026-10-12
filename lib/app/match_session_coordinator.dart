import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/start_match_mapper.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';

/// Coordinates scoring routes while keeping the old snapshot adapter
/// available for compatibility tests and non-production callers.
///
/// The production app supplies [commandService], which makes every scoring
/// mutation command-backed and only updates its controller from a committed
/// [MatchDetail] projection.
class MatchSessionCoordinator extends ChangeNotifier {
  MatchSessionCoordinator(
    this._repository, {
    MatchCommandService? commandService,
  }) : _commandService = commandService;

  final MatchRepository _repository;
  final MatchCommandService? _commandService;
  final Map<String, _ActiveSession> _sessions = {};
  final Set<String> _finishedMatches = {};

  MatchRepository get repository => _repository;

  bool get isCommandBacked => _commandService != null;

  bool get hasActiveMatch => _sessions.keys.any(isActive);

  ScoringController beginMatch(MatchSetup setup) {
    if (isCommandBacked) {
      throw StateError(
        'Command-backed sessions must be started with startCommitted.',
      );
    }
    final existing = _sessions[setup.matchId];
    if (existing != null) {
      return existing.controller;
    }

    final startedAt = DateTime.now();
    final controller = ScoringController(setup: setup);
    final session = _ActiveSession(
      setup: setup,
      startedAt: startedAt,
      controller: controller,
    );
    _sessions[setup.matchId] = session;
    session.writeQueue = _repository.saveMatch(
      Match(
        id: setup.matchId,
        createdAt: startedAt,
        startedAt: startedAt,
        status: MatchStatus.active,
        redName: setup.redName,
        blueName: setup.blueName,
        ruleTemplateSnapshot: controller.state.ruleTemplate,
        timerEnabled: setup.timerEnabled,
      ),
    );
    controller.addListener(() => _scheduleSnapshot(session));
    return controller;
  }

  Future<ScoringController> startCommitted(MatchSetup setup) async {
    final service = _commandService;
    if (service == null) {
      return beginMatch(setup);
    }
    final now = DateTime.now().toUtc();
    final command = buildStartMatchCommand(setup, now: now);
    final projection = await service.start(command);
    final controller = ScoringController.fromCommittedProjection(
      projection,
      service,
    );
    _sessions[setup.matchId] = _ActiveSession(
      setup: setup,
      startedAt: now,
      controller: controller,
    );
    return controller;
  }

  Future<ScoringController?> loadCommitted(String matchId) async {
    final service = _commandService;
    if (service == null) {
      return controllerFor(matchId);
    }
    final existing = _sessions[matchId];
    if (existing != null) return existing.controller;
    final projection = await _repository.getMatchDetail(matchId);
    if (projection == null ||
        projection.match.lifecycle != MatchLifecycle.active) {
      return null;
    }
    final controller = ScoringController.fromCommittedProjection(
      projection,
      service,
    );
    _sessions[matchId] = _ActiveSession(
      setup: MatchSetup(
        matchId: matchId,
        redName: projection.match.redName,
        blueName: projection.match.blueName,
        ruleTemplateId: projection.match.ruleTemplateSnapshot.id,
        ruleTemplateName: projection.match.ruleTemplateSnapshot.name,
        targetScore: projection.match.ruleTemplateSnapshot.targetScore,
        timerEnabled: projection.match.timerEnabled,
        timeLimitMinutes:
            (projection.match.ruleTemplateSnapshot.timeLimitSeconds ?? 600) ~/
            60,
        winByTwo: projection.match.ruleTemplateSnapshot.winByTwo,
        scoreButtons: projection.match.ruleTemplateSnapshot.scoreButtons,
        foulLimit: projection.match.ruleTemplateSnapshot.foulLimit,
        possessionHintEnabled:
            projection.match.ruleTemplateSnapshot.possessionHintEnabled,
        possessionPolicy:
            projection.match.ruleTemplateSnapshot.possessionPolicy,
        customEventTypes:
            projection.match.ruleTemplateSnapshot.customEventTypes,
      ),
      startedAt: projection.match.startedAt ?? projection.match.createdAt,
      controller: controller,
    );
    return controller;
  }

  ScoringController? controllerFor(String matchId) {
    return _sessions[matchId]?.controller;
  }

  bool isActive(String matchId) {
    return _sessions.containsKey(matchId) &&
        !_finishedMatches.contains(matchId);
  }

  Future<void> saveCurrent(String matchId) async {
    if (isCommandBacked) return;
    if (_finishedMatches.contains(matchId)) return;
    final session = _sessions[matchId];
    if (session == null) {
      return;
    }
    _scheduleSnapshot(session);
    await session.writeQueue;
  }

  Future<void> finishMatch(
    String matchId, {
    bool confirmFinalScore = false,
  }) async {
    if (isCommandBacked) {
      final service = _commandService!;
      await service.finish(
        FinishMatchCommand(
          matchId: matchId,
          endedAt: DateTime.now().toUtc(),
          confirmFinalScore: confirmFinalScore,
        ),
      );
      _finishedMatches.add(matchId);
      notifyListeners();
      return;
    }
    final session = _sessions[matchId];
    if (session != null) {
      _scheduleSnapshot(session);
      await session.writeQueue;
    }
    await _repository.finishMatch(matchId, endedAt: DateTime.now());
    _finishedMatches.add(matchId);
    notifyListeners();
  }

  /// Legacy-only snapshot bridge for callers that intentionally construct the
  /// coordinator without a command service. The production app never enters
  /// this path; command-backed sessions do not attach a snapshot listener.
  @Deprecated('Use MatchCommandService commands for live scoring.')
  void _scheduleSnapshot(_ActiveSession session) {
    final state = session.controller.state;
    final locations = [
      for (final location in state.shotLocations)
        ShotLocation(
          id: location.id,
          matchId: state.matchId,
          eventId: location.eventId,
          point: location.point,
          isConfirmed: location.isLocked,
        ),
    ];
    session.writeQueue = session.writeQueue.then(
      (_) => _repository.replaceMatchSnapshot(
        state.matchId,
        events: List.of(state.events),
        shotLocations: locations,
      ),
    );
  }

  @override
  void dispose() {
    for (final session in _sessions.values) {
      session.controller.dispose();
    }
    _sessions.clear();
    _finishedMatches.clear();
    super.dispose();
  }
}

class _ActiveSession {
  _ActiveSession({
    required this.setup,
    required this.startedAt,
    required this.controller,
  });

  final MatchSetup setup;
  final DateTime startedAt;
  final ScoringController controller;
  Future<void> writeQueue = Future.value();
}

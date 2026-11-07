import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';

/// A disposable practice sandbox. The production command path, receipts and
/// transactions run against its own memory database, never the app provider.
class PracticeSession extends ChangeNotifier {
  PracticeSession({MatchCommandFailureInjector? failureInjector}) {
    _database = AppDatabase.inMemory();
    _commands = MatchCommandService(
      _database,
      failureInjector: failureInjector,
    );
    repository = MatchRepository(_database);
  }

  late final AppDatabase _database;
  late final MatchCommandService _commands;
  late final MatchRepository repository;
  ScoringController? controller;
  PracticeStep step = PracticeStep.pregame;
  MatchDetail? result;
  Object? error;
  bool get busy => _pending != null;
  bool _closed = false;
  Future<void>? _pending;
  Future<void>? _closing;
  StartMatchCommand? _startCommand;
  FinishMatchCommand? _finishCommand;
  String? _blueScoreEventId;

  Future<void> start(MatchSetup setup) {
    if (_closed || busy || controller != null) return Future.value();
    // Setup controls are educational. Practice always uses untimed free play
    // and temporary participants, irrespective of imported presets or IDs.
    _startCommand ??= StartMatchCommand(
      redName: setup.redName,
      blueName: setup.blueName,
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: 'Free scoring',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.detailed,
    );
    return _track(() async {
      final detail = await _commands.start(_startCommand!);
      if (_closed) return;
      controller = ScoringController.fromCommittedProjection(detail, _commands)
        ..addListener(_projectionChanged);
      step = PracticeStep.scoreBlueTwo;
    });
  }

  void _projectionChanged() {
    if (_closed) return;
    if (!controller!.isSaving &&
        (step == PracticeStep.undo || step == PracticeStep.finish) &&
        controller!.locationSupplementWindow != null) {
      controller!.cancelLocateLastUnlocatedShot();
      return;
    }
    final state = controller!.state;
    final events = state.events.where((event) => !event.isDeleted).toList();
    final previous = step;
    switch (step) {
      case PracticeStep.scoreBlueTwo:
        final blue = events
            .where(
              (event) =>
                  event.side == TeamSide.blue &&
                  event.points == 2 &&
                  event.outcome == ShotOutcome.made,
            )
            .firstOrNull;
        if (blue != null &&
            state.score.blueScore == 2 &&
            state.score.redScore == 0) {
          _blueScoreEventId = blue.id;
          step = PracticeStep.undo;
        }
      case PracticeStep.undo:
        if (_blueScoreEventId != null &&
            !events.any((event) => event.id == _blueScoreEventId) &&
            state.score.blueScore == 0 &&
            state.score.redScore == 0) {
          step = PracticeStep.courtPoint;
        }
      case PracticeStep.courtPoint:
        final point = state.courtFirstShotDraft?.point;
        if (point != null &&
            point.x.isFinite &&
            point.y.isFinite &&
            point.x >= 0 &&
            point.x <= 1 &&
            point.y >= 0 &&
            point.y <= 1) {
          step = PracticeStep.scoreRedTwo;
        }
      case PracticeStep.scoreRedTwo:
        final red = events
            .where(
              (event) =>
                  event.side == TeamSide.red &&
                  event.points == 2 &&
                  event.outcome == ShotOutcome.made,
            )
            .firstOrNull;
        if (red != null &&
            state.score.redScore == 2 &&
            state.score.blueScore == 0 &&
            state.shotLocations.any(
              (location) => location.eventId == red.id && location.isLocked,
            )) {
          step = PracticeStep.missBlue;
        }
      case PracticeStep.missBlue:
        if (events.any(
              (event) =>
                  event.side == TeamSide.blue &&
                  event.type == EventKind.fieldGoal &&
                  event.outcome == ShotOutcome.missed,
            ) &&
            state.score.redScore == 2 &&
            state.score.blueScore == 0) {
          step = PracticeStep.finish;
        }
      case PracticeStep.pregame:
      case PracticeStep.finish:
      case PracticeStep.result:
        break;
    }
    if (previous != step) {
      // These steps teach undo/finish, not the optional timed supplement. A
      // competing court prompt would point beginners at the wrong action.
      notifyListeners();
    }
  }

  /// Called only after the scoring page's explicit final-score/coverage dialog.
  /// Keep the same command on retry, preserving receipt idempotency.
  Future<void> finish(int redScore, int blueScore, TrackingCoverage coverage) {
    if (_closed ||
        busy ||
        step != PracticeStep.finish ||
        controller!.isSaving) {
      return Future.value();
    }
    _finishCommand ??= FinishMatchCommand(
      matchId: controller!.state.matchId,
      endedAt: DateTime.now().toUtc(),
      confirmFinalScore: true,
      expectedRedScore: redScore,
      expectedBlueScore: blueScore,
      trackingCoverage: coverage,
    );
    return _track(() async {
      final detail = await _commands.finish(_finishCommand!);
      if (_closed) return;
      result = detail;
      step = PracticeStep.result;
    });
  }

  Future<void> _track(Future<void> Function() action) {
    error = null;
    final complete = Completer<void>();
    _pending = complete.future;
    notifyListeners();
    return (() async {
      try {
        await action();
      } on Object catch (failure) {
        if (!_closed) error = failure;
        rethrow;
      } finally {
        _pending = null;
        complete.complete();
        if (!_closed) notifyListeners();
      }
    })();
  }

  /// Disallow new work immediately, but retain the connection until controller
  /// transactions and queued writes have drained. This also covers route pops.
  Future<void> close() {
    if (_closing == null) dispose();
    return _closing!;
  }

  Future<void> _close() async {
    await _pending;
    final scoring = controller;
    if (scoring != null) {
      if (scoring.isSaving) {
        final drained = Completer<void>();
        void check() {
          if (!scoring.isSaving && !drained.isCompleted) drained.complete();
        }

        scoring.addListener(check);
        check();
        await drained.future;
        scoring.removeListener(check);
      }
      scoring.dispose();
    }
    await _database.close();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    controller?.removeListener(_projectionChanged);
    super.dispose();
    _closing = _close();
  }
}

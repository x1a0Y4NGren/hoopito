import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';

class PracticePauseRequired implements Exception {
  const PracticePauseRequired(this.matchId);
  final String matchId;
}

/// Reads at action time instead of relying on a possibly stale route stream.
class PracticeEntry {
  PracticeEntry(this.repository, this.commands);
  final MatchRepository repository;
  final MatchCommandService commands;

  Future<MatchDetail?> enter({String? pauseMatchId}) async {
    final detail = await repository.getActiveMatch();
    if (detail == null) return null;
    final scoring = ScoringController.fromCommittedProjection(detail, commands);
    final paused = scoring.isManuallyPaused;
    scoring.dispose();
    // Recovery and expiry can project a stop or decision while the stored
    // anchor still runs. Require consent and command normalization first.
    if (detail.clock?.requiresPersistence != true &&
        (detail.decision != null ||
            paused ||
            (detail.match.timerEnabled &&
                detail.clock != null &&
                !detail.clock!.isRunning))) {
      return detail;
    }
    if (pauseMatchId != detail.match.id) {
      throw PracticePauseRequired(detail.match.id);
    }
    return commands.pause(
      PauseMatchCommand(
        matchId: detail.match.id,
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }
}

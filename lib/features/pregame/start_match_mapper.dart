import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

class PregameSetupValidationException implements Exception {
  PregameSetupValidationException(this.result);

  final PregameValidationResult result;

  @override
  String toString() {
    return 'PregameSetupValidationException: ${result.errors.map(pregameValidationErrorMessage).join(' ')}';
  }
}

/// Validates and maps the complete pre-game state before the start command is
/// handed to the transactional kernel. Recording metadata is retained for
/// compatibility, but new matches use the historical simple score-only
/// defaults without exposing those implementation details in the start UI.
StartMatchCommand buildStartMatchCommand(MatchSetup setup, {DateTime? now}) {
  final result = validateMatchSetup(setup);
  if (!result.isValid) {
    throw PregameSetupValidationException(result);
  }

  final timestamp = (now ?? DateTime.now()).toUtc();
  final countdown = setup.clockMode == ClockMode.countdown;
  final regulationSeconds = countdown ? setup.timeLimitMinutes * 60 : null;
  return StartMatchCommand(
    matchId: setup.matchId,
    redName: setup.redName.trim(),
    blueName: setup.blueName.trim(),
    redPlayerProfileId: setup.redPlayerProfileId,
    bluePlayerProfileId: setup.bluePlayerProfileId,
    recordingMode: setup.recordingMode ?? RecordingMode.simple,
    trackingCoverage: setup.trackingCoverage,
    clockMode: setup.clockMode,
    regulationSeconds: regulationSeconds,
    timerEnabled: setup.timerEnabled,
    ruleTemplate: RuleTemplate(
      id: setup.ruleTemplateId,
      name: setup.ruleTemplateName ?? setup.ruleTemplateId,
      scoreButtons: List.unmodifiable(setup.scoreButtons),
      targetScore: setup.targetScore,
      timeLimitSeconds: regulationSeconds,
      winByTwo: setup.winByTwo,
      foulLimit: setup.foulLimit,
      possessionHintEnabled: setup.possessionHintEnabled,
      possessionPolicy: setup.possessionPolicy,
      customEventTypes: List.unmodifiable(setup.customEventTypes),
    ),
    createdAt: timestamp,
    startedAt: timestamp,
  );
}

PregameValidationResult validateMatchSetup(MatchSetup setup) {
  final errors = <PregameValidationError>[];
  if (setup.redName.trim().isEmpty) {
    errors.add(PregameValidationError.redParticipantRequired);
  }
  if (setup.blueName.trim().isEmpty) {
    errors.add(PregameValidationError.blueParticipantRequired);
  }
  if (setup.redPlayerProfileId != null &&
      setup.redPlayerProfileId == setup.bluePlayerProfileId) {
    errors.add(PregameValidationError.duplicatePlayerProfile);
  }
  if (setup.clockMode == ClockMode.countdown) {
    if (!setup.timerEnabled) {
      errors.add(PregameValidationError.countdownTimerRequired);
    }
    if (setup.timeLimitMinutes < 1 || setup.timeLimitMinutes > 180) {
      errors.add(PregameValidationError.invalidCountdownDuration);
    }
  }
  return PregameValidationResult(List.unmodifiable(errors));
}

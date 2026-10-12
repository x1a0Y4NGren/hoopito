import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

/// Reusable participant identity without an existing match or participant id.
class SetupParticipantPreset {
  const SetupParticipantPreset({required this.nameSnapshot, this.playerId});

  final String nameSnapshot;
  final String? playerId;
}

/// The editable setup for a new match, never the previous match's progress.
///
/// Recording coverage is deliberately chosen again for each new match. Scores,
/// events, lifecycle, possession and running clock state cannot enter a preset.
class MatchSetupPreset {
  const MatchSetupPreset({
    required this.red,
    required this.blue,
    required this.rules,
    this.timerEnabled = false,
    this.clockMode = ClockMode.countUp,
    this.timeLimitMinutes = 10,
  });

  factory MatchSetupPreset.fromMatchDetail(MatchDetail detail) {
    final match = detail.match;
    final sourceRules = match.ruleTemplateSnapshot;
    final regulationSeconds =
        detail.clock?.state.regulationSeconds ?? sourceRules.timeLimitSeconds;
    final timerEnabled = match.timerEnabled;
    final clockMode = timerEnabled
        ? detail.clock?.state.mode ??
              (regulationSeconds == null
                  ? ClockMode.countUp
                  : ClockMode.countdown)
        : ClockMode.countUp;
    final red = match.participants.firstWhere(
      (participant) => participant.side == TeamSide.red,
    );
    final blue = match.participants.firstWhere(
      (participant) => participant.side == TeamSide.blue,
    );
    return MatchSetupPreset(
      red: SetupParticipantPreset(
        nameSnapshot: red.nameSnapshot,
        playerId: red.playerId,
      ),
      blue: SetupParticipantPreset(
        nameSnapshot: blue.nameSnapshot,
        playerId: blue.playerId,
      ),
      rules: RuleTemplate(
        id: sourceRules.id,
        name: sourceRules.name,
        scoreButtons: List.unmodifiable(sourceRules.scoreButtons),
        targetScore: sourceRules.targetScore,
        timeLimitSeconds: sourceRules.timeLimitSeconds,
        winByTwo: sourceRules.winByTwo,
        foulLimit: sourceRules.foulLimit,
        possessionHintEnabled: sourceRules.possessionHintEnabled,
        possessionPolicy: sourceRules.possessionPolicy,
        customEventTypes: List.unmodifiable(sourceRules.customEventTypes),
      ),
      timerEnabled: timerEnabled,
      clockMode: clockMode,
      timeLimitMinutes: regulationSeconds == null
          ? 10
          : (regulationSeconds / 60).ceil(),
    );
  }

  final SetupParticipantPreset red;
  final SetupParticipantPreset blue;
  final RuleTemplate rules;
  final bool timerEnabled;
  final ClockMode clockMode;
  final int timeLimitMinutes;

  MatchSetupPreset swapped() => MatchSetupPreset(
    red: blue,
    blue: red,
    rules: rules,
    timerEnabled: timerEnabled,
    clockMode: clockMode,
    timeLimitMinutes: timeLimitMinutes,
  );
}

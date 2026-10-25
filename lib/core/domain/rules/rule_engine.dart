import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

enum RuleHintType {
  matchPoint,
  targetReached,
  winByTwoRequired,
  possessionChange,
}

class RuleHint {
  const RuleHint({
    required this.type,
    required this.message,
    this.messageKey,
    this.suggestedSide,
    this.isBlocking = false,
  });

  final RuleHintType type;
  final String message;

  /// Stable localization key used by the UI; [message] is the current
  /// locale's fallback text for callers that do not have a BuildContext.
  final String? messageKey;

  /// The side the configured possession policy actually suggests. A manual
  /// policy produces no possession hint and therefore leaves this null.
  final TeamSide? suggestedSide;
  final bool isBlocking;

  String localizedMessage(String locale) {
    final zh = locale.toLowerCase().startsWith('zh');
    return switch (messageKey) {
      'possessionChange' when suggestedSide != null =>
        zh
            ? '${suggestedSide == TeamSide.red ? '红方' : '蓝方'}球权建议'
            : '${suggestedSide == TeamSide.red ? 'Red' : 'Blue'} possession suggested',
      'possessionChange' => zh ? '球权建议' : 'Possession suggested',
      'targetReached' =>
        zh
            ? '已达到目标分数，请确认结束或继续'
            : 'Target score reached. Confirm finish or continue.',
      'winByTwoRequired' =>
        zh
            ? '已达到目标分数，但还需领先两分'
            : 'Target reached, but a two-point lead is required.',
      'matchPoint' => zh ? '赛点' : 'Match point',
      _ => message,
    };
  }
}

class RuleEngine {
  RuleEngine({this.locale = 'zh'});

  final String locale;

  List<RuleHint> evaluate({
    required RuleTemplate template,
    required ScoreState score,
    required TeamSide scoringSide,
    required int scoringPoints,
    String? requestedLocale,
  }) {
    final selectedLocale = requestedLocale ?? locale;
    final hints = <RuleHint>[];
    if (template.possessionHintEnabled &&
        template.possessionPolicy != PossessionPolicy.manual) {
      final suggestedSide =
          template.possessionPolicy == PossessionPolicy.switchAfterMade
          ? (scoringSide == TeamSide.red ? TeamSide.blue : TeamSide.red)
          : scoringSide;
      hints.add(
        RuleHint(
          type: RuleHintType.possessionChange,
          message: selectedLocale.toLowerCase().startsWith('zh')
              ? '${suggestedSide == TeamSide.red ? '红方' : '蓝方'}球权建议'
              : '${suggestedSide == TeamSide.red ? 'Red' : 'Blue'} possession suggested',
          messageKey: 'possessionChange',
          suggestedSide: suggestedSide,
        ),
      );
    }
    final targetScore = template.targetScore;
    if (targetScore == null) {
      return hints;
    }

    final newRed =
        score.redScore + (scoringSide == TeamSide.red ? scoringPoints : 0);
    final newBlue =
        score.blueScore + (scoringSide == TeamSide.blue ? scoringPoints : 0);
    final sideScore = scoringSide == TeamSide.red ? newRed : newBlue;
    final opponentScore = scoringSide == TeamSide.red ? newBlue : newRed;
    if (sideScore >= targetScore) {
      if (template.winByTwo && sideScore - opponentScore < 2) {
        return [
          ...hints,
          RuleHint(
            type: RuleHintType.winByTwoRequired,
            message: selectedLocale.toLowerCase().startsWith('zh')
                ? '还需领先两分'
                : 'Win by two required',
            messageKey: 'winByTwoRequired',
          ),
        ];
      }

      return [
        ...hints,
        RuleHint(
          type: RuleHintType.targetReached,
          message: selectedLocale.toLowerCase().startsWith('zh')
              ? '已达到目标分数'
              : 'Target score reached',
          messageKey: 'targetReached',
        ),
      ];
    }

    if (sideScore == targetScore - 1) {
      hints.add(
        RuleHint(
          type: RuleHintType.matchPoint,
          message: selectedLocale.toLowerCase().startsWith('zh')
              ? '赛点'
              : 'Match point',
          messageKey: 'matchPoint',
        ),
      );
    }

    return hints;
  }
}

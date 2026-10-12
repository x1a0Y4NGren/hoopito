import 'package:hoopito/core/domain/domain_enums.dart';

export 'package:hoopito/core/domain/domain_enums.dart' show PossessionPolicy;

class RuleTemplate {
  const RuleTemplate({
    required this.id,
    required this.name,
    required this.scoreButtons,
    this.targetScore,
    this.timeLimitSeconds,
    this.winByTwo = false,
    this.foulLimit,
    this.possessionHintEnabled = false,
    this.possessionPolicy = PossessionPolicy.manual,
    this.customEventTypes = const [],
  });

  final String id;
  final String name;
  final List<int> scoreButtons;
  final int? targetScore;
  final int? timeLimitSeconds;
  final bool winByTwo;
  final int? foulLimit;
  final bool possessionHintEnabled;
  final PossessionPolicy possessionPolicy;
  final List<String> customEventTypes;

  @override
  bool operator ==(Object other) {
    return other is RuleTemplate &&
        other.id == id &&
        other.name == name &&
        _listsEqual(other.scoreButtons, scoreButtons) &&
        other.targetScore == targetScore &&
        other.timeLimitSeconds == timeLimitSeconds &&
        other.winByTwo == winByTwo &&
        other.foulLimit == foulLimit &&
        other.possessionHintEnabled == possessionHintEnabled &&
        other.possessionPolicy == possessionPolicy &&
        _listsEqual(other.customEventTypes, customEventTypes);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(scoreButtons),
    targetScore,
    timeLimitSeconds,
    winByTwo,
    foulLimit,
    possessionHintEnabled,
    possessionPolicy,
    Object.hashAll(customEventTypes),
  );

  static bool _listsEqual<T>(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

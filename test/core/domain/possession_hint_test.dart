import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

void main() {
  test('configured scoring event creates a non-blocking possession hint', () {
    const template = RuleTemplate(
      id: 'possession',
      name: '球权轮换',
      scoreButtons: [1, 2, 3],
      possessionHintEnabled: true,
      possessionPolicy: PossessionPolicy.switchAfterMade,
    );

    final hints = RuleEngine().evaluate(
      template: template,
      score: const ScoreState.zero(),
      scoringSide: TeamSide.red,
      scoringPoints: 2,
    );

    expect(
      hints.map((hint) => hint.type),
      contains(RuleHintType.possessionChange),
    );
    expect(hints.single.suggestedSide, TeamSide.blue);
    expect(hints.every((hint) => !hint.isBlocking), isTrue);
  });
}

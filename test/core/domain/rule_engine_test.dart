import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

void main() {
  test('projected target score creates a non-blocking target reached hint', () {
    const template = RuleTemplate(
      id: 'standard-11',
      name: '11 points',
      scoreButtons: [1, 2, 3],
      targetScore: 11,
      winByTwo: true,
    );

    final hints = RuleEngine().evaluate(
      template: template,
      score: const ScoreState(redScore: 10, blueScore: 8),
      scoringSide: TeamSide.red,
      scoringPoints: 1,
    );

    expect(hints.map((hint) => hint.type), [RuleHintType.targetReached]);
    expect(hints.every((hint) => hint.isBlocking == false), isTrue);
  });

  test('projected one short of target creates match point hint only', () {
    const template = RuleTemplate(
      id: 'standard-11',
      name: '11 points',
      scoreButtons: [1, 2, 3],
      targetScore: 11,
      winByTwo: true,
    );

    final hints = RuleEngine().evaluate(
      template: template,
      score: const ScoreState(redScore: 9, blueScore: 8),
      scoringSide: TeamSide.red,
      scoringPoints: 1,
    );

    expect(hints.map((hint) => hint.type), [RuleHintType.matchPoint]);
  });

  test('projected target score prioritizes win-by-two over match point', () {
    const template = RuleTemplate(
      id: 'standard-11',
      name: '11 points',
      scoreButtons: [1, 2, 3],
      targetScore: 11,
      winByTwo: true,
    );

    final hints = RuleEngine().evaluate(
      template: template,
      score: const ScoreState(redScore: 10, blueScore: 10),
      scoringSide: TeamSide.red,
      scoringPoints: 1,
    );

    expect(hints.map((hint) => hint.type), [RuleHintType.winByTwoRequired]);
  });
}

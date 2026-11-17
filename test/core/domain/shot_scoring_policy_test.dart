import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/rules/shot_scoring_policy.dart';
import 'package:hoopito/core/domain/value_objects/court_geometry.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';

void main() {
  CourtPoint meters(double x, double y) => CourtPoint(x: x / 15, y: y / 14);

  test(
    'arc classification includes corners and gives its boundary to inside',
    () {
      for (final entry in <(double, double, bool)>[
        (7.5, 8.325, false),
        (7.5, 8.326, true),
        (7.5, 8.324, false),
        (.9, 1, false),
        (.899, 1, true),
        (14.1, 1, false),
        (14.101, 1, true),
        (7.5, 0, false),
        (7.5, 14, true),
        (1.5, 4.5, false),
        (1.5, 5, true),
      ]) {
        expect(
          CourtGeometry.isOutsideArc(meters(entry.$1, entry.$2)),
          entry.$3,
          reason: '${entry.$1}, ${entry.$2}',
        );
      }
    },
  );

  test(
    'standard convention separates free throws from located field goals',
    () {
      final policy = ShotScoringPolicy(
        const RuleTemplate(
          id: 'standard',
          name: 'Standard',
          scoreButtons: [1, 2, 3],
          scoringConvention: ScoringConvention.standard,
        ),
      );
      final inside = meters(7.5, 5.8);
      final outside = meters(7.5, 10);
      expect(policy.allowedScorePoints(inside), [2]);
      expect(policy.allowedScorePoints(inside, freeThrowEligible: true), [
        1,
        2,
      ]);
      expect(policy.allowedScorePoints(outside, freeThrowEligible: true), [3]);
      expect(policy.allowsFieldGoal(1, null), isFalse);
      expect(policy.allowsFieldGoal(2, outside), isFalse);
      expect(policy.allowsFieldGoal(3, outside), isTrue);
      expect(policy.allowsFieldGoal(0, inside), isTrue);
      expect(policy.allowsFieldGoal(0, outside), isTrue);
      expect(policy.regionForPoints(1), CourtRegion.freeThrowLine);
    },
  );

  test(
    'one per basket permits +1 throughout the court without a +2 action',
    () {
      final policy = ShotScoringPolicy(
        const RuleTemplate(
          id: 'baskets',
          name: 'Baskets',
          scoreButtons: [1, 2, 3],
          scoringConvention: ScoringConvention.onePerBasket,
        ),
      );
      expect(policy.scoreButtons, [1]);
      expect(policy.allowedScorePoints(meters(.1, 1)), [1]);
      expect(policy.allowedScorePoints(meters(7.5, 5)), [1]);
      expect(policy.allowsFieldGoal(2, null), isFalse);
      expect(policy.regionForPoints(1), CourtRegion.all);
    },
  );

  test('three point counts as two restricts +1 inside and +2 outside', () {
    final policy = ShotScoringPolicy(
      const RuleTemplate(
        id: 'baskets-two',
        name: 'Baskets',
        scoreButtons: [1, 2, 3],
        scoringConvention: ScoringConvention.oneAndTwo,
      ),
    );
    expect(policy.scoreButtons, [1, 2]);
    expect(policy.allowedScorePoints(meters(7.5, 5)), [1]);
    expect(policy.allowedScorePoints(meters(.1, 1)), [2]);
    expect(policy.allowsFieldGoal(1, meters(.1, 1)), isFalse);
    expect(policy.regionForPoints(2), CourtRegion.outsideArc);
  });

  test(
    'legacy custom values retain their meaning without inferred regions',
    () {
      final policy = ShotScoringPolicy(
        const RuleTemplate(
          id: 'custom',
          name: 'Custom',
          scoreButtons: [1, 3, 5],
        ),
      );
      expect(policy.scoreButtons, [1, 3, 5]);
      expect(policy.allowedScorePoints(meters(.1, 1)), [1, 3, 5]);
      expect(policy.allowsFieldGoal(5, meters(7.5, 5)), isTrue);
      expect(policy.allowsFieldGoal(-1, null), isFalse);
    },
  );
}

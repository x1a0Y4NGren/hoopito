import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_geometry.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';

/// The declared convention, rather than a button's numeric value, determines
/// whether an action is a field goal and where its location may be recorded.
class ShotScoringPolicy {
  const ShotScoringPolicy(this.rules);

  final RuleTemplate rules;

  bool get isStandard => rules.scoringConvention == ScoringConvention.standard;

  List<int> get scoreButtons => switch (rules.scoringConvention) {
    ScoringConvention.standard => const [1, 2, 3],
    ScoringConvention.onePerBasket => const [1],
    ScoringConvention.oneAndTwo => const [1, 2],
    null => rules.scoreButtons,
  };

  CourtRegion regionForPoints(int points) {
    if (points == 0) return CourtRegion.all;
    return switch (rules.scoringConvention) {
      ScoringConvention.standard => switch (points) {
        1 => CourtRegion.freeThrowLine,
        2 => CourtRegion.insideArc,
        3 => CourtRegion.outsideArc,
        _ => CourtRegion.all,
      },
      ScoringConvention.oneAndTwo => switch (points) {
        1 => CourtRegion.insideArc,
        2 => CourtRegion.outsideArc,
        _ => CourtRegion.all,
      },
      _ => CourtRegion.all,
    };
  }

  bool allowsFieldGoal(int points, CourtPoint? point) {
    if (points < 0) return false;
    if (points == 0) {
      return point == null || CourtGeometry.contains(CourtRegion.all, point);
    }
    // Existing unconstrained rules keep their historical scoring semantics.
    if (rules.scoringConvention == null) {
      return point == null || CourtGeometry.contains(CourtRegion.all, point);
    }
    if (!scoreButtons.contains(points) || (isStandard && points == 1)) {
      return false;
    }
    return point == null ||
        CourtGeometry.contains(regionForPoints(points), point);
  }

  List<int> allowedScorePoints(
    CourtPoint point, {
    bool freeThrowEligible = false,
  }) {
    return scoreButtons
        .where((points) {
          if (isStandard && points == 1) {
            return freeThrowEligible &&
                CourtGeometry.contains(CourtRegion.insideArc, point);
          }
          return allowsFieldGoal(points, point);
        })
        .toList(growable: false);
  }
}

import 'dart:math' as math;

import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/possession_segment.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

class MatchAnalyticsCalculator {
  MatchAnalytics calculate(
    List<MatchEvent> events, {
    int? targetScore,
    bool winByTwo = false,
    TrackingCoverage? trackingCoverage,
    List<ShotLocation> shotLocations = const [],
    List<PossessionSegment>? possessionSegments,
    int? possessionCount,
  }) {
    final orderedEvents =
        events
            .asMap()
            .entries
            .where((entry) => !entry.value.isDeleted)
            .map((entry) => _IndexedEvent(entry.key, entry.value))
            .toList()
          ..sort((first, second) {
            final timeComparison = first.event.occurredAt.compareTo(
              second.event.occurredAt,
            );
            return timeComparison == 0
                ? first.index.compareTo(second.index)
                : timeComparison;
          });

    var redScore = 0;
    var blueScore = 0;
    var madeShotCount = 0;
    var missedShotCount = 0;
    var fieldGoalMadeCount = 0;
    var fieldGoalAttemptCount = 0;
    var freeThrowMadeCount = 0;
    var freeThrowAttemptCount = 0;
    var redFoulCount = 0;
    var blueFoulCount = 0;
    var largestLeadPoints = 0;
    TeamSide? largestLeadSide;
    TeamSide? previousLeader;
    var leadChanges = 0;
    TeamSide? scoringRunSide;
    var scoringRunLength = 0;
    var scoringRunPoints = 0;
    DateTime? scoringRunStartedAt;
    DateTime? scoringRunEndedAt;

    final scoringFlow = <ScoringFlowEntry>[];
    final keyPossessions = <KeyPossession>[];
    final scoringRuns = <ScoringRun>[];
    final scoringRunEventIds = <String>[];
    final locatableShotEventIds = <String>{};

    void closeRun() {
      if (scoringRunSide != null && scoringRunLength >= 2) {
        scoringRuns.add(
          ScoringRun(
            side: scoringRunSide,
            eventIds: scoringRunEventIds,
            points: scoringRunPoints,
            startedAt: scoringRunStartedAt!,
            endedAt: scoringRunEndedAt!,
          ),
        );
      }
      scoringRunEventIds.clear();
      scoringRunLength = 0;
      scoringRunPoints = 0;
      scoringRunStartedAt = null;
      scoringRunEndedAt = null;
    }

    for (final indexedEvent in orderedEvents) {
      final event = indexedEvent.event;
      if (event.type == MatchEventType.foul) {
        if (event.side == TeamSide.red) {
          redFoulCount++;
        } else if (event.side == TeamSide.blue) {
          blueFoulCount++;
        }
        continue;
      }

      final shot = _classifyShot(event);
      if (shot == null || event.side == null) continue;
      if (shot.isFieldGoal) locatableShotEventIds.add(event.id);
      if (shot.isFreeThrow) {
        freeThrowAttemptCount++;
        if (shot.isMade) freeThrowMadeCount++;
      } else if (shot.isFieldGoal) {
        fieldGoalAttemptCount++;
        if (shot.isMade) fieldGoalMadeCount++;
      }

      if (!shot.isMade) {
        missedShotCount++;
        continue;
      }

      madeShotCount++;
      final side = event.side!;
      if (side == TeamSide.red) {
        redScore += event.points;
      } else {
        blueScore += event.points;
      }

      scoringFlow.add(
        ScoringFlowEntry(
          eventId: event.id,
          side: side,
          points: event.points,
          redScore: redScore,
          blueScore: blueScore,
          occurredAt: event.occurredAt,
        ),
      );

      final leader = _leader(redScore, blueScore);
      final leadChanged =
          previousLeader != null && leader != null && previousLeader != leader;
      if (leadChanged) leadChanges++;
      if (leader != null) previousLeader = leader;

      final leadPoints = (redScore - blueScore).abs();
      if (leadPoints > largestLeadPoints) {
        largestLeadPoints = leadPoints;
        largestLeadSide = leader;
      }

      if (redScore == blueScore && redScore != 0) {
        keyPossessions.add(
          _keyPossession(
            type: KeyPossessionType.tie,
            event: event,
            redScore: redScore,
            blueScore: blueScore,
          ),
        );
      }
      if (leadChanged) {
        keyPossessions.add(
          _keyPossession(
            type: KeyPossessionType.overtake,
            event: event,
            redScore: redScore,
            blueScore: blueScore,
          ),
        );
      }

      final sideScore = side == TeamSide.red ? redScore : blueScore;
      final opponentScore = side == TeamSide.red ? blueScore : redScore;
      if (_isMatchPoint(
        sideScore: sideScore,
        opponentScore: opponentScore,
        targetScore: targetScore,
        winByTwo: winByTwo,
      )) {
        keyPossessions.add(
          _keyPossession(
            type: KeyPossessionType.matchPoint,
            event: event,
            redScore: redScore,
            blueScore: blueScore,
          ),
        );
      }

      if (scoringRunSide != side) {
        closeRun();
        scoringRunSide = side;
        scoringRunStartedAt = event.occurredAt;
      }
      scoringRunLength++;
      scoringRunPoints += event.points;
      scoringRunEventIds.add(event.id);
      scoringRunEndedAt = event.occurredAt;
      if (scoringRunLength == 3) {
        keyPossessions.add(
          _keyPossession(
            type: KeyPossessionType.scoringRun,
            event: event,
            redScore: redScore,
            blueScore: blueScore,
          ),
        );
      }
    }
    closeRun();

    final attempts = madeShotCount + missedShotCount;
    final effectiveCoverage = trackingCoverage ?? TrackingCoverage.scoresOnly;
    final isReliable =
        fieldGoalAttemptCount > 0 &&
        effectiveCoverage.index >= TrackingCoverage.shotAttempts.index;
    final recordedPercentage = isReliable
        ? fieldGoalMadeCount / fieldGoalAttemptCount
        : null;

    final locationsByEvent = <String, ShotLocation>{};
    for (final location in shotLocations) {
      if (!location.isConfirmed ||
          !locatableShotEventIds.contains(location.eventId)) {
        continue;
      }
      locationsByEvent[location.eventId] = location;
    }
    final zoneDistribution = <ShotZone, int>{};
    for (final location in locationsByEvent.values) {
      final zone = classifyShotZone(location.point);
      zoneDistribution[zone] = (zoneDistribution[zone] ?? 0) + 1;
    }

    return MatchAnalytics(
      scoringFlow: scoringFlow,
      largestLeadSide: largestLeadSide,
      largestLeadPoints: largestLeadPoints,
      leadChanges: leadChanges,
      madeShotCount: madeShotCount,
      missedShotCount: missedShotCount,
      shootingPercentage: recordedPercentage ?? 0,
      keyPossessions: keyPossessions,
      recordedShootingPercentage: recordedPercentage,
      shootingPercentageIsTrustworthy: isReliable,
      trackingCoverage: effectiveCoverage,
      fieldGoalMadeCount: fieldGoalMadeCount,
      fieldGoalAttemptCount: fieldGoalAttemptCount,
      freeThrowMadeCount: freeThrowMadeCount,
      freeThrowAttemptCount: freeThrowAttemptCount,
      redFoulCount: redFoulCount,
      blueFoulCount: blueFoulCount,
      possessionCount: possessionCount ?? possessionSegments?.length,
      shotAttemptCount: attempts,
      confirmedLocationCount: locationsByEvent.length,
      locationCoverage: fieldGoalAttemptCount == 0
          ? 0
          : math.min(1, locationsByEvent.length / fieldGoalAttemptCount),
      zoneDistribution: zoneDistribution,
      scoringRuns: scoringRuns,
    );
  }

  KeyPossession _keyPossession({
    required KeyPossessionType type,
    required MatchEvent event,
    required int redScore,
    required int blueScore,
  }) {
    return KeyPossession(
      type: type,
      eventId: event.id,
      side: event.side!,
      redScore: redScore,
      blueScore: blueScore,
      occurredAt: event.occurredAt,
    );
  }

  TeamSide? _leader(int redScore, int blueScore) {
    if (redScore == blueScore) return null;
    return redScore > blueScore ? TeamSide.red : TeamSide.blue;
  }

  bool _isMatchPoint({
    required int sideScore,
    required int opponentScore,
    required int? targetScore,
    required bool winByTwo,
  }) {
    if (targetScore == null) return false;
    if (!winByTwo) return sideScore == targetScore - 1;
    if (sideScore <= opponentScore) return false;
    if (sideScore < targetScore) return sideScore == targetScore - 1;
    return sideScore - opponentScore == 1;
  }

  _ShotClassification? _classifyShot(MatchEvent event) {
    switch (event.type) {
      case MatchEventType.score:
        return const _ShotClassification(
          isMade: true,
          isFreeThrow: false,
          isFieldGoal: true,
        );
      case MatchEventType.fieldGoal:
        return _ShotClassification(
          isMade: event.outcome == ShotOutcome.made,
          isFreeThrow: false,
          isFieldGoal: true,
        );
      case MatchEventType.freeThrow:
        return _ShotClassification(
          isMade: event.outcome == ShotOutcome.made,
          isFreeThrow: true,
          isFieldGoal: false,
        );
      case MatchEventType.miss:
        return const _ShotClassification(
          isMade: false,
          isFreeThrow: false,
          isFieldGoal: true,
        );
      default:
        return null;
    }
  }
}

/// Maps a normalized court point into a stable, presentation-independent zone.
ShotZone classifyShotZone(CourtPoint point) {
  final distanceSquared =
      math.pow(point.x - 0.5, 2) + math.pow(point.y - 0.08, 2);
  if (distanceSquared <= 0.15 * 0.15) return ShotZone.restrictedArea;
  if (distanceSquared <= 0.27 * 0.27) return ShotZone.paint;
  if (distanceSquared <= 0.42 * 0.42) return ShotZone.midRange;
  if (point.x <= 0.2 || point.x >= 0.8) return ShotZone.cornerThree;
  if (point.x <= 0.35 || point.x >= 0.65) return ShotZone.wingThree;
  return ShotZone.topThree;
}

class _ShotClassification {
  const _ShotClassification({
    required this.isMade,
    required this.isFreeThrow,
    required this.isFieldGoal,
  });

  final bool isMade;
  final bool isFreeThrow;
  final bool isFieldGoal;
}

class _IndexedEvent {
  const _IndexedEvent(this.index, this.event);

  final int index;
  final MatchEvent event;
}

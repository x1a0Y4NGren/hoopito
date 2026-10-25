import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/analytics/player_analytics_snapshot.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';

/// Produces stable derived values from the canonical match rows.
class PlayerAnalyticsSnapshotCalculator {
  static const version = 1;

  PlayerAnalyticsSnapshot calculate(
    PlayerAnalyticsSnapshotCalculationRequest request,
  ) {
    var playerScore = 0;
    var opponentScore = 0;
    var fieldGoalMade = 0;
    var fieldGoalAttempts = 0;
    var freeThrowMade = 0;
    var freeThrowAttempts = 0;
    var locatableLocationCount = 0;
    var confirmedLocationCount = 0;
    final zones = <ShotZone, int>{};

    final events = [...request.events]
      ..sort((left, right) {
        final byTime = left.occurredAtUtc.compareTo(right.occurredAtUtc);
        return byTime == 0 ? left.id.compareTo(right.id) : byTime;
      });
    for (final event in events) {
      if (event.isDeleted || event.side == null) continue;
      final isPlayerEvent = event.side == request.playerSide;
      final isMade =
          event.type == EventKind.score ||
          ((event.type == EventKind.fieldGoal ||
                  event.type == EventKind.freeThrow) &&
              event.outcome == ShotOutcome.made);
      final isFieldGoal =
          event.type == EventKind.score ||
          event.type == EventKind.fieldGoal ||
          event.type == EventKind.miss;
      if (isMade) {
        if (isPlayerEvent) {
          playerScore += event.points;
        } else {
          opponentScore += event.points;
        }
      }
      if (!isPlayerEvent) continue;
      if (isFieldGoal) {
        fieldGoalAttempts++;
        if (isMade) fieldGoalMade++;
        final location = event.location;
        if (location != null) {
          locatableLocationCount++;
          if (location.isConfirmed) {
            confirmedLocationCount++;
            final zone = classifyShotZone(
              CourtPoint(x: location.x, y: location.y),
            );
            zones[zone] = (zones[zone] ?? 0) + 1;
          }
        }
      }
      if (event.type == EventKind.freeThrow) {
        freeThrowAttempts++;
        if (isMade) freeThrowMade++;
      }
    }

    return PlayerAnalyticsSnapshot(
      matchId: request.matchId,
      playerId: request.playerId,
      opponentPlayerId: request.opponentPlayerId,
      playedAtUtc: request.playedAtUtc,
      playerScore: playerScore,
      opponentScore: opponentScore,
      fieldGoalMade: fieldGoalMade,
      fieldGoalAttempts: fieldGoalAttempts,
      freeThrowMade: freeThrowMade,
      freeThrowAttempts: freeThrowAttempts,
      trackingCoverage: request.trackingCoverage,
      confirmedLocationCount: confirmedLocationCount,
      locatableLocationCount: locatableLocationCount,
      zoneDistributionJson: jsonEncode(zoneDistributionFromJson(zones)),
      calculatorVersion: version,
      sourceSha256: _sourceSha256(request, events),
    );
  }

  String _sourceSha256(
    PlayerAnalyticsSnapshotCalculationRequest request,
    List<PlayerAnalyticsSnapshotEventInput> events,
  ) {
    final source = <String, Object?>{
      'matchId': request.matchId,
      'playerId': request.playerId,
      'opponentPlayerId': request.opponentPlayerId,
      'playerSide': request.playerSide,
      'playedAtUtc': request.playedAtUtc.toUtc().toIso8601String(),
      'trackingCoverage': request.trackingCoverage.name,
      'events': events
          .map(
            (event) => <String, Object?>{
              'id': event.id,
              'side': event.side,
              'type': event.type.name,
              'points': event.points,
              'outcome': event.outcome?.name,
              'occurredAtUtc': event.occurredAtUtc,
              'isDeleted': event.isDeleted,
              'location': event.location == null
                  ? null
                  : <String, Object?>{
                      'id': event.location!.id,
                      'x': event.location!.x,
                      'y': event.location!.y,
                      'isConfirmed': event.location!.isConfirmed,
                    },
            },
          )
          .toList(growable: false),
    };
    return sha256.convert(utf8.encode(jsonEncode(source))).toString();
  }
}

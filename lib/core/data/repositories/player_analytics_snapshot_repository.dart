import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/analytics/player_analytics_snapshot.dart';
import 'package:hoopito/core/domain/analytics/player_analytics_snapshot_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

/// Rebuilds derived snapshots from one bounded canonical match query.
class PlayerAnalyticsSnapshotRepository {
  PlayerAnalyticsSnapshotRepository(
    this._database, {
    PlayerAnalyticsSnapshotCalculator? calculator,
  }) : _calculator = calculator ?? PlayerAnalyticsSnapshotCalculator();

  final AppDatabase _database;
  final PlayerAnalyticsSnapshotCalculator _calculator;

  Future<int> ensureSnapshots({String? playerId}) {
    return _ensureSnapshots(playerId: playerId);
  }

  /// Rebuilds only the imported or otherwise explicitly affected matches.
  ///
  /// A JSON-backed CTE keeps the match filter to one bind variable even for a
  /// large backup, avoiding SQLite's positional-parameter limit without
  /// falling back to one query per match.
  Future<int> ensureSnapshotsForMatches(Iterable<String> matchIds) {
    final normalized = matchIds.toSet().toList()..sort();
    if (normalized.isEmpty) return Future.value(0);
    return _ensureSnapshots(matchIds: normalized);
  }

  Future<int> _ensureSnapshots({String? playerId, List<String>? matchIds}) {
    return _database.transaction(() async {
      final rows = await _canonicalRows(playerId: playerId, matchIds: matchIds);
      final requests = _requestsFromRows(rows);
      if (requests.isEmpty) return 0;
      final snapshots = requests
          .map(_calculator.calculate)
          .toList(growable: false);
      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _database.playerAnalyticsSnapshots,
          snapshots.map(_toRow).toList(growable: false),
        );
      });
      return snapshots.length;
    });
  }

  Future<List<QueryRow>> _canonicalRows({
    String? playerId,
    List<String>? matchIds,
  }) {
    final variables = <Variable<Object>>[];
    final playerPredicate = playerId == null
        ? ''
        : 'AND subject.player_profile_id = ?';
    if (playerId != null) variables.add(Variable.withString(playerId));
    final matchPredicate = matchIds == null
        ? ''
        : 'AND m.id IN (SELECT value FROM json_each(?))';
    if (matchIds != null) {
      variables.add(Variable.withString(jsonEncode(matchIds)));
    }
    return _database
        .customSelect(
          '''
            WITH eligible AS (
              SELECT
                m.id AS match_id,
                subject.player_profile_id AS player_id,
                opponent.player_profile_id AS opponent_player_id,
                subject.side AS player_side,
                COALESCE(m.started_at, m.created_at) AS played_at_utc,
                m.tracking_coverage AS tracking_coverage
              FROM matches m
              JOIN match_participants subject ON subject.match_id = m.id
              LEFT JOIN match_participants opponent
                ON opponent.match_id = m.id AND opponent.side != subject.side
              LEFT JOIN player_analytics_snapshots existing_snapshot
                ON existing_snapshot.match_id = m.id
                AND existing_snapshot.player_id = subject.player_profile_id
                AND existing_snapshot.calculator_version =
                  ${PlayerAnalyticsSnapshotCalculator.version}
              WHERE m.lifecycle IN ('finished', 'archived')
                AND subject.player_profile_id IS NOT NULL
                AND existing_snapshot.match_id IS NULL
                $playerPredicate
                $matchPredicate
            )
            SELECT
              eligible.match_id,
              eligible.player_id,
              eligible.opponent_player_id,
              eligible.player_side,
              eligible.played_at_utc,
              eligible.tracking_coverage,
              event.id AS event_id,
              event.side AS event_side,
              event.type AS event_type,
              event.points AS event_points,
              event.outcome AS event_outcome,
              event.occurred_at AS event_occurred_at,
              event.is_deleted AS event_is_deleted,
              location.id AS location_id,
              location.x AS location_x,
              location.y AS location_y,
              location.is_confirmed AS location_is_confirmed
            FROM eligible
            LEFT JOIN match_events event ON event.match_id = eligible.match_id
            LEFT JOIN shot_locations location ON location.event_id = event.id
            ORDER BY
              eligible.played_at_utc ASC,
              eligible.match_id ASC,
              eligible.player_id ASC,
              event.occurred_at ASC,
              event.id ASC
          ''',
          variables: variables,
          readsFrom: {
            _database.matches,
            _database.matchParticipants,
            _database.matchEvents,
            _database.shotLocations,
            _database.playerAnalyticsSnapshots,
          },
        )
        .get();
  }

  List<PlayerAnalyticsSnapshotCalculationRequest> _requestsFromRows(
    List<QueryRow> rows,
  ) {
    final requests = <String, _RequestAccumulator>{};
    for (final row in rows) {
      final matchId = row.read<String>('match_id');
      final playerId = row.read<String>('player_id');
      final accumulator = requests.putIfAbsent(
        '$matchId\u0000$playerId',
        () => _RequestAccumulator(
          matchId: matchId,
          playerId: playerId,
          opponentPlayerId: row.read<String?>('opponent_player_id'),
          playerSide: row.read<String>('player_side'),
          playedAtUtc: row.read<DateTime>('played_at_utc').toUtc(),
          trackingCoverage: TrackingCoverage.values.byName(
            row.read<String>('tracking_coverage'),
          ),
        ),
      );
      final eventId = row.read<String?>('event_id');
      if (eventId == null) continue;
      final locationId = row.read<String?>('location_id');
      accumulator.events.add(
        PlayerAnalyticsSnapshotEventInput(
          id: eventId,
          side: row.read<String?>('event_side'),
          type: EventKind.values.byName(row.read<String>('event_type')),
          points: row.read<int>('event_points'),
          outcome: _outcome(row.read<String?>('event_outcome')),
          occurredAtUtc: row
              .read<DateTime>('event_occurred_at')
              .toUtc()
              .toIso8601String(),
          isDeleted: row.read<bool>('event_is_deleted'),
          location: locationId == null
              ? null
              : PlayerAnalyticsSnapshotLocationInput(
                  id: locationId,
                  x: row.read<double>('location_x'),
                  y: row.read<double>('location_y'),
                  isConfirmed: row.read<bool>('location_is_confirmed'),
                ),
        ),
      );
    }
    return requests.values
        .map(
          (request) => PlayerAnalyticsSnapshotCalculationRequest(
            matchId: request.matchId,
            playerId: request.playerId,
            opponentPlayerId: request.opponentPlayerId,
            playerSide: request.playerSide,
            playedAtUtc: request.playedAtUtc,
            trackingCoverage: request.trackingCoverage,
            events: List.unmodifiable(request.events),
          ),
        )
        .toList(growable: false);
  }

  ShotOutcome? _outcome(String? value) =>
      value == null ? null : ShotOutcome.values.byName(value);

  PlayerAnalyticsSnapshotRow _toRow(PlayerAnalyticsSnapshot snapshot) =>
      PlayerAnalyticsSnapshotRow(
        matchId: snapshot.matchId,
        playerId: snapshot.playerId,
        opponentPlayerId: snapshot.opponentPlayerId,
        playedAtUtc: snapshot.playedAtUtc,
        playerScore: snapshot.playerScore,
        opponentScore: snapshot.opponentScore,
        fieldGoalMade: snapshot.fieldGoalMade,
        fieldGoalAttempts: snapshot.fieldGoalAttempts,
        freeThrowMade: snapshot.freeThrowMade,
        freeThrowAttempts: snapshot.freeThrowAttempts,
        trackingCoverage: snapshot.trackingCoverage.name,
        confirmedLocationCount: snapshot.confirmedLocationCount,
        locatableLocationCount: snapshot.locatableLocationCount,
        zoneDistributionJson: snapshot.zoneDistributionJson,
        calculatorVersion: snapshot.calculatorVersion,
        sourceSha256: snapshot.sourceSha256,
      );
}

class _RequestAccumulator {
  _RequestAccumulator({
    required this.matchId,
    required this.playerId,
    required this.opponentPlayerId,
    required this.playerSide,
    required this.playedAtUtc,
    required this.trackingCoverage,
  });

  final String matchId;
  final String playerId;
  final String? opponentPlayerId;
  final String playerSide;
  final DateTime playedAtUtc;
  final TrackingCoverage trackingCoverage;
  final events = <PlayerAnalyticsSnapshotEventInput>[];
}

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_analytics_snapshot_repository.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

class PlayerComparisonRepository {
  PlayerComparisonRepository(
    this._database, {
    PlayerAnalyticsSnapshotRepository? snapshotRepository,
    PlayerComparisonReportBuilder? reportBuilder,
  }) : _snapshotRepository =
           snapshotRepository ?? PlayerAnalyticsSnapshotRepository(_database),
       _reportBuilder = reportBuilder ?? PlayerComparisonReportBuilder();

  final AppDatabase _database;
  final PlayerAnalyticsSnapshotRepository _snapshotRepository;
  final PlayerComparisonReportBuilder _reportBuilder;

  Future<int> ensureSnapshots({String? playerId}) =>
      _snapshotRepository.ensureSnapshots(playerId: playerId);

  Future<List<PlayerComparisonMatch>> listEligibleMatches(
    String playerId,
  ) async {
    _validatePlayerId(playerId);
    return _database.transaction(() async {
      await ensureSnapshots(playerId: playerId);
      final rows = await _database
          .customSelect(
            '''
        SELECT
          snapshot.match_id,
          snapshot.played_at_utc,
          snapshot.opponent_player_id,
          snapshot.player_score,
          snapshot.opponent_score,
          opponent.name_snapshot AS opponent_name_snapshot
        FROM player_analytics_snapshots snapshot
        JOIN match_participants subject
          ON subject.match_id = snapshot.match_id
          AND subject.player_profile_id = snapshot.player_id
        JOIN match_participants opponent
          ON opponent.match_id = snapshot.match_id
          AND opponent.side != subject.side
        WHERE snapshot.player_id = ?
        ORDER BY snapshot.played_at_utc DESC, snapshot.match_id DESC
      ''',
            variables: [Variable.withString(playerId)],
            readsFrom: {
              _database.playerAnalyticsSnapshots,
              _database.matchParticipants,
            },
          )
          .get();
      return [
        for (final row in rows)
          PlayerComparisonMatch(
            matchId: row.read<String>('match_id'),
            playedAtUtc: row.read<DateTime>('played_at_utc'),
            opponentPlayerId: row.read<String?>('opponent_player_id'),
            opponentNameSnapshot: row.read<String>('opponent_name_snapshot'),
            playerScore: row.read<int>('player_score'),
            opponentScore: row.read<int>('opponent_score'),
          ),
      ];
    });
  }

  Future<PlayerComparisonReport> compare(
    PlayerComparisonRequest request,
  ) async {
    _validatePlayerId(request.playerId);
    return _database.transaction(() async {
      await ensureSnapshots(playerId: request.playerId);
      final query = _database.select(_database.playerAnalyticsSnapshots)
        ..where((row) => row.playerId.equals(request.playerId))
        ..orderBy([
          (row) => OrderingTerm.asc(row.playedAtUtc),
          (row) => OrderingTerm.asc(row.matchId),
        ]);
      final snapshots = await query.get();
      return switch (request) {
        final MatchPairComparisonRequest pair => _comparePair(pair, snapshots),
        final AdjacentWindowComparisonRequest window => _compareWindows(
          window,
          snapshots,
        ),
      };
    });
  }

  PlayerComparisonReport _comparePair(
    MatchPairComparisonRequest request,
    List<PlayerAnalyticsSnapshotRow> snapshots,
  ) {
    if (request.baselineMatchId == request.currentMatchId) {
      throw const PlayerComparisonException(
        'Match comparison requires two different matches.',
      );
    }
    final byId = {for (final row in snapshots) row.matchId: row};
    final baseline = byId[request.baselineMatchId];
    final current = byId[request.currentMatchId];
    if (baseline == null || current == null) {
      throw const PlayerComparisonException(
        'Both matches must be eligible for the requested player profile.',
      );
    }
    return _reportBuilder.build(
      baseline: _sample(
        [baseline],
        startUtc: baseline.playedAtUtc,
        endUtc: baseline.playedAtUtc,
      ),
      current: _sample(
        [current],
        startUtc: current.playedAtUtc,
        endUtc: current.playedAtUtc,
      ),
      mode: PlayerComparisonMode.matchPair,
    );
  }

  PlayerComparisonReport _compareWindows(
    AdjacentWindowComparisonRequest request,
    List<PlayerAnalyticsSnapshotRow> snapshots,
  ) {
    if (request.opponentPlayerId?.trim().isEmpty ?? false) {
      throw const PlayerComparisonException(
        'Opponent filtering requires a stable player profile ID.',
      );
    }
    final currentEnd = request.asOfUtc;
    final currentStart = currentEnd.subtract(request.window.duration);
    final baselineStart = currentStart.subtract(request.window.duration);
    final eligible = snapshots.where(
      (row) =>
          request.opponentPlayerId == null ||
          row.opponentPlayerId == request.opponentPlayerId,
    );
    final baseline = eligible
        .where(
          (row) =>
              !row.playedAtUtc.isBefore(baselineStart) &&
              row.playedAtUtc.isBefore(currentStart),
        )
        .toList(growable: false);
    final current = eligible
        .where(
          (row) =>
              !row.playedAtUtc.isBefore(currentStart) &&
              row.playedAtUtc.isBefore(currentEnd),
        )
        .toList(growable: false);
    return _reportBuilder.build(
      baseline: _sample(
        baseline,
        startUtc: baselineStart,
        endUtc: currentStart,
      ),
      current: _sample(current, startUtc: currentStart, endUtc: currentEnd),
      mode: PlayerComparisonMode.adjacentWindow,
    );
  }

  PlayerComparisonSample _sample(
    List<PlayerAnalyticsSnapshotRow> rows, {
    required DateTime startUtc,
    required DateTime endUtc,
  }) {
    var wins = 0;
    var pointsFor = 0;
    var pointsAgainst = 0;
    var fieldGoalMade = 0;
    var fieldGoalAttempts = 0;
    var freeThrowMade = 0;
    var freeThrowAttempts = 0;
    var trustworthyAttemptMatchCount = 0;
    var confirmedLocationCount = 0;
    var locatableAttemptCount = 0;
    final zones = <ShotZone, int>{};
    for (final row in rows) {
      if (row.playerScore > row.opponentScore) wins++;
      pointsFor += row.playerScore;
      pointsAgainst += row.opponentScore;
      fieldGoalMade += row.fieldGoalMade;
      fieldGoalAttempts += row.fieldGoalAttempts;
      freeThrowMade += row.freeThrowMade;
      freeThrowAttempts += row.freeThrowAttempts;
      if (_hasTrustworthyAttempts(row.trackingCoverage)) {
        trustworthyAttemptMatchCount++;
      }
      confirmedLocationCount += row.confirmedLocationCount;
      locatableAttemptCount += row.locatableLocationCount;
      for (final entry in _decodeZones(row.zoneDistributionJson).entries) {
        zones[entry.key] = (zones[entry.key] ?? 0) + entry.value;
      }
    }
    return PlayerComparisonSample(
      startUtc: startUtc,
      endUtc: endUtc,
      matchIds: [for (final row in rows) row.matchId],
      wins: wins,
      pointsFor: pointsFor,
      pointsAgainst: pointsAgainst,
      fieldGoalMade: fieldGoalMade,
      fieldGoalAttempts: fieldGoalAttempts,
      freeThrowMade: freeThrowMade,
      freeThrowAttempts: freeThrowAttempts,
      trustworthyAttemptMatchCount: trustworthyAttemptMatchCount,
      confirmedLocationCount: confirmedLocationCount,
      locatableAttemptCount: locatableAttemptCount,
      zoneDistribution: zones,
    );
  }

  bool _hasTrustworthyAttempts(String value) => {
    TrackingCoverage.shotAttempts.name,
    TrackingCoverage.locations.name,
    TrackingCoverage.full.name,
  }.contains(value);

  Map<ShotZone, int> _decodeZones(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is int &&
              ShotZone.values.any((zone) => zone.name == entry.key))
            ShotZone.values.byName(entry.key): entry.value as int,
      };
    } on Object {
      return const {};
    }
  }

  void _validatePlayerId(String playerId) {
    if (playerId.trim().isEmpty) {
      throw const PlayerComparisonException(
        'Comparison requires a stable player profile ID.',
      );
    }
  }
}

import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/analytics/player_career_aggregate.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

/// Reads profile-linked career analytics from one bounded CTE query.
///
/// Profile IDs are the only identity used for both the subject and optional
/// opponent. Match snapshots and nicknames are deliberately not involved.
class PlayerCareerRepository {
  PlayerCareerRepository(this._database);

  final AppDatabase _database;

  Future<PlayerCareerAggregate> getByPlayerId(
    String playerId, {
    PlayerCareerQuery query = const PlayerCareerQuery(),
  }) async {
    final rows = await _careerRows(playerId, query);
    return _aggregate(playerId, rows);
  }

  Stream<PlayerCareerAggregate> watchByPlayerId(
    String playerId, {
    PlayerCareerQuery query = const PlayerCareerQuery(),
  }) {
    final watch = _database.customSelect(
      'SELECT id FROM players WHERE id = ? LIMIT 1',
      variables: [Variable.withString(playerId)],
      readsFrom: {
        _database.players,
        _database.matches,
        _database.matchParticipants,
        _database.matchEvents,
        _database.shotLocations,
      },
    );
    return watch.watch().asyncMap((_) => getByPlayerId(playerId, query: query));
  }

  Future<List<QueryRow>> _careerRows(String playerId, PlayerCareerQuery query) {
    final variables = <Variable<Object>>[Variable.withString(playerId)];
    final predicates = <String>[];
    final windowDays = query.window.days;
    final asOfUtc =
        query.asOfUtc?.toUtc() ??
        (windowDays == null ? null : DateTime.now().toUtc());
    if (windowDays != null) {
      predicates.add('COALESCE(m.started_at, m.created_at) >= ?');
      variables.add(
        Variable.withDateTime(asOfUtc!.subtract(Duration(days: windowDays))),
      );
    }
    if (asOfUtc != null) {
      predicates.add('COALESCE(m.started_at, m.created_at) <= ?');
      variables.add(Variable.withDateTime(asOfUtc));
    }
    if (query.opponentPlayerId != null) {
      predicates.add('''EXISTS (
          SELECT 1 FROM match_participants opponent
          WHERE opponent.match_id = m.id
            AND opponent.player_profile_id = ?
            AND opponent.player_profile_id != ?
        )''');
      variables
        ..add(Variable.withString(query.opponentPlayerId!))
        ..add(Variable.withString(playerId));
    }
    final where = predicates.isEmpty ? '' : 'AND ${predicates.join('\nAND ')}';
    return _database
        .customSelect(
          '''
      WITH eligible_matches AS (
        SELECT
          m.id AS match_id,
          COALESCE(m.started_at, m.created_at) AS played_at,
          m.tracking_coverage AS tracking_coverage,
          mp.side AS player_side
        FROM matches m
        JOIN match_participants mp ON mp.match_id = m.id
        WHERE mp.player_profile_id = ?
          AND m.lifecycle IN ('finished', 'archived')
          $where
      )
      SELECT
        em.match_id AS match_id,
        em.played_at AS played_at,
        em.tracking_coverage AS tracking_coverage,
        em.player_side AS player_side,
        e.id AS event_id,
        e.type AS event_type,
        e.side AS event_side,
        e.points AS event_points,
        e.outcome AS event_outcome,
        e.is_deleted AS event_is_deleted,
        sl.x AS location_x,
        sl.y AS location_y,
        sl.is_confirmed AS location_is_confirmed
      FROM eligible_matches em
      LEFT JOIN match_events e ON e.match_id = em.match_id
      LEFT JOIN shot_locations sl ON sl.event_id = e.id
      ORDER BY em.played_at ASC, em.match_id ASC, e.occurred_at ASC, e.id ASC
      ''',
          variables: variables,
          readsFrom: {
            _database.matches,
            _database.matchParticipants,
            _database.matchEvents,
            _database.shotLocations,
          },
        )
        .get();
  }

  static PlayerCareerAggregate _aggregate(
    String playerId,
    List<QueryRow> rows,
  ) {
    final matches = <String, _MatchCareer>{};
    for (final row in rows) {
      final matchId = row.read<String>('match_id');
      final match = matches.putIfAbsent(
        matchId,
        () => _MatchCareer(
          matchId: matchId,
          playerSide: row.read<String>('player_side'),
          playedAt: row.read<DateTime>('played_at').toUtc(),
          trackingCoverage: _trackingCoverage(
            row.read<String>('tracking_coverage'),
          ),
        ),
      );
      final eventId = row.read<String?>('event_id');
      final eventSide = row.read<String?>('event_side');
      final eventType = row.read<String?>('event_type');
      if (eventId == null || eventSide == null || eventType == null) continue;
      if (row.read<bool>('event_is_deleted')) continue;

      final isPlayerEvent = eventSide == match.playerSide;
      final points = row.read<int>('event_points');
      final outcome = row.read<String?>('event_outcome');
      final isLegacyScore = eventType == EventKind.score.name;
      final isFieldGoal =
          isLegacyScore ||
          eventType == EventKind.fieldGoal.name ||
          eventType == EventKind.miss.name;
      final isFreeThrow = eventType == EventKind.freeThrow.name;
      final isMade =
          isLegacyScore ||
          ((eventType == EventKind.fieldGoal.name || isFreeThrow) &&
              outcome == ShotOutcome.made.name);
      if (isPlayerEvent && isFieldGoal) {
        match.fieldGoalAttempts++;
        if (isMade) match.fieldGoalMade++;
      }
      if (isPlayerEvent && isFreeThrow) {
        match.freeThrowAttempts++;
        if (isMade) match.freeThrowMade++;
      }
      if (isMade) {
        if (eventSide == TeamSide.red.name) {
          match.redScore += points;
        } else if (eventSide == TeamSide.blue.name) {
          match.blueScore += points;
        }
      }

      final x = row.read<double?>('location_x');
      final y = row.read<double?>('location_y');
      if (isPlayerEvent &&
          isFieldGoal &&
          x != null &&
          y != null &&
          row.read<bool?>('location_is_confirmed') == true &&
          match.locatedEventIds.add(eventId)) {
        final zone = classifyShotZone(CourtPoint(x: x, y: y));
        match.zoneHeatmap[zone] = (match.zoneHeatmap[zone] ?? 0) + 1;
      }
    }

    final ordered = matches.values.toList()
      ..sort((a, b) {
        final date = a.playedAt.compareTo(b.playedAt);
        return date == 0 ? a.matchId.compareTo(b.matchId) : date;
      });
    var wins = 0;
    var totalPoints = 0;
    var totalMargin = 0;
    var fieldGoalMade = 0;
    var fieldGoalAttempts = 0;
    var freeThrowMade = 0;
    var freeThrowAttempts = 0;
    final trend = <PlayerCareerShootingTrend>[];
    final heatmap = <ShotZone, int>{};
    for (final match in ordered) {
      final playerIsRed = match.playerSide == TeamSide.red.name;
      final playerPoints = playerIsRed ? match.redScore : match.blueScore;
      final opponentPoints = playerIsRed ? match.blueScore : match.redScore;
      final margin = playerPoints - opponentPoints;
      if (margin > 0) wins++;
      totalPoints += playerPoints;
      totalMargin += margin;
      fieldGoalMade += match.fieldGoalMade;
      fieldGoalAttempts += match.fieldGoalAttempts;
      freeThrowMade += match.freeThrowMade;
      freeThrowAttempts += match.freeThrowAttempts;
      heatmap.addEntries(
        match.zoneHeatmap.entries.map(
          (entry) =>
              MapEntry(entry.key, (heatmap[entry.key] ?? 0) + entry.value),
        ),
      );
      final attempts = match.fieldGoalAttempts + match.freeThrowAttempts;
      final makes = match.fieldGoalMade + match.freeThrowMade;
      trend.add(
        PlayerCareerShootingTrend(
          matchId: match.matchId,
          playedAt: match.playedAt,
          fieldGoalMade: match.fieldGoalMade,
          fieldGoalAttempts: match.fieldGoalAttempts,
          freeThrowMade: match.freeThrowMade,
          freeThrowAttempts: match.freeThrowAttempts,
          recordedAttempts: attempts,
          recordedMakes: makes,
          isTrustworthy:
              attempts > 0 &&
              match.trackingCoverage.index >=
                  TrackingCoverage.shotAttempts.index,
        ),
      );
      match.playerPoints = playerPoints;
      match.margin = margin;
    }

    final recent = ordered.reversed.take(2).toList();
    return PlayerCareerAggregate(
      playerId: playerId,
      matches: ordered.length,
      wins: wins,
      totalPoints: totalPoints,
      averagePoints: ordered.isEmpty ? 0 : totalPoints / ordered.length,
      averageMargin: ordered.isEmpty ? 0 : totalMargin / ordered.length,
      fieldGoalMade: fieldGoalMade,
      fieldGoalAttempts: fieldGoalAttempts,
      freeThrowMade: freeThrowMade,
      freeThrowAttempts: freeThrowAttempts,
      shootingTrend: trend,
      zoneHeatmap: heatmap,
      recentChange: recent.length < 2
          ? const PlayerCareerRecentChange.empty()
          : PlayerCareerRecentChange(
              latestMatchId: recent[0].matchId,
              previousMatchId: recent[1].matchId,
              latestPoints: recent[0].playerPoints,
              previousPoints: recent[1].playerPoints,
              latestMargin: recent[0].margin,
              previousMargin: recent[1].margin,
              latestShootingPercentage: _percentage(recent[0]),
              previousShootingPercentage: _percentage(recent[1]),
            ),
    );
  }

  static double? _percentage(_MatchCareer match) {
    final attempts = match.fieldGoalAttempts;
    if (attempts == 0 ||
        match.trackingCoverage.index < TrackingCoverage.shotAttempts.index) {
      return null;
    }
    return match.fieldGoalMade / attempts;
  }

  static TrackingCoverage _trackingCoverage(String value) {
    return TrackingCoverage.values.firstWhere(
      (coverage) => coverage.name == value,
      orElse: () => TrackingCoverage.scoresOnly,
    );
  }
}

class _MatchCareer {
  _MatchCareer({
    required this.matchId,
    required this.playerSide,
    required this.playedAt,
    required this.trackingCoverage,
  });

  final String matchId;
  final String playerSide;
  final DateTime playedAt;
  final TrackingCoverage trackingCoverage;
  final Set<String> locatedEventIds = <String>{};
  final Map<ShotZone, int> zoneHeatmap = <ShotZone, int>{};
  var redScore = 0;
  var blueScore = 0;
  var fieldGoalMade = 0;
  var fieldGoalAttempts = 0;
  var freeThrowMade = 0;
  var freeThrowAttempts = 0;
  var playerPoints = 0;
  var margin = 0;
}

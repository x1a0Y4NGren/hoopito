import 'package:csv/csv.dart';
import 'package:hoopito/core/data/app_database.dart';

class PlayerStatisticsRow {
  const PlayerStatisticsRow({
    required this.playerId,
    required this.playerName,
    required this.matchesPlayed,
    required this.wins,
    required this.points,
    required this.fieldGoalMade,
    required this.fieldGoalAttempts,
    required this.freeThrowMade,
    required this.freeThrowAttempts,
    required this.attemptsComplete,
    this.matchId = '',
    this.participantId = '',
  });

  final String playerId;
  final String playerName;
  final int matchesPlayed;
  final int wins;
  final int points;
  final String matchId;
  final String participantId;
  final int fieldGoalMade;
  final int fieldGoalAttempts;
  final int freeThrowMade;
  final int freeThrowAttempts;
  final bool attemptsComplete;

  double? get fieldGoalPercentage => attemptsComplete && fieldGoalAttempts > 0
      ? fieldGoalMade / fieldGoalAttempts * 100
      : null;

  double? get freeThrowPercentage => attemptsComplete && freeThrowAttempts > 0
      ? freeThrowMade / freeThrowAttempts * 100
      : null;
}

class CsvExporter {
  const CsvExporter._();

  static final _csv = Csv(lineDelimiter: '\r\n');

  static const matchHeaders = [
    'match_id',
    'red_name',
    'blue_name',
    'status',
    'created_at',
    'started_at',
    'ended_at',
    'timer_enabled',
    'note',
  ];

  static const eventHeaders = [
    'match_id',
    'event_id',
    'event_type',
    'side',
    'points',
    'timestamp',
    'note',
    'custom_event_type',
    'is_deleted',
  ];

  static const playerStatisticsHeaders = [
    'player_id',
    'player_name',
    'match_id',
    'participant_id',
    'matches_played',
    'wins',
    'points',
    'field_goal_made',
    'field_goal_attempts',
    'field_goal_percentage',
    'free_throw_made',
    'free_throw_attempts',
    'free_throw_percentage',
  ];

  static String matchList(
    Iterable<Matche> matches, {
    Iterable<dynamic> participants = const [],
  }) {
    final sorted = matches.toList()..sort((a, b) => a.id.compareTo(b.id));
    final names = <String, Map<String, String>>{};
    for (final participant in participants) {
      names.putIfAbsent(
        participant.matchId as String,
        () => {},
      )[participant.side as String] = participant.nameSnapshot as String;
    }
    return _encode([
      matchHeaders,
      ...sorted.map(
        (match) => [
          match.id,
          names[match.id]?['red'] ?? '',
          names[match.id]?['blue'] ?? '',
          match.lifecycle,
          _timestamp(match.createdAt),
          _timestampOrEmpty(match.startedAt),
          _timestampOrEmpty(match.endedAt),
          match.timerEnabled,
          match.note ?? '',
        ],
      ),
    ]);
  }

  static String eventList(Iterable<MatchEventRow> events) {
    final sorted = events.toList()..sort((a, b) => a.id.compareTo(b.id));
    return _encode([
      eventHeaders,
      ...sorted.map(
        (event) => [
          event.matchId,
          event.id,
          event.type,
          event.side ?? '',
          event.points,
          _timestamp(event.occurredAt),
          event.note ?? '',
          event.customLabel ?? '',
          event.isDeleted,
        ],
      ),
    ]);
  }

  static String playerStatistics(Iterable<PlayerStatisticsRow> statistics) {
    final sorted = statistics.toList()
      ..sort((a, b) {
        if (a.playerId.isEmpty != b.playerId.isEmpty) {
          return a.playerId.isEmpty ? 1 : -1;
        }
        final idOrder = a.playerId.compareTo(b.playerId);
        if (idOrder != 0) return idOrder;
        final matchOrder = a.matchId.compareTo(b.matchId);
        return matchOrder == 0
            ? a.participantId.compareTo(b.participantId)
            : matchOrder;
      });
    return _encode([
      playerStatisticsHeaders,
      ...sorted.map(
        (player) => [
          player.playerId,
          player.playerName,
          player.matchId,
          player.participantId,
          player.matchesPlayed,
          player.wins,
          player.points,
          player.fieldGoalMade,
          player.fieldGoalAttempts,
          player.fieldGoalPercentage?.toStringAsFixed(2) ?? '',
          player.freeThrowMade,
          player.freeThrowAttempts,
          player.freeThrowPercentage?.toStringAsFixed(2) ?? '',
        ],
      ),
    ]);
  }

  static String _encode(List<List<Object?>> rows) {
    return _csv.encode(rows);
  }

  static String _timestamp(DateTime value) => value.toUtc().toIso8601String();

  static String _timestampOrEmpty(DateTime? value) =>
      value == null ? '' : _timestamp(value);
}

import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

export 'package:hoopito/core/domain/domain_enums.dart'
    show MatchLifecycle, MatchStatus, RecordingMode, TrackingCoverage;

class MatchParticipant {
  const MatchParticipant({
    required this.id,
    required this.matchId,
    required this.side,
    required this.nameSnapshot,
    this.playerProfileId,
  });

  final String id;
  final String matchId;
  final TeamSide side;
  final String nameSnapshot;
  final String? playerProfileId;

  /// Short compatibility name used by some repository consumers.
  String? get playerId => playerProfileId;
}

class Match {
  Match({
    required this.id,
    required this.createdAt,
    required this.ruleTemplateSnapshot,
    MatchLifecycle? lifecycle,
    MatchStatus? status,
    String? redName,
    String? blueName,
    List<MatchParticipant> participants = const [],
    this.recordingMode = RecordingMode.simple,
    this.trackingCoverage = TrackingCoverage.scoresOnly,
    this.startedAt,
    this.endedAt,
    this.timerEnabled = false,
    this.note,
  }) : lifecycle = _resolveLifecycle(lifecycle, status),
       participants = _normalizeParticipants(
         matchId: id,
         participants: participants,
         redName: redName,
         blueName: blueName,
       ) {
    if (this.participants.length != 2 ||
        this.participants
                .map((participant) => participant.side)
                .toSet()
                .length !=
            2) {
      throw ArgumentError(
        'A match requires exactly one red and one blue participant.',
      );
    }
    if (this.participants.any((participant) => participant.matchId != id)) {
      throw ArgumentError('Match participants must reference their match.');
    }
    if (this.participants.any(
      (participant) => participant.nameSnapshot.trim().isEmpty,
    )) {
      throw ArgumentError('Match participant names cannot be empty.');
    }
    if ((redName != null &&
            redName != _nameFor(this.participants, TeamSide.red)) ||
        (blueName != null &&
            blueName != _nameFor(this.participants, TeamSide.blue))) {
      throw ArgumentError(
        'Legacy participant names must match canonical participant snapshots.',
      );
    }
  }

  final String id;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final MatchLifecycle lifecycle;
  final List<MatchParticipant> participants;
  final RuleTemplate ruleTemplateSnapshot;
  final RecordingMode recordingMode;
  final TrackingCoverage trackingCoverage;
  final bool timerEnabled;
  final String? note;

  /// Compatibility getter for the old property name.
  MatchLifecycle get status => lifecycle;

  /// Compatibility getters derived from canonical participant rows.
  String get redName => _nameFor(participants, TeamSide.red);
  String get blueName => _nameFor(participants, TeamSide.blue);

  static MatchLifecycle _resolveLifecycle(
    MatchLifecycle? lifecycle,
    MatchStatus? status,
  ) {
    if (lifecycle != null && status != null && lifecycle != status) {
      throw ArgumentError('Lifecycle and legacy status cannot disagree.');
    }
    return lifecycle ?? status ?? MatchLifecycle.draft;
  }

  static List<MatchParticipant> _normalizeParticipants({
    required String matchId,
    required List<MatchParticipant> participants,
    required String? redName,
    required String? blueName,
  }) {
    if (participants.isNotEmpty) {
      return List.unmodifiable(participants);
    }
    if (redName == null || blueName == null) {
      return const [];
    }
    return List.unmodifiable([
      MatchParticipant(
        id: '$matchId-red',
        matchId: matchId,
        side: TeamSide.red,
        nameSnapshot: redName,
      ),
      MatchParticipant(
        id: '$matchId-blue',
        matchId: matchId,
        side: TeamSide.blue,
        nameSnapshot: blueName,
      ),
    ]);
  }

  static String _nameFor(List<MatchParticipant> participants, TeamSide side) {
    for (final participant in participants) {
      if (participant.side == side) return participant.nameSnapshot;
    }
    return '';
  }
}

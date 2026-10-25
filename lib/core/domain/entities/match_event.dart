import 'package:hoopito/core/domain/value_objects/team_side.dart';

import 'package:hoopito/core/domain/domain_enums.dart';

export 'package:hoopito/core/domain/domain_enums.dart'
    show EventKind, MatchEventType, ShotOutcome;

class MatchEvent {
  MatchEvent({
    required this.id,
    required this.matchId,
    required this.type,
    required this.side,
    required this.points,
    required this.occurredAt,
    this.note,
    this.outcome,
    this.matchClockPositionSeconds,
    String? customLabel,
    String? customType,
    this.isDeleted = false,
  }) : customLabel = _normalizeLabel(customLabel ?? customType) {
    switch (type) {
      case EventKind.score:
        if (side == null || points <= 0) {
          throw ArgumentError('Score events require a side and points.');
        }
      case EventKind.fieldGoal:
        if (side == null ||
            outcome == null ||
            (outcome != ShotOutcome.made && outcome != ShotOutcome.missed)) {
          throw ArgumentError(
            'Field-goal events require a side and shot outcome.',
          );
        }
        if (outcome == ShotOutcome.made && points <= 0) {
          throw ArgumentError('Made field goals require positive points.');
        }
        if (outcome == ShotOutcome.missed && points != 0) {
          throw ArgumentError('Missed field goals must have zero points.');
        }
      case EventKind.freeThrow:
        if (side == null ||
            outcome == null ||
            (outcome != ShotOutcome.made && outcome != ShotOutcome.missed)) {
          throw ArgumentError(
            'Free-throw events require a side and shot outcome.',
          );
        }
        if (outcome == ShotOutcome.made && points <= 0) {
          throw ArgumentError('Made free throws require positive points.');
        }
        if (outcome == ShotOutcome.missed && points != 0) {
          throw ArgumentError('Missed free throws must have zero points.');
        }
      case EventKind.miss:
        if (side == null || points != 0) {
          throw ArgumentError(
            'Legacy miss events require a side and zero points.',
          );
        }
      default:
        break;
    }
    if (matchClockPositionSeconds != null && matchClockPositionSeconds! < 0) {
      throw ArgumentError('Match-clock positions cannot be negative.');
    }
  }

  factory MatchEvent.score({
    required String id,
    required String matchId,
    required TeamSide side,
    required int points,
    required DateTime occurredAt,
  }) {
    if (points <= 0) {
      throw ArgumentError('Score points must be positive.');
    }
    return MatchEvent(
      id: id,
      matchId: matchId,
      type: MatchEventType.score,
      side: side,
      points: points,
      occurredAt: occurredAt,
      outcome: ShotOutcome.made,
    );
  }

  final String id;
  final String matchId;
  final MatchEventType type;
  final TeamSide? side;
  final int points;
  final DateTime occurredAt;
  final String? note;
  final ShotOutcome? outcome;
  final int? matchClockPositionSeconds;
  final String? customLabel;

  /// Compatibility getter for the v0.1 database field name.
  String? get customType => customLabel;
  final bool isDeleted;

  static String? _normalizeLabel(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

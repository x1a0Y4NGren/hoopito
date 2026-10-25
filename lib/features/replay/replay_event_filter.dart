import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';

/// A composable, data-only filter for the replay event timeline.
///
/// An empty set means "any" for that dimension.  Deleted events are visible
/// by default because replay is also the review surface for corrections.
class ReplayEventFilter {
  const ReplayEventFilter({
    this.sides = const <TeamSide>{},
    this.outcomes = const <ShotOutcome?>{},
    this.kinds = const <EventKind>{},
    this.points = const <int>{},
    this.includeDeleted = true,
  });

  static const all = ReplayEventFilter();

  final Set<TeamSide> sides;
  final Set<ShotOutcome?> outcomes;
  final Set<EventKind> kinds;
  final Set<int> points;
  final bool includeDeleted;

  ReplayEventFilter copyWith({
    Set<TeamSide>? sides,
    Set<ShotOutcome?>? outcomes,
    Set<EventKind>? kinds,
    Set<int>? points,
    bool? includeDeleted,
  }) {
    return ReplayEventFilter(
      sides: sides ?? this.sides,
      outcomes: outcomes ?? this.outcomes,
      kinds: kinds ?? this.kinds,
      points: points ?? this.points,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  bool matches(ReplayEventData event) {
    if (!includeDeleted && event.isDeleted) return false;
    if (sides.isNotEmpty && !sides.contains(event.side)) return false;
    if (outcomes.isNotEmpty && !outcomes.contains(event.outcome)) return false;
    if (kinds.isNotEmpty &&
        !kinds.contains(event.rawKind ?? _legacyKind(event.kind))) {
      return false;
    }
    if (points.isNotEmpty && !points.contains(event.points)) return false;
    return true;
  }

  EventKind _legacyKind(ReplayEventKind kind) {
    return switch (kind) {
      ReplayEventKind.score => EventKind.score,
      ReplayEventKind.foul => EventKind.foul,
      ReplayEventKind.miss => EventKind.miss,
      ReplayEventKind.other => EventKind.custom,
    };
  }
}

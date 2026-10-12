import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:hoopito/core/audit/audit_log_entry.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/replay/replay_event_filter.dart';

enum ReplayEventKind { score, foul, miss, other }

enum ReplayKindFilter { all, scores, fouls }

enum ReplaySideFilter { all, red, blue }

/// The complete set of fields a replay reviewer can correct on an existing
/// event.  Every value is optional so command adapters can send a partial
/// correction, while the editor sends the current value for each field it
/// exposes.  [eventId] and [reason] are kept outside the persisted payload so
/// the controller remains independent from the command kernel.
class ReplayEventCorrection {
  const ReplayEventCorrection({
    required this.eventId,
    this.type,
    this.side,
    this.points,
    this.outcome,
    this.note,
    this.customLabel,
    this.matchClockPositionSeconds,
    this.reason,
  });

  final String eventId;
  final EventKind? type;
  final TeamSide? side;
  final int? points;
  final ShotOutcome? outcome;
  final String? note;
  final String? customLabel;
  final int? matchClockPositionSeconds;
  final String? reason;
}

class ReplayEventData {
  const ReplayEventData({
    required this.id,
    required this.kind,
    required this.side,
    required this.elapsed,
    this.points = 0,
    this.note,
    this.locationId,
    this.shotPoint,
    this.rawKind,
    this.outcome,
    this.customLabel,
    this.occurredAt,
    this.matchClockPositionSeconds,
    this.isDeleted = false,
  });

  final String id;
  final ReplayEventKind kind;
  final TeamSide? side;
  final int points;
  final Duration elapsed;
  final String? note;
  final String? locationId;

  /// Confirmed court point; pending locations are omitted by the data mapper.
  final CourtPoint? shotPoint;

  /// The persisted event vocabulary. [kind] remains the display category.
  final EventKind? rawKind;
  final ShotOutcome? outcome;
  final String? customLabel;
  final DateTime? occurredAt;
  final int? matchClockPositionSeconds;
  final bool isDeleted;

  /// Compatibility alias for consumers that call the persisted value type.
  EventKind? get eventType => rawKind;

  ReplayEventData copyWith({String? note, CourtPoint? shotPoint}) {
    return ReplayEventData(
      id: id,
      kind: kind,
      side: side,
      elapsed: elapsed,
      points: points,
      note: note ?? this.note,
      locationId: locationId,
      shotPoint: shotPoint ?? this.shotPoint,
      rawKind: rawKind,
      outcome: outcome,
      customLabel: customLabel,
      occurredAt: occurredAt,
      matchClockPositionSeconds: matchClockPositionSeconds,
      isDeleted: isDeleted,
    );
  }
}

class ReplayPossessionSegmentData {
  const ReplayPossessionSegmentData({
    required this.id,
    required this.side,
    required this.startedAtEventId,
    required this.startedAt,
    this.endedAtEventId,
    this.endedAt,
    this.reason,
    this.source = PossessionSource.manual,
  }) : assert(endedAt == null || endedAt >= startedAt);

  final String id;
  final TeamSide side;
  final String startedAtEventId;
  final Duration startedAt;
  final String? endedAtEventId;
  final Duration? endedAt;
  final String? reason;
  final PossessionSource source;

  bool get isOpen => endedAtEventId == null;
}

class ReplayMatchData {
  ReplayMatchData({
    required this.matchId,
    required this.redName,
    required this.blueName,
    required this.redScore,
    required this.blueScore,
    required this.duration,
    required List<ReplayEventData> events,
    List<ReplayPossessionSegmentData> possessionSegments = const [],
    this.analytics,
    this.isFinished = true,
  }) : events = List.unmodifiable(events),
       possessionSegments = List.unmodifiable(possessionSegments);

  final String matchId;
  final String redName;
  final String blueName;
  final int redScore;
  final int blueScore;
  final Duration duration;
  final bool isFinished;
  final List<ReplayEventData> events;
  final List<ReplayPossessionSegmentData> possessionSegments;
  final MatchAnalytics? analytics;
}

class ReplayController extends ChangeNotifier {
  ReplayController({
    required ReplayMatchData data,
    this.onMoveShotLocation,
    this.onSoftDeleteEvent,
    this.onUpdateEventNote,
    this.onCorrectEvent,
    this.onUndoEvent,
    this.onRestoreEvent,
    this.onCorrectShotLocation,
    this.loadAuditLogs,
  }) : _data = data;

  ReplayMatchData _data;
  final Future<void> Function(
    String locationId,
    CourtPoint point,
    String? reason,
  )?
  onMoveShotLocation;
  final Future<void> Function(String eventId, String? reason)?
  onSoftDeleteEvent;
  final Future<void> Function(String eventId, String note, String? reason)?
  onUpdateEventNote;
  final Future<void> Function(ReplayEventCorrection correction)? onCorrectEvent;
  final Future<void> Function(String eventId, String? reason)? onUndoEvent;
  final Future<void> Function(String eventId, String? reason)? onRestoreEvent;
  final Future<void> Function(String eventId, CourtPoint point, String? reason)?
  onCorrectShotLocation;
  final Future<List<AuditLogEntry>> Function()? loadAuditLogs;
  ReplayKindFilter _kindFilter = ReplayKindFilter.all;
  ReplaySideFilter _sideFilter = ReplaySideFilter.all;
  ReplayEventFilter _eventFilter = ReplayEventFilter.all;
  bool _isEditing = false;
  String? _selectedEventId;
  CourtPoint? _pendingShotPoint;

  ReplayMatchData get data => _data;
  ReplayKindFilter get kindFilter => _kindFilter;
  ReplaySideFilter get sideFilter => _sideFilter;
  ReplayEventFilter get eventFilter => _eventFilter;
  bool get isEditing => _isEditing;
  bool get canEdit =>
      onMoveShotLocation != null ||
      onSoftDeleteEvent != null ||
      onUpdateEventNote != null ||
      onCorrectEvent != null ||
      onUndoEvent != null ||
      onRestoreEvent != null ||
      onCorrectShotLocation != null;
  String? get selectedEventId => _selectedEventId;
  ReplayEventData? get selectedEvent {
    final id = _selectedEventId;
    if (id == null) return null;
    return _data.events.where((event) => event.id == id).firstOrNull;
  }

  PendingShotLocation? get pendingShotLocation {
    final event = selectedEvent;
    final point = _pendingShotPoint;
    if (!_isEditing || event == null || point == null || event.side == null) {
      return null;
    }
    return PendingShotLocation(
      eventId: event.id,
      side: event.side!,
      points: event.points,
      point: point,
    );
  }

  UnmodifiableListView<ReplayEventData> get visibleEvents {
    final indexed =
        data.events
            .asMap()
            .entries
            .where(
              (entry) =>
                  _eventFilter.matches(entry.value) &&
                  _matchesFilters(entry.value),
            )
            .toList()
          ..sort((first, second) {
            final firstAt = first.value.occurredAt;
            final secondAt = second.value.occurredAt;
            if (firstAt == null || secondAt == null) {
              if (firstAt == null && secondAt == null) {
                return first.key.compareTo(second.key);
              }
              return firstAt == null ? 1 : -1;
            }
            final comparison = firstAt.compareTo(secondAt);
            return comparison == 0
                ? first.key.compareTo(second.key)
                : comparison;
          });
    return UnmodifiableListView(
      indexed.map((entry) => entry.value).toList(growable: false),
    );
  }

  UnmodifiableListView<ScoringShotLocation> get shotLocations {
    final locations = <ScoringShotLocation>[];
    for (final event in visibleEvents) {
      final point = event.shotPoint;
      final side = event.side;
      final rawKind = event.rawKind;
      final isShot =
          event.kind == ReplayEventKind.score ||
          event.kind == ReplayEventKind.miss ||
          rawKind == EventKind.fieldGoal ||
          rawKind == EventKind.freeThrow ||
          rawKind == EventKind.miss ||
          rawKind == EventKind.score;
      if (event.isDeleted || !isShot || point == null || side == null) {
        continue;
      }
      locations.add(
        ScoringShotLocation(
          id: event.locationId ?? 'replay-shot-${event.id}',
          eventId: event.id,
          side: side,
          points: event.points,
          point: point,
          isLocked: true,
        ),
      );
    }
    return UnmodifiableListView(locations);
  }

  int get scoreEventCount => _data.events
      .where((event) => !event.isDeleted && event.kind == ReplayEventKind.score)
      .length;

  int get foulEventCount => _data.events
      .where((event) => !event.isDeleted && event.kind == ReplayEventKind.foul)
      .length;

  int get locatedShotCount => shotLocations.length;

  /// Full-match coverage is independent of the timeline and court filters.
  int get fieldGoalAttemptCount =>
      _data.analytics?.fieldGoalAttemptCount ?? _fieldGoalAttempts.length;

  int get confirmedLocationCount =>
      _data.analytics?.confirmedLocationCount ??
      _fieldGoalAttempts.where((event) => event.shotPoint != null).length;

  double get locationCoverage =>
      _data.analytics?.locationCoverage ??
      (fieldGoalAttemptCount == 0
          ? 0
          : confirmedLocationCount / fieldGoalAttemptCount);

  Iterable<ReplayEventData> get _fieldGoalAttempts => _data.events.where(
    (event) =>
        !event.isDeleted &&
        event.side != null &&
        switch (event.rawKind) {
          EventKind.score || EventKind.fieldGoal || EventKind.miss => true,
          null =>
            event.kind == ReplayEventKind.score ||
                event.kind == ReplayEventKind.miss,
          _ => false,
        },
  );

  void setKindFilter(ReplayKindFilter value) {
    if (_kindFilter == value) return;
    _kindFilter = value;
    _eventFilter = _eventFilter.copyWith(
      kinds: switch (value) {
        ReplayKindFilter.all => const <EventKind>{},
        ReplayKindFilter.scores => const <EventKind>{
          EventKind.score,
          EventKind.fieldGoal,
          EventKind.freeThrow,
        },
        ReplayKindFilter.fouls => const <EventKind>{EventKind.foul},
      },
    );
    notifyListeners();
  }

  void setSideFilter(ReplaySideFilter value) {
    if (_sideFilter == value) return;
    _sideFilter = value;
    _eventFilter = _eventFilter.copyWith(
      sides: switch (value) {
        ReplaySideFilter.all => const <TeamSide>{},
        ReplaySideFilter.red => const <TeamSide>{TeamSide.red},
        ReplaySideFilter.blue => const <TeamSide>{TeamSide.blue},
      },
    );
    notifyListeners();
  }

  /// Replaces the composable filter used by replay consumers.
  void setEventFilter(ReplayEventFilter value) {
    if (_eventFilter == value) return;
    _eventFilter = value;
    _kindFilter = _kindFilterFrom(value.kinds);
    _sideFilter = _sideFilterFrom(value.sides);
    notifyListeners();
  }

  void setEditing(bool value) {
    if (value && !canEdit) return;
    if (_isEditing == value) return;
    _isEditing = value;
    if (!value) clearSelection(notify: false);
    notifyListeners();
  }

  void selectEvent(String eventId) {
    // Selection is a read-only review affordance as well as the entry point
    // for editing.  Editing remains gated by [_isEditing] in the mutation
    // methods and in [pendingShotLocation].
    if (!_data.events.any((event) => event.id == eventId)) {
      return;
    }
    _selectedEventId = eventId;
    _pendingShotPoint = selectedEvent?.shotPoint;
    notifyListeners();
  }

  void selectLocation(String locationId) {
    if (!_isEditing) return;
    final event = _data.events
        .where(
          (item) =>
              item.locationId == locationId ||
              (item.locationId == null &&
                  item.shotPoint != null &&
                  'replay-shot-${item.id}' == locationId),
        )
        .firstOrNull;
    if (event != null) selectEvent(event.id);
  }

  void updatePendingShotPoint(CourtPoint point) {
    if (!_isEditing || selectedEvent?.locationId == null) return;
    _pendingShotPoint = point;
    notifyListeners();
  }

  void clearSelection({bool notify = true}) {
    _selectedEventId = null;
    _pendingShotPoint = null;
    if (notify) notifyListeners();
  }

  Future<void> saveSelectedShot({String? reason}) async {
    final event = selectedEvent;
    final point = _pendingShotPoint;
    final locationId = event?.locationId;
    if (event == null || locationId == null || point == null) {
      return;
    }
    if (onCorrectShotLocation != null) {
      await onCorrectShotLocation!(event.id, point, reason);
    } else if (onMoveShotLocation != null) {
      await onMoveShotLocation!(locationId, point, reason);
    }
  }

  Future<void> updateSelectedNote(String note, {String? reason}) async {
    final eventId = _selectedEventId;
    if (eventId == null) return;
    if (onCorrectEvent != null) {
      await onCorrectEvent!(
        ReplayEventCorrection(eventId: eventId, note: note, reason: reason),
      );
    } else if (onUpdateEventNote != null) {
      await onUpdateEventNote!(eventId, note, reason);
    }
  }

  Future<void> correctSelectedEvent({
    EventKind? type,
    TeamSide? side,
    int? points,
    ShotOutcome? outcome,
    String? note,
    String? customLabel,
    int? matchClockPositionSeconds,
    String? reason,
  }) async {
    final eventId = _selectedEventId;
    final callback = onCorrectEvent;
    if (eventId == null || callback == null) return;
    await callback(
      ReplayEventCorrection(
        eventId: eventId,
        type: type,
        side: side,
        points: points,
        outcome: outcome,
        note: note,
        customLabel: customLabel,
        matchClockPositionSeconds: matchClockPositionSeconds,
        reason: reason,
      ),
    );
  }

  Future<void> correctSelectedShotLocation(
    CourtPoint point, {
    String? reason,
  }) async {
    final event = selectedEvent;
    final callback = onCorrectShotLocation;
    if (event == null || callback == null) return;
    await callback(event.id, point, reason);
  }

  Future<void> deleteSelectedEvent({String? reason}) async {
    final eventId = _selectedEventId;
    if (eventId == null) return;
    if (onUndoEvent != null) {
      await onUndoEvent!(eventId, reason);
    } else if (onSoftDeleteEvent != null) {
      await onSoftDeleteEvent!(eventId, reason);
    } else {
      return;
    }
    clearSelection(notify: false);
  }

  Future<void> restoreSelectedEvent({String? reason}) async {
    final eventId = _selectedEventId;
    if (eventId == null || onRestoreEvent == null) return;
    await onRestoreEvent!(eventId, reason);
    clearSelection(notify: false);
  }

  void replaceData(ReplayMatchData data) {
    _data = data;
    final selected = selectedEvent;
    if (selected == null) {
      clearSelection(notify: false);
    } else {
      _pendingShotPoint = selected.shotPoint;
    }
    notifyListeners();
  }

  bool _matchesFilters(ReplayEventData event) {
    final matchesKind = switch (_kindFilter) {
      ReplayKindFilter.all => true,
      ReplayKindFilter.scores => event.kind == ReplayEventKind.score,
      ReplayKindFilter.fouls => event.kind == ReplayEventKind.foul,
    };
    final matchesSide = switch (_sideFilter) {
      ReplaySideFilter.all => true,
      ReplaySideFilter.red => event.side == TeamSide.red,
      ReplaySideFilter.blue => event.side == TeamSide.blue,
    };
    return matchesKind && matchesSide;
  }

  ReplayKindFilter _kindFilterFrom(Set<EventKind> kinds) {
    if (kinds.length == 1 && kinds.single == EventKind.score) {
      return ReplayKindFilter.scores;
    }
    if (kinds.length == 1 && kinds.single == EventKind.foul) {
      return ReplayKindFilter.fouls;
    }
    return ReplayKindFilter.all;
  }

  ReplaySideFilter _sideFilterFrom(Set<TeamSide> sides) {
    if (sides.length == 1 && sides.single == TeamSide.red) {
      return ReplaySideFilter.red;
    }
    if (sides.length == 1 && sides.single == TeamSide.blue) {
      return ReplaySideFilter.blue;
    }
    return ReplaySideFilter.all;
  }
}

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/scoring/scoring_reducer.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

DateTime _defaultScoringControllerNowUtc() => DateTime.now().toUtc();

enum ShotLocationCommitSource { courtFirst, supplement }

/// Identifies the event and location rows created or confirmed by a scoring
/// surface action. In local-only mode these IDs identify controller state
/// rather than durable database rows.
class ShotLocationCommitReceipt {
  const ShotLocationCommitReceipt({
    required this.eventId,
    required this.shotLocationId,
    required this.side,
    required this.points,
    required this.point,
    required this.source,
  });

  final String eventId;
  final String shotLocationId;
  final TeamSide side;
  final int points;
  final CourtPoint point;
  final ShotLocationCommitSource source;

  String get actualShotLocationId => shotLocationId;
}

/// Result of retrying a command, including the durable shot receipt when the
/// command committed a location-bearing scoring action.
class ScoringCommandRetryResult {
  const ScoringCommandRetryResult({required this.accepted, this.receipt});

  final bool accepted;
  final ShotLocationCommitReceipt? receipt;
}

class PendingShotLocation {
  const PendingShotLocation({
    required this.eventId,
    required this.side,
    required this.points,
    required this.point,
    this.isExplicit = false,
  });

  final String eventId;
  final TeamSide side;
  final int points;
  final CourtPoint point;
  final bool isExplicit;

  PendingShotLocation copyWith({CourtPoint? point}) {
    return PendingShotLocation(
      eventId: eventId,
      side: side,
      points: points,
      point: point ?? this.point,
      isExplicit: isExplicit,
    );
  }
}

class ScoringShotLocation {
  const ScoringShotLocation({
    required this.id,
    required this.eventId,
    required this.side,
    required this.points,
    required this.point,
    required this.isLocked,
  });

  final String id;
  final String eventId;
  final TeamSide side;
  final int points;
  final CourtPoint point;
  final bool isLocked;

  /// A located missed field-goal is represented by a zero-point shot event.
  /// Keeping this interpretation next to the projection avoids duplicating
  /// event-kind lookups throughout the presentation layer.
  bool get isMiss => points == 0;
}

/// A court-first detailed-mode shot that has not been committed yet.
///
/// This object is deliberately local-only. It is promoted to a persisted
/// [RecordMatchEventCommand] only when [ScoringController.commitDetailedShot]
/// is called.
class CourtFirstShotDraft {
  const CourtFirstShotDraft({
    required this.point,
    this.side,
    this.outcome = ShotOutcome.made,
    this.points = 1,
  });

  final CourtPoint point;
  final TeamSide? side;
  final ShotOutcome outcome;
  final int points;

  CourtFirstShotDraft copyWith({
    CourtPoint? point,
    TeamSide? side,
    ShotOutcome? outcome,
    int? points,
  }) {
    return CourtFirstShotDraft(
      point: point ?? this.point,
      side: side ?? this.side,
      outcome: outcome ?? this.outcome,
      points: points ?? this.points,
    );
  }
}

/// Compatibility alias for callers that used the pre-unification detailed
/// draft name.
typedef DetailedShotDraft = CourtFirstShotDraft;

/// The durable score-first opportunity to attach a court location. The
/// service enforces [openedAtUtc, expiresAtUtc) when a confirmation command
/// carries its request timestamp.
class LocationSupplementWindow {
  const LocationSupplementWindow({
    required this.eventId,
    required this.side,
    required this.points,
    required this.openedAtUtc,
  });

  final String eventId;
  final TeamSide side;
  final int points;
  final DateTime openedAtUtc;

  DateTime get openedAt => openedAtUtc;

  DateTime get expiresAtUtc =>
      openedAtUtc.add(locationSupplementWindowDuration);

  DateTime get deadlineUtc => expiresAtUtc;

  DateTime get expiresAt => expiresAtUtc;

  String get shotEventId => eventId;

  bool contains(DateTime requestedAtUtc) {
    final value = requestedAtUtc.toUtc();
    return !value.isBefore(openedAtUtc) && value.isBefore(expiresAtUtc);
  }
}

class MatchScoringState {
  const MatchScoringState({
    required this.matchId,
    required this.redName,
    required this.blueName,
    required this.events,
    required this.score,
    required this.shotLocations,
    required this.ruleTemplate,
    this.recordingMode = RecordingMode.simple,
    this.trackingCoverage = TrackingCoverage.scoresOnly,
    this.timerEnabled = false,
    this.clock,
    this.currentPossession,
    this.pendingLocation,
    CourtFirstShotDraft? courtFirstShotDraft,
    this.locationSupplementWindow,
    DetailedShotDraft? detailedShotDraft,
    this.redFouls = 0,
    this.blueFouls = 0,
    this.ruleHints = const [],
    this.decision,
    this.ruleWarnings = const [],
  }) : courtFirstShotDraft = courtFirstShotDraft ?? detailedShotDraft;

  final String matchId;
  final String redName;
  final String blueName;
  final List<MatchEvent> events;
  final ScoreState score;
  final List<ScoringShotLocation> shotLocations;
  final RuleTemplate ruleTemplate;
  final RecordingMode recordingMode;
  final TrackingCoverage trackingCoverage;
  final bool timerEnabled;
  final ClockProjection? clock;
  final TeamSide? currentPossession;
  final PendingShotLocation? pendingLocation;
  final CourtFirstShotDraft? courtFirstShotDraft;
  final LocationSupplementWindow? locationSupplementWindow;

  /// Compatibility field for existing consumers; new code should use
  /// [courtFirstShotDraft].
  CourtFirstShotDraft? get detailedShotDraft => courtFirstShotDraft;
  final int redFouls;
  final int blueFouls;
  final List<RuleHint> ruleHints;
  final MatchDecision? decision;
  final List<MatchRuleWarning> ruleWarnings;

  /// Whether the match is currently in the user-controlled paused state.
  ///
  /// Pause/resume is stored as a pair of system semantic events rather than
  /// inferred from the clock: untimed matches can therefore be paused too.
  /// Other pause-typed records (for example rule decisions) and deleted rows
  /// deliberately do not participate in this state.
  bool get isManuallyPaused {
    for (final event in events.reversed) {
      if (event.isDeleted || event.type != EventKind.pause) continue;
      if (event.customLabel == 'pause') return true;
      if (event.customLabel == 'resume') return false;
    }
    return false;
  }

  MatchScoringState copyWith({
    List<MatchEvent>? events,
    ScoreState? score,
    List<ScoringShotLocation>? shotLocations,
    RuleTemplate? ruleTemplate,
    RecordingMode? recordingMode,
    TrackingCoverage? trackingCoverage,
    bool? timerEnabled,
    ClockProjection? clock,
    TeamSide? currentPossession,
    bool clearCurrentPossession = false,
    PendingShotLocation? pendingLocation,
    CourtFirstShotDraft? courtFirstShotDraft,
    DetailedShotDraft? detailedShotDraft,
    LocationSupplementWindow? locationSupplementWindow,
    bool clearDetailedShotDraft = false,
    bool clearCourtFirstShotDraft = false,
    bool clearLocationSupplementWindow = false,
    bool clearPendingLocation = false,
    int? redFouls,
    int? blueFouls,
    List<RuleHint>? ruleHints,
    MatchDecision? decision,
    List<MatchRuleWarning>? ruleWarnings,
  }) {
    return MatchScoringState(
      matchId: matchId,
      redName: redName,
      blueName: blueName,
      events: events ?? this.events,
      score: score ?? this.score,
      shotLocations: shotLocations ?? this.shotLocations,
      ruleTemplate: ruleTemplate ?? this.ruleTemplate,
      recordingMode: recordingMode ?? this.recordingMode,
      trackingCoverage: trackingCoverage ?? this.trackingCoverage,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      clock: clock ?? this.clock,
      currentPossession: clearCurrentPossession
          ? null
          : currentPossession ?? this.currentPossession,
      pendingLocation: clearPendingLocation
          ? null
          : pendingLocation ?? this.pendingLocation,
      courtFirstShotDraft: clearDetailedShotDraft || clearCourtFirstShotDraft
          ? null
          : courtFirstShotDraft ??
                detailedShotDraft ??
                this.courtFirstShotDraft,
      locationSupplementWindow: clearLocationSupplementWindow
          ? null
          : locationSupplementWindow ?? this.locationSupplementWindow,
      redFouls: redFouls ?? this.redFouls,
      blueFouls: blueFouls ?? this.blueFouls,
      ruleHints: ruleHints ?? this.ruleHints,
      decision: decision ?? this.decision,
      ruleWarnings: ruleWarnings ?? this.ruleWarnings,
    );
  }
}

class ScoringController extends ChangeNotifier {
  ScoringController({
    String? matchId,
    MatchSetup? setup,
    MatchCommandService? commandService,
    MatchDetail? committedProjection,
    DateTime Function()? nowUtc,
  }) : _commandService = commandService,
       _nowUtc = nowUtc ?? _defaultScoringControllerNowUtc,
       _state = committedProjection == null
           ? MatchScoringState(
               matchId: setup?.matchId ?? matchId ?? 'match-local',
               redName: setup?.redName ?? defaultRedPlayerName,
               blueName: setup?.blueName ?? defaultBluePlayerName,
               events: const [],
               score: const ScoreState.zero(),
               shotLocations: const [],
               ruleTemplate: _ruleTemplateFromSetup(setup),
               recordingMode: setup?.recordingMode ?? RecordingMode.simple,
               trackingCoverage:
                   setup?.trackingCoverage ?? TrackingCoverage.scoresOnly,
               timerEnabled: setup?.timerEnabled ?? false,
             )
           : _stateFromProjection(
               committedProjection,
               nowUtc: nowUtc ?? _defaultScoringControllerNowUtc,
             );

  factory ScoringController.fromCommittedProjection(
    MatchDetail projection,
    MatchCommandService commandService, {
    DateTime Function()? nowUtc,
  }) {
    return ScoringController(
      commandService: commandService,
      committedProjection: projection,
      nowUtc: nowUtc,
    );
  }

  final MatchCommandService? _commandService;
  final DateTime Function() _nowUtc;
  final ScoringReducer _reducer = ScoringReducer();
  final RuleEngine _ruleEngine = RuleEngine();
  MatchScoringState _state;
  final Queue<_QueuedScoringCommand> _commandQueue =
      Queue<_QueuedScoringCommand>();
  final Set<String> _localAtomicScoringEventIds = <String>{};
  final List<_LocalUndoAction> _localUndoHistory = <_LocalUndoAction>[];
  bool _drainingQueue = false;
  bool _exclusiveBusy = false;
  bool _disposed = false;
  final Set<String> _failedWrites = {};

  bool get isSaving =>
      _drainingQueue || _exclusiveBusy || _commandQueue.isNotEmpty;
  bool get hasSaveFailure => _failedWrites.isNotEmpty;

  MatchScoringState get state => _state;

  RecordingMode get recordingMode => _state.recordingMode;

  TrackingCoverage get trackingCoverage => _state.trackingCoverage;

  ClockProjection? get clock => _state.clock;

  MatchDecision? get decision => _state.decision;

  List<MatchRuleWarning> get ruleWarnings => _state.ruleWarnings;

  TeamSide? get currentPossession => _state.currentPossession;

  bool get timerEnabled => _state.timerEnabled;

  bool get isManuallyPaused => _state.isManuallyPaused;

  CourtFirstShotDraft? get courtFirstShotDraft => _state.courtFirstShotDraft;

  DetailedShotDraft? get detailedShotDraft => courtFirstShotDraft;

  LocationSupplementWindow? get locationSupplementWindow =>
      _state.locationSupplementWindow;

  bool get isCommandBacked => _commandService != null;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// Records a fully specified event through the transactional command
  /// boundary. The command object is created before it enters the queue, so
  /// every rapid tap owns a stable command/event ID and can be retried as-is.
  Future<bool> recordEventCommitted(RecordMatchEventCommand command) {
    if (_disposed ||
        command.matchId != _state.matchId ||
        _exclusiveBusy ||
        _state.detailedShotDraft != null ||
        _state.pendingLocation != null) {
      return Future<bool>.value(false);
    }
    final service = _commandService;
    if (service == null) {
      return Future<bool>.value(_recordLocalCommand(command));
    }
    return _enqueueCommand(command, () => service.record(command));
  }

  Future<bool> recordScoreCommitted({
    required TeamSide side,
    required int points,
    DateTime? occurredAt,
  }) async {
    if (_disposed || _ordinaryActionBlocked) return false;
    if (points <= 0) return false;
    final service = _commandService;
    if (service == null) {
      return addScore(side: side, points: points);
    }
    return recordEventCommitted(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.fieldGoal,
        side: side,
        points: points,
        outcome: ShotOutcome.made,
        occurredAt: (occurredAt ?? _nowUtc()).toUtc(),
      ),
    );
  }

  Future<bool> recordFieldGoalCommitted({
    required TeamSide side,
    required ShotOutcome outcome,
    int points = 0,
    CourtPoint? location,
    DateTime? occurredAt,
  }) {
    if (outcome == ShotOutcome.made && points <= 0) return Future.value(false);
    if (outcome == ShotOutcome.missed && points != 0) {
      return Future.value(false);
    }
    if (outcome == ShotOutcome.notApplicable) return Future.value(false);
    return recordEventCommitted(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.fieldGoal,
        side: side,
        points: points,
        outcome: outcome,
        occurredAt: (occurredAt ?? _nowUtc()).toUtc(),
        shotLocation: location == null
            ? null
            : MatchShotLocationInput(x: location.x, y: location.y),
      ),
    );
  }

  Future<bool> recordMissCommitted({
    required TeamSide side,
    DateTime? occurredAt,
  }) {
    return recordFieldGoalCommitted(
      side: side,
      outcome: ShotOutcome.missed,
      occurredAt: occurredAt,
    );
  }

  Future<bool> recordFreeThrowCommitted({
    required TeamSide side,
    required bool made,
    int points = 1,
  }) {
    final resolvedPoints = made ? points : 0;
    if (made && resolvedPoints <= 0) return Future<bool>.value(false);
    return recordEventCommitted(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.freeThrow,
        side: side,
        points: resolvedPoints,
        outcome: made ? ShotOutcome.made : ShotOutcome.missed,
        occurredAt: _nowUtc().toUtc(),
      ),
    );
  }

  Future<bool> recordPossessionCommitted(TeamSide side, {String? reason}) {
    return recordEventCommitted(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.possession,
        side: side,
        points: 0,
        note: reason,
        occurredAt: _nowUtc().toUtc(),
      ),
    );
  }

  Future<bool> recordNoteCommitted(String note) {
    if (note.trim().isEmpty) return Future<bool>.value(false);
    return recordEventCommitted(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.note,
        side: null,
        points: 0,
        note: note,
        occurredAt: _nowUtc().toUtc(),
      ),
    );
  }

  Future<bool> recordCustomCommitted({
    required String label,
    TeamSide? side,
    int points = 0,
  }) {
    if (label.trim().isEmpty || points < 0) return Future<bool>.value(false);
    return recordEventCommitted(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.custom,
        side: side,
        points: points,
        customLabel: label,
        occurredAt: _nowUtc().toUtc(),
      ),
    );
  }

  Future<bool> recordFoulCommitted(TeamSide side) async {
    if (_disposed || _ordinaryActionBlocked) return false;
    final service = _commandService;
    if (service == null) {
      addFoul(side);
      return true;
    }
    return recordEventCommitted(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.foul,
        side: side,
        points: 0,
        occurredAt: _nowUtc().toUtc(),
      ),
    );
  }

  /// Compatibility entry point for older scoring surfaces. Keep it routed
  /// through the same chronological policy as the current top-bar action so
  /// the two APIs cannot disagree about what one undo press means.
  Future<bool> undoLastEventCommitted() => undoLastScoringActionCommitted();

  /// Undoes the latest user-recorded live action. A committed supplement
  /// location is undone before its shot; a court-first event/location is one
  /// durable action. Clock, finish, and derived metadata are ignored. The
  /// historical method name remains part of the public compatibility API.
  Future<bool> undoLastScoringActionCommitted() async {
    if (_disposed ||
        _state.courtFirstShotDraft != null ||
        _state.pendingLocation != null) {
      return false;
    }
    final hasUndoableAction = _state.events.any(
      (event) => !event.isDeleted && event.type.isLiveUndoable,
    );
    if (!hasUndoableAction) return false;
    final service = _commandService;
    if (service == null) {
      return _undoLocalScoringAction();
    }
    if (_exclusiveBusy || _drainingQueue || _commandQueue.isNotEmpty) {
      return false;
    }
    final command = UndoLastScoringActionCommand(
      matchId: _state.matchId,
      reason: 'Scoring UI undo',
    );
    return _runExclusive(command, () => service.undoLastScoringAction(command));
  }

  bool _undoLocalScoringAction() {
    final action = _takeLatestLocalUndoAction();
    if (action == null) return false;
    final event = _state.events
        .where(
          (candidate) => candidate.id == action.eventId && !candidate.isDeleted,
        )
        .firstOrNull;
    if (event == null) return false;

    final locationId = action.locationId;
    if (locationId != null) {
      final locationIndex = _state.shotLocations.indexWhere(
        (location) => location.id == locationId && location.isLocked,
      );
      if (locationIndex < 0) return false;
      final locations = [..._state.shotLocations]..removeAt(locationIndex);
      _state = _state.copyWith(
        shotLocations: locations,
        clearLocationSupplementWindow: true,
      );
      final replacement = _latestUnlocatedShot;
      if (replacement?.id == event.id && replacement?.side != null) {
        _state = _state.copyWith(
          locationSupplementWindow: LocationSupplementWindow(
            eventId: replacement!.id,
            side: replacement.side!,
            points: replacement.points,
            openedAtUtc: replacement.occurredAt.toUtc(),
          ),
        );
      }
      notifyListeners();
      return true;
    }

    _localAtomicScoringEventIds.remove(event.id);
    _localUndoHistory.removeWhere((candidate) => candidate.eventId == event.id);
    final locations = _state.shotLocations
        .where((location) => location.eventId != event.id)
        .toList(growable: false);
    final events = _state.events
        .map(
          (candidate) => candidate.id == event.id
              ? MatchEvent(
                  id: candidate.id,
                  matchId: candidate.matchId,
                  type: candidate.type,
                  side: candidate.side,
                  points: candidate.points,
                  occurredAt: candidate.occurredAt,
                  note: candidate.note,
                  customLabel: candidate.customLabel,
                  outcome: candidate.outcome,
                  matchClockPositionSeconds:
                      candidate.matchClockPositionSeconds,
                  isDeleted: true,
                )
              : candidate,
        )
        .toList(growable: false);
    final isScoringEvent = _isScoringEvent(event);
    final nextPossession = _latestPossession(events);
    final fouls = _countFouls(events);
    _state = _state.copyWith(
      events: events,
      score: _reducer.reduce(events),
      shotLocations: locations,
      currentPossession: nextPossession,
      clearCurrentPossession: nextPossession == null,
      redFouls: fouls.red,
      blueFouls: fouls.blue,
      ruleHints: isScoringEvent ? const [] : null,
      clearLocationSupplementWindow: isScoringEvent,
    );
    if (isScoringEvent) {
      final replacement = _latestUnlocatedShot;
      if (replacement != null && replacement.side != null) {
        _state = _state.copyWith(
          locationSupplementWindow: LocationSupplementWindow(
            eventId: replacement.id,
            side: replacement.side!,
            points: replacement.points,
            openedAtUtc: replacement.occurredAt.toUtc(),
          ),
        );
      }
    }
    notifyListeners();
    return true;
  }

  _LocalUndoAction? _takeLatestLocalUndoAction() {
    while (_localUndoHistory.isNotEmpty) {
      final action = _localUndoHistory.removeLast();
      final eventExists = _state.events.any(
        (event) =>
            event.id == action.eventId &&
            !event.isDeleted &&
            event.type.isLiveUndoable,
      );
      final locationExists =
          action.locationId == null ||
          _state.shotLocations.any(
            (location) => location.id == action.locationId && location.isLocked,
          );
      if (eventExists && locationExists) return action;
    }

    MatchEvent? event;
    for (final candidate in _state.events.reversed) {
      if (!candidate.isDeleted && candidate.type.isLiveUndoable) {
        event = candidate;
        break;
      }
    }
    if (event == null) return null;
    if (!_localAtomicScoringEventIds.contains(event.id)) {
      for (final location in _state.shotLocations.reversed) {
        if (location.eventId == event.id && location.isLocked) {
          return _LocalUndoAction.location(
            eventId: event.id,
            locationId: location.id,
          );
        }
      }
    }
    return _LocalUndoAction.event(event.id);
  }

  bool addScore({required TeamSide side, required int points}) {
    if (_disposed) return false;
    if (isCommandBacked) {
      unawaited(recordScoreCommitted(side: side, points: points));
      return true;
    }
    if (_ordinaryActionBlocked) {
      return false;
    }

    final eventId = '${_state.matchId}-event-${_state.events.length + 1}';
    final hints = _ruleEngine.evaluate(
      template: _state.ruleTemplate,
      score: _state.score,
      scoringSide: side,
      scoringPoints: points,
    );
    final event = MatchEvent.score(
      id: eventId,
      matchId: _state.matchId,
      side: side,
      points: points,
      occurredAt: _nowUtc().toUtc(),
    );
    final events = [..._state.events, event];
    _localUndoHistory.add(_LocalUndoAction.event(event.id));
    _state = _state.copyWith(
      events: events,
      score: _reducer.reduce(events),
      locationSupplementWindow: LocationSupplementWindow(
        eventId: eventId,
        side: side,
        points: points,
        openedAtUtc: event.occurredAt.toUtc(),
      ),
      ruleHints: hints,
    );
    notifyListeners();
    return true;
  }

  void updatePendingLocation(CourtPoint point) {
    if (_disposed || _exclusiveBusy) return;
    final pending = _state.pendingLocation;
    if (pending == null) {
      return;
    }
    _state = _state.copyWith(pendingLocation: pending.copyWith(point: point));
    notifyListeners();
  }

  /// Confirms the current location interaction.
  ///
  /// Existing callers may omit [expectedEventId] to confirm the current
  /// score-first supplement. Interaction surfaces that retain a draft across
  /// projection replacement should pass its event ID so only that identity is
  /// accepted.
  Future<void> confirmPendingLocation([
    CourtPoint? point,
    String? expectedEventId,
  ]) async {
    if (_disposed) return;
    final pending = _state.pendingLocation;
    if (pending == null) {
      final window = _state.locationSupplementWindow;
      if (window != null &&
          (expectedEventId == null || expectedEventId == window.eventId)) {
        await attachSupplementLocation(
          point ?? CourtPoint(x: 0.5, y: 0.58),
          eventId: expectedEventId,
        );
      }
      return;
    }
    if (expectedEventId != null && expectedEventId != pending.eventId) return;
    final confirmedPoint = point ?? pending.point;
    final window = _state.locationSupplementWindow;
    if (window != null && window.eventId == pending.eventId) {
      await attachSupplementLocation(confirmedPoint);
      return;
    }
    final service = _commandService;
    if (service != null) {
      if (_exclusiveBusy || _drainingQueue || _commandQueue.isNotEmpty) return;
      final command = ConfirmShotLocationCommand(
        matchId: _state.matchId,
        eventId: pending.eventId,
        point: confirmedPoint,
        requestedAtUtc: _nowUtc().toUtc(),
      );
      await _runExclusive(command, () => service.confirmShotLocation(command));
      return;
    }
    final marker = ScoringShotLocation(
      id: '${_state.matchId}-shot-${_state.shotLocations.length + 1}',
      eventId: pending.eventId,
      side: pending.side,
      points: pending.points,
      point: confirmedPoint,
      isLocked: true,
    );
    _localUndoHistory.add(
      _LocalUndoAction.location(
        eventId: pending.eventId,
        locationId: marker.id,
      ),
    );
    _state = _state.copyWith(
      shotLocations: [..._state.shotLocations, marker],
      clearPendingLocation: true,
    );
    notifyListeners();
  }

  /// Applies the committed projection returned by a retryable command
  /// failure. The original command object is retained by the failure, so a
  /// retry cannot accidentally allocate a second event or receipt.
  Future<bool> retryCommand(MatchCommandFailure failure) async {
    final result = await retryCommandWithReceipt(failure);
    return result.accepted;
  }

  /// Retries a command and returns the durable shot receipt when the command
  /// is a court-first or supplement location commit. Other command kinds are
  /// still retried normally and report only whether they were accepted.
  Future<ScoringCommandRetryResult> retryCommandWithReceipt(
    MatchCommandFailure failure,
  ) async {
    if (_disposed ||
        _exclusiveBusy ||
        _drainingQueue ||
        _commandQueue.isNotEmpty ||
        failure.command.matchId != _state.matchId) {
      return const ScoringCommandRetryResult(accepted: false);
    }
    final projection = await _runExclusiveProjection(
      failure.command,
      failure.retry,
    );
    if (projection == null) {
      return const ScoringCommandRetryResult(accepted: false);
    }
    final command = failure.command;
    ShotLocationCommitReceipt? receipt;
    if (command is RecordMatchEventCommand && command.shotLocation != null) {
      receipt = _receiptFromProjection(
        projection,
        eventId: command.eventId,
        source: ShotLocationCommitSource.courtFirst,
      );
    } else if (command is ConfirmShotLocationCommand) {
      receipt = _receiptFromProjection(
        projection,
        eventId: command.eventId,
        source: ShotLocationCommitSource.supplement,
      );
    }
    return ScoringCommandRetryResult(accepted: true, receipt: receipt);
  }

  /// Starts an explicit, non-blocking location capture for the latest
  /// unlocated field-goal attempt. Scoring history remains untouched until a
  /// location confirmation command succeeds.
  bool beginLocateLastUnlocatedShot() {
    if (_disposed ||
        _exclusiveBusy ||
        _drainingQueue ||
        _commandQueue.isNotEmpty ||
        _state.detailedShotDraft != null) {
      return false;
    }
    final candidate = _latestUnlocatedShot;
    if (candidate == null || candidate.side == null) return false;
    final window =
        _state.locationSupplementWindow ??
        LocationSupplementWindow(
          eventId: candidate.id,
          side: candidate.side!,
          points: candidate.points,
          openedAtUtc: candidate.occurredAt.toUtc(),
        );
    _state = _state.copyWith(
      locationSupplementWindow: window,
      pendingLocation: PendingShotLocation(
        eventId: candidate.id,
        side: candidate.side!,
        points: candidate.points,
        point: CourtPoint(x: 0.5, y: 0.58),
        isExplicit: true,
      ),
    );
    notifyListeners();
    return true;
  }

  bool cancelLocateLastUnlocatedShot() => skipPendingLocation();

  /// Begins or moves a court-first shot. Repeated taps update the same local
  /// draft until it is committed or cancelled.
  bool beginOrMoveCourtFirstShot(
    CourtPoint point, {
    TeamSide? side,
    ShotOutcome? outcome,
    int? points,
  }) {
    if (_disposed ||
        _exclusiveBusy ||
        _drainingQueue ||
        _commandQueue.isNotEmpty ||
        _state.pendingLocation != null) {
      return false;
    }
    final existing = _state.courtFirstShotDraft;
    _state = _state.copyWith(
      courtFirstShotDraft: CourtFirstShotDraft(
        point: point,
        side: side ?? existing?.side ?? currentPossession,
        outcome: outcome ?? existing?.outcome ?? ShotOutcome.made,
        points: points ?? existing?.points ?? 1,
      ),
    );
    notifyListeners();
    return true;
  }

  bool cancelCourtFirstShot() => cancelDetailedShot();

  /// Drops a stale supplement opportunity. The durable score remains in the
  /// projection and can still be undone as a scoring action.
  bool expireSupplementWindow({DateTime? atUtc}) {
    final window = _state.locationSupplementWindow;
    if (_disposed || window == null) return false;
    final at = (atUtc ?? _nowUtc()).toUtc();
    if (at.isBefore(window.expiresAtUtc)) return false;
    _state = _state.copyWith(
      clearLocationSupplementWindow: true,
      clearPendingLocation: _state.pendingLocation?.eventId == window.eventId,
    );
    notifyListeners();
    return true;
  }

  /// Confirms a score-first location through the transactional command. The
  /// request timestamp is forwarded so the service remains the deadline
  /// authority even if a controller is rebuilt or stale UI is restored.
  Future<bool> attachSupplementLocation(
    CourtPoint point, {
    DateTime? requestedAtUtc,
    String? eventId,
  }) async {
    return (await attachSupplementLocationWithReceipt(
          point,
          requestedAtUtc: requestedAtUtc,
          eventId: eventId,
        )) !=
        null;
  }

  Future<ShotLocationCommitReceipt?> attachSupplementLocationWithReceipt(
    CourtPoint point, {
    DateTime? requestedAtUtc,
    String? eventId,
  }) async {
    if (_disposed || _exclusiveBusy) return null;
    final requested = (requestedAtUtc ?? _nowUtc()).toUtc();
    final window = _state.locationSupplementWindow;
    if (window == null ||
        (eventId != null && eventId != window.eventId) ||
        !window.contains(requested)) {
      return null;
    }
    final service = _commandService;
    final event = _state.events
        .where((item) => item.id == window.eventId && !item.isDeleted)
        .firstOrNull;
    if (event == null) return null;
    if (service == null) {
      final marker = ScoringShotLocation(
        id: '${_state.matchId}-shot-${_state.shotLocations.length + 1}',
        eventId: event.id,
        side: window.side,
        points: window.points,
        point: point,
        isLocked: true,
      );
      _localUndoHistory.add(
        _LocalUndoAction.location(eventId: event.id, locationId: marker.id),
      );
      _state = _state.copyWith(
        shotLocations: [..._state.shotLocations, marker],
        clearLocationSupplementWindow: true,
        clearPendingLocation: true,
      );
      notifyListeners();
      return ShotLocationCommitReceipt(
        eventId: event.id,
        shotLocationId: marker.id,
        side: marker.side,
        points: marker.points,
        point: marker.point,
        source: ShotLocationCommitSource.supplement,
      );
    }
    if (_drainingQueue || _commandQueue.isNotEmpty) return null;
    final command = ConfirmShotLocationCommand(
      matchId: _state.matchId,
      eventId: event.id,
      point: point,
      requestedAtUtc: requested,
    );
    final projection = await _runExclusiveProjection(
      command,
      () => service.confirmShotLocation(command),
    );
    if (projection == null) return null;
    return _receiptFromProjection(
      projection,
      eventId: command.eventId,
      source: ShotLocationCommitSource.supplement,
    );
  }

  /// Starts a detailed-mode local draft. The current possession is used as
  /// the initial shooter when available, but remains explicitly correctable.
  bool beginDetailedShot(CourtPoint point, {TeamSide? side}) {
    if (_disposed ||
        _exclusiveBusy ||
        _drainingQueue ||
        _commandQueue.isNotEmpty ||
        _state.pendingLocation != null ||
        _state.detailedShotDraft != null) {
      return false;
    }
    _state = _state.copyWith(
      courtFirstShotDraft: CourtFirstShotDraft(
        point: point,
        side: side ?? currentPossession,
      ),
    );
    notifyListeners();
    return true;
  }

  void updateDetailedShot({
    CourtPoint? point,
    TeamSide? side,
    ShotOutcome? outcome,
    int? points,
  }) {
    if (_disposed || _exclusiveBusy) return;
    final draft = _state.detailedShotDraft;
    if (draft == null) return;
    final nextOutcome = outcome ?? draft.outcome;
    final nextPoints = nextOutcome == ShotOutcome.missed
        ? 0
        : points ?? draft.points;
    _state = _state.copyWith(
      courtFirstShotDraft: CourtFirstShotDraft(
        point: point ?? draft.point,
        side: side ?? draft.side,
        outcome: nextOutcome,
        points: nextPoints,
      ),
    );
    notifyListeners();
  }

  void updateCourtFirstShot({
    CourtPoint? point,
    TeamSide? side,
    ShotOutcome? outcome,
    int? points,
  }) => updateDetailedShot(
    point: point,
    side: side,
    outcome: outcome,
    points: points,
  );

  Future<bool> commitDetailedShot() async {
    return (await commitDetailedShotWithReceipt()) != null;
  }

  Future<ShotLocationCommitReceipt?> commitDetailedShotWithReceipt() async {
    if (_disposed) return null;
    final draft = _state.detailedShotDraft;
    if (draft == null || draft.side == null) return null;
    if (draft.outcome == ShotOutcome.notApplicable) return null;
    if (_commandService == null) {
      final command = RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.fieldGoal,
        side: draft.side,
        points: draft.outcome == ShotOutcome.missed ? 0 : draft.points,
        outcome: draft.outcome,
        occurredAt: _nowUtc().toUtc(),
        shotLocation: MatchShotLocationInput(
          x: draft.point.x,
          y: draft.point.y,
        ),
      );
      if (_recordLocalCommand(command)) {
        _state = _state.copyWith(clearDetailedShotDraft: true);
        notifyListeners();
        return _receiptFromLocalState(
          eventId: command.eventId,
          source: ShotLocationCommitSource.courtFirst,
        );
      }
      return null;
    }
    if (_exclusiveBusy || _drainingQueue || _commandQueue.isNotEmpty) {
      return null;
    }
    final command = RecordMatchEventCommand(
      matchId: _state.matchId,
      type: EventKind.fieldGoal,
      side: draft.side,
      points: draft.outcome == ShotOutcome.missed ? 0 : draft.points,
      outcome: draft.outcome,
      occurredAt: _nowUtc().toUtc(),
      shotLocation: MatchShotLocationInput(x: draft.point.x, y: draft.point.y),
    );
    final projection = await _runExclusiveProjection(
      command,
      () => _commandService.record(command),
    );
    if (projection != null && !_disposed) {
      _state = _state.copyWith(clearDetailedShotDraft: true);
      notifyListeners();
      return _receiptFromProjection(
        projection,
        eventId: command.eventId,
        source: ShotLocationCommitSource.courtFirst,
      );
    }
    return null;
  }

  Future<ShotLocationCommitReceipt?> commitCourtFirstShotWithReceipt() {
    return commitDetailedShotWithReceipt();
  }

  Future<bool> commitCourtFirstShot() async {
    return (await commitCourtFirstShotWithReceipt()) != null;
  }

  bool cancelDetailedShot() {
    if (_disposed || _exclusiveBusy || _state.detailedShotDraft == null) {
      return false;
    }
    _state = _state.copyWith(clearDetailedShotDraft: true);
    notifyListeners();
    return true;
  }

  Future<bool> pauseCommitted() {
    if (_disposed || _exclusiveBusy) {
      return Future<bool>.value(false);
    }
    final service = _commandService;
    if (service == null) {
      return Future<bool>.value(_recordLocalSemantic('pause'));
    }
    final command = PauseMatchCommand(
      matchId: _state.matchId,
      occurredAt: _nowUtc().toUtc(),
    );
    return _enqueueCommand(command, () => service.pause(command));
  }

  Future<bool> resumeCommitted() {
    if (_disposed ||
        _exclusiveBusy ||
        _drainingQueue ||
        _commandQueue.isNotEmpty) {
      return Future<bool>.value(false);
    }
    final service = _commandService;
    if (service == null) {
      return Future<bool>.value(_recordLocalSemantic('resume'));
    }
    final command = ResumeMatchCommand(
      matchId: _state.matchId,
      occurredAt: _nowUtc().toUtc(),
    );
    return _runExclusive(command, () => service.resume(command));
  }

  Future<bool> pauseClockCommitted() => pauseCommitted();

  Future<bool> resumeClockCommitted() => resumeCommitted();

  bool skipPendingLocation() {
    if (_disposed ||
        _exclusiveBusy ||
        _drainingQueue ||
        _commandQueue.isNotEmpty) {
      return false;
    }
    if (_state.pendingLocation == null &&
        _state.locationSupplementWindow == null) {
      return false;
    }
    final hadPendingLocation = _state.pendingLocation != null;
    _state = _state.copyWith(clearPendingLocation: true);
    if (!hadPendingLocation) {
      _state = _state.copyWith(clearLocationSupplementWindow: true);
    }
    notifyListeners();
    return true;
  }

  void undoLastEvent() {
    if (_disposed || _state.events.isEmpty) {
      return;
    }
    final lastEvent = _state.events.last;
    final events = _state.events.take(_state.events.length - 1).toList();
    final locations = _state.shotLocations
        .where((location) => location.eventId != lastEvent.id)
        .toList();
    _localUndoHistory.removeWhere((action) => action.eventId == lastEvent.id);
    _localAtomicScoringEventIds.remove(lastEvent.id);
    final fouls = _countFouls(events);
    _state = _state.copyWith(
      events: events,
      score: _reducer.reduce(events),
      shotLocations: locations,
      redFouls: fouls.red,
      blueFouls: fouls.blue,
      ruleHints: const [],
      clearPendingLocation: true,
    );
    notifyListeners();
  }

  void addFoul(TeamSide side) {
    if (_disposed || _ordinaryActionBlocked) return;
    if (isCommandBacked) {
      unawaited(recordFoulCommitted(side));
      return;
    }
    final event = MatchEvent(
      id: '${_state.matchId}-event-${_state.events.length + 1}',
      matchId: _state.matchId,
      type: MatchEventType.foul,
      side: side,
      points: 0,
      occurredAt: _nowUtc().toUtc(),
    );
    final events = [..._state.events, event];
    _localUndoHistory.add(_LocalUndoAction.event(event.id));
    final fouls = _countFouls(events);
    _state = _state.copyWith(
      events: events,
      redFouls: fouls.red,
      blueFouls: fouls.blue,
    );
    notifyListeners();
  }

  static RuleTemplate _ruleTemplateFromSetup(MatchSetup? setup) {
    return RuleTemplate(
      id: setup?.ruleTemplateId ?? 'free',
      name:
          setup?.ruleTemplateName ??
          switch (setup?.ruleTemplateId) {
            'eleven' || 'eleven_win_by_two' => '11 分制',
            'twenty_one' => '21 分制',
            'timed_ten' => '10 分钟计时',
            _ => '自由计分',
          },
      scoreButtons: setup?.scoreButtons ?? const [1, 2, 3],
      foulLimit: setup?.foulLimit,
      possessionHintEnabled: setup?.possessionHintEnabled ?? false,
      customEventTypes: setup?.customEventTypes ?? const [],
      targetScore: setup?.targetScore,
      timeLimitSeconds: setup?.timerEnabled == true
          ? setup!.timeLimitMinutes * 60
          : null,
      winByTwo: setup?.winByTwo ?? false,
    );
  }

  static MatchScoringState _stateFromProjection(
    MatchDetail projection, {
    required DateTime Function() nowUtc,
  }) {
    final events = List<MatchEvent>.unmodifiable(projection.events);
    final locations = <ScoringShotLocation>[];
    for (final location in projection.shotLocations) {
      final event = events
          .where((item) => item.id == location.eventId)
          .firstOrNull;
      if (event?.side == null) continue;
      locations.add(
        ScoringShotLocation(
          id: location.id,
          eventId: location.eventId,
          side: event!.side!,
          points: event.points,
          point: location.point,
          isLocked: location.isConfirmed,
        ),
      );
    }
    final locationEventIds = projection.shotLocations
        .where((location) => location.isConfirmed)
        .map((location) => location.eventId)
        .toSet();
    LocationSupplementWindow? supplement;
    final projectedNowUtc = nowUtc().toUtc();
    MatchEvent? latestScoringEvent;
    for (final event in events.reversed) {
      if (!event.isDeleted && _isScoringEvent(event)) {
        latestScoringEvent = event;
        break;
      }
    }
    final event = latestScoringEvent;
    if (event != null &&
        event.side != null &&
        (event.type == EventKind.score ||
            event.type == EventKind.fieldGoal ||
            event.type == EventKind.miss) &&
        !locationEventIds.contains(event.id) &&
        projectedNowUtc.isBefore(
          event.occurredAt.toUtc().add(locationSupplementWindowDuration),
        )) {
      supplement = LocationSupplementWindow(
        eventId: event.id,
        side: event.side!,
        points: event.points,
        openedAtUtc: event.occurredAt.toUtc(),
      );
    }
    return MatchScoringState(
      matchId: projection.match.id,
      redName: projection.match.redName,
      blueName: projection.match.blueName,
      events: events,
      score: ScoreState(
        redScore: projection.redScore,
        blueScore: projection.blueScore,
      ),
      shotLocations: List.unmodifiable(locations),
      locationSupplementWindow: supplement,
      ruleTemplate: projection.match.ruleTemplateSnapshot,
      recordingMode: projection.match.recordingMode,
      trackingCoverage: projection.match.trackingCoverage,
      timerEnabled: projection.match.timerEnabled,
      clock: projection.clock,
      // Command-backed projections already contain the durable possession
      // segment history. Reconstructing this value from event rows loses
      // suggested segments because those rows are not possession events.
      // Local-only scoring still derives possession in _recordLocalCommand.
      currentPossession: projection.currentPossession,
      redFouls: projection.redFouls,
      blueFouls: projection.blueFouls,
      ruleHints: _ruleHintsFromProjection(projection),
      decision: projection.decision,
      ruleWarnings: List.unmodifiable(projection.warnings),
    );
  }

  static List<RuleHint> _ruleHintsFromProjection(MatchDetail projection) {
    final activeEvents = projection.events
        .where((event) => !event.isDeleted)
        .toList(growable: false);
    if (activeEvents.isEmpty) return const [];

    MatchEvent? scoringEvent;
    final latest = activeEvents.last;
    if (_isRuleScoringEvent(latest)) {
      scoringEvent = latest;
    } else if (latest.type == EventKind.pause &&
        latest.customLabel?.startsWith('decision:') == true) {
      for (final event in activeEvents.reversed) {
        if (_isRuleScoringEvent(event)) {
          scoringEvent = event;
          break;
        }
      }
    }
    if (scoringEvent?.side == null) return const [];

    final event = scoringEvent!;
    final previousScore = ScoreState(
      redScore:
          projection.redScore - (event.side == TeamSide.red ? event.points : 0),
      blueScore:
          projection.blueScore -
          (event.side == TeamSide.blue ? event.points : 0),
    );
    final hints = RuleEngine().evaluate(
      template: projection.match.ruleTemplateSnapshot,
      score: previousScore,
      scoringSide: event.side!,
      scoringPoints: event.points,
    );
    // A made free throw can reach a target, but it does not establish a new
    // possession boundary: the command projection deliberately waits for the
    // end of the attempt sequence before suggesting possession.
    if (event.type == EventKind.freeThrow) {
      return List.unmodifiable(
        hints.where((hint) => hint.type != RuleHintType.possessionChange),
      );
    }
    return List.unmodifiable(hints);
  }

  static bool _isRuleScoringEvent(MatchEvent event) {
    if (event.side == null || event.points <= 0) return false;
    return switch (event.type) {
      EventKind.score => true,
      EventKind.fieldGoal ||
      EventKind.freeThrow => event.outcome == ShotOutcome.made,
      _ => false,
    };
  }

  void _replaceFromProjection(
    MatchDetail projection, {
    PendingShotLocation? pendingLocation,
  }) {
    if (_disposed) return;
    final previousDraft = _state.detailedShotDraft;
    final previousPending = _state.pendingLocation;
    _state = _stateFromProjection(projection, nowUtc: _nowUtc);
    final pending = pendingLocation ?? previousPending;
    if (pending != null &&
        pending.eventId == _state.locationSupplementWindow?.eventId &&
        projection.events.any(
          (event) => event.id == pending.eventId && !event.isDeleted,
        ) &&
        !projection.shotLocations.any(
          (location) => location.eventId == pending.eventId,
        )) {
      _state = _state.copyWith(pendingLocation: pending);
    }
    if (previousDraft != null) {
      _state = _state.copyWith(courtFirstShotDraft: previousDraft);
    }
  }

  /// Replaces the local view with a committed Drift projection received from
  /// the reactive composition root. This intentionally does not issue a
  /// command or retain any database rows in memory.
  void replaceCommittedProjection(MatchDetail projection) {
    if (_disposed) return;
    _replaceFromProjection(projection);
    notifyListeners();
  }

  Future<bool> _enqueueCommand(
    MatchCommand command,
    Future<MatchDetail> Function() operation,
  ) {
    if (_disposed || _exclusiveBusy) return Future<bool>.value(false);
    final completer = Completer<bool>();
    _commandQueue.add(
      _QueuedScoringCommand(
        command: command,
        operation: operation,
        completer: completer,
      ),
    );
    unawaited(_drainCommandQueue());
    return completer.future;
  }

  Future<void> _drainCommandQueue() async {
    if (_drainingQueue) return;
    _drainingQueue = true;
    notifyListeners();
    try {
      while (_commandQueue.isNotEmpty) {
        final queued = _commandQueue.removeFirst();
        if (_disposed) {
          if (!queued.completer.isCompleted) queued.completer.complete(false);
          continue;
        }
        try {
          final projection = await queued.operation();
          if (_disposed) {
            queued.completer.complete(false);
            continue;
          }
          _replaceFromProjection(projection);
          _failedWrites.remove(queued.command.commandId);
          notifyListeners();
          queued.completer.complete(true);
        } on Object catch (error, stackTrace) {
          _failedWrites.add(queued.command.commandId);
          if (!queued.completer.isCompleted) {
            queued.completer.completeError(error, stackTrace);
          }
        }
      }
    } finally {
      _drainingQueue = false;
      notifyListeners();
    }
  }

  Future<bool> _runExclusive(
    MatchCommand command,
    Future<MatchDetail> Function() operation,
  ) async {
    return (await _runExclusiveProjection(command, operation)) != null;
  }

  Future<MatchDetail?> _runExclusiveProjection(
    MatchCommand command,
    Future<MatchDetail> Function() operation,
  ) async {
    if (_disposed ||
        _exclusiveBusy ||
        _drainingQueue ||
        _commandQueue.isNotEmpty) {
      return null;
    }
    _exclusiveBusy = true;
    notifyListeners();
    try {
      final projection = await operation();
      if (_disposed) return null;
      _replaceFromProjection(projection);
      _failedWrites.remove(command.commandId);
      notifyListeners();
      return projection;
    } on Object {
      _failedWrites.add(command.commandId);
      rethrow;
    } finally {
      _exclusiveBusy = false;
      notifyListeners();
    }
  }

  ShotLocationCommitReceipt? _receiptFromProjection(
    MatchDetail projection, {
    required String eventId,
    required ShotLocationCommitSource source,
  }) {
    final event = projection.events
        .where((candidate) => candidate.id == eventId && !candidate.isDeleted)
        .firstOrNull;
    final location = projection.shotLocations
        .where(
          (candidate) => candidate.eventId == eventId && candidate.isConfirmed,
        )
        .firstOrNull;
    if (event?.side == null || location == null) return null;
    return ShotLocationCommitReceipt(
      eventId: eventId,
      shotLocationId: location.id,
      side: event!.side!,
      points: event.points,
      point: location.point,
      source: source,
    );
  }

  ShotLocationCommitReceipt? _receiptFromLocalState({
    required String eventId,
    required ShotLocationCommitSource source,
  }) {
    final event = _state.events
        .where((candidate) => candidate.id == eventId && !candidate.isDeleted)
        .firstOrNull;
    final location = _state.shotLocations
        .where(
          (candidate) => candidate.eventId == eventId && candidate.isLocked,
        )
        .firstOrNull;
    if (event?.side == null || location == null) return null;
    return ShotLocationCommitReceipt(
      eventId: eventId,
      shotLocationId: location.id,
      side: event!.side!,
      points: event.points,
      point: location.point,
      source: source,
    );
  }

  bool _recordLocalCommand(RecordMatchEventCommand command) {
    if (_disposed) return false;
    final event = MatchEvent(
      id: command.eventId,
      matchId: command.matchId,
      type: command.type,
      side: command.side,
      points: command.points,
      occurredAt: command.occurredAt,
      outcome:
          command.outcome ??
          (command.type == EventKind.score ? ShotOutcome.made : null),
      note: command.note,
      customLabel: command.customLabel,
      matchClockPositionSeconds: command.matchClockPositionSeconds,
    );
    final events = [..._state.events, event];
    final locations = [..._state.shotLocations];
    final opensSupplementWindow =
        event.type == EventKind.score ||
        event.type == EventKind.fieldGoal ||
        event.type == EventKind.miss;
    final closesSupplementWindow = event.type == EventKind.freeThrow;
    if (command.shotLocation != null && command.type == EventKind.fieldGoal) {
      locations.add(
        ScoringShotLocation(
          id: command.shotLocationId!,
          eventId: event.id,
          side: command.side!,
          points: event.points,
          point: CourtPoint(
            x: command.shotLocation!.x,
            y: command.shotLocation!.y,
          ),
          isLocked: true,
        ),
      );
      _localAtomicScoringEventIds.add(event.id);
    }
    if (event.type.isLiveUndoable) {
      _localUndoHistory.add(_LocalUndoAction.event(event.id));
    }
    _state = _state.copyWith(
      events: List.unmodifiable(events),
      score: _reducer.reduce(events),
      shotLocations: List.unmodifiable(locations),
      locationSupplementWindow:
          command.shotLocation == null && opensSupplementWindow
          ? (event.side == null
                ? null
                : LocationSupplementWindow(
                    eventId: event.id,
                    side: event.side!,
                    points: event.points,
                    openedAtUtc: event.occurredAt.toUtc(),
                  ))
          : null,
      clearLocationSupplementWindow:
          command.shotLocation != null || closesSupplementWindow,
      currentPossession: _latestPossession(events),
      redFouls: _countFouls(events).red,
      blueFouls: _countFouls(events).blue,
    );
    notifyListeners();
    return true;
  }

  bool _recordLocalSemantic(String label) {
    return _recordLocalCommand(
      RecordMatchEventCommand(
        matchId: _state.matchId,
        type: EventKind.pause,
        side: null,
        points: 0,
        customLabel: label,
        occurredAt: _nowUtc().toUtc(),
      ),
    );
  }

  bool get _ordinaryActionBlocked =>
      _state.pendingLocation != null || _state.detailedShotDraft != null;

  MatchEvent? get _latestUnlocatedShot {
    final locatedIds = _state.shotLocations.map((item) => item.eventId).toSet();
    final nowUtc = _nowUtc().toUtc();
    for (final event in _state.events.reversed) {
      if (event.isDeleted || !_isScoringEvent(event)) {
        continue;
      }
      // Any newer scoring action, including a free throw, owns or closes the
      // supplement window for all older attempts.
      if (event.side == null || locatedIds.contains(event.id)) return null;
      if ((event.type != EventKind.fieldGoal &&
              event.type != EventKind.score &&
              event.type != EventKind.miss) ||
          !nowUtc.isBefore(
            event.occurredAt.toUtc().add(locationSupplementWindowDuration),
          )) {
        return null;
      }
      return event;
    }
    return null;
  }

  static bool _isScoringEvent(MatchEvent event) {
    return event.type == EventKind.score ||
        event.type == EventKind.fieldGoal ||
        event.type == EventKind.miss ||
        event.type == EventKind.freeThrow;
  }

  static TeamSide? _latestPossession(List<MatchEvent> events) {
    for (final event in events.reversed) {
      if (!event.isDeleted &&
          event.type == EventKind.possession &&
          event.side != null) {
        return event.side;
      }
    }
    return null;
  }

  static ({int red, int blue}) _countFouls(List<MatchEvent> events) {
    var red = 0;
    var blue = 0;
    for (final event in events) {
      if (event.isDeleted || event.type != MatchEventType.foul) {
        continue;
      }
      if (event.side == TeamSide.red) {
        red++;
      } else if (event.side == TeamSide.blue) {
        blue++;
      }
    }
    return (red: red, blue: blue);
  }
}

class _LocalUndoAction {
  const _LocalUndoAction.event(this.eventId) : locationId = null;

  const _LocalUndoAction.location({
    required this.eventId,
    required this.locationId,
  });

  final String eventId;
  final String? locationId;
}

class _QueuedScoringCommand {
  _QueuedScoringCommand({
    required this.command,
    required this.operation,
    required this.completer,
  });

  final MatchCommand command;
  final Future<MatchDetail> Function() operation;
  final Completer<bool> completer;
}

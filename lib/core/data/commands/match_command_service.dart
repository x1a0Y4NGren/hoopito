import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain_match;
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/possession_segment.dart'
    as domain_possession;
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/clock/clock_engine.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart' as domain;
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:uuid/uuid.dart';

export 'package:hoopito/core/domain/clock/clock_engine.dart'
    show ClockEngine, ClockProjection, ClockRecoveryReason, MatchClockEngine;
export 'package:hoopito/core/domain/entities/match_detail.dart'
    show
        MatchDecisionKind,
        MatchDecisionReason,
        MatchDecision,
        MatchRuleWarning;

/// Location supplements are accepted in the half-open interval
/// [openedAtUtc, openedAtUtc + ten seconds).
const Duration locationSupplementWindowDuration = Duration(seconds: 10);

/// Compatibility spelling used by scoring surfaces that describe the same
/// window as a deadline rather than a duration.
const Duration scoringLocationSupplementDuration =
    locationSupplementWindowDuration;
const Duration scoringSupplementWindowDuration =
    locationSupplementWindowDuration;

/// A test-only hook which is intentionally absent from the default service.
/// Hooks run after the business rows have been written but before the Drift
/// transaction callback returns, making rollback behavior observable without
/// weakening production error handling.
typedef MatchCommandFailureInjector =
    FutureOr<void> Function(MatchCommandFailurePoint point);

enum MatchCommandFailurePoint {
  afterMatchWritten,
  afterEventWritten,
  afterAuditWritten,
  afterLifecycleWritten,
  beforeCommit,
}

/// Immutable input shared by every command. IDs are generated when a command
/// is constructed, before a transaction is entered, so the same object can be
/// retried after a transient failure.
abstract class MatchCommand {
  MatchCommand({String? commandId}) : commandId = commandId ?? _newUuid();

  final String commandId;

  String get commandType;

  String get matchId;

  Map<String, Object?> get payload;

  String get fingerprint =>
      _fingerprint(<String, Object?>{'commandType': commandType, ...payload});
}

class StartMatchCommand extends MatchCommand {
  factory StartMatchCommand({
    String? commandId,
    String? matchId,
    required String redName,
    required String blueName,
    required RuleTemplate ruleTemplate,
    required RecordingMode recordingMode,
    TrackingCoverage trackingCoverage = TrackingCoverage.scoresOnly,
    ClockMode clockMode = ClockMode.countUp,
    int? regulationSeconds,
    bool timerEnabled = false,
    DateTime? createdAt,
    DateTime? startedAt,
    String? note,
    String? redParticipantId,
    String? blueParticipantId,
    String? redPlayerProfileId,
    String? bluePlayerProfileId,
    String? clockId,
  }) {
    final created = (createdAt ?? DateTime.now()).toUtc();
    return StartMatchCommand._(
      commandId: commandId,
      matchId: matchId,
      redName: redName,
      blueName: blueName,
      ruleTemplate: _copyRuleTemplate(ruleTemplate),
      recordingMode: recordingMode,
      trackingCoverage: trackingCoverage,
      clockMode: clockMode,
      regulationSeconds: regulationSeconds,
      timerEnabled: timerEnabled,
      createdAt: created,
      startedAt: (startedAt ?? created).toUtc(),
      note: note,
      redParticipantId: redParticipantId,
      blueParticipantId: blueParticipantId,
      redPlayerProfileId: redPlayerProfileId,
      bluePlayerProfileId: bluePlayerProfileId,
      clockId: clockId,
    );
  }

  StartMatchCommand._({
    super.commandId,
    String? matchId,
    required this.redName,
    required this.blueName,
    required this.ruleTemplate,
    required this.recordingMode,
    required this.trackingCoverage,
    required this.clockMode,
    required this.regulationSeconds,
    required this.timerEnabled,
    required this.createdAt,
    required this.startedAt,
    required this.note,
    String? redParticipantId,
    String? blueParticipantId,
    this.redPlayerProfileId,
    this.bluePlayerProfileId,
    String? clockId,
  }) : matchId = matchId ?? _newUuid(),
       redParticipantId = redParticipantId ?? _newUuid(),
       blueParticipantId = blueParticipantId ?? _newUuid(),
       clockId = clockId ?? _newUuid();

  @override
  final String matchId;
  final String redName;
  final String blueName;
  final RuleTemplate ruleTemplate;
  final RecordingMode recordingMode;
  final TrackingCoverage trackingCoverage;
  final ClockMode clockMode;
  final int? regulationSeconds;
  final bool timerEnabled;
  final DateTime createdAt;
  final DateTime startedAt;
  final String? note;
  final String redParticipantId;
  final String blueParticipantId;
  final String? redPlayerProfileId;
  final String? bluePlayerProfileId;
  final String clockId;

  @override
  String get commandType => 'start';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'redName': redName,
    'blueName': blueName,
    'ruleTemplate': _ruleTemplateJson(ruleTemplate),
    'recordingMode': recordingMode.name,
    'trackingCoverage': trackingCoverage.name,
    'clockMode': clockMode.name,
    'regulationSeconds': regulationSeconds,
    'timerEnabled': timerEnabled,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'note': note,
    'redParticipantId': redParticipantId,
    'blueParticipantId': blueParticipantId,
    'redPlayerProfileId': redPlayerProfileId,
    'bluePlayerProfileId': bluePlayerProfileId,
    'clockId': clockId,
  };
}

class MatchShotLocationInput {
  const MatchShotLocationInput({required this.x, required this.y, this.id});

  final double x;
  final double y;
  final String? id;

  Map<String, Object?> toJson({String? resolvedId}) => <String, Object?>{
    'id': resolvedId ?? id,
    'x': x,
    'y': y,
  };
}

class RecordMatchEventCommand extends MatchCommand {
  RecordMatchEventCommand({
    super.commandId,
    required this.matchId,
    String? eventId,
    this.type = EventKind.score,
    required this.side,
    required this.points,
    required DateTime occurredAt,
    this.outcome,
    this.note,
    this.customLabel,
    this.matchClockPositionSeconds,
    this.shotLocation,
    String? shotLocationId,
    String? auditId,
  }) : eventId = eventId ?? _newUuid(),
       occurredAt = occurredAt.toUtc(),
       shotLocationId = shotLocation == null
           ? null
           : (shotLocationId ?? shotLocation.id ?? _newUuid()),
       auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String eventId;
  final EventKind type;
  final TeamSide? side;
  final int points;
  final DateTime occurredAt;
  final ShotOutcome? outcome;
  final String? note;
  final String? customLabel;
  final int? matchClockPositionSeconds;
  final MatchShotLocationInput? shotLocation;
  final String? shotLocationId;
  final String auditId;

  @override
  String get commandType => 'record';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'type': type.name,
    'side': side?.name,
    'points': points,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'outcome': outcome?.name,
    'note': note,
    'customLabel': customLabel,
    'matchClockPositionSeconds': matchClockPositionSeconds,
    'shotLocation': shotLocation?.toJson(resolvedId: shotLocationId),
    'auditId': auditId,
  };
}

class ConfirmShotLocationCommand extends MatchCommand {
  ConfirmShotLocationCommand({
    super.commandId,
    required this.matchId,
    required this.eventId,
    required this.point,
    required DateTime requestedAtUtc,
    String? shotLocationId,
    String? auditId,
  }) : shotLocationId = shotLocationId ?? _newUuid(),
       requestedAtUtc = requestedAtUtc.toUtc(),
       auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String eventId;
  final CourtPoint point;

  /// Timestamp captured by the scoring surface when the user requested the
  /// location confirmation. The service enforces the ten-second deadline
  /// against this required command-boundary timestamp.
  final DateTime requestedAtUtc;
  final String shotLocationId;
  final String auditId;

  @override
  String get commandType => 'confirmShotLocation';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'shotLocationId': shotLocationId,
    'x': point.x,
    'y': point.y,
    'requestedAtUtc': requestedAtUtc.toIso8601String(),
    'auditId': auditId,
  };
}

/// Undoes the latest durable user-recorded action for a live match. The
/// service selects the action from persisted event/location rows and audit
/// chronology, so the command remains correct after a rebuild. The historical
/// command name is retained for receipt and backup compatibility.
class UndoLastScoringActionCommand extends MatchCommand {
  UndoLastScoringActionCommand({
    super.commandId,
    required this.matchId,
    this.reason,
    String? auditId,
  }) : auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String? reason;
  final String auditId;

  @override
  String get commandType => 'undoLastScoringAction';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'reason': reason,
    'auditId': auditId,
  };
}

typedef UndoScoringActionCommand = UndoLastScoringActionCommand;

class CorrectMatchEventCommand extends MatchCommand {
  CorrectMatchEventCommand({
    super.commandId,
    required this.matchId,
    required this.eventId,
    this.type,
    this.side,
    this.points,
    this.outcome,
    this.note,
    this.customLabel,
    this.matchClockPositionSeconds,
    this.reason,
    String? auditId,
  }) : auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String eventId;
  final EventKind? type;
  final TeamSide? side;
  final int? points;
  final ShotOutcome? outcome;
  final String? note;
  final String? customLabel;
  final int? matchClockPositionSeconds;
  final String? reason;
  final String auditId;

  @override
  String get commandType => 'correct';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'type': type?.name,
    'side': side?.name,
    'points': points,
    'outcome': outcome?.name,
    'note': note,
    'customLabel': customLabel,
    'matchClockPositionSeconds': matchClockPositionSeconds,
    'reason': reason,
    'auditId': auditId,
  };
}

class UndoMatchEventCommand extends MatchCommand {
  UndoMatchEventCommand({
    super.commandId,
    required this.matchId,
    required this.eventId,
    this.reason,
    String? auditId,
  }) : auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String eventId;
  final String? reason;
  final String auditId;

  @override
  String get commandType => 'undo';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'reason': reason,
    'auditId': auditId,
  };
}

/// Restores an event which was soft-deleted during replay review. The event
/// identity and all recorded facts are preserved; only [isDeleted] changes.
class RestoreMatchEventCommand extends MatchCommand {
  RestoreMatchEventCommand({
    super.commandId,
    required this.matchId,
    required this.eventId,
    this.reason,
    String? auditId,
  }) : auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String eventId;
  final String? reason;
  final String auditId;

  @override
  String get commandType => 'restore';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'reason': reason,
    'auditId': auditId,
  };
}

/// Moves the confirmed location attached to a field-goal attempt.
///
/// A location is corrected in place so its identity remains stable for
/// exports and audit readers. [newPoint], [location], and raw [x]/[y] are
/// compatibility spellings for callers that do not use the original
/// [point] name.
class CorrectShotLocationCommand extends MatchCommand {
  CorrectShotLocationCommand({
    super.commandId,
    required this.matchId,
    required this.eventId,
    CourtPoint? point,
    CourtPoint? newPoint,
    CourtPoint? location,
    double? x,
    double? y,
    String? shotLocationId,
    String? locationId,
    this.reason,
    String? auditId,
  }) : point =
           point ??
           newPoint ??
           location ??
           ((x != null && y != null)
               ? CourtPoint(x: x, y: y)
               : (throw ArgumentError(
                   'A corrected shot location is required.',
                 ))),
       shotLocationId = shotLocationId ?? locationId,
       auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String eventId;
  final CourtPoint point;
  final String? shotLocationId;
  final String? reason;
  final String auditId;

  /// Alias retained for domain callers that call the row a location.
  String? get locationId => shotLocationId;

  @override
  String get commandType => 'correctShotLocation';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'shotLocationId': shotLocationId,
    'x': point.x,
    'y': point.y,
    'reason': reason,
    'auditId': auditId,
  };
}

class PauseMatchCommand extends MatchCommand {
  PauseMatchCommand({
    super.commandId,
    required this.matchId,
    required DateTime occurredAt,
    String? eventId,
  }) : eventId =
           eventId ?? (commandId == null ? _newUuid() : '$commandId:event'),
       occurredAt = occurredAt.toUtc();

  @override
  final String matchId;
  final String eventId;
  final DateTime occurredAt;

  @override
  String get commandType => 'pause';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

class ResumeMatchCommand extends MatchCommand {
  ResumeMatchCommand({
    super.commandId,
    required this.matchId,
    required DateTime occurredAt,
    String? eventId,
  }) : eventId =
           eventId ?? (commandId == null ? _newUuid() : '$commandId:event'),
       occurredAt = occurredAt.toUtc();

  @override
  final String matchId;
  final String eventId;
  final DateTime occurredAt;

  @override
  String get commandType => 'resume';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

/// Acknowledges a blocking target/clock decision and resumes target play or
/// starts overtime. The persisted decision marker makes this command safe to
/// retry and prevents the same score projection from prompting repeatedly.
class ContinueMatchCommand extends MatchCommand {
  ContinueMatchCommand({
    super.commandId,
    required this.matchId,
    required DateTime occurredAt,
    String? eventId,
  }) : eventId =
           eventId ?? (commandId == null ? _newUuid() : '$commandId:event'),
       occurredAt = occurredAt.toUtc();

  @override
  final String matchId;
  final String eventId;
  final DateTime occurredAt;

  @override
  String get commandType => 'continue';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'eventId': eventId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };
}

class FinishMatchCommand extends MatchCommand {
  FinishMatchCommand({
    super.commandId,
    required this.matchId,
    required DateTime endedAt,
    bool? confirmFinalScore,
    bool? finalScoreConfirmed,
    bool? confirmedFinalScore,
    this.expectedRedScore,
    this.expectedBlueScore,
    this.trackingCoverage,
  }) : endedAt = endedAt.toUtc(),
       confirmFinalScore =
           confirmedFinalScore ??
           finalScoreConfirmed ??
           confirmFinalScore ??
           false;

  @override
  final String matchId;
  final DateTime endedAt;

  /// Finishing is an explicit score confirmation. Callers must opt in after
  /// presenting the final score to the user.
  final bool confirmFinalScore;

  /// The score the user confirmed in the finish dialog. When both values are
  /// supplied, finish behaves as a compare-and-set operation against the
  /// score read inside the same Drift transaction.
  final int? expectedRedScore;
  final int? expectedBlueScore;

  /// Optional user confirmation of how completely attempts were recorded.
  /// A null value retains the stored declaration and is deliberately omitted
  /// from [payload] so receipts created by older versions keep their original
  /// fingerprint.
  final TrackingCoverage? trackingCoverage;

  @override
  String get commandType => 'finish';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'endedAt': endedAt.toUtc().toIso8601String(),
    'confirmFinalScore': confirmFinalScore,
    'expectedRedScore': expectedRedScore,
    'expectedBlueScore': expectedBlueScore,
    if (trackingCoverage != null) 'trackingCoverage': trackingCoverage!.name,
  };
}

/// Explicitly corrects the persisted completeness declaration without
/// changing scoring events or participating in the live undo stack.
class SetTrackingCoverageCommand extends MatchCommand {
  SetTrackingCoverageCommand({
    super.commandId,
    required this.matchId,
    required this.trackingCoverage,
    required this.reason,
  });

  @override
  final String matchId;
  final TrackingCoverage trackingCoverage;
  final String reason;

  @override
  String get commandType => 'setTrackingCoverage';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'trackingCoverage': trackingCoverage.name,
    'reason': reason.trim(),
  };
}

/// Records a human possession decision. The command creates a replayable
/// possession event and atomically rotates the persisted segment.
class SetPossessionCommand extends MatchCommand {
  SetPossessionCommand({
    super.commandId,
    required this.matchId,
    required this.side,
    required this.reason,
    required DateTime occurredAt,
    String? eventId,
  }) : eventId = eventId ?? '${commandId ?? _newUuid()}:event',
       occurredAt = occurredAt.toUtc();

  @override
  final String matchId;
  final TeamSide side;
  final String reason;
  final DateTime occurredAt;
  final String eventId;

  @override
  String get commandType => 'setPossession';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'side': side.name,
    'reason': reason,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'eventId': eventId,
  };
}

class AbandonMatchCommand extends MatchCommand {
  AbandonMatchCommand({
    super.commandId,
    required this.matchId,
    required DateTime endedAt,
  }) : endedAt = endedAt.toUtc();

  @override
  final String matchId;
  final DateTime endedAt;

  @override
  String get commandType => 'abandon';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'endedAt': endedAt.toUtc().toIso8601String(),
  };
}

/// Reclaims a match imported from a backup after the user explicitly chooses
/// it from the imported-incomplete recovery surface. Imported rows are stored
/// as abandoned until this command succeeds, so they cannot steal the active
/// session during merge.
class ResumeImportedIncompleteMatchCommand extends MatchCommand {
  ResumeImportedIncompleteMatchCommand({
    super.commandId,
    required this.matchId,
    DateTime? claimedAtUtc,
  }) : claimedAtUtc = (claimedAtUtc ?? DateTime.now()).toUtc();

  @override
  final String matchId;
  final DateTime claimedAtUtc;

  @override
  String get commandType => 'resumeImportedIncomplete';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'claimedAtUtc': claimedAtUtc.toUtc().toIso8601String(),
  };
}

/// Links a match-only participant to a stable player profile after the match
/// is no longer active. The participant's name snapshot is intentionally not
/// rewritten, so historical displays remain faithful to what was recorded.
class LinkMatchParticipantCommand extends MatchCommand {
  LinkMatchParticipantCommand({
    super.commandId,
    required this.matchId,
    required this.participantId,
    required this.playerProfileId,
    this.reason,
    String? auditId,
  }) : auditId = auditId ?? _newUuid();

  @override
  final String matchId;
  final String participantId;
  final String playerProfileId;
  final String? reason;
  final String auditId;

  @override
  String get commandType => 'linkParticipant';

  @override
  Map<String, Object?> get payload => <String, Object?>{
    'commandId': commandId,
    'matchId': matchId,
    'participantId': participantId,
    'playerProfileId': playerProfileId,
    'reason': reason,
    'auditId': auditId,
  };
}

typedef StartCommand = StartMatchCommand;
typedef RecordCommand = RecordMatchEventCommand;
typedef RecordEventCommand = RecordMatchEventCommand;
typedef ConfirmLocationCommand = ConfirmShotLocationCommand;
typedef ConfirmShotCommand = ConfirmShotLocationCommand;
typedef CorrectCommand = CorrectMatchEventCommand;
typedef CorrectEventCommand = CorrectMatchEventCommand;
typedef UndoCommand = UndoMatchEventCommand;
typedef UndoEventCommand = UndoMatchEventCommand;
typedef RestoreCommand = RestoreMatchEventCommand;
typedef RestoreEventCommand = RestoreMatchEventCommand;
typedef RestoreMatchEvent = RestoreMatchEventCommand;
typedef CorrectLocationCommand = CorrectShotLocationCommand;
typedef CorrectFieldGoalLocationCommand = CorrectShotLocationCommand;
typedef CorrectConfirmedShotLocationCommand = CorrectShotLocationCommand;
typedef MoveShotLocationCommand = CorrectShotLocationCommand;
typedef PauseCommand = PauseMatchCommand;
typedef ResumeCommand = ResumeMatchCommand;
typedef ContinueCommand = ContinueMatchCommand;
typedef ContinuePlayCommand = ContinueMatchCommand;
typedef ContinueOvertimeCommand = ContinueMatchCommand;
typedef AcknowledgeDecisionCommand = ContinueMatchCommand;
typedef MatchClockService = MatchCommandService;
typedef FinishCommand = FinishMatchCommand;
typedef SetPossession = SetPossessionCommand;
typedef AbandonCommand = AbandonMatchCommand;
typedef ResumeImportedCommand = ResumeImportedIncompleteMatchCommand;
typedef LinkParticipantCommand = LinkMatchParticipantCommand;
typedef LinkPlayerCommand = LinkMatchParticipantCommand;
typedef MatchProjection = MatchDetail;
typedef CommittedMatchProjection = MatchDetail;

/// Base typed failure returned by every command operation.
class MatchCommandFailure implements Exception {
  MatchCommandFailure({
    required this.command,
    required this.message,
    required this.canRetry,
    this.projectionMatchId,
    this.cause,
    this.stackTrace,
  });

  final MatchCommand command;
  final String message;
  final bool canRetry;
  final String? projectionMatchId;
  final Object? cause;
  final StackTrace? stackTrace;
  MatchDetail? lastCommittedProjection;
  Future<MatchDetail> Function()? _retryAction;

  MatchDetail? get projection => lastCommittedProjection;

  bool get retryable => canRetry;

  MatchCommand get immutableCommand => command;

  Future<MatchDetail> retry() {
    if (!canRetry || _retryAction == null) {
      return Future<MatchDetail>.error(
        StateError('Command ${command.commandId} is not retryable.'),
      );
    }
    return _retryAction!();
  }

  @override
  String toString() => '$runtimeType: $message';
}

class CommandConflictFailure extends MatchCommandFailure {
  CommandConflictFailure({required super.command, super.projectionMatchId})
    : super(
        message:
            'Command ${command.commandId} was already committed with a '
            'different payload.',
        canRetry: false,
      );
}

class ActiveMatchConflictFailure extends MatchCommandFailure {
  ActiveMatchConflictFailure({
    required super.command,
    required super.projectionMatchId,
  }) : super(message: 'Another match is already active.', canRetry: false);
}

class CommandValidationFailure extends MatchCommandFailure {
  CommandValidationFailure({
    required super.command,
    required super.message,
    super.projectionMatchId,
  }) : super(canRetry: false);
}

class EndConditionFailure extends CommandValidationFailure {
  EndConditionFailure({
    required super.command,
    required this.decision,
    super.projectionMatchId,
  }) : super(message: decision.message);

  final MatchDecision decision;
}

/// The score changed after the user confirmed the finish dialog. The caller
/// should refresh the live projection and ask for confirmation again; the
/// active match is intentionally left untouched by this failure.
class FinalScoreConflictFailure extends CommandValidationFailure {
  FinalScoreConflictFailure({
    required super.command,
    required this.expectedRedScore,
    required this.expectedBlueScore,
    required this.actualRedScore,
    required this.actualBlueScore,
    super.projectionMatchId,
  }) : super(
         message:
             'Final score changed: expected $expectedRedScore : '
             '$expectedBlueScore, current $actualRedScore : $actualBlueScore.',
       );

  final int expectedRedScore;
  final int expectedBlueScore;
  final int actualRedScore;
  final int actualBlueScore;
}

class ClockRecoveryFailure extends CommandValidationFailure {
  ClockRecoveryFailure({
    required super.command,
    required this.recoveryMessage,
    super.projectionMatchId,
  }) : super(message: recoveryMessage);

  final String recoveryMessage;
}

class CommandTransactionFailure extends MatchCommandFailure {
  CommandTransactionFailure({
    required super.command,
    required super.message,
    required super.cause,
    required super.stackTrace,
    super.projectionMatchId,
  }) : super(canRetry: true);
}

typedef MatchCommandException = MatchCommandFailure;
typedef CommandFailure = MatchCommandFailure;

class _PossessionReplayState {
  _PossessionReplayState({
    required this.id,
    required this.matchId,
    required this.side,
    required this.startedAtEventId,
    required this.reason,
    required this.source,
  });

  final String id;
  final String matchId;
  final TeamSide side;
  final String startedAtEventId;
  final String? reason;
  final PossessionSource source;
  String? endedAtEventId;
}

enum _LiveUndoKind { event, location }

class _UndoableLiveAction {
  const _UndoableLiveAction.event({required this.event})
    : kind = _LiveUndoKind.event,
      location = null;

  const _UndoableLiveAction.location({
    required this.event,
    required this.location,
  }) : kind = _LiveUndoKind.location;

  final _LiveUndoKind kind;
  final MatchEventRow? event;
  final ShotLocation? location;
}

class MatchCommandService {
  MatchCommandService(
    this._database, {
    MatchCommandFailureInjector? failureInjector,
    FutureOr<void> Function()? failureHook,
    DateTime Function()? now,
  }) : _failureInjector = failureInjector,
       _failureHook = failureHook,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final MatchCommandFailureInjector? _failureInjector;
  final FutureOr<void> Function()? _failureHook;
  final DateTime Function() _now;

  /// Reconstructs a clock from persisted seconds plus its UTC anchor. A
  /// backward wall-clock move and a countdown expiry are normalized in one
  /// transaction so the same recovery state is not reported repeatedly.
  Future<ClockProjection?> readClock(String matchId, {DateTime? at}) async {
    return _database.transaction(() async {
      final row = await _clockRow(matchId);
      if (row == null) return null;
      final projection = ClockEngine().project(
        state: _clockState(row),
        now: (at ?? _now()).toUtc(),
      );
      if (projection.requiresPersistence) {
        await _persistClockProjection(projection);
      }
      return projection;
    });
  }

  Future<ClockProjection?> getClock(String matchId, {DateTime? at}) =>
      readClock(matchId, at: at);

  Future<ClockProjection?> clock(String matchId, {DateTime? at}) =>
      readClock(matchId, at: at);

  Future<MatchDetail> start(StartMatchCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        final active = await _activeRow();
        if (active != null) {
          throw ActiveMatchConflictFailure(
            command: command,
            projectionMatchId: active.matchId,
          );
        }
        final existing = await _matchRow(command.matchId);
        if (existing != null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Match ${command.matchId} already exists.',
            projectionMatchId: command.matchId,
          );
        }
        _validateStart(command);
        if (command.redPlayerProfileId != null &&
            await _playerRow(command.redPlayerProfileId!) == null) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Missing red player profile ${command.redPlayerProfileId}.',
            projectionMatchId: command.matchId,
          );
        }
        if (command.bluePlayerProfileId != null &&
            await _playerRow(command.bluePlayerProfileId!) == null) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Missing blue player profile ${command.bluePlayerProfileId}.',
            projectionMatchId: command.matchId,
          );
        }

        await _database
            .into(_database.matches)
            .insert(
              MatchesCompanion.insert(
                id: command.matchId,
                lifecycle: Value(MatchLifecycle.active.name),
                recordingMode: Value(command.recordingMode.name),
                trackingCoverage: Value(command.trackingCoverage.name),
                ruleTemplateJson: jsonEncode(
                  _ruleTemplateJson(command.ruleTemplate),
                ),
                createdAt: command.createdAt,
                startedAt: Value(command.startedAt),
                endedAt: const Value.absent(),
                timerEnabled: Value(command.timerEnabled),
                note: Value(command.note),
              ),
            );
        await _database
            .into(_database.matchParticipants)
            .insert(
              MatchParticipantsCompanion.insert(
                id: command.redParticipantId,
                matchId: command.matchId,
                side: TeamSide.red.name,
                nameSnapshot: command.redName.trim(),
                playerProfileId: Value(command.redPlayerProfileId),
              ),
            );
        await _database
            .into(_database.matchParticipants)
            .insert(
              MatchParticipantsCompanion.insert(
                id: command.blueParticipantId,
                matchId: command.matchId,
                side: TeamSide.blue.name,
                nameSnapshot: command.blueName.trim(),
                playerProfileId: Value(command.bluePlayerProfileId),
              ),
            );
        await _database
            .into(_database.matchClocks)
            .insert(
              MatchClocksCompanion.insert(
                id: command.clockId,
                matchId: command.matchId,
                mode: Value(command.clockMode.name),
                phase: Value(ClockPhase.regulation.name),
                accumulatedSeconds: const Value(0),
                runningSinceUtc: Value(
                  command.timerEnabled ? command.startedAt : null,
                ),
                // Count-up clocks may arrive from older callers with an
                // unused duration; the persisted clock contract keeps that
                // field null. A countdown duration is validated above.
                regulationSeconds: Value(
                  command.clockMode == ClockMode.countdown
                      ? command.regulationSeconds
                      : null,
                ),
              ),
            );
        await _database
            .into(_database.activeSessions)
            .insert(
              ActiveSessionsCompanion.insert(
                id: const Value('active'),
                matchId: command.matchId,
                claimedAtUtc: Value(command.startedAt),
              ),
            );
        await _inject(MatchCommandFailurePoint.afterMatchWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> record(RecordMatchEventCommand command) async {
    // Normalize clock boundaries before opening the event transaction. A
    // countdown expiry or wall-clock recovery must remain persisted even
    // though the attempted score is rejected.
    if (await _receipt(command.commandId) == null) {
      final precondition = await _preflightRecord(command);
      if (precondition != null) {
        precondition.lastCommittedProjection = await _projection(
          command.matchId,
        );
        throw precondition;
      }
    }
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireActiveMatch(command);
        await _guardInputClock(command);
        _validateRecord(command);
        final existing = await _eventRow(command.eventId);
        if (existing != null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} already exists.',
            projectionMatchId: command.matchId,
          );
        }
        final event = _eventFromCommand(command);
        await _database
            .into(_database.matchEvents)
            .insert(_eventCompanion(event));
        if (command.shotLocation != null) {
          await _database
              .into(_database.shotLocations)
              .insert(
                ShotLocationsCompanion.insert(
                  id: command.shotLocationId!,
                  matchId: command.matchId,
                  eventId: command.eventId,
                  x: command.shotLocation!.x,
                  y: command.shotLocation!.y,
                  isConfirmed: const Value(true),
                ),
              );
        }
        await _applyManualPossessionEvent(command);
        await _applyPossessionSuggestion(command);
        final after = <String, Object?>{
          ..._eventJsonFromEvent(event),
          if (command.shotLocation != null)
            'shotLocation': command.shotLocation!.toJson(
              resolvedId: command.shotLocationId,
            ),
        };
        await _writeAudit(
          id: command.auditId,
          matchId: command.matchId,
          targetId: command.eventId,
          action: 'create',
          before: const <String, Object?>{},
          after: after,
        );
        await _applyPostEventRules(command);
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> confirmShotLocation(ConfirmShotLocationCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireActiveMatch(command);
        final event = await _eventRow(command.eventId);
        if (event == null || event.matchId != command.matchId) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing event ${command.eventId}.',
            projectionMatchId: command.matchId,
          );
        }
        final supportsLocation =
            event.type == EventKind.fieldGoal.name ||
            event.type == EventKind.score.name ||
            event.type == EventKind.miss.name;
        if (event.isDeleted ||
            !supportsLocation ||
            (event.type == EventKind.fieldGoal.name &&
                event.outcome != ShotOutcome.made.name &&
                event.outcome != ShotOutcome.missed.name) ||
            (event.type == EventKind.score.name && event.points <= 0) ||
            (event.type == EventKind.miss.name && event.points != 0)) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Only a committed field-goal, score, or miss can receive a location.',
            projectionMatchId: command.matchId,
          );
        }
        final latestScoringEvent = await _latestScoringEvent(command.matchId);
        if (latestScoringEvent?.id != event.id) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Only the newest unlocated scoring event can receive a location.',
            projectionMatchId: command.matchId,
          );
        }
        final openedAtUtc = event.occurredAt.toUtc();
        final deadline = openedAtUtc.add(locationSupplementWindowDuration);
        final serverNowUtc = _now().toUtc();
        if (event.occurredAt.toUtc().isAfter(serverNowUtc) ||
            command.requestedAtUtc.isBefore(openedAtUtc) ||
            !command.requestedAtUtc.isBefore(deadline) ||
            !serverNowUtc.isBefore(deadline)) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Shot locations must be confirmed within ten seconds of the shot.',
            projectionMatchId: command.matchId,
          );
        }
        final existing = await _shotLocationForEvent(command.eventId);
        if (existing != null) {
          if (existing.isConfirmed) {
            throw CommandValidationFailure(
              command: command,
              message: 'Event ${command.eventId} already has a shot location.',
              projectionMatchId: command.matchId,
            );
          }
          // Undo keeps the row as durable history and merely unconfirms it.
          // Reconfirmation therefore updates the same identity instead of
          // allocating a second row (the event index is unique).
          await (_database.update(
            _database.shotLocations,
          )..where((row) => row.id.equals(existing.id))).write(
            ShotLocationsCompanion(
              x: Value(command.point.x),
              y: Value(command.point.y),
              isConfirmed: const Value(true),
            ),
          );
          await _writeAudit(
            id: command.auditId,
            matchId: command.matchId,
            targetId: command.eventId,
            action: 'locate',
            before: _shotLocationJson(existing),
            after: <String, Object?>{
              ..._shotLocationJson(existing),
              'x': command.point.x,
              'y': command.point.y,
              'isConfirmed': true,
            },
          );
          await _inject(MatchCommandFailurePoint.afterEventWritten);
          final result = await _writeReceipt(command);
          await _inject(MatchCommandFailurePoint.afterAuditWritten);
          await _inject(MatchCommandFailurePoint.beforeCommit);
          return result;
        }
        await _database
            .into(_database.shotLocations)
            .insert(
              ShotLocationsCompanion.insert(
                id: command.shotLocationId,
                matchId: command.matchId,
                eventId: command.eventId,
                x: command.point.x,
                y: command.point.y,
                isConfirmed: const Value(true),
              ),
            );
        await _writeAudit(
          id: command.auditId,
          matchId: command.matchId,
          targetId: command.eventId,
          action: 'locate',
          before: const <String, Object?>{},
          after: <String, Object?>{
            'eventId': command.eventId,
            'shotLocationId': command.shotLocationId,
            'x': command.point.x,
            'y': command.point.y,
            'isConfirmed': true,
          },
        );
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  /// Undoes the latest user-recorded live action using audit chronology.
  ///
  /// A location supplement is its own action, so it is unconfirmed first and
  /// the score remains intact. A court-first event/location write is one
  /// `create` action and is undone atomically. Timer, finish, semantic, and
  /// replay-only edits never enter the candidate set. Fouls, possession,
  /// notes, and custom events do participate and cannot be skipped in favor
  /// of an older score.
  Future<MatchDetail> undoLastScoringAction(
    UndoLastScoringActionCommand command,
  ) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        // Live scoring undo is a mutation of the active match state. A
        // finished/archived projection is durable history and cannot be
        // reopened through this command.
        await _requireActiveMatch(command);
        final selected = await _latestLiveUndoAction(command.matchId);
        if (selected == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'There is no committed match action to undo.',
            projectionMatchId: command.matchId,
          );
        }

        if (selected.kind == _LiveUndoKind.location) {
          final location = selected.location!;
          final before = _shotLocationJson(location);
          await (_database.update(_database.shotLocations)
                ..where((row) => row.id.equals(location.id)))
              .write(const ShotLocationsCompanion(isConfirmed: Value(false)));
          await _writeAudit(
            id: command.auditId,
            matchId: command.matchId,
            targetId: location.eventId,
            action: 'undo',
            before: before,
            after: <String, Object?>{...before, 'isConfirmed': false},
            reason: command.reason,
          );
        } else {
          final event = selected.event!;
          final beforeProjection = await _projectionInTransaction(
            command.matchId,
          );
          final before = _eventJson(event);
          final after = <String, Object?>{...before, 'isDeleted': true};
          await (_database.update(_database.matchEvents)
                ..where((row) => row.id.equals(event.id)))
              .write(const MatchEventsCompanion(isDeleted: Value(true)));
          final locations = await (_database.select(
            _database.shotLocations,
          )..where((row) => row.eventId.equals(event.id))).get();
          final confirmedLocations = locations
              .where((location) => location.isConfirmed)
              .toList(growable: false);
          if (confirmedLocations.isNotEmpty) {
            await (_database.update(_database.shotLocations)
                  ..where((row) => row.eventId.equals(event.id)))
                .write(const ShotLocationsCompanion(isConfirmed: Value(false)));
            after['shotLocations'] = [
              for (final location in confirmedLocations)
                <String, Object?>{
                  ..._shotLocationJson(location),
                  'isConfirmed': false,
                },
            ];
            if (confirmedLocations.length == 1) {
              after['shotLocation'] =
                  (after['shotLocations'] as List<Object?>).first;
            }
          }
          await _writeAudit(
            id: command.auditId,
            matchId: command.matchId,
            targetId: event.id,
            action: 'undo',
            before: before,
            after: after,
            reason: command.reason,
          );
          await _recalculatePossessionSuggestions(command.matchId);
          final eventType = EventKind.values.byName(event.type);
          if (_eventTypeChangesScore(eventType)) {
            await _restoreDecisionStateAfterScoringUndo(
              command,
              selectedEvent: event,
            );
          }
          final afterProjection = await _projectionInTransaction(
            command.matchId,
          );
          await _applyPostScoreRules(
            command.matchId,
            scoreChanged: _scoresChanged(beforeProjection, afterProjection),
            decisionEventId: '${command.commandId}:decision',
            scoringEventId: event.id,
          );
        }

        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> undoLastScoringActionCommitted(
    UndoLastScoringActionCommand command,
  ) => undoLastScoringAction(command);

  Future<MatchDetail> correct(CorrectMatchEventCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireReplayEditableMatch(command);
        final before = await _eventRow(command.eventId);
        if (before == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing event ${command.eventId}.',
            projectionMatchId: command.matchId,
          );
        }
        if (before.matchId != command.matchId) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} belongs to another match.',
            projectionMatchId: before.matchId,
          );
        }
        final beforeProjection = await _projectionInTransaction(
          command.matchId,
        );
        await _guardEventMutation(command, before);
        if (before.isDeleted) {
          throw CommandValidationFailure(
            command: command,
            message: 'Deleted events must be restored before correction.',
            projectionMatchId: command.matchId,
          );
        }
        late final MatchEvent replacement;
        try {
          replacement = _correctedEvent(before, command);
        } on ArgumentError catch (error) {
          throw CommandValidationFailure(
            command: command,
            message: error.message?.toString() ?? error.toString(),
            projectionMatchId: command.matchId,
          );
        }
        if (replacement.type == EventKind.score &&
            replacement.outcome != null &&
            replacement.outcome != ShotOutcome.made) {
          throw CommandValidationFailure(
            command: command,
            message: 'Score events must have a made outcome.',
            projectionMatchId: command.matchId,
          );
        }
        final beforeJson = _eventJson(before);
        final afterJson = _eventJsonFromEvent(replacement);
        final existingLocation = await _shotLocationForEvent(command.eventId);
        if (existingLocation != null &&
            !_eventTypeSupportsLocation(replacement.type)) {
          await (_database.delete(
            _database.shotLocations,
          )..where((location) => location.id.equals(existingLocation.id))).go();
          await _writeAudit(
            id: '${command.auditId}:location',
            matchId: command.matchId,
            targetId: command.eventId,
            action: 'locate',
            before: _shotLocationJson(existingLocation),
            after: const <String, Object?>{},
            reason: command.reason,
          );
        }
        await (_database.update(_database.matchEvents)
              ..where((event) => event.id.equals(command.eventId)))
            .write(_eventCompanion(replacement, includeId: false));
        await _writeAudit(
          id: command.auditId,
          matchId: command.matchId,
          targetId: command.eventId,
          action: 'edit',
          before: beforeJson,
          after: afterJson,
          reason: command.reason,
        );
        await _recalculatePossessionSuggestions(command.matchId);
        final afterProjection = await _projectionInTransaction(command.matchId);
        await _applyPostScoreRules(
          command.matchId,
          scoreChanged: _scoresChanged(beforeProjection, afterProjection),
          decisionEventId: '${command.commandId}:decision',
          scoringEventId: command.eventId,
        );
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> undo(UndoMatchEventCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireReplayEditableMatch(command);
        final before = await _eventRow(command.eventId);
        if (before == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing event ${command.eventId}.',
            projectionMatchId: command.matchId,
          );
        }
        if (before.matchId != command.matchId) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} belongs to another match.',
            projectionMatchId: before.matchId,
          );
        }
        final beforeProjection = await _projectionInTransaction(
          command.matchId,
        );
        await _guardEventMutation(command, before);
        if (before.isDeleted) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} is already deleted.',
            projectionMatchId: command.matchId,
          );
        }
        final beforeJson = _eventJson(before);
        final afterJson = <String, Object?>{...beforeJson, 'isDeleted': true};
        await (_database.update(_database.matchEvents)
              ..where((event) => event.id.equals(command.eventId)))
            .write(const MatchEventsCompanion(isDeleted: Value(true)));
        await _writeAudit(
          id: command.auditId,
          matchId: command.matchId,
          targetId: command.eventId,
          action: 'undo',
          before: beforeJson,
          after: afterJson,
          reason: command.reason,
        );
        await _recalculatePossessionSuggestions(command.matchId);
        final afterProjection = await _projectionInTransaction(command.matchId);
        await _applyPostScoreRules(
          command.matchId,
          scoreChanged: _scoresChanged(beforeProjection, afterProjection),
          decisionEventId: '${command.commandId}:decision',
          scoringEventId: command.eventId,
        );
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  /// Restores a soft-deleted event and rebuilds the derived score and
  /// possession projection in the same transaction.
  Future<MatchDetail> restore(RestoreMatchEventCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireReplayEditableMatch(command);
        final before = await _eventRow(command.eventId);
        if (before == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing event ${command.eventId}.',
            projectionMatchId: command.matchId,
          );
        }
        if (before.matchId != command.matchId) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} belongs to another match.',
            projectionMatchId: before.matchId,
          );
        }
        await _guardEventMutation(command, before);
        if (!before.isDeleted) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} is not deleted.',
            projectionMatchId: command.matchId,
          );
        }
        final beforeProjection = await _projectionInTransaction(
          command.matchId,
        );
        final beforeJson = _eventJson(before);
        await (_database.update(_database.matchEvents)
              ..where((event) => event.id.equals(command.eventId)))
            .write(const MatchEventsCompanion(isDeleted: Value(false)));
        await _restoreManualPossessionSegment(before);
        await _writeAudit(
          id: command.auditId,
          matchId: command.matchId,
          targetId: command.eventId,
          action: 'restore',
          before: beforeJson,
          after: <String, Object?>{...beforeJson, 'isDeleted': false},
          reason: command.reason,
        );
        await _recalculatePossessionSuggestions(command.matchId);
        final afterProjection = await _projectionInTransaction(command.matchId);
        await _applyPostScoreRules(
          command.matchId,
          scoreChanged: _scoresChanged(beforeProjection, afterProjection),
          decisionEventId: '${command.commandId}:decision',
          scoringEventId: command.eventId,
        );
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  /// Corrects an existing confirmed scoring location without changing its row
  /// identity or the event's score contribution.
  Future<MatchDetail> correctShotLocation(CorrectShotLocationCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireReplayEditableMatch(command);
        final event = await _eventRow(command.eventId);
        if (event == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing event ${command.eventId}.',
            projectionMatchId: command.matchId,
          );
        }
        if (event.matchId != command.matchId) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} belongs to another match.',
            projectionMatchId: event.matchId,
          );
        }
        if (event.isDeleted) {
          throw CommandValidationFailure(
            command: command,
            message: 'Deleted events cannot receive a location correction.',
            projectionMatchId: command.matchId,
          );
        }
        final eventType = EventKind.values.byName(event.type);
        if (!_eventTypeSupportsLocation(eventType) ||
            (eventType == EventKind.fieldGoal &&
                event.outcome != ShotOutcome.made.name &&
                event.outcome != ShotOutcome.missed.name) ||
            (eventType == EventKind.score && event.points <= 0) ||
            (eventType == EventKind.miss && event.points != 0)) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Only a confirmed field-goal, score, or miss can move its location.',
            projectionMatchId: command.matchId,
          );
        }
        final location = await _shotLocationForEvent(command.eventId);
        if (location == null || location.matchId != command.matchId) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing shot location for event ${command.eventId}.',
            projectionMatchId: command.matchId,
          );
        }
        if (!location.isConfirmed) {
          throw CommandValidationFailure(
            command: command,
            message: 'Only confirmed shot locations can be corrected.',
            projectionMatchId: command.matchId,
          );
        }
        if (command.shotLocationId != null &&
            command.shotLocationId != location.id) {
          throw CommandValidationFailure(
            command: command,
            message: 'Shot location does not belong to the event.',
            projectionMatchId: command.matchId,
          );
        }
        final before = _shotLocationJson(location);
        final after = <String, Object?>{
          ...before,
          'x': command.point.x,
          'y': command.point.y,
        };
        await (_database.update(
          _database.shotLocations,
        )..where((row) => row.id.equals(location.id))).write(
          ShotLocationsCompanion(
            x: Value(command.point.x),
            y: Value(command.point.y),
          ),
        );
        await _writeAudit(
          id: command.auditId,
          matchId: command.matchId,
          targetId: command.eventId,
          action: 'edit',
          before: before,
          after: after,
          reason: command.reason,
        );
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> pause(PauseMatchCommand command) async {
    final failure = await _preflightSemantic(command, label: 'pause');
    if (failure != null) {
      failure.lastCommittedProjection = await _projection(command.matchId);
      throw failure;
    }
    return _recordSemantic(command, label: 'pause');
  }

  Future<MatchDetail> resume(ResumeMatchCommand command) async {
    final failure = await _preflightSemantic(command, label: 'resume');
    if (failure != null) {
      failure.lastCommittedProjection = await _projection(command.matchId);
      throw failure;
    }
    return _recordSemantic(command, label: 'resume');
  }

  Future<MatchDetail> continueMatch(ContinueMatchCommand command) {
    return _continueDecision(command);
  }

  Future<MatchDetail> continuePlay(ContinueMatchCommand command) {
    return continueMatch(command);
  }

  Future<MatchDetail> acknowledgeDecision(ContinueMatchCommand command) {
    return continueMatch(command);
  }

  Future<MatchDetail> finish(FinishMatchCommand command) {
    return _complete(command, MatchLifecycle.finished);
  }

  Future<MatchDetail> setTrackingCoverage(SetTrackingCoverageCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        final row = await _matchRow(command.matchId);
        if (row == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing match ${command.matchId}.',
          );
        }
        final lifecycle = MatchLifecycle.values.byName(row.lifecycle);
        if (lifecycle == MatchLifecycle.active) {
          await _requireActiveMatch(command);
        }
        if (lifecycle != MatchLifecycle.active &&
            lifecycle != MatchLifecycle.finished &&
            lifecycle != MatchLifecycle.archived) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Tracking coverage can only be corrected for a playable match.',
            projectionMatchId: command.matchId,
          );
        }
        if (command.reason.trim().isEmpty) {
          throw CommandValidationFailure(
            command: command,
            message: 'A tracking coverage correction reason is required.',
            projectionMatchId: command.matchId,
          );
        }
        final current = TrackingCoverage.values.byName(row.trackingCoverage);
        if (current != command.trackingCoverage) {
          await (_database.update(
            _database.matches,
          )..where((match) => match.id.equals(command.matchId))).write(
            MatchesCompanion(
              trackingCoverage: Value(command.trackingCoverage.name),
            ),
          );
          await _writeAudit(
            id: '${command.commandId}:audit',
            matchId: command.matchId,
            targetId: command.matchId,
            action: 'edit',
            before: <String, Object?>{
              'matchId': command.matchId,
              'trackingCoverage': current.name,
            },
            after: <String, Object?>{
              'matchId': command.matchId,
              'trackingCoverage': command.trackingCoverage.name,
            },
            reason: command.reason,
          );
        }
        await _inject(MatchCommandFailurePoint.afterLifecycleWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> setPossession(SetPossessionCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireActiveMatch(command);
        if (command.reason.trim().isEmpty) {
          throw CommandValidationFailure(
            command: command,
            message: 'A possession correction reason is required.',
            projectionMatchId: command.matchId,
          );
        }
        final latestEvent =
            await (_database.select(_database.matchEvents)
                  ..where(
                    (event) =>
                        event.matchId.equals(command.matchId) &
                        event.isDeleted.equals(false),
                  )
                  ..orderBy([
                    (event) => OrderingTerm.desc(event.occurredAt),
                    (_) =>
                        OrderingTerm.desc(const CustomExpression<int>('rowid')),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        if (latestEvent != null &&
            command.occurredAt.isBefore(latestEvent.occurredAt)) {
          throw CommandValidationFailure(
            command: command,
            message:
                'A possession boundary cannot precede the latest match event.',
            projectionMatchId: command.matchId,
          );
        }
        if (await _eventRow(command.eventId) != null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Event ${command.eventId} already exists.',
            projectionMatchId: command.matchId,
          );
        }

        final open =
            await (_database.select(_database.possessionSegments)
                  ..where(
                    (segment) =>
                        segment.matchId.equals(command.matchId) &
                        segment.endedAtEventId.isNull(),
                  )
                  ..orderBy([
                    (_) =>
                        OrderingTerm.desc(const CustomExpression<int>('rowid')),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        final before = open == null
            ? const <String, Object?>{}
            : _possessionJson(open);
        await _database
            .into(_database.matchEvents)
            .insert(
              MatchEventsCompanion.insert(
                id: command.eventId,
                matchId: command.matchId,
                type: EventKind.possession.name,
                side: Value(command.side.name),
                points: const Value(0),
                occurredAt: command.occurredAt,
                note: Value(command.reason),
              ),
            );
        if (open != null &&
            open.side == command.side.name &&
            open.source == PossessionSource.manual.name) {
          final unchanged = _possessionJson(open);
          await _writeAudit(
            id: '${command.commandId}:audit',
            matchId: command.matchId,
            targetId: open.id,
            action: 'possession',
            before: before,
            after: unchanged,
            reason: command.reason,
          );
          await _inject(MatchCommandFailurePoint.afterEventWritten);
          final result = await _writeReceipt(command);
          await _inject(MatchCommandFailurePoint.afterAuditWritten);
          await _inject(MatchCommandFailurePoint.beforeCommit);
          return result;
        }
        if (open != null) {
          await (_database.update(
            _database.possessionSegments,
          )..where((segment) => segment.id.equals(open.id))).write(
            PossessionSegmentsCompanion(endedAtEventId: Value(command.eventId)),
          );
        }
        final next = PossessionSegmentsCompanion.insert(
          id: '${command.commandId}:segment',
          matchId: command.matchId,
          side: command.side.name,
          startedAtEventId: command.eventId,
          reason: Value(command.reason),
          source: Value(PossessionSource.manual.name),
        );
        await _database.into(_database.possessionSegments).insert(next);
        final after = <String, Object?>{
          'id': '${command.commandId}:segment',
          'matchId': command.matchId,
          'side': command.side.name,
          'startedAtEventId': command.eventId,
          'reason': command.reason,
          'source': PossessionSource.manual.name,
        };
        await _writeAudit(
          id: '${command.commandId}:audit',
          matchId: command.matchId,
          targetId: '${command.commandId}:segment',
          action: 'possession',
          before: before,
          after: after,
          reason: command.reason,
        );
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> abandon(AbandonMatchCommand command) {
    return _complete(command, MatchLifecycle.abandoned);
  }

  /// Restores one imported unfinished graph into the live scoring boundary.
  ///
  /// The active-session cardinality check and lifecycle transition share one
  /// Drift transaction. A concurrent/new active match therefore causes the
  /// entire restore to roll back, leaving the imported record discoverable for
  /// a later retry.
  Future<MatchDetail> resumeImportedIncomplete(
    ResumeImportedIncompleteMatchCommand command,
  ) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        final row = await _matchRow(command.matchId);
        if (row == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing imported match ${command.matchId}.',
          );
        }
        if (row.lifecycle != MatchLifecycle.abandoned.name ||
            !_isImportedIncompleteNote(row.note)) {
          throw CommandValidationFailure(
            command: command,
            message:
                'Match ${command.matchId} is not an imported-incomplete record.',
            projectionMatchId: command.matchId,
          );
        }
        final active = await _activeRow();
        if (active != null) {
          throw ActiveMatchConflictFailure(
            command: command,
            projectionMatchId: active.matchId,
          );
        }

        final before = <String, Object?>{
          'id': row.id,
          'lifecycle': row.lifecycle,
          'endedAt': row.endedAt?.toUtc().toIso8601String(),
          'note': row.note,
        };
        final restoredNote = _removeImportedIncompleteMarker(row.note);
        await (_database.update(
          _database.matches,
        )..where((match) => match.id.equals(command.matchId))).write(
          MatchesCompanion(
            lifecycle: Value(MatchLifecycle.active.name),
            endedAt: Value(null),
            note: Value(restoredNote),
          ),
        );
        await _database
            .into(_database.activeSessions)
            .insert(
              ActiveSessionsCompanion.insert(
                id: const Value('active'),
                matchId: command.matchId,
                claimedAtUtc: Value(command.claimedAtUtc),
              ),
            );
        await _writeAudit(
          id: '${command.commandId}:import',
          matchId: command.matchId,
          targetId: command.matchId,
          action: 'restore',
          before: before,
          after: <String, Object?>{
            ...before,
            'lifecycle': MatchLifecycle.active.name,
            'endedAt': null,
            'note': restoredNote,
          },
          reason: 'resume-imported-incomplete',
        );
        await _inject(MatchCommandFailurePoint.afterLifecycleWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> linkParticipant(LinkMatchParticipantCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;

        final match = await _matchRow(command.matchId);
        if (match == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing match ${command.matchId}.',
          );
        }
        final lifecycle = MatchLifecycle.values.byName(match.lifecycle);
        if (lifecycle != MatchLifecycle.finished &&
            lifecycle != MatchLifecycle.archived) {
          throw CommandValidationFailure(
            command: command,
            message: 'Only completed matches can link participants.',
            projectionMatchId: command.matchId,
          );
        }
        if (command.playerProfileId.trim().isEmpty) {
          throw CommandValidationFailure(
            command: command,
            message: 'A player profile is required.',
            projectionMatchId: command.matchId,
          );
        }

        final participant = await _participantRow(
          command.matchId,
          command.participantId,
        );
        if (participant == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Participant does not belong to this match.',
            projectionMatchId: command.matchId,
          );
        }
        if (participant.playerProfileId != null) {
          throw CommandValidationFailure(
            command: command,
            message: 'This participant is already linked to a profile.',
            projectionMatchId: command.matchId,
          );
        }
        if (await _playerRow(command.playerProfileId) == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing player profile ${command.playerProfileId}.',
            projectionMatchId: command.matchId,
          );
        }
        final otherParticipants =
            await (_database.select(_database.matchParticipants)..where(
                  (row) =>
                      row.matchId.equals(command.matchId) &
                      row.playerProfileId.equals(command.playerProfileId) &
                      row.id.isNotIn([command.participantId]),
                ))
                .get();
        if (otherParticipants.isNotEmpty) {
          throw CommandValidationFailure(
            command: command,
            message: 'That profile is already used by the other participant.',
            projectionMatchId: command.matchId,
          );
        }

        final before = _participantJson(participant);
        await (_database.update(_database.matchParticipants)..where(
              (row) =>
                  row.id.equals(command.participantId) &
                  row.matchId.equals(command.matchId),
            ))
            .write(
              MatchParticipantsCompanion(
                playerProfileId: Value(command.playerProfileId),
              ),
            );
        final updated = await _participantRow(
          command.matchId,
          command.participantId,
        );
        if (updated == null) {
          throw StateError('Linked participant disappeared before commit.');
        }
        await _writeAudit(
          id: command.auditId,
          matchId: command.matchId,
          targetId: command.participantId,
          // Participant linking is a participant edit in the existing audit
          // vocabulary. Reusing `edit` keeps older replay/backup readers able
          // to decode the row while the before/after payload identifies the
          // exact link operation.
          action: 'edit',
          before: before,
          after: _participantJson(updated),
          reason: command.reason,
        );
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  // Named aliases keep the command boundary easy to discover for consumers
  // while all paths still execute through the same transactional methods.
  Future<MatchDetail> startMatch(StartMatchCommand command) => start(command);

  Future<MatchDetail> recordEvent(RecordMatchEventCommand command) =>
      record(command);

  Future<MatchDetail> confirmLocation(ConfirmShotLocationCommand command) =>
      confirmShotLocation(command);

  Future<MatchDetail> correctEvent(CorrectMatchEventCommand command) =>
      correct(command);

  Future<MatchDetail> undoEvent(UndoMatchEventCommand command) => undo(command);

  Future<MatchDetail> undoScoringAction(UndoLastScoringActionCommand command) =>
      undoLastScoringAction(command);

  Future<MatchDetail> restoreEvent(RestoreMatchEventCommand command) =>
      restore(command);

  Future<MatchDetail> restoreMatchEvent(RestoreMatchEventCommand command) =>
      restore(command);

  Future<MatchDetail> correctLocation(CorrectShotLocationCommand command) =>
      correctShotLocation(command);

  Future<MatchDetail> correctFieldGoalLocation(
    CorrectShotLocationCommand command,
  ) => correctShotLocation(command);

  Future<MatchDetail> moveShotLocation(CorrectShotLocationCommand command) =>
      correctShotLocation(command);

  Future<MatchDetail> pauseMatch(PauseMatchCommand command) => pause(command);

  Future<MatchDetail> resumeMatch(ResumeMatchCommand command) =>
      resume(command);

  Future<MatchDetail> continueMatchPlay(ContinueMatchCommand command) =>
      continueMatch(command);

  Future<MatchDetail> finishMatch(FinishMatchCommand command) =>
      finish(command);

  Future<MatchDetail> setPossessionSegment(SetPossessionCommand command) =>
      setPossession(command);

  Future<MatchDetail> abandonMatch(AbandonMatchCommand command) =>
      abandon(command);

  Future<MatchDetail> linkMatchParticipant(
    LinkMatchParticipantCommand command,
  ) => linkParticipant(command);

  Future<MatchDetail> _recordSemantic(
    MatchCommand command, {
    required String label,
  }) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireActiveMatch(command);
        final row = await _clockRow(command.matchId);
        if (row == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing match clock for ${command.matchId}.',
            projectionMatchId: command.matchId,
          );
        }
        final now = _now().toUtc();
        final matchRow = await _matchRow(command.matchId);
        final timerEnabled = matchRow?.timerEnabled ?? false;
        final clockProjection = ClockEngine().project(
          state: _clockState(row),
          now: now,
        );
        if (clockProjection.requiresPersistence) {
          await _persistClockProjection(clockProjection);
        }
        final latestSemantic = await _latestSemanticLabel(command.matchId);
        final isPaused = latestSemantic == 'pause';
        final detail = await _projectionInTransaction(command.matchId);
        final pendingDecision = detail?.decision;
        if (pendingDecision != null) {
          throw EndConditionFailure(
            command: command,
            decision: pendingDecision,
            projectionMatchId: command.matchId,
          );
        }
        if ((label == 'pause' && isPaused) ||
            (label == 'resume' && !isPaused)) {
          throw CommandValidationFailure(
            command: command,
            message: label == 'pause'
                ? 'Match ${command.matchId} is already paused.'
                : 'Match ${command.matchId} is not paused.',
            projectionMatchId: command.matchId,
          );
        }
        if (timerEnabled &&
            label == 'pause' &&
            clockProjection.runningSinceUtc == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Match ${command.matchId} is not running.',
            projectionMatchId: command.matchId,
          );
        }
        if (timerEnabled &&
            label == 'resume' &&
            clockProjection.runningSinceUtc != null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Match ${command.matchId} is already running.',
            projectionMatchId: command.matchId,
          );
        }
        if (label == 'resume' &&
            clockProjection.phase == ClockPhase.regulationExpired) {
          final detail = await _projectionInTransaction(command.matchId);
          final decision =
              detail?.decision ??
              _decisionForScores(
                reason: MatchDecisionReason.regulationExpired,
                detail: detail,
              );
          throw EndConditionFailure(
            command: command,
            decision: decision,
            projectionMatchId: command.matchId,
          );
        }
        final eventId = switch (command) {
          PauseMatchCommand(:final eventId) => eventId,
          ResumeMatchCommand(:final eventId) => eventId,
          _ => throw StateError('Unsupported semantic command.'),
        };
        final occurredAt = switch (command) {
          PauseMatchCommand(:final occurredAt) => occurredAt,
          ResumeMatchCommand(:final occurredAt) => occurredAt,
          _ => _now().toUtc(),
        };
        final beforeClock = _clockJson(_clockState(row));
        final nextClock = label == 'pause' || !timerEnabled
            ? clockProjection.normalizedState.copyWith(runningSinceUtc: null)
            : clockProjection.normalizedState.copyWith(runningSinceUtc: now);
        await _updateClock(nextClock);
        await _database
            .into(_database.matchEvents)
            .insert(
              MatchEventsCompanion.insert(
                id: eventId,
                matchId: command.matchId,
                type: EventKind.pause.name,
                points: const Value(0),
                occurredAt: occurredAt,
                customLabel: Value(label),
              ),
            );
        await _writeAudit(
          id: _newUuid(),
          matchId: command.matchId,
          targetId: row.id,
          action: 'edit',
          before: beforeClock,
          after: _clockJson(nextClock),
          reason: 'clock-$label',
        );
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> _continueDecision(ContinueMatchCommand command) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        await _requireActiveMatch(command);
        final row = await _clockRow(command.matchId);
        if (row == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing match clock for ${command.matchId}.',
            projectionMatchId: command.matchId,
          );
        }

        final now = _now().toUtc();
        final matchRow = await _matchRow(command.matchId);
        final timerEnabled = matchRow?.timerEnabled ?? false;
        final clockProjection = ClockEngine().project(
          state: _clockState(row),
          now: now,
        );
        if (clockProjection.requiresPersistence) {
          await _persistClockProjection(clockProjection);
        }
        final detail = await _projectionInTransaction(command.matchId);
        final decision =
            detail?.decision ??
            _decisionFromLabel(
              await _latestDecisionLabel(command.matchId),
              redScore: detail?.redScore ?? 0,
              blueScore: detail?.blueScore ?? 0,
            );
        if (decision == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'There is no pending match decision to continue.',
            projectionMatchId: command.matchId,
          );
        }

        final beforeClock = _clockJson(clockProjection.normalizedState);
        final ClockState nextClock;
        final String semanticLabel;
        if (decision.reason == MatchDecisionReason.regulationExpired ||
            clockProjection.phase == ClockPhase.regulationExpired) {
          nextClock = clockProjection.normalizedState.copyWith(
            phase: ClockPhase.overtime,
            accumulatedSeconds: 0,
            runningSinceUtc: timerEnabled ? now : null,
          );
          semanticLabel = 'continueOvertime';
        } else {
          nextClock = clockProjection.normalizedState.copyWith(
            runningSinceUtc: timerEnabled ? now : null,
          );
          semanticLabel = 'continueTarget';
        }
        await _updateClock(nextClock);
        await _database
            .into(_database.matchEvents)
            .insert(
              MatchEventsCompanion.insert(
                id: command.eventId,
                matchId: command.matchId,
                type: EventKind.pause.name,
                points: const Value(0),
                occurredAt: command.occurredAt,
                customLabel: Value(semanticLabel),
              ),
            );
        await _writeAudit(
          id: _newUuid(),
          matchId: command.matchId,
          targetId: row.id,
          action: 'edit',
          before: beforeClock,
          after: _clockJson(nextClock),
          reason: semanticLabel,
        );
        await _inject(MatchCommandFailurePoint.afterEventWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> _complete(
    MatchCommand command,
    MatchLifecycle lifecycle,
  ) {
    return _execute(command, () {
      return _database.transaction(() async {
        final duplicate = await _returnForDuplicate(command);
        if (duplicate != null) return duplicate;
        final row = await _matchRow(command.matchId);
        if (row == null) {
          throw CommandValidationFailure(
            command: command,
            message: 'Missing match ${command.matchId}.',
          );
        }
        if (row.lifecycle != MatchLifecycle.active.name) {
          throw CommandValidationFailure(
            command: command,
            message: 'Only an active match can become terminal.',
            projectionMatchId: command.matchId,
          );
        }
        final active = await _activeRow();
        if (active?.matchId != command.matchId) {
          throw ActiveMatchConflictFailure(
            command: command,
            projectionMatchId: active?.matchId ?? command.matchId,
          );
        }
        TrackingCoverage? finishCoverage;
        if (lifecycle == MatchLifecycle.finished) {
          final confirmed = command is FinishMatchCommand
              ? command.confirmFinalScore
              : true;
          if (!confirmed) {
            throw CommandValidationFailure(
              command: command,
              message: 'Final score confirmation is required.',
              projectionMatchId: command.matchId,
            );
          }
          final detail = await _projectionInTransaction(command.matchId);
          final expectedRedScore = command is FinishMatchCommand
              ? command.expectedRedScore
              : null;
          final expectedBlueScore = command is FinishMatchCommand
              ? command.expectedBlueScore
              : null;
          if ((expectedRedScore == null) != (expectedBlueScore == null)) {
            throw CommandValidationFailure(
              command: command,
              message:
                  'Expected red and blue scores must be supplied together.',
              projectionMatchId: command.matchId,
            );
          }
          if (detail != null &&
              expectedRedScore != null &&
              expectedBlueScore != null &&
              (detail.redScore != expectedRedScore ||
                  detail.blueScore != expectedBlueScore)) {
            throw FinalScoreConflictFailure(
              command: command,
              expectedRedScore: expectedRedScore,
              expectedBlueScore: expectedBlueScore,
              actualRedScore: detail.redScore,
              actualBlueScore: detail.blueScore,
              projectionMatchId: command.matchId,
            );
          }
          final decision = detail?.decision;
          if (decision != null && !decision.canFinish) {
            throw EndConditionFailure(
              command: command,
              decision: decision,
              projectionMatchId: command.matchId,
            );
          }
          if (command is FinishMatchCommand &&
              command.trackingCoverage != null) {
            final requested = command.trackingCoverage!;
            final current = TrackingCoverage.values.byName(
              row.trackingCoverage,
            );
            finishCoverage =
                requested == TrackingCoverage.scoresOnly ||
                    current.index <= requested.index
                ? requested
                : current;
          }
        }
        final endedAt = switch (command) {
          FinishMatchCommand(:final endedAt) => endedAt,
          AbandonMatchCommand(:final endedAt) => endedAt,
          _ => _now().toUtc(),
        };
        final openPossession =
            await (_database.select(_database.possessionSegments)
                  ..where(
                    (segment) =>
                        segment.matchId.equals(command.matchId) &
                        segment.endedAtEventId.isNull(),
                  )
                  ..orderBy([
                    (_) =>
                        OrderingTerm.desc(const CustomExpression<int>('rowid')),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        if (openPossession != null) {
          final closeEventId = '${command.commandId}:event';
          await _database
              .into(_database.matchEvents)
              .insert(
                MatchEventsCompanion.insert(
                  id: closeEventId,
                  matchId: command.matchId,
                  type: EventKind.possession.name,
                  side: Value(openPossession.side),
                  points: const Value(0),
                  occurredAt: endedAt,
                  customLabel: Value('finish:${lifecycle.name}'),
                ),
              );
          await (_database.update(
            _database.possessionSegments,
          )..where((segment) => segment.id.equals(openPossession.id))).write(
            PossessionSegmentsCompanion(endedAtEventId: Value(closeEventId)),
          );
          await _writeAudit(
            id: '${command.commandId}:possession-audit',
            matchId: command.matchId,
            targetId: openPossession.id,
            action: 'possession',
            before: _possessionJson(openPossession),
            after: <String, Object?>{
              ..._possessionJson(openPossession),
              'endedAtEventId': closeEventId,
            },
            reason: 'match-$lifecycle',
          );
        }
        final clockRow = await _clockRow(command.matchId);
        if (clockRow != null) {
          final beforeClock = _clockState(clockRow);
          final clockProjection = ClockEngine().project(
            state: beforeClock,
            now: _now().toUtc(),
          );
          final nextClock = clockProjection.normalizedState.copyWith(
            runningSinceUtc: null,
          );
          await _updateClock(nextClock);
          await _writeAudit(
            id: _newUuid(),
            matchId: command.matchId,
            targetId: clockRow.id,
            action: 'edit',
            before: _clockJson(beforeClock),
            after: _clockJson(nextClock),
            reason: 'clock-$lifecycle',
          );
        }
        await (_database.update(
          _database.matches,
        )..where((match) => match.id.equals(command.matchId))).write(
          MatchesCompanion(
            lifecycle: Value(lifecycle.name),
            endedAt: Value(endedAt),
            trackingCoverage: finishCoverage == null
                ? const Value.absent()
                : Value(finishCoverage.name),
          ),
        );
        if (finishCoverage != null &&
            finishCoverage.name != row.trackingCoverage) {
          await _writeAudit(
            id: '${command.commandId}:coverage-audit',
            matchId: command.matchId,
            targetId: command.matchId,
            action: 'edit',
            before: <String, Object?>{
              'matchId': command.matchId,
              'trackingCoverage': row.trackingCoverage,
            },
            after: <String, Object?>{
              'matchId': command.matchId,
              'trackingCoverage': finishCoverage.name,
            },
            reason: 'finish-tracking-coverage',
          );
        }
        await (_database.delete(_database.activeSessions)..where(
              (session) =>
                  session.id.equals('active') &
                  session.matchId.equals(command.matchId),
            ))
            .go();
        await _inject(MatchCommandFailurePoint.afterLifecycleWritten);
        final result = await _writeReceipt(command);
        await _inject(MatchCommandFailurePoint.afterAuditWritten);
        await _inject(MatchCommandFailurePoint.beforeCommit);
        return result;
      });
    });
  }

  Future<MatchDetail> _execute(
    MatchCommand command,
    Future<MatchDetail> Function() operation,
  ) async {
    try {
      return await operation();
    } on MatchCommandFailure catch (failure) {
      failure.lastCommittedProjection = await _projection(
        failure.projectionMatchId ?? command.matchId,
      );
      if (failure.canRetry) {
        failure._retryAction ??= () => _execute(command, operation);
      }
      rethrow;
    } on Object catch (error, stackTrace) {
      final active = command is StartMatchCommand ? await _activeRow() : null;
      if (active != null && active.matchId != command.matchId) {
        final failure = ActiveMatchConflictFailure(
          command: command,
          projectionMatchId: active.matchId,
        );
        failure.lastCommittedProjection = await _projection(active.matchId);
        throw failure;
      }
      final failure = CommandTransactionFailure(
        command: command,
        message: 'Command ${command.commandId} rolled back: $error',
        cause: error,
        stackTrace: stackTrace,
        projectionMatchId: command.matchId,
      );
      failure.lastCommittedProjection = await _projection(command.matchId);
      failure._retryAction = () => _execute(command, operation);
      throw failure;
    }
  }

  Future<MatchDetail?> _returnForDuplicate(MatchCommand command) async {
    final receipt = await _receipt(command.commandId);
    if (receipt == null) return null;
    final before = _decodeObject(receipt.beforeJson);
    final storedFingerprint = before['fingerprint'];
    if (storedFingerprint != command.fingerprint) {
      throw CommandConflictFailure(
        command: command,
        projectionMatchId: before['matchId'] as String?,
      );
    }
    final after = _decodeObject(receipt.afterJson);
    final storedProjection = after['projection'];
    if (storedProjection is Map) {
      return _projectionFromJson(storedProjection.cast<String, Object?>());
    }
    // Receipts written by the pre-projection kernel remain readable. They do
    // not have an immutable result, so use the current committed projection
    // only as a compatibility fallback for those legacy rows.
    return _projection(command.matchId);
  }

  static bool _isImportedIncompleteNote(String? note) {
    final value = note?.trim();
    return value == importedIncompleteNoteMarker ||
        (value?.endsWith('[$importedIncompleteNoteMarker]') ?? false);
  }

  static String? _removeImportedIncompleteMarker(String? note) {
    final value = note?.trim();
    if (value == null || value == importedIncompleteNoteMarker) return null;
    const suffix = '[$importedIncompleteNoteMarker]';
    if (!value.endsWith(suffix)) return value;
    final restored = value.substring(0, value.length - suffix.length).trim();
    return restored.isEmpty ? null : restored;
  }

  Future<MatchDetail> _writeReceipt(MatchCommand command) async {
    final projection = await _projectionInTransaction(command.matchId);
    if (projection == null) {
      throw StateError('Command committed without a readable projection.');
    }
    await _database
        .into(_database.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: command.commandId,
            matchId: command.matchId,
            targetId: command.commandId,
            action: 'command',
            beforeJson: jsonEncode(<String, Object?>{
              'commandType': command.commandType,
              'commandId': command.commandId,
              'matchId': command.matchId,
              'fingerprint': command.fingerprint,
            }),
            afterJson: jsonEncode(<String, Object?>{
              'committed': true,
              'commandType': command.commandType,
              'matchId': command.matchId,
              'projection': _projectionJson(projection),
            }),
            reason: const Value.absent(),
            createdAt: _now().toUtc(),
          ),
        );
    return projection;
  }

  Future<void> _writeAudit({
    required String id,
    required String matchId,
    required String targetId,
    required String action,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    String? reason,
  }) {
    final normalized = reason?.trim();
    return _database
        .into(_database.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: id,
            matchId: matchId,
            targetId: targetId,
            action: action,
            beforeJson: jsonEncode(before),
            afterJson: jsonEncode(after),
            reason: Value(
              normalized == null || normalized.isEmpty ? null : normalized,
            ),
            createdAt: _now().toUtc(),
          ),
        );
  }

  Future<void> _requireActiveMatch(MatchCommand command) async {
    final row = await _matchRow(command.matchId);
    if (row == null) {
      throw CommandValidationFailure(
        command: command,
        message: 'Missing match ${command.matchId}.',
      );
    }
    final active = await _activeRow();
    if (row.lifecycle != MatchLifecycle.active.name ||
        active?.matchId != command.matchId) {
      throw CommandValidationFailure(
        command: command,
        message: 'Match ${command.matchId} is not the active match.',
        projectionMatchId: command.matchId,
      );
    }
  }

  /// Replay edits use the same active-match policy as the existing correct
  /// and undo commands, while also allowing completed matches to be edited
  /// from finished/archived replay. Draft and abandoned matches remain
  /// outside the correction boundary.
  Future<void> _requireReplayEditableMatch(MatchCommand command) async {
    final row = await _matchRow(command.matchId);
    if (row == null) {
      throw CommandValidationFailure(
        command: command,
        message: 'Missing match ${command.matchId}.',
      );
    }
    final lifecycle = MatchLifecycle.values.byName(row.lifecycle);
    if (lifecycle != MatchLifecycle.active &&
        lifecycle != MatchLifecycle.finished &&
        lifecycle != MatchLifecycle.archived) {
      throw CommandValidationFailure(
        command: command,
        message: 'Only active, finished, or archived matches can be edited.',
        projectionMatchId: command.matchId,
      );
    }
  }

  Future<AuditLog?> _receipt(String commandId) async {
    final query = _database.select(_database.auditLogs)
      ..where((row) => row.id.equals(commandId));
    final row = await query.getSingleOrNull();
    if (row == null || row.action == 'command') return row;
    throw CommandConflictFailure(
      command: _UnknownCommand(commandId),
      projectionMatchId: row.matchId,
    );
  }

  Future<Matche?> _matchRow(String id) {
    final query = _database.select(_database.matches)
      ..where((row) => row.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<ActiveSession?> _activeRow() {
    final query = _database.select(_database.activeSessions)
      ..where((row) => row.id.equals('active'));
    return query.getSingleOrNull();
  }

  Future<MatchEventRow?> _eventRow(String id) {
    final query = _database.select(_database.matchEvents)
      ..where((row) => row.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Returns event rows in durable commit chronology.
  ///
  /// A command writes its event and its `create` audit in one transaction.
  /// When every event has that audit, the audit row order is the ownership
  /// chronology used by scoring undo. Legacy/imported rows can be missing a
  /// create audit; in that case the event row order is the only durable
  /// chronology and remains the authoritative fallback for the whole replay.
  Future<List<MatchEventRow>> _durableEventChronology(String matchId) async {
    final rows =
        await (_database.select(_database.matchEvents)
              ..where((event) => event.matchId.equals(matchId))
              ..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    if (rows.isEmpty) return const <MatchEventRow>[];

    final audits =
        await (_database.select(_database.auditLogs)
              ..where(
                (audit) =>
                    audit.matchId.equals(matchId) &
                    audit.action.equals('create'),
              )
              ..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    final eventById = <String, MatchEventRow>{
      for (final event in rows) event.id: event,
    };
    final auditedIds = <String>{};
    final auditedRows = <MatchEventRow>[];
    for (final audit in audits) {
      final event = eventById[audit.targetId];
      if (event != null && auditedIds.add(event.id)) {
        auditedRows.add(event);
      }
    }
    if (auditedRows.length != rows.length) return rows;
    return auditedRows;
  }

  Future<ShotLocation?> _shotLocationForEvent(String eventId) {
    final query = _database.select(_database.shotLocations)
      ..where((row) => row.eventId.equals(eventId));
    return query.getSingleOrNull();
  }

  /// Returns the newest scoring event in durable commit order. Every scoring
  /// event participates in ownership, including free throws: a newly
  /// committed free throw therefore closes the previous field-goal window.
  Future<MatchEventRow?> _latestScoringEvent(String matchId) async {
    final rows =
        await (_database.select(_database.matchEvents)
              ..where(
                (event) =>
                    event.matchId.equals(matchId) &
                    event.isDeleted.equals(false) &
                    event.type.isIn([
                      EventKind.score.name,
                      EventKind.fieldGoal.name,
                      EventKind.miss.name,
                      EventKind.freeThrow.name,
                    ]),
              )
              ..orderBy([
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    final eventById = <String, MatchEventRow>{
      for (final event in rows) event.id: event,
    };
    final audits =
        await (_database.select(_database.auditLogs)
              ..where(
                (audit) =>
                    audit.matchId.equals(matchId) &
                    audit.action.equals('create'),
              )
              ..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    MatchEventRow? latest;
    for (final audit in audits) {
      final event = eventById[audit.targetId];
      if (event != null) latest = event;
    }
    // A row without a create audit may be a legacy/imported event committed
    // after an audited event. The durable event row order is authoritative in
    // that case; do not let an older audit claim ownership of its window.
    if (rows.isNotEmpty &&
        !audits.any((audit) => audit.targetId == rows.first.id)) {
      return rows.first;
    }
    if (latest != null) return latest;
    // Imported rows from pre-audit backups still need a deterministic
    // fallback; newly committed events always have a create audit above.
    return rows.isEmpty ? null : rows.first;
  }

  Future<_UndoableLiveAction?> _latestLiveUndoAction(String matchId) async {
    final events =
        await (_database.select(_database.matchEvents)
              ..where(
                (event) =>
                    event.matchId.equals(matchId) &
                    event.isDeleted.equals(false) &
                    event.type.isIn(
                      liveUndoableEventKinds
                          .map((kind) => kind.name)
                          .toList(growable: false),
                    ),
              )
              ..orderBy([
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    final eventById = <String, MatchEventRow>{
      for (final event in events) event.id: event,
    };
    final locations =
        await (_database.select(_database.shotLocations)..where(
              (location) =>
                  location.matchId.equals(matchId) &
                  location.isConfirmed.equals(true),
            ))
            .get();
    final locationByEvent = <String, ShotLocation>{
      for (final location in locations) location.eventId: location,
    };
    final audits =
        await (_database.select(_database.auditLogs)
              ..where(
                (audit) =>
                    audit.matchId.equals(matchId) &
                    audit.action.isIn(['create', 'locate']),
              )
              ..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();

    _UndoableLiveAction? latest;
    for (final audit in audits) {
      final event = eventById[audit.targetId];
      if (event == null) continue;
      if (audit.action == 'locate') {
        final location = locationByEvent[event.id];
        if (location == null) continue;
        latest = _UndoableLiveAction.location(event: event, location: location);
        continue;
      }
      latest = _UndoableLiveAction.event(event: event);
    }
    // Legacy/imported event rows may have no create audit. If the newest
    // durable row is one of those events, it is still the next undoable
    // action. New records use audit chronology whenever it exists.
    final createAuditEventIds = <String>{
      for (final audit in audits)
        if (audit.action == 'create') audit.targetId,
    };
    if (events.isNotEmpty && !createAuditEventIds.contains(events.first.id)) {
      if (latest?.event?.id == events.first.id) return latest;
      final event = events.first;
      return _UndoableLiveAction.event(event: event);
    }
    return latest;
  }

  static Map<String, Object?> _shotLocationJson(ShotLocation row) =>
      <String, Object?>{
        'id': row.id,
        'matchId': row.matchId,
        'eventId': row.eventId,
        'x': row.x,
        'y': row.y,
        'isConfirmed': row.isConfirmed,
      };

  static bool _eventTypeSupportsLocation(EventKind type) {
    return type == EventKind.fieldGoal ||
        type == EventKind.score ||
        type == EventKind.miss;
  }

  static bool _eventTypeChangesScore(EventKind type) {
    return type == EventKind.score ||
        type == EventKind.fieldGoal ||
        type == EventKind.freeThrow;
  }

  Future<PlayerRow?> _playerRow(String id) {
    final query = _database.select(_database.players)
      ..where((row) => row.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<MatchParticipant?> _participantRow(
    String matchId,
    String participantId,
  ) {
    final query = _database.select(_database.matchParticipants)
      ..where(
        (row) => row.matchId.equals(matchId) & row.id.equals(participantId),
      );
    return query.getSingleOrNull();
  }

  Future<MatchDetail?> _projection(String matchId) {
    return _projectionInTransaction(matchId);
  }

  Future<MatchDetail?> _projectionInTransaction(String matchId) async {
    final match = await _matchRow(matchId);
    if (match == null) return null;
    final events =
        await (_database.select(_database.matchEvents)
              ..where((event) => event.matchId.equals(matchId))
              ..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    final locations = await (_database.select(
      _database.shotLocations,
    )..where((location) => location.matchId.equals(matchId))).get();
    final participants = await (_database.select(
      _database.matchParticipants,
    )..where((participant) => participant.matchId.equals(matchId))).get();
    final possessionSegments =
        await (_database.select(_database.possessionSegments)
              ..where((segment) => segment.matchId.equals(matchId))
              ..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    final eventOrder = <String, int>{
      for (var index = 0; index < events.length; index++)
        events[index].id: index,
    };
    possessionSegments.sort(
      (left, right) => (eventOrder[left.startedAtEventId] ?? events.length)
          .compareTo(eventOrder[right.startedAtEventId] ?? events.length),
    );
    final detail = MatchRepository.buildDetail(
      match,
      events,
      locations,
      participantRows: participants,
      possessionRows: possessionSegments,
    );
    final clockRow = await _clockRow(matchId);
    final clock = clockRow == null
        ? null
        : ClockEngine().project(
            state: _clockState(clockRow),
            now: _now().toUtc(),
          );
    final decision =
        _decisionFromLabel(
          await _latestDecisionLabel(matchId),
          redScore: detail.redScore,
          blueScore: detail.blueScore,
        ) ??
        (clock?.phase == ClockPhase.regulationExpired
            ? _decisionForScores(
                reason: MatchDecisionReason.regulationExpired,
                detail: detail,
              )
            : null);
    return detail.copyWith(
      clock: clock,
      decision: decision,
      warnings: _warningsFor(detail),
    );
  }

  Future<MatchClock?> _clockRow(String matchId) {
    final query = _database.select(_database.matchClocks)
      ..where((clock) => clock.matchId.equals(matchId));
    return query.getSingleOrNull();
  }

  ClockState _clockState(MatchClock row) {
    return ClockState(
      id: row.id,
      matchId: row.matchId,
      mode: ClockMode.values.byName(row.mode),
      phase: ClockPhase.values.byName(row.phase),
      accumulatedSeconds: row.accumulatedSeconds,
      runningSinceUtc: row.runningSinceUtc?.toUtc(),
      regulationSeconds: row.regulationSeconds,
    );
  }

  Future<void> _updateClock(ClockState state) {
    return (_database.update(
      _database.matchClocks,
    )..where((clock) => clock.id.equals(state.id))).write(
      MatchClocksCompanion(
        phase: Value(state.phase.name),
        accumulatedSeconds: Value(state.accumulatedSeconds),
        runningSinceUtc: Value(state.runningSinceUtc),
      ),
    );
  }

  Future<void> _persistClockProjection(ClockProjection projection) {
    return _persistClockProjectionAndRecovery(projection);
  }

  Future<void> _persistClockProjectionAndRecovery(
    ClockProjection projection,
  ) async {
    await _updateClock(projection.normalizedState);
    if (projection.recoveryReason !=
        ClockRecoveryReason.wallClockMovedBackward) {
      return;
    }
    final state = projection.state;
    final key = _fingerprint(<String, Object?>{
      'clockId': state.id,
      'matchId': state.matchId,
      'reason': projection.recoveryReason!.name,
      'runningSinceUtc': state.runningSinceUtc?.toUtc().toIso8601String(),
    });
    final eventId = 'clock-recovery-$key';
    if (await _eventRow(eventId) == null) {
      await _database
          .into(_database.matchEvents)
          .insert(
            MatchEventsCompanion.insert(
              id: eventId,
              matchId: state.matchId,
              type: EventKind.pause.name,
              points: const Value(0),
              occurredAt: projection.nowUtc,
              customLabel: const Value('pause'),
            ),
          );
    }
    final auditId = 'clock-recovery-audit-$key';
    final audit = await (_database.select(
      _database.auditLogs,
    )..where((row) => row.id.equals(auditId))).getSingleOrNull();
    if (audit == null) {
      await _writeAudit(
        id: auditId,
        matchId: state.matchId,
        targetId: state.id,
        action: 'edit',
        before: _clockJson(state),
        after: _clockJson(projection.normalizedState),
        reason: 'clock-recovery',
      );
    }
  }

  Future<String?> _latestSemanticLabel(String matchId) async {
    final rows =
        await (_database.select(_database.matchEvents)
              ..where(
                (event) =>
                    event.matchId.equals(matchId) &
                    event.type.equals(EventKind.pause.name) &
                    event.isDeleted.equals(false),
              )
              ..orderBy([
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    return rows.isEmpty ? null : rows.first.customLabel;
  }

  Future<String?> _latestDecisionLabel(String matchId) async {
    final latest = await _latestSemanticLabel(matchId);
    return latest != null && latest.startsWith('decision:') ? latest : null;
  }

  Future<MatchEventRow?> _latestDecisionEvent(String matchId) async {
    final rows =
        await (_database.select(_database.matchEvents)
              ..where(
                (event) =>
                    event.matchId.equals(matchId) &
                    event.type.equals(EventKind.pause.name) &
                    event.isDeleted.equals(false),
              )
              ..orderBy([
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    for (final row in rows) {
      if (row.customLabel?.startsWith('decision:') == true) return row;
    }
    return null;
  }

  /// A target-score decision is a derived pause, not an independent user
  /// action. Undoing the score must atomically remove that pause and restore
  /// the clock state captured by its durable decision-clock audit row.
  Future<void> _restoreDecisionStateAfterScoringUndo(
    UndoLastScoringActionCommand command, {
    required MatchEventRow selectedEvent,
  }) async {
    // A continued target decision remains in the event table for history, but
    // the latest semantic event is no longer the decision pause. In that
    // state undoing a later score must not erase the earlier acknowledgement.
    if (await _latestDecisionLabel(command.matchId) == null) return;
    final decision = await _latestDecisionEvent(command.matchId);
    if (decision == null) {
      return;
    }
    final clockRow = await _clockRow(command.matchId);
    if (clockRow == null) {
      throw CommandValidationFailure(
        command: command,
        message:
            'Cannot safely associate the active scoring decision with a clock state.',
        projectionMatchId: command.matchId,
      );
    }
    // The decision pause is derived from the scoring transaction. Its audit
    // row carries the source event identity, so undo never compares client
    // supplied occurredAt values (which may be future or out of order).
    final decisionClockAudits =
        await (_database.select(_database.auditLogs)
              ..where(
                (audit) =>
                    audit.matchId.equals(command.matchId) &
                    audit.targetId.equals(clockRow.id) &
                    audit.action.equals('edit') &
                    audit.reason.equals('decision-clock'),
              )
              ..orderBy([
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    AuditLog? decisionClockAudit;
    for (final audit in decisionClockAudits) {
      final after = _decodeObject(audit.afterJson);
      if (after['scoringEventId'] == selectedEvent.id) {
        decisionClockAudit = audit;
        break;
      }
    }
    if (decisionClockAudit == null) {
      // Very early databases recorded the decision-clock mutation without a
      // source event ID. Reconstruct that relation from the durable audit
      // adjacency used by the transaction: a scoring create audit followed by
      // its decision-clock audit. This is deliberately stricter than matching
      // occurredAt, which is client supplied and may be out of order.
      final allAudits =
          await (_database.select(_database.auditLogs)
                ..where((audit) => audit.matchId.equals(command.matchId))
                ..orderBy([
                  (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
                ]))
              .get();
      String? latestScoringCreateId;
      final scoringEventIds = <String>{
        for (final event in await (_database.select(
          _database.matchEvents,
        )..where((event) => event.matchId.equals(command.matchId))).get())
          if (event.type == EventKind.score.name ||
              event.type == EventKind.fieldGoal.name ||
              event.type == EventKind.miss.name ||
              event.type == EventKind.freeThrow.name)
            event.id,
      };
      for (final audit in allAudits) {
        if (audit.action == 'create' &&
            scoringEventIds.contains(audit.targetId)) {
          latestScoringCreateId = audit.targetId;
          continue;
        }
        if (audit.targetId != clockRow.id ||
            audit.action != 'edit' ||
            audit.reason != 'decision-clock') {
          continue;
        }
        final after = _decodeObject(audit.afterJson);
        if (after['scoringEventId'] == null &&
            latestScoringCreateId == selectedEvent.id) {
          decisionClockAudit = audit;
        }
      }
    }
    if (decisionClockAudit == null) {
      // This method runs inside the undo transaction, so rejecting here rolls
      // back the score tombstone, its audit, locations, and any clock writes.
      // A decision with no durable source relation is unsafe to remove.
      throw CommandValidationFailure(
        command: command,
        message:
            'Cannot safely associate the active scoring decision with the selected score.',
        projectionMatchId: command.matchId,
      );
    }
    await (_database.update(_database.matchEvents)
          ..where((row) => row.id.equals(decision.id)))
        .write(const MatchEventsCompanion(isDeleted: Value(true)));
    await _writeAudit(
      id: '${command.auditId}:decision',
      matchId: command.matchId,
      targetId: decision.id,
      action: 'undo',
      before: _eventJson(decision),
      after: <String, Object?>{..._eventJson(decision), 'isDeleted': true},
      reason: 'undo-decision',
    );

    final restored = _clockStateFromJson(
      _decodeObject(decisionClockAudit.beforeJson),
    );
    final current = _clockState(clockRow);
    await _updateClock(restored);
    await _writeAudit(
      id: '${command.auditId}:decision-clock',
      matchId: command.matchId,
      targetId: clockRow.id,
      action: 'edit',
      before: _clockJson(current),
      after: _clockJson(restored),
      reason: 'undo-decision-clock',
    );
  }

  Future<void> _guardInputClock(MatchCommand command) async {
    final row = await _clockRow(command.matchId);
    if (row == null) return;
    final clock = ClockEngine().project(
      state: _clockState(row),
      now: _now().toUtc(),
    );
    if (clock.requiresPersistence) {
      await _persistClockProjection(clock);
    }
    final detail = await _projectionInTransaction(command.matchId);
    final decision = detail?.decision;
    if (decision != null) {
      throw EndConditionFailure(
        command: command,
        decision: decision,
        projectionMatchId: command.matchId,
      );
    }
  }

  Future<void> _guardEventMutation(
    MatchCommand command,
    MatchEventRow event,
  ) async {
    if ((event.type == EventKind.pause.name ||
            event.type == EventKind.possession.name) &&
        event.customLabel != null) {
      throw CommandValidationFailure(
        command: command,
        message: 'System semantic events cannot be corrected or undone.',
        projectionMatchId: command.matchId,
      );
    }
    final match = await _matchRow(command.matchId);
    final lifecycle = match == null
        ? null
        : MatchLifecycle.values.byName(match.lifecycle);
    // Once a match is in replay, end-condition guards belong to the live
    // scoring boundary and must not prevent a historical correction.
    if (lifecycle == MatchLifecycle.finished ||
        lifecycle == MatchLifecycle.archived) {
      return;
    }
    final detail = await _projectionInTransaction(command.matchId);
    final decision = detail?.decision;
    if (decision != null) {
      throw EndConditionFailure(
        command: command,
        decision: decision,
        projectionMatchId: command.matchId,
      );
    }
  }

  Future<MatchCommandFailure?> _preflightRecord(
    RecordMatchEventCommand command,
  ) async {
    final row = await _clockRow(command.matchId);
    if (row == null) return null;
    final projection = ClockEngine().project(
      state: _clockState(row),
      now: _now().toUtc(),
    );
    if (projection.requiresPersistence) {
      await _database.transaction(() => _persistClockProjection(projection));
    }
    if (projection.recoveryReason != null) {
      return ClockRecoveryFailure(
        command: command,
        recoveryMessage:
            projection.recoveryMessage ??
            'The clock was paused because the device clock moved backward.',
        projectionMatchId: command.matchId,
      );
    }
    final detail = await _projection(command.matchId);
    final decision = detail?.decision;
    if (decision != null) {
      return EndConditionFailure(
        command: command,
        decision: decision,
        projectionMatchId: command.matchId,
      );
    }
    return null;
  }

  Future<MatchCommandFailure?> _preflightSemantic(
    MatchCommand command, {
    required String label,
  }) async {
    if (await _receipt(command.commandId) != null) return null;
    final row = await _clockRow(command.matchId);
    if (row == null) return null;
    final projection = ClockEngine().project(
      state: _clockState(row),
      now: _now().toUtc(),
    );
    if (projection.requiresPersistence) {
      await _database.transaction(() => _persistClockProjection(projection));
    }
    if (projection.recoveryReason != null) {
      return ClockRecoveryFailure(
        command: command,
        recoveryMessage:
            projection.recoveryMessage ??
            'The clock was paused because the device clock moved backward.',
        projectionMatchId: command.matchId,
      );
    }
    final detail = await _projection(command.matchId);
    final decision = detail?.decision;
    if (decision != null) {
      return EndConditionFailure(
        command: command,
        decision: decision,
        projectionMatchId: command.matchId,
      );
    }
    if (label == 'resume' && projection.recoveryReason != null) {
      return ClockRecoveryFailure(
        command: command,
        recoveryMessage:
            projection.recoveryMessage ??
            'The clock was paused because the device clock moved backward.',
        projectionMatchId: command.matchId,
      );
    }
    return null;
  }

  Future<void> _applyPostEventRules(RecordMatchEventCommand command) {
    return _applyPostScoreRules(
      command.matchId,
      scoreChanged: _isMadeScore(command),
      decisionEventId: '${command.commandId}:decision',
      scoringEventId: command.eventId,
    );
  }

  Future<void> _restoreManualPossessionSegment(MatchEventRow event) async {
    if (event.type != EventKind.possession.name ||
        event.side == null ||
        event.customLabel != null) {
      return;
    }
    final id = '${event.id}:possession';
    final existing = await (_database.select(
      _database.possessionSegments,
    )..where((segment) => segment.id.equals(id))).getSingleOrNull();
    if (existing != null) return;
    await _database
        .into(_database.possessionSegments)
        .insert(
          PossessionSegmentsCompanion.insert(
            id: id,
            matchId: event.matchId,
            side: event.side!,
            startedAtEventId: event.id,
            reason: Value(
              event.note?.trim().isNotEmpty == true
                  ? event.note!.trim()
                  : 'manual-possession',
            ),
            source: Value(PossessionSource.manual.name),
          ),
        );
  }

  /// Rebuilds only derived possession suggestions after an event mutation.
  ///
  /// Manual segments are durable human decisions, so their rows and audit
  /// records are retained. The replay sweep resets only their derived close
  /// boundaries, then replays valid events to close them again where a later
  /// manual or valid suggestion actually changed possession. Suggested rows
  /// are reconciled by their originating event, which removes a row whose hit
  /// was corrected/undone without disturbing later valid segments.
  Future<void> _recalculatePossessionSuggestions(String matchId) async {
    final match = await _matchRow(matchId);
    if (match == null) return;
    final template = _ruleTemplateFromMap(
      _decodeObject(match.ruleTemplateJson),
    );
    final segmentRows =
        await (_database.select(_database.possessionSegments)
              ..where((segment) => segment.matchId.equals(matchId))
              ..orderBy([
                (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
              ]))
            .get();
    final manualRows = segmentRows
        .where((row) => row.source == PossessionSource.manual.name)
        .toList(growable: false);
    final suggestedRows = segmentRows
        .where((row) => row.source == PossessionSource.suggested.name)
        .toList(growable: false);
    final events = await _durableEventChronology(matchId);

    final activeManualEventsById = <String, MatchEventRow>{
      for (final event in events)
        if (!event.isDeleted &&
            event.type == EventKind.possession.name &&
            event.side != null)
          event.id: event,
    };
    final manualByStart = <String, _PossessionReplayState>{};
    final desiredManualById = <String, _PossessionReplayState>{};
    final manualEndById = <String, String?>{};
    for (final row in manualRows) {
      final event = activeManualEventsById[row.startedAtEventId];
      if (event == null) continue;
      final state = _PossessionReplayState(
        id: row.id,
        matchId: row.matchId,
        side: TeamSide.values.byName(event.side!),
        startedAtEventId: row.startedAtEventId,
        reason: row.reason,
        source: PossessionSource.manual,
      );
      manualByStart[row.startedAtEventId] = state;
      desiredManualById[row.id] = state;
      manualEndById[row.id] = null;
    }

    final desiredSuggestedByStart = <String, _PossessionReplayState>{};
    _PossessionReplayState? active;

    void closeActive(String eventId) {
      final current = active;
      if (current == null) return;
      current.endedAtEventId = eventId;
      if (current.source == PossessionSource.manual) {
        manualEndById[current.id] = eventId;
      }
    }

    for (final event in events.where((event) => !event.isDeleted)) {
      if (event.type == EventKind.possession.name && event.side != null) {
        final manual = manualByStart[event.id];
        if (manual != null) {
          if (active != null && active.id != manual.id) {
            closeActive(event.id);
          }
          active = manual;
        }
        continue;
      }
      if (!template.possessionHintEnabled ||
          template.possessionPolicy == PossessionPolicy.manual ||
          !_isMadePossessionEvent(event) ||
          event.side == null) {
        continue;
      }

      final shooter = TeamSide.values.byName(event.side!);
      final suggestedSide =
          template.possessionPolicy == PossessionPolicy.switchAfterMade
          ? (shooter == TeamSide.red ? TeamSide.blue : TeamSide.red)
          : shooter;
      if (active?.side == suggestedSide) continue;
      closeActive(event.id);
      final state = desiredSuggestedByStart.putIfAbsent(
        event.id,
        () => _PossessionReplayState(
          id: '${event.id}:possession',
          matchId: matchId,
          side: suggestedSide,
          startedAtEventId: event.id,
          reason: 'made:${template.possessionPolicy.name};event:${event.id}',
          source: PossessionSource.suggested,
        ),
      );
      active = state;
    }

    for (final row in manualRows) {
      final state = desiredManualById[row.id];
      if (state == null) {
        await (_database.delete(
          _database.possessionSegments,
        )..where((segment) => segment.id.equals(row.id))).go();
        continue;
      }
      final nextEnd = manualEndById[row.id];
      if (row.side == state.side.name && row.endedAtEventId == nextEnd) {
        continue;
      }
      await (_database.update(
        _database.possessionSegments,
      )..where((segment) => segment.id.equals(row.id))).write(
        PossessionSegmentsCompanion(
          side: Value(state.side.name),
          endedAtEventId: Value<String?>(nextEnd),
        ),
      );
    }

    final existingSuggestedByStart = <String, PossessionSegment>{
      for (final row in suggestedRows) row.startedAtEventId: row,
    };
    final desiredStarts = desiredSuggestedByStart.keys.toSet();
    for (final row in suggestedRows) {
      if (desiredStarts.contains(row.startedAtEventId)) continue;
      await (_database.delete(
        _database.possessionSegments,
      )..where((segment) => segment.id.equals(row.id))).go();
    }

    for (final state in desiredSuggestedByStart.values) {
      final existing = existingSuggestedByStart[state.startedAtEventId];
      if (existing == null) {
        await _database
            .into(_database.possessionSegments)
            .insert(
              PossessionSegmentsCompanion.insert(
                id: state.id,
                matchId: state.matchId,
                side: state.side.name,
                startedAtEventId: state.startedAtEventId,
                endedAtEventId: Value(state.endedAtEventId),
                reason: Value(state.reason),
                source: Value(PossessionSource.suggested.name),
              ),
            );
        continue;
      }
      if (existing.side == state.side.name &&
          existing.endedAtEventId == state.endedAtEventId &&
          existing.reason == state.reason) {
        continue;
      }
      await (_database.update(
        _database.possessionSegments,
      )..where((segment) => segment.id.equals(existing.id))).write(
        PossessionSegmentsCompanion(
          side: Value(state.side.name),
          startedAtEventId: Value(state.startedAtEventId),
          endedAtEventId: Value<String?>(state.endedAtEventId),
          reason: Value(state.reason),
          source: Value(PossessionSource.suggested.name),
        ),
      );
    }
  }

  Future<void> _applyPossessionSuggestion(
    RecordMatchEventCommand command,
  ) async {
    // A free-throw command does not tell us whether it is the final attempt
    // in a sequence. Keep possession unchanged until that fact is available;
    // inferring a switch after an intermediate made free throw would create a
    // false segment boundary.
    if (!_isMadeScore(command) || command.type == EventKind.freeThrow) return;
    final match = await _matchRow(command.matchId);
    if (match == null) return;
    final template = _ruleTemplateFromMap(
      _decodeObject(match.ruleTemplateJson),
    );
    if (!template.possessionHintEnabled ||
        template.possessionPolicy == PossessionPolicy.manual ||
        command.side == null) {
      return;
    }
    final suggestedSide =
        template.possessionPolicy == PossessionPolicy.switchAfterMade
        ? (command.side == TeamSide.red ? TeamSide.blue : TeamSide.red)
        : command.side!;
    final open =
        await (_database.select(_database.possessionSegments)
              ..where(
                (segment) =>
                    segment.matchId.equals(command.matchId) &
                    segment.endedAtEventId.isNull(),
              )
              ..orderBy([
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (open != null && open.side == suggestedSide.name) return;

    final reason =
        'made:${template.possessionPolicy.name};event:${command.eventId}';
    if (open != null) {
      await (_database.update(
        _database.possessionSegments,
      )..where((segment) => segment.id.equals(open.id))).write(
        PossessionSegmentsCompanion(endedAtEventId: Value(command.eventId)),
      );
    }
    final id = '${command.eventId}:possession';
    await _database
        .into(_database.possessionSegments)
        .insert(
          PossessionSegmentsCompanion.insert(
            id: id,
            matchId: command.matchId,
            side: suggestedSide.name,
            startedAtEventId: command.eventId,
            reason: Value(reason),
            source: Value(PossessionSource.suggested.name),
          ),
        );
    await _writeAudit(
      id: '${command.eventId}:possession-audit',
      matchId: command.matchId,
      targetId: id,
      action: 'possession_suggestion',
      before: open == null ? const <String, Object?>{} : _possessionJson(open),
      after: <String, Object?>{
        'id': id,
        'matchId': command.matchId,
        'side': suggestedSide.name,
        'startedAtEventId': command.eventId,
        'reason': reason,
        'source': PossessionSource.suggested.name,
      },
      reason: reason,
    );
  }

  Future<void> _applyManualPossessionEvent(
    RecordMatchEventCommand command,
  ) async {
    if (command.type != EventKind.possession || command.side == null) return;
    final open =
        await (_database.select(_database.possessionSegments)
              ..where(
                (segment) =>
                    segment.matchId.equals(command.matchId) &
                    segment.endedAtEventId.isNull(),
              )
              ..orderBy([
                (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (open != null &&
        open.side == command.side!.name &&
        open.source == PossessionSource.manual.name) {
      return;
    }
    if (open != null) {
      await (_database.update(
        _database.possessionSegments,
      )..where((segment) => segment.id.equals(open.id))).write(
        PossessionSegmentsCompanion(endedAtEventId: Value(command.eventId)),
      );
    }
    final reason = command.note?.trim().isNotEmpty == true
        ? command.note!.trim()
        : 'manual-possession';
    final id = '${command.eventId}:possession';
    await _database
        .into(_database.possessionSegments)
        .insert(
          PossessionSegmentsCompanion.insert(
            id: id,
            matchId: command.matchId,
            side: command.side!.name,
            startedAtEventId: command.eventId,
            reason: Value(reason),
            source: Value(PossessionSource.manual.name),
          ),
        );
    await _writeAudit(
      id: '${command.eventId}:possession-audit',
      matchId: command.matchId,
      targetId: id,
      action: 'possession',
      before: open == null ? const <String, Object?>{} : _possessionJson(open),
      after: <String, Object?>{
        'id': id,
        'matchId': command.matchId,
        'side': command.side!.name,
        'startedAtEventId': command.eventId,
        'reason': reason,
        'source': PossessionSource.manual.name,
      },
      reason: reason,
    );
  }

  Future<void> _applyPostScoreRules(
    String matchId, {
    required bool scoreChanged,
    required String decisionEventId,
    String? scoringEventId,
  }) async {
    final detail = await _projectionInTransaction(matchId);
    if (detail == null) return;
    final row = await _clockRow(matchId);
    if (row == null) return;
    final beforeClock = _clockState(row);
    final now = _now().toUtc();
    final clock = ClockEngine().project(state: _clockState(row), now: now);
    if (clock.requiresPersistence) {
      await _persistClockProjection(clock);
    }

    MatchDecisionReason? reason;
    if (clock.phase == ClockPhase.regulationExpired) {
      reason = MatchDecisionReason.regulationExpired;
    } else if (scoreChanged) {
      final template = detail.match.ruleTemplateSnapshot;
      final target = template.targetScore;
      if (target != null) {
        final leading = detail.redScore >= detail.blueScore
            ? detail.redScore
            : detail.blueScore;
        final trailing = detail.redScore < detail.blueScore
            ? detail.redScore
            : detail.blueScore;
        if (leading >= target) {
          reason = template.winByTwo && leading - trailing < 2
              ? MatchDecisionReason.winByTwoRequired
              : MatchDecisionReason.targetReached;
        }
      }
    }
    if (reason == null) return;

    final existingDecision = await _latestDecisionLabel(matchId);
    if (existingDecision != null) return;
    final nextClock = clock.normalizedState.copyWith(runningSinceUtc: null);
    await _updateClock(nextClock);
    await _writeAudit(
      id: _newUuid(),
      matchId: matchId,
      targetId: row.id,
      action: 'edit',
      before: _clockJson(beforeClock),
      after: <String, Object?>{
        ..._clockJson(nextClock),
        'scoringEventId': scoringEventId,
      },
      reason: 'decision-clock',
    );
    await _database
        .into(_database.matchEvents)
        .insert(
          MatchEventsCompanion.insert(
            id: decisionEventId,
            matchId: matchId,
            type: EventKind.pause.name,
            points: const Value(0),
            occurredAt: now,
            customLabel: Value('decision:${reason.name}'),
          ),
        );
  }

  static bool _scoresChanged(MatchDetail? before, MatchDetail? after) {
    if (before == null || after == null) return false;
    return before.redScore != after.redScore ||
        before.blueScore != after.blueScore;
  }

  static bool _isMadeScore(RecordMatchEventCommand command) {
    if (command.type == EventKind.score) return command.points > 0;
    return (command.type == EventKind.fieldGoal ||
            command.type == EventKind.freeThrow) &&
        command.outcome == ShotOutcome.made &&
        command.points > 0;
  }

  static bool _isMadePossessionEvent(MatchEventRow event) {
    if (event.points <= 0 || event.side == null) return false;
    if (event.type == EventKind.score.name) return true;
    return event.type == EventKind.fieldGoal.name &&
        event.outcome == ShotOutcome.made.name;
  }

  MatchDecision? _decisionFromLabel(
    String? label, {
    required int redScore,
    required int blueScore,
  }) {
    if (label == null || !label.startsWith('decision:')) return null;
    final reasonName = label.substring('decision:'.length);
    MatchDecisionReason? reason;
    for (final value in MatchDecisionReason.values) {
      if (value.name == reasonName) {
        reason = value;
        break;
      }
    }
    return reason == null
        ? null
        : _decisionForScores(
            reason: reason,
            redScore: redScore,
            blueScore: blueScore,
          );
  }

  MatchDecision _decisionForScores({
    required MatchDecisionReason reason,
    MatchDetail? detail,
    int? redScore,
    int? blueScore,
  }) {
    final resolvedRed = redScore ?? detail?.redScore ?? 0;
    final resolvedBlue = blueScore ?? detail?.blueScore ?? 0;
    final message = switch (reason) {
      MatchDecisionReason.targetReached => '已达到目标分数，请确认结束或继续',
      MatchDecisionReason.winByTwoRequired => '已达到目标分数，但还需领先两分，请继续',
      MatchDecisionReason.regulationExpired => '常规时间结束，请确认结束或进入加时',
    };
    return MatchDecision(
      kind: MatchDecisionKind.finishOrContinue,
      reason: reason,
      redScore: resolvedRed,
      blueScore: resolvedBlue,
      canFinish: reason != MatchDecisionReason.winByTwoRequired,
      messageKey: reason.name,
      message: message,
    );
  }

  List<MatchRuleWarning> _warningsFor(MatchDetail detail) {
    final limit = detail.match.ruleTemplateSnapshot.foulLimit;
    if (limit == null || limit <= 0) return const <MatchRuleWarning>[];
    final warnings = <MatchRuleWarning>[];
    if (detail.redFouls >= limit) {
      warnings.add(
        MatchRuleWarning(
          kind: MatchWarningKind.foulLimit,
          side: TeamSide.red,
          count: detail.redFouls,
          limit: limit,
          message: 'Red foul limit reached.',
        ),
      );
    }
    if (detail.blueFouls >= limit) {
      warnings.add(
        MatchRuleWarning(
          kind: MatchWarningKind.foulLimit,
          side: TeamSide.blue,
          count: detail.blueFouls,
          limit: limit,
          message: 'Blue foul limit reached.',
        ),
      );
    }
    return List.unmodifiable(warnings);
  }

  static Map<String, Object?> _clockJson(ClockState state) => <String, Object?>{
    'id': state.id,
    'matchId': state.matchId,
    'mode': state.mode.name,
    'phase': state.phase.name,
    'accumulatedSeconds': state.accumulatedSeconds,
    'runningSinceUtc': state.runningSinceUtc?.toUtc().toIso8601String(),
    'regulationSeconds': state.regulationSeconds,
  };

  static Map<String, Object?> _possessionJson(PossessionSegment row) =>
      <String, Object?>{
        'id': row.id,
        'matchId': row.matchId,
        'side': row.side,
        'startedAtEventId': row.startedAtEventId,
        'endedAtEventId': row.endedAtEventId,
        'reason': row.reason,
        'source': row.source,
      };

  Future<void> _inject(MatchCommandFailurePoint point) async {
    await _failureInjector?.call(point);
    await _failureHook?.call();
  }

  static void _validateStart(StartMatchCommand command) {
    if (command.redName.trim().isEmpty || command.blueName.trim().isEmpty) {
      throw CommandValidationFailure(
        command: command,
        message: 'Both participant names are required.',
      );
    }
    if (command.redPlayerProfileId != null &&
        command.redPlayerProfileId == command.bluePlayerProfileId) {
      throw CommandValidationFailure(
        command: command,
        message: 'A player profile cannot occupy both sides.',
      );
    }
    if (command.clockMode == ClockMode.countdown) {
      if (!command.timerEnabled) {
        throw CommandValidationFailure(
          command: command,
          message: 'Countdown clocks must be enabled.',
        );
      }
      if (command.regulationSeconds == null ||
          command.regulationSeconds! < 60 ||
          command.regulationSeconds! > 180 * 60 ||
          command.regulationSeconds! % 60 != 0) {
        throw CommandValidationFailure(
          command: command,
          message:
              'Countdown duration must be a whole minute between 1 and 180 minutes.',
        );
      }
    }
  }

  static void _validateRecord(RecordMatchEventCommand command) {
    if (command.points < 0) {
      throw CommandValidationFailure(
        command: command,
        message: 'Event points cannot be negative.',
      );
    }
    if (command.matchClockPositionSeconds != null &&
        command.matchClockPositionSeconds! < 0) {
      throw CommandValidationFailure(
        command: command,
        message: 'Match-clock positions cannot be negative.',
      );
    }
    if (command.type == EventKind.score &&
        command.outcome != null &&
        command.outcome != ShotOutcome.made) {
      throw CommandValidationFailure(
        command: command,
        message: 'Score events must have a made outcome.',
        projectionMatchId: command.matchId,
      );
    }
    if (command.shotLocation != null) {
      if (command.type != EventKind.fieldGoal) {
        throw CommandValidationFailure(
          command: command,
          message: 'Shot locations require a field-goal event.',
        );
      }
      try {
        CourtPoint(x: command.shotLocation!.x, y: command.shotLocation!.y);
      } on Object catch (error) {
        throw CommandValidationFailure(
          command: command,
          message: 'Shot location is invalid: $error',
        );
      }
    }
    try {
      _eventFromCommand(command);
    } on ArgumentError catch (error) {
      throw CommandValidationFailure(
        command: command,
        message: error.message?.toString() ?? error.toString(),
      );
    }
  }

  static MatchEvent _eventFromCommand(RecordMatchEventCommand command) {
    return MatchEvent(
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
  }

  static MatchEvent _correctedEvent(
    MatchEventRow before,
    CorrectMatchEventCommand command,
  ) {
    return MatchEvent(
      id: before.id,
      matchId: before.matchId,
      type: command.type ?? EventKind.values.byName(before.type),
      side:
          command.side ??
          (before.side == null ? null : TeamSide.values.byName(before.side!)),
      points: command.points ?? before.points,
      occurredAt: before.occurredAt.toUtc(),
      outcome:
          command.outcome ??
          (before.outcome == null
              ? null
              : ShotOutcome.values.byName(before.outcome!)),
      note: command.note ?? before.note,
      customLabel: command.customLabel ?? before.customLabel,
      matchClockPositionSeconds:
          command.matchClockPositionSeconds ?? before.matchClockPositionSeconds,
      isDeleted: before.isDeleted,
    );
  }

  static MatchEventsCompanion _eventCompanion(
    MatchEvent event, {
    bool includeId = true,
  }) {
    return MatchEventsCompanion(
      id: includeId ? Value(event.id) : const Value.absent(),
      matchId: Value(event.matchId),
      type: Value(event.type.name),
      side: Value(event.side?.name),
      points: Value(event.points),
      outcome: Value(event.outcome?.name),
      matchClockPositionSeconds: Value(event.matchClockPositionSeconds),
      occurredAt: Value(event.occurredAt),
      note: Value(event.note),
      customLabel: Value(event.customLabel),
      isDeleted: Value(event.isDeleted),
    );
  }

  static Map<String, Object?> _participantJson(MatchParticipant row) =>
      <String, Object?>{
        'id': row.id,
        'matchId': row.matchId,
        'side': row.side,
        'nameSnapshot': row.nameSnapshot,
        'playerProfileId': row.playerProfileId,
      };

  static Map<String, Object?> _eventJson(MatchEventRow row) =>
      <String, Object?>{
        'id': row.id,
        'matchId': row.matchId,
        'type': row.type,
        'side': row.side,
        'points': row.points,
        'occurredAt': row.occurredAt.toUtc().toIso8601String(),
        'note': row.note,
        'customLabel': row.customLabel,
        'outcome': row.outcome,
        'matchClockPositionSeconds': row.matchClockPositionSeconds,
        'isDeleted': row.isDeleted,
      };

  static Map<String, Object?> _eventJsonFromEvent(MatchEvent event) =>
      <String, Object?>{
        'id': event.id,
        'matchId': event.matchId,
        'type': event.type.name,
        'side': event.side?.name,
        'points': event.points,
        'occurredAt': event.occurredAt.toUtc().toIso8601String(),
        'note': event.note,
        'customLabel': event.customLabel,
        'outcome': event.outcome?.name,
        'matchClockPositionSeconds': event.matchClockPositionSeconds,
        'isDeleted': event.isDeleted,
      };
}

Map<String, Object?> _projectionJson(MatchDetail detail) {
  return <String, Object?>{
    'match': <String, Object?>{
      'id': detail.match.id,
      'createdAt': detail.match.createdAt.toUtc().toIso8601String(),
      'startedAt': detail.match.startedAt?.toUtc().toIso8601String(),
      'endedAt': detail.match.endedAt?.toUtc().toIso8601String(),
      'lifecycle': detail.match.lifecycle.name,
      'recordingMode': detail.match.recordingMode.name,
      'trackingCoverage': detail.match.trackingCoverage.name,
      'timerEnabled': detail.match.timerEnabled,
      'note': detail.match.note,
      'ruleTemplate': _ruleTemplateJson(detail.match.ruleTemplateSnapshot),
      'participants': [
        for (final participant in detail.match.participants)
          <String, Object?>{
            'id': participant.id,
            'matchId': participant.matchId,
            'side': participant.side.name,
            'nameSnapshot': participant.nameSnapshot,
            'playerProfileId': participant.playerProfileId,
          },
      ],
    },
    'events': detail.events
        .map(MatchCommandService._eventJsonFromEvent)
        .toList(),
    'shotLocations': [
      for (final location in detail.shotLocations)
        <String, Object?>{
          'id': location.id,
          'matchId': location.matchId,
          'eventId': location.eventId,
          'x': location.point.x,
          'y': location.point.y,
          'isConfirmed': location.isConfirmed,
        },
    ],
    'possessionSegments': [
      for (final segment in detail.possessionSegments)
        <String, Object?>{
          'id': segment.id,
          'matchId': segment.matchId,
          'side': segment.side.name,
          'startedAtEventId': segment.startedAtEventId,
          'endedAtEventId': segment.endedAtEventId,
          'reason': segment.reason,
          'source': segment.source.name,
        },
    ],
    'redScore': detail.redScore,
    'blueScore': detail.blueScore,
    'redFouls': detail.redFouls,
    'blueFouls': detail.blueFouls,
    'shotAttemptCount': detail.shotAttemptCount,
    'locatedShotCount': detail.locatedShotCount,
    if (detail.clock != null)
      'clock': <String, Object?>{
        // Keep the historical top-level state fields for readers that still
        // understand the first receipt shape, while preserving both sides of
        // a running projection for retries and backup restores.
        ...MatchCommandService._clockJson(detail.clock!.normalizedState),
        'state': MatchCommandService._clockJson(detail.clock!.state),
        'normalizedState': MatchCommandService._clockJson(
          detail.clock!.normalizedState,
        ),
        'elapsedSeconds': detail.clock!.elapsedSeconds,
        'displaySeconds': detail.clock!.displaySeconds,
        'remainingSeconds': detail.clock!.remainingSeconds,
        'recoveryReason': detail.clock!.recoveryReason?.name,
        'recoveryMessage': detail.clock!.recoveryMessage,
        'requiresPersistence': detail.clock!.requiresPersistence,
        'nowUtc': detail.clock!.nowUtc.toUtc().toIso8601String(),
      },
    if (detail.decision != null)
      'decision': <String, Object?>{
        'kind': detail.decision!.kind.name,
        'reason': detail.decision!.reason.name,
        'redScore': detail.decision!.redScore,
        'blueScore': detail.decision!.blueScore,
        'canFinish': detail.decision!.canFinish,
        'canContinue': detail.decision!.canContinue,
        'message': detail.decision!.message,
        'messageKey': detail.decision!.messageKey,
      },
    'warnings': [
      for (final warning in detail.warnings)
        <String, Object?>{
          'kind': warning.kind.name,
          'side': warning.side.name,
          'count': warning.count,
          'limit': warning.limit,
          'message': warning.message,
        },
    ],
  };
}

MatchDetail _projectionFromJson(Map<String, Object?> json) {
  final matchJson = (json['match'] as Map).cast<String, Object?>();
  final participantJson =
      (matchJson['participants'] as List<Object?>?) ?? const <Object?>[];
  final participants = participantJson
      .map((raw) {
        final value = (raw as Map).cast<String, Object?>();
        return domain_match.MatchParticipant(
          id: value['id'] as String,
          matchId: value['matchId'] as String,
          side: TeamSide.values.byName(value['side'] as String),
          nameSnapshot: value['nameSnapshot'] as String,
          playerProfileId: value['playerProfileId'] as String?,
        );
      })
      .toList(growable: false);
  final ruleJson = (matchJson['ruleTemplate'] as Map).cast<String, Object?>();
  final match = domain_match.Match(
    id: matchJson['id'] as String,
    createdAt: DateTime.parse(matchJson['createdAt'] as String).toUtc(),
    startedAt: _dateFromJson(matchJson['startedAt']),
    endedAt: _dateFromJson(matchJson['endedAt']),
    lifecycle: MatchLifecycle.values.byName(matchJson['lifecycle'] as String),
    participants: participants,
    recordingMode: RecordingMode.values.byName(
      matchJson['recordingMode'] as String,
    ),
    trackingCoverage: TrackingCoverage.values.byName(
      matchJson['trackingCoverage'] as String,
    ),
    ruleTemplateSnapshot: _ruleTemplateFromMap(ruleJson),
    timerEnabled: matchJson['timerEnabled'] as bool? ?? false,
    note: matchJson['note'] as String?,
  );

  final eventJson = (json['events'] as List<Object?>?) ?? const <Object?>[];
  final events = eventJson
      .map((raw) {
        final value = (raw as Map).cast<String, Object?>();
        return MatchEvent(
          id: value['id'] as String,
          matchId: value['matchId'] as String,
          type: EventKind.values.byName(value['type'] as String),
          side: value['side'] == null
              ? null
              : TeamSide.values.byName(value['side'] as String),
          points: (value['points'] as num).toInt(),
          occurredAt: DateTime.parse(value['occurredAt'] as String).toUtc(),
          note: value['note'] as String?,
          customLabel: value['customLabel'] as String?,
          outcome: value['outcome'] == null
              ? null
              : ShotOutcome.values.byName(value['outcome'] as String),
          matchClockPositionSeconds:
              (value['matchClockPositionSeconds'] as num?)?.toInt(),
          isDeleted: value['isDeleted'] as bool? ?? false,
        );
      })
      .toList(growable: false);

  final locationJson =
      (json['shotLocations'] as List<Object?>?) ?? const <Object?>[];
  final locations = locationJson
      .map((raw) {
        final value = (raw as Map).cast<String, Object?>();
        return domain.ShotLocation(
          id: value['id'] as String,
          matchId: value['matchId'] as String,
          eventId: value['eventId'] as String,
          point: CourtPoint(
            x: (value['x'] as num).toDouble(),
            y: (value['y'] as num).toDouble(),
          ),
          isConfirmed: value['isConfirmed'] as bool,
        );
      })
      .toList(growable: false);

  final possessionJson =
      (json['possessionSegments'] as List<Object?>?) ?? const <Object?>[];
  final possessionSegments = possessionJson
      .map((raw) {
        final value = (raw as Map).cast<String, Object?>();
        return domain_possession.PossessionSegment(
          id: value['id'] as String,
          matchId: value['matchId'] as String,
          side: TeamSide.values.byName(value['side'] as String),
          startedAtEventId: value['startedAtEventId'] as String,
          endedAtEventId: value['endedAtEventId'] as String?,
          reason: value['reason'] as String?,
          source: PossessionSource.values.byName(value['source'] as String),
        );
      })
      .toList(growable: false);

  ClockProjection? clock;
  final clockJson = json['clock'];
  if (clockJson is Map) {
    final value = clockJson.cast<String, Object?>();
    final stateJson = value['state'];
    final normalizedJson = value['normalizedState'];
    final fallbackStateJson = stateJson is Map
        ? stateJson.cast<String, Object?>()
        : normalizedJson is Map
        ? normalizedJson.cast<String, Object?>()
        : value;
    final legacyState = _clockStateFromJson(fallbackStateJson);
    final state = stateJson is Map
        ? _clockStateFromJson(stateJson.cast<String, Object?>())
        : legacyState;
    final normalizedState = normalizedJson is Map
        ? _clockStateFromJson(normalizedJson.cast<String, Object?>())
        : legacyState;
    final nowUtc = value['nowUtc'] is String
        ? DateTime.parse(value['nowUtc'] as String).toUtc()
        : (normalizedState.runningSinceUtc ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    final derived = ClockEngine().project(state: state, now: nowUtc);
    final recoveryName = value['recoveryReason'] as String?;
    final phase = value['phase'] is String
        ? ClockPhase.values.byName(value['phase'] as String)
        : derived.phase;
    clock = ClockProjection(
      state: state,
      normalizedState: normalizedState,
      nowUtc: nowUtc,
      elapsedSeconds:
          (value['elapsedSeconds'] as num?)?.toInt() ?? derived.elapsedSeconds,
      displaySeconds:
          (value['displaySeconds'] as num?)?.toInt() ?? derived.displaySeconds,
      phase: phase,
      remainingSeconds: value.containsKey('remainingSeconds')
          ? (value['remainingSeconds'] as num?)?.toInt()
          : derived.remainingSeconds,
      recoveryReason: recoveryName == null
          ? null
          : ClockRecoveryReason.values.byName(recoveryName),
      recoveryMessage: value['recoveryMessage'] as String?,
      requiresPersistence: value['requiresPersistence'] as bool? ?? false,
    );
  }
  MatchDecision? decision;
  final decisionJson = json['decision'];
  if (decisionJson is Map) {
    final value = decisionJson.cast<String, Object?>();
    decision = MatchDecision(
      kind: MatchDecisionKind.values.byName(value['kind'] as String),
      reason: MatchDecisionReason.values.byName(value['reason'] as String),
      redScore: (value['redScore'] as num).toInt(),
      blueScore: (value['blueScore'] as num).toInt(),
      canFinish: value['canFinish'] as bool? ?? true,
      canContinue: value['canContinue'] as bool? ?? true,
      message: value['message'] as String? ?? '',
      messageKey: value['messageKey'] as String?,
    );
  }
  final warningJson = (json['warnings'] as List<Object?>?) ?? const [];
  final warnings = warningJson
      .map((raw) {
        final value = (raw as Map).cast<String, Object?>();
        return MatchRuleWarning(
          kind: MatchWarningKind.values.byName(value['kind'] as String),
          side: TeamSide.values.byName(value['side'] as String),
          count: (value['count'] as num).toInt(),
          limit: (value['limit'] as num).toInt(),
          message: value['message'] as String? ?? '',
        );
      })
      .toList(growable: false);

  return MatchDetail(
    match: match,
    events: List.unmodifiable(events),
    shotLocations: List.unmodifiable(locations),
    redScore: (json['redScore'] as num).toInt(),
    blueScore: (json['blueScore'] as num).toInt(),
    redFouls: (json['redFouls'] as num).toInt(),
    blueFouls: (json['blueFouls'] as num).toInt(),
    shotAttemptCount: (json['shotAttemptCount'] as num).toInt(),
    locatedShotCount: (json['locatedShotCount'] as num).toInt(),
    possessionSegments: List.unmodifiable(possessionSegments),
    clock: clock,
    decision: decision,
    warnings: List.unmodifiable(warnings),
  );
}

DateTime? _dateFromJson(Object? value) {
  return value == null ? null : DateTime.parse(value as String).toUtc();
}

ClockState _clockStateFromJson(Map<String, Object?> value) {
  return ClockState(
    id: value['id'] as String,
    matchId: value['matchId'] as String,
    mode: ClockMode.values.byName(value['mode'] as String),
    phase: ClockPhase.values.byName(value['phase'] as String),
    accumulatedSeconds: (value['accumulatedSeconds'] as num).toInt(),
    runningSinceUtc: _dateFromJson(value['runningSinceUtc']),
    regulationSeconds: (value['regulationSeconds'] as num?)?.toInt(),
  );
}

RuleTemplate _ruleTemplateFromMap(Map<String, Object?> json) {
  return RuleTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    scoreButtons: ((json['scoreButtons'] as List<Object?>?) ?? const [])
        .map((value) => (value as num).toInt())
        .toList(growable: false),
    targetScore: (json['targetScore'] as num?)?.toInt(),
    timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt(),
    winByTwo: json['winByTwo'] as bool? ?? false,
    foulLimit: (json['foulLimit'] as num?)?.toInt(),
    possessionHintEnabled: json['possessionHintEnabled'] as bool? ?? false,
    possessionPolicy: json['possessionPolicy'] == null
        ? PossessionPolicy.manual
        : PossessionPolicy.values.byName(json['possessionPolicy'] as String),
    customEventTypes: ((json['customEventTypes'] as List<Object?>?) ?? const [])
        .cast<String>(),
  );
}

class _UnknownCommand extends MatchCommand {
  _UnknownCommand(String commandId) : super(commandId: commandId);

  @override
  String get commandType => 'unknown';

  @override
  String get matchId => '';

  @override
  Map<String, Object?> get payload => const <String, Object?>{};
}

Map<String, Object?> _decodeObject(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map) return const <String, Object?>{};
  return decoded.cast<String, Object?>();
}

Map<String, Object?> _ruleTemplateJson(RuleTemplate template) =>
    <String, Object?>{
      'id': template.id,
      'name': template.name,
      'scoreButtons': template.scoreButtons,
      'targetScore': template.targetScore,
      'timeLimitSeconds': template.timeLimitSeconds,
      'winByTwo': template.winByTwo,
      'foulLimit': template.foulLimit,
      'possessionHintEnabled': template.possessionHintEnabled,
      'possessionPolicy': template.possessionPolicy.name,
      'customEventTypes': template.customEventTypes,
    };

RuleTemplate _copyRuleTemplate(RuleTemplate template) {
  return RuleTemplate(
    id: template.id,
    name: template.name,
    scoreButtons: List.unmodifiable(template.scoreButtons),
    targetScore: template.targetScore,
    timeLimitSeconds: template.timeLimitSeconds,
    winByTwo: template.winByTwo,
    foulLimit: template.foulLimit,
    possessionHintEnabled: template.possessionHintEnabled,
    possessionPolicy: template.possessionPolicy,
    customEventTypes: List.unmodifiable(template.customEventTypes),
  );
}

String _fingerprint(Map<String, Object?> payload) =>
    sha256.convert(utf8.encode(jsonEncode(payload))).toString();

String _newUuid() => const Uuid().v4();

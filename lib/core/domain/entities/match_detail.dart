import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/active_session.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/possession_segment.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart';
import 'package:hoopito/core/domain/clock/clock_engine.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

enum MatchDecisionKind { finishOrContinue }

enum MatchDecisionReason { targetReached, winByTwoRequired, regulationExpired }

/// A persisted end-condition acknowledgement required before more input.
class MatchDecision {
  const MatchDecision({
    required this.kind,
    required this.reason,
    required this.redScore,
    required this.blueScore,
    this.canFinish = true,
    this.canContinue = true,
    this.message = '',
    this.messageKey,
  });

  final MatchDecisionKind kind;
  final MatchDecisionReason reason;
  final int redScore;
  final int blueScore;
  final bool canFinish;
  final bool canContinue;
  final String message;
  final String? messageKey;

  String localizedMessage(String locale) {
    final zh = locale.toLowerCase().startsWith('zh');
    return switch (messageKey) {
      'targetReached' =>
        zh
            ? '已达到目标分数，请确认结束或继续'
            : 'Target score reached. Confirm finish or continue.',
      'winByTwoRequired' =>
        zh
            ? '已达到目标分数，但还需领先两分，请继续'
            : 'Target reached, but a two-point lead is required. Continue?',
      'regulationExpired' =>
        zh
            ? '常规时间结束，请确认结束或进入加时'
            : 'Regulation time expired. Confirm finish or continue in overtime?',
      _ => message,
    };
  }

  bool get blocksInput => true;
}

enum MatchWarningKind { foulLimit }

class MatchRuleWarning {
  const MatchRuleWarning({
    required this.kind,
    required this.side,
    required this.count,
    required this.limit,
    this.message = '',
  });

  final MatchWarningKind kind;
  final TeamSide side;
  final int count;
  final int limit;
  final String message;

  String localizedMessage(String locale) {
    final zh = locale.toLowerCase().startsWith('zh');
    if (kind == MatchWarningKind.foulLimit) {
      final sideLabel = zh
          ? (side == TeamSide.red ? '红方' : '蓝方')
          : (side == TeamSide.red ? 'Red' : 'Blue');
      return zh
          ? '$sideLabel犯规已达到$limit次'
          : '$sideLabel foul limit reached ($limit).';
    }
    return message;
  }
}

class MatchDetail {
  const MatchDetail({
    required this.match,
    required this.events,
    required this.shotLocations,
    required this.redScore,
    required this.blueScore,
    required this.redFouls,
    required this.blueFouls,
    required this.shotAttemptCount,
    required this.locatedShotCount,
    this.possessionSegments = const <PossessionSegment>[],
    this.clock,
    this.decision,
    this.warnings = const <MatchRuleWarning>[],
    this.activeSession,
  });

  final Match match;
  final List<MatchEvent> events;
  final List<ShotLocation> shotLocations;
  final int redScore;
  final int blueScore;
  final int redFouls;
  final int blueFouls;
  final int shotAttemptCount;
  final int locatedShotCount;
  final List<PossessionSegment> possessionSegments;
  final ClockProjection? clock;
  final MatchDecision? decision;
  final List<MatchRuleWarning> warnings;
  final ActiveSession? activeSession;

  /// The last durable active-session claim observed by the app. This is used
  /// for recovery UI; it is deliberately separate from [match.createdAt],
  /// which describes the match rather than the latest persisted session.
  DateTime? get lastPersistedAt {
    var latest = activeSession?.claimedAtUtc;
    for (final event in events) {
      if (latest == null || event.occurredAt.isAfter(latest)) {
        latest = event.occurredAt;
      }
    }
    return latest;
  }

  MatchDecision? get ruleDecision => decision;

  MatchDecision? get endDecision => decision;

  MatchRuleWarning? get warning => warnings.isEmpty ? null : warnings.first;

  /// The most recently recorded possession, including a segment that was
  /// closed by match completion. A missing segment means possession is
  /// intentionally unknown (manual policy before the first selection).
  TeamSide? get currentPossession =>
      possessionSegments.isEmpty ? null : possessionSegments.last.side;

  MatchDetail copyWith({
    ClockProjection? clock,
    MatchDecision? decision,
    List<MatchRuleWarning>? warnings,
    List<PossessionSegment>? possessionSegments,
  }) {
    return MatchDetail(
      match: match,
      events: events,
      shotLocations: shotLocations,
      redScore: redScore,
      blueScore: blueScore,
      redFouls: redFouls,
      blueFouls: blueFouls,
      shotAttemptCount: shotAttemptCount,
      locatedShotCount: locatedShotCount,
      possessionSegments: possessionSegments ?? this.possessionSegments,
      clock: clock ?? this.clock,
      decision: decision ?? this.decision,
      warnings: warnings ?? this.warnings,
      activeSession: activeSession,
    );
  }

  TeamSide? get winner {
    if (redScore == blueScore) {
      return null;
    }
    return redScore > blueScore ? TeamSide.red : TeamSide.blue;
  }

  Duration? get duration {
    final endedAt = match.endedAt;
    if (endedAt == null) {
      return null;
    }
    return endedAt.difference(match.startedAt ?? match.createdAt);
  }

  double get shotLocationCompleteness {
    if (shotAttemptCount == 0) {
      return 0;
    }
    return locatedShotCount / shotAttemptCount;
  }
}

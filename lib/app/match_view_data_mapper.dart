import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/match_history_entry.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/features/history/history_controller.dart';
import 'package:hoopito/features/replay/replay_controller.dart';

ReplayMatchData replayDataFromDetail(MatchDetail detail) {
  final locationsByEvent = {
    for (final location in detail.shotLocations)
      if (location.isConfirmed) location.eventId: location,
  };
  final startedAt = detail.match.startedAt ?? detail.match.createdAt;
  final elapsedByEvent = {
    for (final event in detail.events)
      event.id: _nonNegativeDifference(event.occurredAt, startedAt),
  };
  final validPossessionSegments = detail.possessionSegments
      .where((segment) {
        final segmentStartedAt = elapsedByEvent[segment.startedAtEventId];
        if (segmentStartedAt == null) return false;
        final segmentEndedAt = segment.endedAtEventId == null
            ? null
            : elapsedByEvent[segment.endedAtEventId];
        if (segment.endedAtEventId != null && segmentEndedAt == null) {
          return false;
        }
        return segmentEndedAt == null || segmentEndedAt >= segmentStartedAt;
      })
      .toList(growable: false);
  final possessionSegments = <ReplayPossessionSegmentData>[];
  for (final segment in validPossessionSegments) {
    final segmentStartedAt = elapsedByEvent[segment.startedAtEventId]!;
    final segmentEndedAt = segment.endedAtEventId == null
        ? null
        : elapsedByEvent[segment.endedAtEventId];
    possessionSegments.add(
      ReplayPossessionSegmentData(
        id: segment.id,
        side: segment.side,
        startedAtEventId: segment.startedAtEventId,
        startedAt: segmentStartedAt,
        endedAtEventId: segment.endedAtEventId,
        endedAt: segmentEndedAt,
        reason: segment.reason,
        source: segment.source,
      ),
    );
  }

  return ReplayMatchData(
    matchId: detail.match.id,
    redName: detail.match.redName,
    blueName: detail.match.blueName,
    redScore: detail.redScore,
    blueScore: detail.blueScore,
    duration: detail.duration ?? _elapsedSince(startedAt),
    analytics: MatchAnalyticsCalculator().calculate(
      detail.events,
      targetScore: detail.match.ruleTemplateSnapshot.targetScore,
      winByTwo: detail.match.ruleTemplateSnapshot.winByTwo,
      trackingCoverage: detail.match.trackingCoverage,
      shotLocations: detail.shotLocations,
      possessionSegments: validPossessionSegments,
    ),
    possessionSegments: possessionSegments,
    isFinished:
        detail.match.status == MatchStatus.finished ||
        detail.match.status == MatchStatus.archived,
    events: [
      for (final event in detail.events)
        ReplayEventData(
          id: event.id,
          kind: _replayKind(event),
          rawKind: event.type,
          side: event.side,
          points: event.points,
          elapsed: _nonNegativeDifference(event.occurredAt, startedAt),
          note: event.note,
          outcome: event.outcome,
          customLabel: event.customLabel,
          occurredAt: event.occurredAt,
          matchClockPositionSeconds: event.matchClockPositionSeconds,
          isDeleted: event.isDeleted,
          locationId: locationsByEvent[event.id]?.id,
          shotPoint: locationsByEvent[event.id]?.point,
        ),
    ],
  );
}

HistoryMatchSummary historySummaryFromEntry(MatchHistoryEntry entry) {
  return HistoryMatchSummary(
    matchId: entry.id,
    playedAt: entry.playedAt.toLocal(),
    redName: entry.redName,
    blueName: entry.blueName,
    redScore: entry.redScore,
    blueScore: entry.blueScore,
    ruleName: entry.ruleName,
    duration: entry.duration ?? Duration.zero,
    locatedShots: entry.locatedShotCount,
    scoringEvents: entry.shotAttemptCount,
    lifecycle: switch (entry.lifecycle) {
      MatchLifecycle.active => HistoryMatchLifecycle.active,
      MatchLifecycle.finished => HistoryMatchLifecycle.finished,
      MatchLifecycle.archived => HistoryMatchLifecycle.archived,
      MatchLifecycle.abandoned => HistoryMatchLifecycle.abandoned,
      MatchLifecycle.draft => HistoryMatchLifecycle.draft,
    },
    recordingMode: entry.recordingMode.name,
    isImportedIncomplete: entry.importedIncomplete,
  );
}

ReplayEventKind _replayKind(MatchEvent event) {
  return switch (event.type) {
    MatchEventType.score => ReplayEventKind.score,
    MatchEventType.fieldGoal || MatchEventType.freeThrow =>
      event.outcome == ShotOutcome.made
          ? ReplayEventKind.score
          : ReplayEventKind.miss,
    MatchEventType.foul => ReplayEventKind.foul,
    MatchEventType.miss => ReplayEventKind.miss,
    _ => ReplayEventKind.other,
  };
}

Duration _nonNegativeDifference(DateTime value, DateTime origin) {
  final difference = value.difference(origin);
  return difference.isNegative ? Duration.zero : difference;
}

Duration _elapsedSince(DateTime startedAt) {
  return _nonNegativeDifference(DateTime.now(), startedAt);
}

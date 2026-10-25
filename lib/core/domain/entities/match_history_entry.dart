import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

/// A bounded, stable page of history results.
///
/// Pages use an offset because the local database is the source of truth and
/// history does not need a network-safe opaque cursor. The repository orders
/// every page by `playedAt DESC, id DESC`, so the same offset can be requested
/// again while the underlying library is unchanged.
class MatchHistoryPage {
  const MatchHistoryPage({
    required this.entries,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<MatchHistoryEntry> entries;
  final int offset;
  final int limit;
  final bool hasMore;

  int? get nextOffset => hasMore ? offset + entries.length : null;
}

/// Filters accepted by the history projection query.
///
/// [from] is inclusive and [to] is exclusive. By default only completed
/// (unarchived) matches are returned. Active matches are intentionally never
/// included here; they belong to the resume/recovery projection.
class MatchHistoryFilter {
  const MatchHistoryFilter({
    this.search,
    this.from,
    this.to,
    this.ruleId,
    this.ruleName,
    this.recordingMode,
    this.lifecycle,
    this.lifecycles = const <MatchLifecycle>{},
    this.archived,
    this.playerProfileId,
    this.importedIncomplete = false,
  });

  /// Matches a participant snapshot, linked profile nickname, or profile id.
  final String? search;
  final DateTime? from;
  final DateTime? to;
  final String? ruleId;
  final String? ruleName;
  final RecordingMode? recordingMode;
  final MatchLifecycle? lifecycle;
  final Set<MatchLifecycle> lifecycles;
  final bool? archived;
  final String? playerProfileId;

  /// Restricts the projection to unfinished records imported from a backup.
  /// These rows retain the `abandoned` storage lifecycle until a user
  /// explicitly resumes them, so this flag is intentionally separate from
  /// [lifecycle].
  final bool importedIncomplete;

  Set<MatchLifecycle> get selectedLifecycles {
    if (importedIncomplete) return const {MatchLifecycle.abandoned};
    if (lifecycles.isNotEmpty) return lifecycles;
    if (lifecycle != null) return {lifecycle!};
    return const {MatchLifecycle.finished};
  }
}

class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.id,
    required this.playedAt,
    required this.redName,
    required this.blueName,
    required this.redScore,
    required this.blueScore,
    required this.winner,
    required this.ruleName,
    required this.duration,
    required this.shotAttemptCount,
    required this.locatedShotCount,
    required this.shotLocationCompleteness,
    this.lifecycle = MatchLifecycle.finished,
    this.recordingMode = RecordingMode.simple,
    this.trackingCoverage = TrackingCoverage.scoresOnly,
    this.ruleId,
    this.redPlayerProfileId,
    this.bluePlayerProfileId,
    this.redPlayerNickname,
    this.bluePlayerNickname,
    this.importedIncomplete = false,
  });

  final String id;
  final DateTime playedAt;
  final String redName;
  final String blueName;
  final int redScore;
  final int blueScore;
  final TeamSide? winner;
  final String ruleName;
  final Duration? duration;
  final int shotAttemptCount;
  final int locatedShotCount;
  final double shotLocationCompleteness;
  final MatchLifecycle lifecycle;
  final RecordingMode recordingMode;
  final TrackingCoverage trackingCoverage;
  final String? ruleId;
  final String? redPlayerProfileId;
  final String? bluePlayerProfileId;
  final String? redPlayerNickname;
  final String? bluePlayerNickname;
  final bool importedIncomplete;

  bool get isArchived => lifecycle == MatchLifecycle.archived;
}

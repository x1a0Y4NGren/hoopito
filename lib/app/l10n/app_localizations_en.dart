// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get v2Saving => 'Saving';

  @override
  String get v2Saved => 'Saved on device';

  @override
  String get v2SaveFailed => 'Could not save. Try again.';

  @override
  String get v2LastAction => 'Last action';

  @override
  String v2GrowthChartRange(int count, int total) {
    return 'Showing the latest $count of $total games';
  }

  @override
  String get v2SafetyWriteError =>
      'Could not save and verify a safety copy before replacement. Local data was not replaced. Check storage space and try again.';

  @override
  String get v2SafetyLoadError => 'Could not load safety copies. Try again.';

  @override
  String get v2BackupRows => 'rows';

  @override
  String v2BackupCapacityError(String measured, String limit) {
    return 'Backup exceeds supported capacity ($measured; limit $limit). Original data is preserved.';
  }

  @override
  String get v2SwapSides => 'Swap sides';

  @override
  String get v2PresetApplied =>
      'Players and rules copied. You can still make changes.';

  @override
  String get v2RulesSummary => 'Rule summary';

  @override
  String get v2StartFailed => 'Could not start the match. Try again.';

  @override
  String get v2PointsDifference => 'Points difference · last two games';

  @override
  String get v2MarginDifference => 'Margin change · last two games';

  @override
  String get v2Matches => 'Matches';

  @override
  String get v2RecentMatches => 'Recent matches';

  @override
  String get v2RecentPreset => 'Use last match setup';

  @override
  String get v2Result => 'Result';

  @override
  String get v2Rematch => 'Play again';

  @override
  String get v2Share => 'Share report';

  @override
  String get v2Replay => 'Full replay';

  @override
  String get v2CoverageTitle => 'Recording scope';

  @override
  String get v2CoverageScores => 'Mainly scores';

  @override
  String get v2CoverageComplete => 'All shot attempts recorded';

  @override
  String get v2CoverageHelp =>
      'Mainly scores hides shooting percentages. Full recording includes every field goal and free throw, made or missed.';

  @override
  String get v2CorrectCoverage => 'Correct recording scope';

  @override
  String get v2CoverageReason => 'Recording scope correction';

  @override
  String get v2FieldGoalPercentage => 'FG%';

  @override
  String get v2FreeThrowPercentage => 'FT%';

  @override
  String get v2RecordedSample => 'Charts show recorded attempts only';

  @override
  String get v2LocationScope =>
      'Confirmed field goal locations / recorded field goal attempts';

  @override
  String get v2SavePlayer => 'Save to player profile';

  @override
  String get v2CreatePlayer => 'Create player profile';

  @override
  String get v2SelectPlayer => 'Choose existing player';

  @override
  String get v2PlayerSaved =>
      'Player profile linked. The name in this game stays the same.';

  @override
  String get v2Retry => 'Retry';

  @override
  String get v2GuideTitle => 'Quick guide';

  @override
  String get v2GuideScore => 'Record scores';

  @override
  String get v2GuideScoreBody => 'Tap either side’s +1, +2 or +3 to score.';

  @override
  String get v2GuideLocation => 'Locations and misses';

  @override
  String get v2GuideLocationBody =>
      'Tap the court before scoring, or add a location within 10 seconds afterward. You can record misses too.';

  @override
  String get v2GuideUndo => 'Undo and finish';

  @override
  String get v2GuideUndoBody =>
      'Tap Undo to reverse the last action. When you’re done, tap Finish at the top and confirm whether every shot was recorded.';

  @override
  String get v2GuideSkip => 'Skip';

  @override
  String get v2GuideNext => 'Next';

  @override
  String get v2GuideDone => 'Got it';

  @override
  String get v2AbandonedMatch => 'Match not finished';

  @override
  String get v2AbandonedMatchHelp =>
      'You can still replay the saved record. This game is excluded from completed-game statistics.';

  @override
  String get v2SafetyTitle => 'Restore safety copies';

  @override
  String get v2SafetyHelp =>
      'A safety copy is a backup of your local data saved automatically before replacement. The latest two are kept here for recovery. Restoring one also saves and verifies a copy of your current data first.';

  @override
  String get v2SafetyEmpty => 'No safety copies yet';

  @override
  String get v2SafetyRestore => 'Restore this copy';

  @override
  String get v2SafetyConfirm =>
      'This copy will replace all local data. Hoopito first saves and verifies a safety copy of your current data. If that fails, nothing is replaced. End any ongoing match first.';

  @override
  String get v2GrowthSample =>
      'FG% in match order. Gaps mean incomplete recording or no attempts.';

  @override
  String get appName => 'Hoopito';

  @override
  String get startScoring => 'Start';

  @override
  String get replayHistory => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get projectDetails => 'Project';

  @override
  String get ruleTargetReached =>
      'Target score reached. Finish or keep playing?';

  @override
  String get ruleWinByTwoRequired =>
      'Target score reached. Keep playing until one side leads by 2.';

  @override
  String get ruleMatchPoint => 'Match point';

  @override
  String get rulePossessionSuggested => 'Possession suggested';

  @override
  String ruleFoulLimit(Object limit, Object side) {
    return '$side has reached the foul limit of $limit.';
  }

  @override
  String get finishOrContinueOvertime =>
      'Regulation time expired. Confirm finish or continue in overtime?';

  @override
  String get matchDecisionTitle => 'Match decision';

  @override
  String get continueMatch => 'Continue';

  @override
  String get finishMatch => 'Finish match';

  @override
  String get confirmFinalScoreTitle => 'Confirm final score';

  @override
  String get confirmFinalScoreBody =>
      'Finishing locks this score and closes the live match.';

  @override
  String finalScoreLine(
    Object blueName,
    Object blueScore,
    Object redName,
    Object redScore,
  ) {
    return '$redName $redScore : $blueScore $blueName';
  }

  @override
  String get cancelAction => 'Cancel';

  @override
  String get actionFailedRetry => 'Action failed. Please try again.';

  @override
  String get historyTitle => 'Recent matches';

  @override
  String get historyHomeTooltip => 'Back to home';

  @override
  String get replayExitToScoringTooltip => 'Back to scoring';

  @override
  String get replayExitToHistoryTooltip => 'Back to history';

  @override
  String get historySearchHint => 'Search players or matches';

  @override
  String get historyCompleted => 'Completed';

  @override
  String get historyArchived => 'Archived';

  @override
  String get historyAll => 'All';

  @override
  String get historyResetFilters => 'Reset filters';

  @override
  String get historyEmpty => 'No match records';

  @override
  String get historyEmptyDescription => 'Completed matches will appear here.';

  @override
  String get historyActiveMatch => 'Match in progress';

  @override
  String get historyResume => 'Resume';

  @override
  String get historyActions => 'Match actions';

  @override
  String get historyArchive => 'Archive';

  @override
  String get historyUnarchive => 'Unarchive';

  @override
  String get historyDeletePermanently => 'Delete permanently';

  @override
  String get historyDeleteTitle => 'Delete match permanently?';

  @override
  String get historyDeleteBody =>
      'This match and its events, shot locations, and activity log will be permanently deleted. This cannot be undone.';

  @override
  String get historyLoadMore => 'Load more';

  @override
  String get historyMoreFilters => 'More filters';

  @override
  String get historyAdvancedTitle => 'Advanced filters';

  @override
  String get historyRuleLabel => 'Rule name';

  @override
  String get historyRecordingModeLabel => 'Recording mode';

  @override
  String get historyAllModes => 'All modes';

  @override
  String get historySimpleMode => 'Simple';

  @override
  String get historyDetailedMode => 'Detailed';

  @override
  String get historyStartDate => 'Start date';

  @override
  String get historyEndDate => 'End date';

  @override
  String get historyClearDates => 'Clear dates';

  @override
  String get historyApplyFilters => 'Apply filters';

  @override
  String get historyLoadError => 'Could not load match history.';

  @override
  String get historyRetry => 'Retry';

  @override
  String get historyRule => 'Rule';

  @override
  String get historyDuration => 'Duration';

  @override
  String get historyResult => 'Result';

  @override
  String get historyDraw => 'Draw';

  @override
  String historyWinner(Object winnerName) {
    return 'Winner: $winnerName';
  }

  @override
  String get historyLocationCompleteness => 'Shot locations recorded';

  @override
  String get replayTitle => 'Match replay';

  @override
  String get replayExportTooltip => 'Export replay image';

  @override
  String get replayAuditTooltip => 'Activity log';

  @override
  String get replayEditMode => 'Edit mode';

  @override
  String get replayReadOnly => 'View only';

  @override
  String get replayFinished => 'Final';

  @override
  String get replayInProgress => 'In progress';

  @override
  String get replayExportTitle => 'Replay share image';

  @override
  String get replayExportDescription =>
      'Create a local image with the shot chart and game analysis.';

  @override
  String get replayClose => 'Close';

  @override
  String get replayGenerating => 'Generating';

  @override
  String get replayGenerateShare => 'Generate and share';

  @override
  String get replayExportFailed =>
      'Could not generate or share the image. Try again.';

  @override
  String get replayExportAnalysis => 'Game analysis';

  @override
  String get replayExportShotLocations => 'Shot locations';

  @override
  String get replayExportShootingPercentage => 'Shooting percentage';

  @override
  String get replayExportLeadChanges => 'Lead changes';

  @override
  String get replayExportLargestLead => 'Largest lead';

  @override
  String get replayExportKeyMoments => 'Key moments';

  @override
  String get replayNoData => 'None';

  @override
  String replayExportLeadChangesValue(Object count) {
    return '$count';
  }

  @override
  String replayExportKeyMomentsValue(Object count) {
    return '$count';
  }

  @override
  String get replayCourt => 'Shot chart';

  @override
  String get replaySaveLocation => 'Save shot location';

  @override
  String get replayOverview => 'Overview';

  @override
  String get replayDuration => 'Duration';

  @override
  String get replayScoringEvents => 'Scoring records';

  @override
  String get replayFouls => 'Fouls';

  @override
  String get replayLocationCompleteness => 'Shot location coverage';

  @override
  String get replayPossession => 'Possession history';

  @override
  String get replayFinishedBoundary => 'Game finished';

  @override
  String get replayInProgressBoundary => 'Unfinished game';

  @override
  String get replayNoPossession => 'No possession history recorded';

  @override
  String get replayPossessionManual => 'Manual';

  @override
  String get replayPossessionSuggested => 'Suggested';

  @override
  String get replayPossessionCurrent => 'No end time recorded';

  @override
  String replayPossessionEnded(Object time) {
    return 'Ended $time';
  }

  @override
  String replayPossessionReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get replayNoReason => 'No reason provided';

  @override
  String get replaySuggestedReason =>
      'Possession suggested by the rule after a made shot';

  @override
  String get replayTimeline => 'Game timeline';

  @override
  String get replayFilters => 'Replay filters';

  @override
  String get replayNoEvents => 'No records match the filters';

  @override
  String get replayFilterAll => 'All';

  @override
  String get replayFilterScores => 'Scores';

  @override
  String get replayFilterFouls => 'Fouls';

  @override
  String get replayFilterMisses => 'Misses';

  @override
  String get replayFilterOther => 'Other';

  @override
  String get replayFilterBoth => 'Both';

  @override
  String get replayFilterRed => 'Red';

  @override
  String get replayFilterBlue => 'Blue';

  @override
  String get replayFilterShowDeleted => 'Show deleted';

  @override
  String get replayFilterHideDeleted => 'Hide deleted';

  @override
  String get replayFilterMade => 'Made';

  @override
  String get replayFilterMissed => 'Missed';

  @override
  String get replayFilterPoints => 'Points';

  @override
  String replayActionScore(Object points) {
    return '+$points points';
  }

  @override
  String get replayActionFoul => 'Foul';

  @override
  String get replayActionMiss => 'Shot missed';

  @override
  String get replayActionRecord => 'Record';

  @override
  String get replayMatchSide => 'Match';

  @override
  String get replayDeleted => 'Deleted';

  @override
  String replayClockPosition(Object seconds) {
    return 'Clock ${seconds}s';
  }

  @override
  String get replayEditorTitle => 'Edit record';

  @override
  String get replayEditorSide => 'Side';

  @override
  String get replayEditorEventKind => 'Record type';

  @override
  String get replayEditorPoints => 'Points';

  @override
  String get replayEditorOutcome => 'Outcome';

  @override
  String get replayEditorNote => 'Note';

  @override
  String get replayEditorCustomLabel => 'Custom label';

  @override
  String get replayEditorClock => 'Match clock position (seconds)';

  @override
  String get replayEditorLocationX => 'Location X';

  @override
  String get replayEditorLocationY => 'Location Y';

  @override
  String get replayLocationEditTitle => 'Save location correction';

  @override
  String get replayLocationSaveAction => 'Save';

  @override
  String get replayEditorReason => 'Reason (optional)';

  @override
  String get replayEditorDelete => 'Delete';

  @override
  String get replayEditorRestore => 'Restore';

  @override
  String get replayEditorSave => 'Save changes';

  @override
  String get replayEditorSaveNote => 'Save note';

  @override
  String get replayEditorInvalidNumber => 'Enter a valid number.';

  @override
  String get replayEditorLocationRange =>
      'Location values must be between 0 and 1.';

  @override
  String get replayEditorDeleteTitle => 'Delete this record?';

  @override
  String get replayEditorDeleteBody =>
      'This record will no longer count toward the score or statistics. Its activity log is kept. You can show deleted records and restore it later.';

  @override
  String get replayEditorConfirmDelete => 'Delete';

  @override
  String get replayEditorRestoreTitle => 'Restore this record?';

  @override
  String get replayEditorRestoreBody =>
      'This record will count toward the score and statistics again.';

  @override
  String get replayEditorConfirmRestore => 'Restore';

  @override
  String get replayAuditTitle => 'Activity log';

  @override
  String get replayAuditEmpty => 'No activity yet';

  @override
  String replayAuditReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get replayAuditNoReason => 'No reason provided';

  @override
  String get replayAuditActionCreate => 'Created';

  @override
  String get replayAuditActionUndo => 'Undone';

  @override
  String get replayAuditActionEdit => 'Edited';

  @override
  String get replayAuditActionDelete => 'Deleted';

  @override
  String get replayAuditActionImport => 'Imported';

  @override
  String get replayAuditActionRestore => 'Restored';

  @override
  String get replayAuditActionCommand => 'Action performed';

  @override
  String get replayAuditActionLocate => 'Shot location set';

  @override
  String get replayAuditActionPossession => 'Possession updated';

  @override
  String get replayAuditActionPossessionSuggestion => 'Possession suggested';

  @override
  String get replayAuditActionUnknown => 'Unknown operation';

  @override
  String get replayAuditTargetEvent => 'Record';

  @override
  String get replayAuditTargetLocation => 'Shot location';

  @override
  String get replayAuditTargetMatch => 'Match';

  @override
  String get replayAuditTargetCommand => 'Action';

  @override
  String get replayAuditFieldType => 'Record type';

  @override
  String get replayAuditFieldSide => 'Side';

  @override
  String get replayAuditFieldPoints => 'Points';

  @override
  String get replayAuditFieldOutcome => 'Outcome';

  @override
  String get replayAuditFieldNote => 'Note';

  @override
  String get replayAuditFieldCustomLabel => 'Custom label';

  @override
  String get replayAuditFieldClock => 'Match clock';

  @override
  String get replayAuditFieldDeleted => 'Deleted';

  @override
  String get replayAuditFieldX => 'Location X';

  @override
  String get replayAuditFieldY => 'Location Y';

  @override
  String get replayAuditValueNone => '—';

  @override
  String get replayAuditValueDeleted => 'Yes';

  @override
  String get replayAuditValueActive => 'No';

  @override
  String get replayAnalyticsTitle => 'Game analysis';

  @override
  String get replayAnalyticsLeadChanges => 'Lead changes';

  @override
  String get replayAnalyticsLargestLead => 'Largest lead';

  @override
  String get replayAnalyticsShootingPercentage => 'Shooting percentage';

  @override
  String get replayAnalyticsKeyMoments => 'Key moments';

  @override
  String get replayAnalyticsNoAttempts => 'No attempts';

  @override
  String get replayAnalyticsScoringFlow => 'Score progression';

  @override
  String get replayAnalyticsNoScoringEvents => 'No scores recorded';

  @override
  String get replayAnalyticsKeyPossessions => 'Key possessions';

  @override
  String get replayAnalyticsNoKeyPossessions => 'No key possessions';

  @override
  String replayAnalyticsScoreSemantics(
    Object blueScore,
    Object points,
    Object redScore,
    Object side,
  ) {
    return '$side scored $points; $redScore to $blueScore';
  }

  @override
  String get replayAnalyticsTie => 'Tied the game';

  @override
  String get replayAnalyticsOvertake => 'Took the lead';

  @override
  String get replayAnalyticsMatchPoint => 'Reached match point';

  @override
  String get replayAnalyticsScoringRun => 'Scoring run';

  @override
  String get replayAnalyticsShotRecord => 'Shot record';

  @override
  String get replayAnalyticsRecordedAttempts => 'Recorded attempts';

  @override
  String get replayAnalyticsIncompleteShooting =>
      'Incomplete recording; percentage hidden';

  @override
  String get replayAnalyticsFieldGoals => 'Field goals';

  @override
  String get replayAnalyticsFreeThrows => 'Free throws';

  @override
  String get replayAnalyticsFouls => 'Fouls';

  @override
  String get replayAnalyticsPossessions => 'Possessions';

  @override
  String get replayAnalyticsTrackingCoverage => 'Recording scope';

  @override
  String get replayAnalyticsLocationCoverage => 'Location coverage';

  @override
  String get replayAnalyticsShotZones => 'Shot zones';

  @override
  String get replayAnalyticsZoneRestrictedArea => 'Restricted area';

  @override
  String get replayAnalyticsZonePaint => 'Paint';

  @override
  String get replayAnalyticsZoneMidRange => 'Mid-range';

  @override
  String get replayAnalyticsZoneCornerThree => 'Corner three';

  @override
  String get replayAnalyticsZoneWingThree => 'Wing three';

  @override
  String get replayAnalyticsZoneTopThree => 'Top three';

  @override
  String get replayAnalyticsZoneUnknown => 'Unknown zone';

  @override
  String get replayAnalyticsTrackingNone => 'No tracking';

  @override
  String get replayAnalyticsTrackingScoresOnly => 'Scores only';

  @override
  String get replayAnalyticsTrackingShotAttempts => 'Shot outcomes';

  @override
  String get replayAnalyticsTrackingLocations => 'Shots and locations';

  @override
  String get replayAnalyticsTrackingFull => 'Full tracking';

  @override
  String get playerAnalyticsTooltip => 'View player analytics';

  @override
  String get playerAnalyticsTitle => 'Player analytics';

  @override
  String get playerAnalyticsWindow => 'Time range';

  @override
  String get playerAnalyticsSevenDays => 'Last 7 days';

  @override
  String get playerAnalyticsThirtyDays => 'Last 30 days';

  @override
  String get playerAnalyticsNinetyDays => 'Last 90 days';

  @override
  String get playerAnalyticsAllTime => 'All time';

  @override
  String get playerAnalyticsOpponent => 'Opponent';

  @override
  String get playerAnalyticsAllOpponents => 'All opponents';

  @override
  String get playerAnalyticsGrowth => 'Growth trend';

  @override
  String get playerAnalyticsRecentChange => 'Recent change';

  @override
  String get playerAnalyticsAveragePoints => 'Points per game';

  @override
  String get playerAnalyticsAverageMargin => 'Average margin';

  @override
  String get playerAnalyticsRecord => 'Record';

  @override
  String get playerAnalyticsMatches => 'games';

  @override
  String get playerAnalyticsWins => 'wins';

  @override
  String get playerAnalyticsShootingTrend => 'Shooting trend';

  @override
  String get playerAnalyticsFieldGoals => 'Field goals';

  @override
  String get playerAnalyticsFreeThrows => 'Free throws';

  @override
  String get playerAnalyticsRecordedShots => 'Recorded shots';

  @override
  String get playerAnalyticsNoReliablePercentage =>
      'No FG% to show. A game needs complete shot recording and at least one field goal attempt.';

  @override
  String get playerAnalyticsZoneHeatmap => 'Shot zones';

  @override
  String get playerAnalyticsNoMatches => 'No completed games in this window';

  @override
  String get playerAnalyticsNoTrend => 'Not enough trend data yet';

  @override
  String get playerAnalyticsOpponentNone => 'All opponents';

  @override
  String get playerAnalyticsLoadError => 'Could not load analytics';

  @override
  String get playerAnalyticsLoadErrorBody =>
      'Could not load player analytics. Try again.';

  @override
  String get playerAnalyticsNotFound => 'Player not found';

  @override
  String get playerAnalyticsNotFoundBody =>
      'This player profile may have been deleted.';

  @override
  String get playerAnalyticsRetry => 'Retry';

  @override
  String get playerComparisonOpen => 'Compare';

  @override
  String get playerComparisonTitle => 'Player comparison';

  @override
  String get playerComparisonMode => 'Comparison mode';

  @override
  String get playerComparisonMatchMode => 'Games';

  @override
  String get playerComparisonWindowMode => 'Time ranges';

  @override
  String get playerComparisonMatchModeHint =>
      'Choose two completed games linked to this player to compare.';

  @override
  String get playerComparisonWindowModeHint =>
      'Compare two consecutive time ranges that do not overlap. The later range ends when this page was opened.';

  @override
  String get playerComparisonBaseline => 'Reference';

  @override
  String get playerComparisonCurrent => 'Comparison';

  @override
  String get playerComparisonDifference => 'Difference';

  @override
  String get playerComparisonSelectBaseline => 'Choose reference game';

  @override
  String get playerComparisonSelectCurrent => 'Choose comparison game';

  @override
  String get playerComparisonSwap => 'Swap the two games';

  @override
  String get playerComparisonChooseGame => 'Choose a game';

  @override
  String get playerComparisonLoading => 'Comparing';

  @override
  String get playerComparisonLoadError => 'Could not load comparison';

  @override
  String get playerComparisonLoadErrorBody =>
      'Could not load the game comparison. Try again.';

  @override
  String get playerComparisonRetry => 'Retry';

  @override
  String get playerComparisonNoMatches => 'No games to compare';

  @override
  String get playerComparisonNoMatchesBody =>
      'Finish a game with this player profile, then return to compare.';

  @override
  String get playerComparisonNeedTwoMatches => 'Two games are required';

  @override
  String get playerComparisonNeedTwoMatchesBody =>
      'Finish one more game with this player profile to compare two games. You can compare time ranges now.';

  @override
  String get playerComparisonEmptyWindows => 'No games in either time range';

  @override
  String get playerComparisonEmptyWindowsBody =>
      'Try a longer time range or remove the opponent filter.';

  @override
  String get playerComparisonBaselineEmpty =>
      'The reference time range has no games.';

  @override
  String get playerComparisonCurrentEmpty =>
      'The comparison time range has no games.';

  @override
  String get playerComparisonSummary => 'Stats comparison';

  @override
  String get playerComparisonResult => 'Result';

  @override
  String get playerComparisonMatchCount => 'Games';

  @override
  String get playerComparisonWinRate => 'Win rate';

  @override
  String get playerComparisonPoints => 'Points';

  @override
  String get playerComparisonPointsPerGame => 'Points per game';

  @override
  String get playerComparisonMargin => 'Margin';

  @override
  String get playerComparisonMarginPerGame => 'Margin per game';

  @override
  String get playerComparisonFieldGoalsMade => 'Field goals made';

  @override
  String get playerComparisonFieldGoalAttempts => 'Field goal attempts';

  @override
  String get playerComparisonFieldGoalPercentage => 'Field goal percentage';

  @override
  String get playerComparisonFreeThrowsMade => 'Free throws made';

  @override
  String get playerComparisonFreeThrowAttempts => 'Free throw attempts';

  @override
  String get playerComparisonFreeThrowPercentage => 'Free throw percentage';

  @override
  String get playerComparisonLocationCoverage => 'Shot location coverage';

  @override
  String get playerComparisonConfirmedZones =>
      'Confirmed shot locations by zone';

  @override
  String get playerComparisonConfirmedZonesNote =>
      'Zone percentages use confirmed field goal locations only.';

  @override
  String get playerComparisonIncrease => 'Increase';

  @override
  String get playerComparisonDecrease => 'Decrease';

  @override
  String get playerComparisonEqual => 'No change';

  @override
  String get playerComparisonInsufficientData => 'Not enough data';

  @override
  String get playerComparisonWin => 'Win';

  @override
  String get playerComparisonLoss => 'Loss';

  @override
  String get playerComparisonTie => 'Tie';

  @override
  String get playerComparisonPercentagePoints => 'pp';

  @override
  String get replayMoreActions => 'More actions';

  @override
  String get legacyBootstrapTitle => 'Hoopito data compatibility check';

  @override
  String get legacyBootstrapHeadline => 'Could not open legacy v0.1 data';

  @override
  String legacyBootstrapBody(Object version) {
    return 'This version cannot open the old database$version. The original file stays unchanged; Hoopito will not automatically convert, delete, or clear it. Export or back up the old file before creating new local data with this version.';
  }

  @override
  String get bootstrapFailureBody =>
      'Could not open local records. Your existing data is unchanged. Try again later or create a new local database.';

  @override
  String get entryPreparingRecords => 'Opening local records…';

  @override
  String get settingsDefaultSection => 'Defaults';

  @override
  String get settingsDefaultRuleTitle => 'Default scoring rule';

  @override
  String get settingsDefaultRuleSubtitle =>
      'Currently follows pre-game settings';

  @override
  String get settingsRulesSection => 'Match rules';

  @override
  String get settingsRulesTemplateTitle => 'Rule templates';

  @override
  String get settingsRulesTemplateSubtitle =>
      'Built-in templates and custom match rules';

  @override
  String get settingsFeedbackSection => 'Scoring feedback';

  @override
  String get settingsHapticTitle => 'Haptic feedback';

  @override
  String get settingsHapticEnabled => 'On';

  @override
  String get settingsHapticDisabled => 'Off';

  @override
  String get settingsSoundTitle => 'Action sounds';

  @override
  String get settingsSoundEnabled => 'On';

  @override
  String get settingsSoundDisabled => 'Off';

  @override
  String get settingsAppearanceSection => 'Appearance';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Choose the app language';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeSubtitle =>
      'Choose light, dark, or your system theme';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsMotionTitle => 'Motion';

  @override
  String get settingsMotionSubtitle =>
      'Use standard motion or fewer animations';

  @override
  String get settingsMotionStandard => 'Standard motion';

  @override
  String get settingsMotionReduced => 'Reduced motion';

  @override
  String get settingsMotionHelp =>
      'Reduced motion shortens transitions and removes decorative animations.';

  @override
  String get settingsMotionPreview => 'Motion preview';

  @override
  String get settingsMotionPreviewStandard => 'Preview: standard motion';

  @override
  String get settingsMotionPreviewReduced => 'Preview: reduced motion';

  @override
  String get settingsDataSection => 'Data';

  @override
  String get settingsDataManagementTitle => 'Data and backups';

  @override
  String get settingsDataManagementSubtitle =>
      'Export data, restore backups, and set up automatic backups';

  @override
  String get settingsManualDataSection => 'Export and restore';

  @override
  String get settingsAutomaticBackupSection => 'Automatic backup settings';

  @override
  String get settingsExportDataTitle => 'Export data';

  @override
  String get settingsExportDataSubtitle =>
      'Use JSON backups to restore data or CSV files for analysis';

  @override
  String get settingsExportDataDialogTitle => 'Choose export format';

  @override
  String get settingsStatisticsSection => 'Statistics';

  @override
  String get settingsStatisticsSubtitle => 'Calculated from local match events';

  @override
  String get settingsBackupSection => 'Backup and export';

  @override
  String get settingsExportBackupTitle => 'Export full backup';

  @override
  String get settingsExportBackupSubtitle =>
      'A JSON file with matches, players, rules, events, and settings';

  @override
  String get settingsExportBackupSuccess =>
      'Share sheet opened. Choose where to save or send the backup.';

  @override
  String get settingsRestoreTitle => 'Restore from backup';

  @override
  String get settingsRestoreSubtitleMerge =>
      'Merge a backup, or back up current data before replacing it';

  @override
  String get settingsRestoreSubtitleBlocked =>
      'You can merge during a match. End it before replacing data.';

  @override
  String get settingsExportCsvTitle => 'Export CSV';

  @override
  String get settingsExportCsvSubtitle =>
      'Three files: matches, events, and player statistics';

  @override
  String get settingsExportCsvSuccess =>
      'Share sheet opened. Choose where to save the three CSV files.';

  @override
  String get settingsAutomaticBackupTitle => 'Automatic backup';

  @override
  String get settingsAutomaticBackupEnabled => 'On';

  @override
  String get settingsAutomaticBackupDisabled => 'Off';

  @override
  String get settingsBackupDirectoryTitle => 'Backup location';

  @override
  String get settingsBackupDirectoryPickerTitle =>
      'Choose automatic backup folder';

  @override
  String get settingsBackupDirectoryUnselected =>
      'No folder selected. Only folders you choose are accessed.';

  @override
  String get settingsBackupNowTitle => 'Back up now';

  @override
  String get settingsBackupNever => 'No manual or automatic backups yet';

  @override
  String settingsBackupLastSuccess(Object date, Object time) {
    return 'Last successful backup: $date $time';
  }

  @override
  String get settingsBackupRetentionTitle => 'Automatic backups to keep';

  @override
  String get settingsBackupRetentionSubtitle =>
      'Only older Hoopito automatic backups are removed. Manual backups and safety copies are kept.';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsPrivacyTitle => 'Local data';

  @override
  String get settingsPrivacySubtitle =>
      'Personal data is stored on this device. Hoopito does not upload it.';

  @override
  String get settingsExperimentalSection => 'Experimental';

  @override
  String get settingsExperimentalTitle => 'Experimental features';

  @override
  String get settingsExperimentalSubtitle =>
      'No experimental features are available';

  @override
  String get settingsDiagnosticsSection => 'Developer diagnostics';

  @override
  String get settingsDiagnosticsTitle => 'Diagnostics';

  @override
  String get settingsDiagnosticsSubtitle => 'No diagnostic data is available';

  @override
  String get settingsProjectSection => 'Project';

  @override
  String get settingsAboutTitle => 'About Hoopito';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsAboutSubtitle =>
      'Free and open source forever. See the license and how to contribute.';

  @override
  String get settingsRestoreDialogTitle => 'How would you like to restore?';

  @override
  String get settingsRestorePickerTitle => 'Choose a Hoopito backup';

  @override
  String get settingsMergeTitle => 'Merge (recommended)';

  @override
  String get settingsMergeSubtitle =>
      'Keep local settings and the ongoing match. Conflicting records are kept separately without overwriting local records. Players are not merged just because their nicknames match.';

  @override
  String get settingsReplaceTitle => 'Replace local data';

  @override
  String get settingsReplaceSubtitle =>
      'Back up and verify current data first, then replace all local data with the selected backup. If it fails, the original data is kept.';

  @override
  String get settingsReplaceBlocked => 'End the current match first';

  @override
  String get settingsReplaceConfirmTitle => 'Replace all local data?';

  @override
  String get settingsReplaceConfirmBody =>
      'After checking the selected backup, Hoopito saves and verifies a backup of your current data (a safety copy), then replaces all local data. If any step fails, nothing is replaced. End any ongoing match first.';

  @override
  String get settingsReplaceConfirmAction => 'Choose backup';

  @override
  String get settingsRestoreNotSelected => 'No backup file selected';

  @override
  String get settingsMergeCompleted =>
      'Backup merged. Local settings and the ongoing match are unchanged.';

  @override
  String get settingsReplaceCompleted =>
      'Local data replaced with the backup. Automatic backup location reset.';

  @override
  String get settingsDirectoryUpdated => 'Automatic backup location updated';

  @override
  String get settingsDirectoryNotSelected => 'No folder selected';

  @override
  String get settingsAutomaticBackupNotConfigured =>
      'No folder selected; automatic backup remains off';

  @override
  String get settingsAutomaticBackupTurnedOn => 'Automatic backup enabled';

  @override
  String get settingsAutomaticBackupTurnedOff => 'Automatic backup disabled';

  @override
  String get settingsHapticTurnedOn => 'Haptic feedback enabled';

  @override
  String get settingsHapticTurnedOff => 'Haptic feedback disabled';

  @override
  String get settingsSoundTurnedOn => 'Action sounds enabled';

  @override
  String get settingsSoundTurnedOff => 'Action sounds disabled';

  @override
  String get settingsBackupWritten => 'Backup saved to the selected folder';

  @override
  String settingsRetentionUpdated(Object count) {
    return 'The latest $count automatic backups will be kept';
  }

  @override
  String get settingsErrorChecksum =>
      'Backup verification failed; the file may be damaged or modified';

  @override
  String get settingsErrorFutureVersion =>
      'This backup is from a newer version. Update Hoopito and try again.';

  @override
  String get settingsErrorInvalidBackup =>
      'Invalid backup; existing data was not modified';

  @override
  String get settingsErrorMerge =>
      'Backup merge failed; local data was not modified';

  @override
  String get settingsErrorDirectoryRequired =>
      'Choose an automatic backup folder first';

  @override
  String get settingsErrorDirectoryUnavailable =>
      'Cannot save to the selected folder. Choose it again.';

  @override
  String get settingsErrorBackupWrite =>
      'Could not save the backup. Choose the backup folder again and try again.';

  @override
  String get settingsErrorRestoreBlocked => 'End the current match first';

  @override
  String get settingsErrorGeneric => 'The operation failed. Try again later.';

  @override
  String get playerAnalyticsNoLocationData => 'No shot location data';

  @override
  String get homePlayersTooltip => 'Players';

  @override
  String get homeSettingsTooltip => 'Settings';

  @override
  String get homeProjectTooltip => 'Project details';

  @override
  String get homeActiveMatch => 'Match in progress';

  @override
  String get homeClockNotConfigured => 'Timer off';

  @override
  String get homeClockRegulationExpired => 'Regulation ended';

  @override
  String get homeClockRunning => 'Timer running';

  @override
  String get homeClockPaused => 'Timer paused';

  @override
  String get homeLastPersistedUnknown => 'Last save time unavailable';

  @override
  String homeLastPersisted(Object date) {
    return 'Last saved: $date';
  }

  @override
  String get homeResumeMatch => 'Resume match';

  @override
  String get homeAbandonMatch => 'Abandon match';

  @override
  String get homeAbandonTitle => 'Abandon this match?';

  @override
  String get homeAbandonBody =>
      'The match stays in history, but you can no longer resume it from home.';

  @override
  String get homeConfirmAbandon => 'Abandon';

  @override
  String get homeActiveMatchBlocked =>
      'A match is already in progress. Resume or abandon it first.';

  @override
  String get homeVersus => 'vs';

  @override
  String get playersTitle => 'Players';

  @override
  String get playersCreate => 'New player';

  @override
  String get playersEdit => 'Edit player';

  @override
  String get playersEmptyTitle => 'No saved players';

  @override
  String get playersEmptyBody =>
      'You can play without saving a profile. Save one to find the player easily next time.';

  @override
  String get playersLoadError => 'Could not load players';

  @override
  String get playersLoadErrorBody =>
      'Local player data is temporarily unavailable.';

  @override
  String get retryAction => 'Retry';

  @override
  String get playersPreferredRed => 'Prefers Red';

  @override
  String get playersPreferredBlue => 'Prefers Blue';

  @override
  String get playersPreferredUnset => 'No preferred side';

  @override
  String get playerSaveFailed => 'Could not save the player. Try again.';

  @override
  String get playerDeleteTitle => 'Delete player?';

  @override
  String get playerDeleteBody =>
      'Only this player profile will be deleted; existing matches will remain.';

  @override
  String get deleteAction => 'Delete';

  @override
  String get playerDeleteFailed => 'Could not delete the player. Try again.';

  @override
  String get playerNewTitle => 'New player';

  @override
  String get playerEditTitle => 'Edit player';

  @override
  String get playerDeleteTooltip => 'Delete player';

  @override
  String get playerSaveTooltip => 'Save player';

  @override
  String get playerOpenError => 'Could not open player profile';

  @override
  String get playerOpenErrorBody =>
      'Could not open this player profile. Try again.';

  @override
  String get playerNicknameLabel => 'Nickname';

  @override
  String get playerNicknameRequired => 'Enter a player nickname';

  @override
  String get playerPreferredSide => 'Preferred side';

  @override
  String get playerSideAny => 'Any';

  @override
  String get playerSideRed => 'Red';

  @override
  String get playerSideBlue => 'Blue';

  @override
  String get playerNoteLabel => 'Note';

  @override
  String get playerNoteHint => 'Style, habits, or anything to remember';

  @override
  String get playerSaving => 'Saving';

  @override
  String get rulesTitle => 'Rule templates';

  @override
  String get rulesEmptyTitle => 'No rule templates yet';

  @override
  String get rulesEmptyBody =>
      'Create a rule template to use in your next match.';

  @override
  String get rulesCreate => 'New rule';

  @override
  String get rulesLoadError => 'Could not load rule templates';

  @override
  String get rulesLoadErrorBody => 'Could not load rule templates. Try again.';

  @override
  String get rulesBuiltIn => 'Built-in';

  @override
  String get rulesCustom => 'Custom';

  @override
  String get ruleBuiltInFreeScoring => 'Free scoring';

  @override
  String get ruleBuiltInElevenWinByTwo => '11 points (win by 2)';

  @override
  String get ruleBuiltInTwentyOne => '21 points';

  @override
  String get ruleBuiltInTimedTen => '10-minute timed';

  @override
  String rulesScoringButtons(Object buttons) {
    return 'Scoring $buttons';
  }

  @override
  String rulesTarget(Object points) {
    return 'Target $points points';
  }

  @override
  String rulesMinutes(Object minutes) {
    return '$minutes minutes';
  }

  @override
  String get rulesWinByTwo => 'Win by 2';

  @override
  String get ruleNewTitle => 'New rule';

  @override
  String get ruleEditTitle => 'Edit rule';

  @override
  String get ruleNameLabel => 'Template name';

  @override
  String get ruleNameRequired => 'Enter a name';

  @override
  String get ruleTargetLabel => 'Target points (optional)';

  @override
  String get ruleTimeLimitLabel => 'Time limit in minutes (optional)';

  @override
  String get ruleFoulLimitLabel => 'Foul limit (optional)';

  @override
  String get ruleScoreButtonsLabel => 'Points per button (comma-separated)';

  @override
  String get ruleCustomLabelsLabel => 'Custom event names (comma-separated)';

  @override
  String get ruleWinByTwoTitle => 'Win by 2 points';

  @override
  String get rulePossessionHintTitle => 'Suggest possession after scoring';

  @override
  String get rulePossessionHintSubtitle =>
      'Hints only. You can still score manually.';

  @override
  String get rulePossessionPolicyLabel => 'Possession after scoring';

  @override
  String get rulePossessionPolicyHelper =>
      'Turn on possession hints to choose how they work.';

  @override
  String get ruleSaveAction => 'Save rule';

  @override
  String rulePositiveInteger(Object label) {
    return '$label must be a positive integer';
  }

  @override
  String get ruleAtLeastOneInteger => 'Enter at least one positive integer';

  @override
  String get rulePolicyManual => 'Set manually';

  @override
  String get rulePolicySwitchAfterMade => 'Switch after a made shot';

  @override
  String get rulePolicyKeepAfterMade => 'Keep after a made shot';

  @override
  String get pregameTitle => 'Pregame setup';

  @override
  String get pregamePlayers => 'Players';

  @override
  String get pregameRuleTemplate => 'Rule template';

  @override
  String get pregameFreeScoring => 'Free scoring';

  @override
  String get pregameElevenPoint => '11-point game';

  @override
  String get pregameTwentyOnePoint => '21-point game';

  @override
  String get pregameTimer => 'Timer';

  @override
  String get pregameWinByTwo => 'Win by 2 points';

  @override
  String get pregameAdvanced => 'Advanced settings';

  @override
  String get pregameTargetScore => 'Target score';

  @override
  String get pregameEditTargetScore => 'Edit target score';

  @override
  String get pregameConfirmTargetScore => 'Confirm';

  @override
  String pregameTargetScoreRange(int min, int max) {
    return 'Enter a whole number from $min to $max';
  }

  @override
  String get pregamePoint => 'points';

  @override
  String get pregameStartMatch => 'Start match';

  @override
  String get pregameRecordingMode => 'Recording mode (required)';

  @override
  String get pregameTrackingCoverage => 'Miss tracking coverage';

  @override
  String get pregameClockMode => 'Timer mode';

  @override
  String get pregameTemporaryParticipant => 'Temporary name (no profile)';

  @override
  String get pregameManageRules => 'Manage rule templates';

  @override
  String get pregameSimpleMode => 'Simple';

  @override
  String get pregameDetailedMode => 'Detailed';

  @override
  String get pregameTrackingHelper =>
      'Choose which attempts and misses should be recorded in the replay.';

  @override
  String get pregameTimerEnabled => 'Enabled: choose a clock mode';

  @override
  String get pregameTimerDisabled => 'Match time is not recorded when off';

  @override
  String get pregameCountUp => 'Count up';

  @override
  String get pregameCountDown => 'Countdown';

  @override
  String get pregameCountdownLabel => 'Countdown (1–180 minutes)';

  @override
  String get pregameCountdownHelper =>
      'Countdown must be between 1 and 180 minutes.';

  @override
  String get pregameMinutes => 'minutes';

  @override
  String get pregameProfileConflict =>
      'The other side has already selected this player. Choose a different profile.';

  @override
  String get pregameCountdownInvalid =>
      'Enter a whole number of minutes from 1 to 180.';

  @override
  String get pregameTrackingNone => 'Do not track attempts or misses';

  @override
  String get pregameTrackingScoresOnly => 'Scores only';

  @override
  String get pregameTrackingShotAttempts => 'Shot attempts';

  @override
  String get pregameTrackingLocations => 'Shots and locations';

  @override
  String get pregameTrackingFull => 'Full tracking (including misses)';

  @override
  String get pregameDeletedPlayer => 'Deleted player profile';

  @override
  String get pregameParticipationMode => 'Choose player';

  @override
  String pregameTemporaryName(Object side) {
    return '$side temporary name';
  }

  @override
  String pregameNameSnapshot(Object side) {
    return '$side match name';
  }

  @override
  String get pregameTemporaryHint =>
      'Enter a temporary name; both sides may share a temporary name.';

  @override
  String get pregameSnapshotHint =>
      'This name is for this match only. The player profile stays the same.';

  @override
  String get pregameRed => 'Red';

  @override
  String get pregameBlue => 'Blue';

  @override
  String get pregameValidationRedRequired => 'Enter a name for Red.';

  @override
  String get pregameValidationBlueRequired => 'Enter a name for Blue.';

  @override
  String get pregameValidationDuplicateProfile =>
      'Choose a different player profile for each side.';

  @override
  String get pregameValidationRedMissing =>
      'Red’s selected player profile was not found. Choose another or enter a temporary name.';

  @override
  String get pregameValidationBlueMissing =>
      'Blue’s selected player profile was not found. Choose another or enter a temporary name.';

  @override
  String get pregameValidationModeRequired =>
      'Choose a recording mode before starting the match.';

  @override
  String get pregameValidationCountdownRequired =>
      'Turn on the timer before choosing countdown.';

  @override
  String get pregameValidationCountdownDuration =>
      'Set the countdown to 1–180 minutes.';

  @override
  String get scoringSimpleRedShot => 'Red shot';

  @override
  String get scoringSimpleBlueShot => 'Blue shot';

  @override
  String get scoringMade => 'Made';

  @override
  String get scoringMissed => 'Miss';

  @override
  String scoringPoints(Object points) {
    return '$points points';
  }

  @override
  String get scoringCancelDraft => 'Cancel draft';

  @override
  String get scoringSubmitShot => 'Submit shot';

  @override
  String get scoringUndo => 'Undo';

  @override
  String get scoringLocateLastShot => 'Locate last shot';

  @override
  String get scoringPause => 'Pause';

  @override
  String get scoringFinishShort => 'Finish';

  @override
  String get scoringMatchControlsTitle => 'Pause or finish the match?';

  @override
  String get scoringMatchControlsBody =>
      'Pause if you need a break, or confirm the score to finish the match.';

  @override
  String get scoringReturnToScoring => 'Return to scoring';

  @override
  String get scoringPauseMatch => 'Pause match';

  @override
  String get scoringMatchPausedTitle => 'Match paused';

  @override
  String get scoringMatchPausedBody => 'Resume the match to keep scoring.';

  @override
  String get scoringReturnHome => 'Return home';

  @override
  String get scoringPendingPauseExitBody =>
      'A gray shot marker is still unfinished. Returning home or finishing the match will discard this unfinished shot.';

  @override
  String get scoringDiscardDraft => 'Discard unfinished shot';

  @override
  String get scoringResume => 'Resume';

  @override
  String get scoringBlueFreeThrowMade => 'Blue free throw made';

  @override
  String get scoringBlueFreeThrowMissed => 'Blue free throw missed';

  @override
  String get scoringRedFreeThrowMade => 'Red free throw made';

  @override
  String get scoringRedFreeThrowMissed => 'Red free throw missed';

  @override
  String get scoringPossessionBlue => 'Blue possession';

  @override
  String get scoringPossessionRed => 'Red possession';

  @override
  String get scoringNote => 'Note';

  @override
  String get scoringCustom => 'Custom';

  @override
  String get scoringClockRunning => 'Timer running';

  @override
  String scoringClockStatus(Object status) {
    return 'Timer status: $status';
  }

  @override
  String get scoringPendingLocationTitle => 'This shot is unfinished';

  @override
  String get scoringPendingDraftTitle => 'A shot draft is not submitted';

  @override
  String get scoringPendingLocationBody =>
      'Finish recording this shot, or cancel the unfinished step and leave.';

  @override
  String get scoringPendingDraftBody =>
      'Cancel or submit the current shot before leaving.';

  @override
  String get scoringStay => 'Stay in match';

  @override
  String get scoringCancelLocationLeave => 'Cancel and leave';

  @override
  String get scoringCancelDraftLeave => 'Cancel draft and leave';

  @override
  String get scoringSubmitLeave => 'Submit and leave';

  @override
  String get scoringDraftCreateFailed => 'Could not create a shot draft';

  @override
  String get scoringMissTrackingDisabled =>
      'Missed shots are not recorded with these settings';

  @override
  String get scoringActionRejected =>
      'Finish the current shot or location first';

  @override
  String get scoringFreeThrowTrackingDisabled =>
      'This free throw is not recorded with the current tracking setting';

  @override
  String get scoringPossessionNotCommitted =>
      'The possession change was not committed';

  @override
  String get scoringNoUnlocatedShot => 'No unlocated shot is available';

  @override
  String get scoringLocationCancelFailed =>
      'The current location cannot be cancelled';

  @override
  String get scoringUndoFailed => 'Could not undo';

  @override
  String get scoringPauseFailed => 'The timer cannot be paused now';

  @override
  String get scoringResumeFailed => 'The timer cannot be resumed now';

  @override
  String get scoringDraftIncomplete => 'The shot draft is incomplete';

  @override
  String get scoringNoDraft => 'There is no draft to cancel';

  @override
  String get scoringAddNote => 'Add note';

  @override
  String get scoringNoteHint =>
      'For example: a timeout, a play, or what happened on court';

  @override
  String get scoringRecordNote => 'Save note';

  @override
  String get scoringRecordCustom => 'Record custom event';

  @override
  String get scoringEventLabel => 'Event name';

  @override
  String get scoringRecordEvent => 'Record event';

  @override
  String get scoringNoTimer => 'No timer';

  @override
  String get scoringTimerNotConfigured => 'Timer off';

  @override
  String get scoringOvertime => 'Overtime';

  @override
  String get scoringRegulationExpired => 'Regulation ended';

  @override
  String get scoringClockPaused => 'Timer paused';

  @override
  String get scoringBackToScoringList => 'Back to scoring';

  @override
  String scoringMatchTime(Object time) {
    return 'Match time: $time';
  }

  @override
  String get scoringResumeClock => 'Resume timer';

  @override
  String get scoringMarkShotTitle => 'Mark shot location?';

  @override
  String get scoringMarkShotBody =>
      'Tap or drag the dot on the court, then confirm.';

  @override
  String get scoringDoNotMark => 'Do not mark';

  @override
  String get scoringMark => 'Mark';

  @override
  String get scoringResolvePending =>
      'Confirm or cancel the location, or undo the shot first';

  @override
  String get scoringReplay => 'Replay';

  @override
  String get courtReplayLabel => 'Replay court';

  @override
  String get courtEditLabel => 'Shot location editor';

  @override
  String get courtReplayHint => 'View recorded shots';

  @override
  String get courtEditHint =>
      'Tap the court to record or adjust a shot location';

  @override
  String get routeLoading => 'Loading';

  @override
  String get routeHomeLoadError => 'Could not load the active match';

  @override
  String get routeActiveMatchCheckError =>
      'Could not check for a match in progress';

  @override
  String get routeActiveMatchCheckBody =>
      'Return home and try again to check whether a match is already in progress.';

  @override
  String get routeMatchLoadError => 'Could not load the match';

  @override
  String get routeMatchNotActive => 'This match is not in progress';

  @override
  String get routeMatchNotActiveBody => 'Resume a match in progress from home.';

  @override
  String get routeMatchRestoring => 'Restoring match';

  @override
  String get routeMatchRestoringBody => 'Restoring scoring. Please wait.';

  @override
  String get routeReplayOpenError => 'Could not open replay';

  @override
  String get routeReplayOpenErrorBody =>
      'Match data could not be read. Return and try again.';

  @override
  String get routeReplayNotFound => 'Match not found';

  @override
  String get routeReplayNotFoundBody => 'The record may have been removed.';

  @override
  String get routeActiveMatchTitle => 'A match is already in progress';

  @override
  String get routeContinueMatch => 'Continue match';

  @override
  String get routeAbandonMatch => 'Abandon match';

  @override
  String get routeActiveCheckLoading =>
      'Checking for a match in progress. Try again shortly.';

  @override
  String get routeStartMatchConflict =>
      'A match is already in progress; continue or abandon it first.';

  @override
  String get routeAbandonFailed => 'Could not abandon the match. Try again.';

  @override
  String get routeResumeFailed => 'Could not resume the match. Try again.';

  @override
  String get routeLeaveTitle => 'Leave match';

  @override
  String get routeLeaveBody =>
      'Keep the timer running, or pause it before leaving.';

  @override
  String get routeLeaveStay => 'Stay in match';

  @override
  String get routeLeaveKeepRunning => 'Keep timer running';

  @override
  String get routeLeavePauseAndLeave => 'Pause and leave';

  @override
  String get routeClockCheckError =>
      'Could not check the timer. Stay in the match and try again.';

  @override
  String get routeProjectLinkError =>
      'Could not open the link. Try again later.';

  @override
  String get projectTitle => 'Project details';

  @override
  String get projectTagline =>
      'An offline scoring and replay tool for one-on-one basketball.';

  @override
  String get projectFreeForever => 'Free forever';

  @override
  String get projectFreeForeverDetail =>
      'Core scoring and replay features will always be free.';

  @override
  String get projectOpenSource => 'Open source forever';

  @override
  String get projectOpenSourceDetail =>
      'The source code stays public for anyone to review or contribute to.';

  @override
  String get projectOffline => 'Local and offline';

  @override
  String get projectOfflineDetail =>
      'Record matches without an account or internet connection.';

  @override
  String get projectPrivacy => 'Personal data stays local';

  @override
  String get projectPrivacyDetail =>
      'Player and match data is stored on this device. Hoopito does not upload it.';

  @override
  String get projectOpen => 'Explore and contribute';

  @override
  String get projectContribute => 'Contribution guide';

  @override
  String get projectIssue => 'Report an issue';

  @override
  String get projectOpenBrowser => 'Open in browser';

  @override
  String get exportBackupDialogTitle => 'Choose a Hoopito backup';

  @override
  String get exportAutomaticBackupDialogTitle =>
      'Choose an automatic backup folder';

  @override
  String get exportFullBackupSubject => 'Hoopito full local backup';

  @override
  String get exportSafetyBackupSubject =>
      'Hoopito safety backup before restore';

  @override
  String get exportCsvSubject => 'Hoopito CSV export';

  @override
  String get exportReplaySubject => 'Hoopito match replay';

  @override
  String get projectGitHub => 'GitHub';

  @override
  String get projectLicense => 'License';

  @override
  String get historyImportedIncompleteTitle => 'Unfinished match from a backup';

  @override
  String get historyImportedIncompleteBody =>
      'This match was imported from a backup. Resume it to keep scoring.';

  @override
  String get historyResumeImportedIncomplete => 'Resume match';

  @override
  String get historyResumeImportedIncompleteFailed =>
      'Could not resume this match. Check that no other match is in progress.';

  @override
  String get historyImportedIncompleteLoadError =>
      'Could not load imported unfinished matches.';

  @override
  String get historyImportedIncompleteRetry => 'Retry';

  @override
  String get pregameTemplatesFallbackLoading =>
      'Using built-in rules because templates could not be loaded. Player profiles are still loading.';

  @override
  String get pregamePlayersLoading =>
      'Player profiles are still loading. You can enter temporary names for now.';

  @override
  String get pregameTemplatesPlayersError =>
      'Rule templates and player profiles could not be loaded. You can use temporary names to start.';

  @override
  String get pregamePlayersError =>
      'Player profiles could not be loaded. You can use temporary names to start.';

  @override
  String get pregameTemplatesFallbackNotice =>
      'Could not load rule templates. Using built-in rules for now.';

  @override
  String get scoringConfirmLocation => 'Confirm location';

  @override
  String get scoringSkipLocation => 'Cancel location';

  @override
  String get scoringFoul => 'Foul';

  @override
  String scoringFoulForSide(Object side) {
    return '$side foul';
  }

  @override
  String get scoringMore => 'More';

  @override
  String get scoringShotsGroup => 'Shots';

  @override
  String get scoringShotDisplayGroup => 'Shot display';

  @override
  String scoringShowMissMarkers(Object side) {
    return 'Show $side misses';
  }

  @override
  String get scoringDisplayShown => 'Shown';

  @override
  String get scoringDisplayHidden => 'Hidden';

  @override
  String get scoringFreeThrowsGroup => 'Free throws';

  @override
  String get scoringMatchStatusGroup => 'Match status';

  @override
  String get scoringRecordsGroup => 'Records';

  @override
  String get scoringNotesCustomRecordsGroup => 'Notes and custom records';

  @override
  String get scoringMatchGroup => 'Match';

  @override
  String get scoringChooseScoringSide => 'Choose Blue or Red to score';

  @override
  String scoringSupplementPrompt(Object points, Object seconds, Object side) {
    return '$side +$points: add location · ${seconds}s left';
  }

  @override
  String scoringMissSupplementPrompt(Object seconds, Object side) {
    return '$side miss: add location · ${seconds}s left';
  }

  @override
  String get scoringSupplementExpired => 'Time to add a location has run out';

  @override
  String scoringScoreSemantics(Object points, Object side) {
    return '$side +$points points';
  }

  @override
  String scoringLocationPendingSemantics(
    Object points,
    Object seconds,
    Object side,
  ) {
    return '$side +$points, $seconds seconds left to add a location';
  }

  @override
  String scoringMissSemantics(Object side) {
    return '$side miss';
  }

  @override
  String scoringMissLocationPendingSemantics(Object seconds, Object side) {
    return '$side miss, $seconds seconds left to add a location';
  }

  @override
  String get updateTitle => 'Software update';

  @override
  String get updateSubtitle => 'Check for, download, and install new versions';

  @override
  String updateCurrentVersion(Object version) {
    return 'Current version: $version';
  }

  @override
  String get updateAutoCheck => 'Check for updates at startup';

  @override
  String get updateAutoCheckDetail =>
      'Checks online for new versions after startup without uploading match or player records. You can still check manually when this is off.';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateUpToDate => 'You are up to date';

  @override
  String updateAvailable(Object version) {
    return 'Version $version is available';
  }

  @override
  String updateDownloadSize(Object size) {
    return 'Download size: $size';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateDownload => 'Download update';

  @override
  String get updateDownloadQueued =>
      'Waiting for the system to start the download';

  @override
  String updateDownloading(Object received, Object total) {
    return 'Downloading $received / $total';
  }

  @override
  String get updateDownloadPaused =>
      'Download paused; the system will continue when possible';

  @override
  String get updateVerifying => 'Verifying the installation package…';

  @override
  String get updateReady => 'Ready to install';

  @override
  String get updateInstall => 'Install update';

  @override
  String get updateCancelDownload => 'Cancel download';

  @override
  String get updateRetryDownload => 'Download again';

  @override
  String get updateCheckFailed =>
      'Unable to check for updates. Check your connection and try again.';

  @override
  String get updateDownloadFailed =>
      'Download did not finish. Check your connection and storage, then try again.';

  @override
  String get updateVerificationFailed =>
      'Package verification failed. Download it again.';

  @override
  String get updateFileMissing =>
      'The installation package was removed. Download it again.';

  @override
  String get updateInstallBlocked =>
      'Finish or end the current match before installing. Installation is also blocked until the match status is confirmed.';

  @override
  String get updatePermissionTitle => 'Allow update installation';

  @override
  String get updatePermissionBody =>
      'Allow Hoopito to install apps in system settings, then return here. You will still need to confirm in the system installer.';

  @override
  String get updateOpenSettings => 'Open system settings';

  @override
  String get updateInstallFailed =>
      'Unable to open the installer. Check the system installation permission and try again.';

  @override
  String get updateInstallerOpened =>
      'System installer opened. Confirm installation there. If you cancel, you can try again.';

  @override
  String get updateIncompatible =>
      'This update needs a newer version of Android and cannot be installed on this device.';

  @override
  String get updateUnsupported =>
      'In-app updates are not available on this platform yet.';

  @override
  String get updateSettingsFailed => 'The setting was not saved. Try again.';

  @override
  String get updateFallback => 'Using GitHub as a fallback download source';

  @override
  String get pregameGoalScoringMode => 'Scoring mode';

  @override
  String get pregameGoalModeFree => 'Free scoring';

  @override
  String get pregameGoalModeTarget => 'Target scoring';

  @override
  String get ruleBuiltInDefault => 'Default rules';

  @override
  String get scoringTargetReachedTitle => 'Target score reached';

  @override
  String scoringTargetPoints(int target) {
    return 'Target: $target points';
  }

  @override
  String scoringTargetReachedPlayer(String name) {
    return '$name has reached the target';
  }

  @override
  String get scoringTargetReachedTie =>
      'Both sides reached the target. Scores are tied.';

  @override
  String get scoringTargetSupplement =>
      'You can still add the last shot’s location';

  @override
  String get scoringTargetSkipLocation => 'Skip location';

  @override
  String get scoringTargetUndoScore => 'Undo last score';

  @override
  String get scoringTargetContinueHelp =>
      'Continue to play past the target without further target reminders';

  @override
  String get summaryGameFinished => 'Game finished';

  @override
  String summaryWinner(String name) {
    return '$name wins';
  }
}

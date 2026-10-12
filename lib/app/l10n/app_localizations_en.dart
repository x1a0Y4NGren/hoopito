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
  String get v2SaveFailed => 'Save failed; retry';

  @override
  String get v2LastAction => 'Last action';

  @override
  String v2GrowthChartRange(int count, int total) {
    return 'Showing the latest $count of $total games';
  }

  @override
  String get v2SafetyWriteError =>
      'The safety copy could not be saved and verified. Current data was preserved. Check device storage and try again.';

  @override
  String get v2SafetyLoadError => 'Safety copies could not be read. Try again.';

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
      'Players and rules copied; adjust before starting';

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
  String get v2CoverageComplete => 'Every shot recorded';

  @override
  String get v2CoverageHelp =>
      'Confirm only when every attempt, including misses, was recorded. Choose mainly scores if attempts were missed.';

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
      'Confirmed locations / recorded field goal attempts';

  @override
  String get v2SavePlayer => 'Save to player profile';

  @override
  String get v2CreatePlayer => 'Create player profile';

  @override
  String get v2SelectPlayer => 'Choose existing player';

  @override
  String get v2PlayerSaved => 'Profile linked; match name preserved';

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
      'Tap the court first, or add a location within 10 seconds after scoring. Record misses too.';

  @override
  String get v2GuideUndo => 'Undo and finish';

  @override
  String get v2GuideUndoBody =>
      'Undo restores the last action. Tap Finish at the top and confirm the recording scope.';

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
      'You can replay the saved record. This match is excluded from completed-match statistics.';

  @override
  String get v2SafetyTitle => 'Restore safety copies';

  @override
  String get v2SafetyHelp =>
      'Current data is protected before replacement or rollback. The two most recent copies are kept.';

  @override
  String get v2SafetyEmpty => 'No safety copies yet';

  @override
  String get v2SafetyRestore => 'Restore this copy';

  @override
  String get v2SafetyConfirm =>
      'Restoring this copy replaces current data after saving another safety copy.';

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
      'Target score reached. Confirm finish or continue.';

  @override
  String get ruleWinByTwoRequired =>
      'Target reached, but a two-point lead is required. Continue?';

  @override
  String get ruleMatchPoint => 'Match point';

  @override
  String get rulePossessionSuggested => 'Possession suggested';

  @override
  String ruleFoulLimit(Object limit, Object side) {
    return '$side foul limit reached ($limit).';
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
      'Events, locations, and audit records will be deleted and cannot be recovered.';

  @override
  String get historyLoadMore => 'Load more';

  @override
  String get historyMoreFilters => 'More filters';

  @override
  String get historyAdvancedTitle => 'Advanced filters';

  @override
  String get historyRuleLabel => 'Rule';

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
  String get historyLocationCompleteness => 'Location completeness';

  @override
  String get replayTitle => 'Match replay';

  @override
  String get replayExportTooltip => 'Export replay image';

  @override
  String get replayAuditTooltip => 'Audit history';

  @override
  String get replayEditMode => 'Edit mode';

  @override
  String get replayReadOnly => 'Read only';

  @override
  String get replayFinished => 'Final';

  @override
  String get replayInProgress => 'In progress';

  @override
  String get replayExportTitle => 'Replay share image';

  @override
  String get replayExportDescription =>
      'Locations and analysis will be saved as a local image.';

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
  String get replayScoringEvents => 'Scoring events';

  @override
  String get replayFouls => 'Fouls';

  @override
  String get replayLocationCompleteness => 'Location completeness';

  @override
  String get replayPossession => 'Possession segments';

  @override
  String get replayFinishedBoundary => 'Final boundary';

  @override
  String get replayInProgressBoundary => 'Live boundary';

  @override
  String get replayNoPossession => 'No possession segments recorded';

  @override
  String get replayPossessionManual => 'Manual';

  @override
  String get replayPossessionSuggested => 'Suggested';

  @override
  String get replayPossessionCurrent => 'In progress';

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
  String get replaySuggestedReason => 'Suggested by the scoring rule';

  @override
  String get replayTimeline => 'Event timeline';

  @override
  String get replayFilters => 'Replay filters';

  @override
  String get replayNoEvents => 'No events match the filters';

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
  String get replayEditorTitle => 'Edit event';

  @override
  String get replayEditorSide => 'Side';

  @override
  String get replayEditorEventKind => 'Event type';

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
  String get replayEditorDelete => 'Soft delete';

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
  String get replayEditorDeleteTitle => 'Delete this event?';

  @override
  String get replayEditorDeleteBody =>
      'The event will be marked deleted and its audit history will be preserved.';

  @override
  String get replayEditorConfirmDelete => 'Delete';

  @override
  String get replayEditorRestoreTitle => 'Restore this event?';

  @override
  String get replayEditorRestoreBody =>
      'The event will contribute to the match projection again.';

  @override
  String get replayEditorConfirmRestore => 'Restore';

  @override
  String get replayAuditTitle => 'Audit history';

  @override
  String get replayAuditEmpty => 'No edit history';

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
  String get replayAuditActionCommand => 'Command';

  @override
  String get replayAuditActionLocate => 'Located';

  @override
  String get replayAuditActionPossession => 'Possession updated';

  @override
  String get replayAuditActionPossessionSuggestion => 'Possession suggested';

  @override
  String get replayAuditActionUnknown => 'Unknown operation';

  @override
  String get replayAuditTargetEvent => 'Event';

  @override
  String get replayAuditTargetLocation => 'Shot location';

  @override
  String get replayAuditTargetMatch => 'Match';

  @override
  String get replayAuditTargetCommand => 'Command';

  @override
  String get replayAuditFieldType => 'Event type';

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
  String get replayAnalyticsScoringFlow => 'Scoring flow';

  @override
  String get replayAnalyticsNoScoringEvents => 'No scoring events';

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
  String get replayAnalyticsTrackingCoverage => 'Recording coverage';

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
  String get playerAnalyticsWindow => 'Time window';

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
      'Not enough complete attempts to show a percentage';

  @override
  String get playerAnalyticsZoneHeatmap => 'Shot zones';

  @override
  String get playerAnalyticsNoMatches => 'No completed games in this window';

  @override
  String get playerAnalyticsNoTrend => 'Not enough trend data yet';

  @override
  String get playerAnalyticsOpponentNone => 'No opponent filter';

  @override
  String get playerAnalyticsLoadError => 'Could not load analytics';

  @override
  String get playerAnalyticsLoadErrorBody =>
      'Career analytics could not be loaded. Try again to refresh the local match data.';

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
  String get playerComparisonWindowMode => 'Time windows';

  @override
  String get playerComparisonMatchModeHint =>
      'Compare two completed games linked to this player.';

  @override
  String get playerComparisonWindowModeHint =>
      'Compare two adjacent, non-overlapping windows ending when this page was opened.';

  @override
  String get playerComparisonBaseline => 'Baseline';

  @override
  String get playerComparisonCurrent => 'Current';

  @override
  String get playerComparisonDifference => 'Difference';

  @override
  String get playerComparisonSelectBaseline => 'Select baseline game';

  @override
  String get playerComparisonSelectCurrent => 'Select current game';

  @override
  String get playerComparisonSwap => 'Swap baseline and current games';

  @override
  String get playerComparisonChooseGame => 'Choose a game';

  @override
  String get playerComparisonLoading => 'Building comparison';

  @override
  String get playerComparisonLoadError => 'Could not load comparison';

  @override
  String get playerComparisonLoadErrorBody =>
      'Local analytics could not be rebuilt. Check the match data and try again.';

  @override
  String get playerComparisonRetry => 'Retry';

  @override
  String get playerComparisonNoMatches => 'No games to compare';

  @override
  String get playerComparisonNoMatchesBody =>
      'Finish a game with this linked player profile before comparing samples.';

  @override
  String get playerComparisonNeedTwoMatches => 'Two games are required';

  @override
  String get playerComparisonNeedTwoMatchesBody =>
      'Finish one more linked game to compare individual games. Time-window comparison is still available.';

  @override
  String get playerComparisonEmptyWindows => 'No games in either window';

  @override
  String get playerComparisonEmptyWindowsBody =>
      'Try a longer window or remove the opponent filter.';

  @override
  String get playerComparisonBaselineEmpty =>
      'The baseline window has no games.';

  @override
  String get playerComparisonCurrentEmpty => 'The current window has no games.';

  @override
  String get playerComparisonSummary => 'Evidence summary';

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
  String get playerComparisonLocationCoverage => 'Location coverage';

  @override
  String get playerComparisonConfirmedZones => 'Confirmed shot-location share';

  @override
  String get playerComparisonConfirmedZonesNote =>
      'Zone percentages use confirmed shot locations only.';

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
    return 'An incompatible legacy database version$version was detected. The existing file will remain unchanged; Hoopito will not silently migrate, delete, or clear it. Export or back up the old file first, then create new local data with this version.';
  }

  @override
  String get bootstrapFailureBody =>
      'The local database could not be opened. Existing data was not modified. Try again later or create a new local database.';

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
  String get settingsThemeSubtitle => 'Choose how the app is displayed';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsMotionTitle => 'Motion';

  @override
  String get settingsMotionSubtitle =>
      'Choose how much interface motion is used';

  @override
  String get settingsMotionStandard => 'Standard motion';

  @override
  String get settingsMotionReduced => 'Reduced motion';

  @override
  String get settingsMotionHelp =>
      'Reduced motion shortens transitions and removes decorative movement.';

  @override
  String get settingsMotionPreview => 'Motion preview';

  @override
  String get settingsMotionPreviewStandard => 'Preview: standard motion';

  @override
  String get settingsMotionPreviewReduced => 'Preview: reduced motion';

  @override
  String get settingsDataSection => 'Data';

  @override
  String get settingsDataManagementTitle => 'Manage data and backups';

  @override
  String get settingsDataManagementSubtitle =>
      'Export, restore, and automatic backups in one place';

  @override
  String get settingsManualDataSection => 'Export and restore';

  @override
  String get settingsAutomaticBackupSection => 'Automatic backup settings';

  @override
  String get settingsExportDataTitle => 'Export data';

  @override
  String get settingsExportDataSubtitle =>
      'Choose a restorable JSON backup or CSV files for analysis';

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
      'JSON file containing matches, players, rules, events, and settings';

  @override
  String get settingsExportBackupSuccess =>
      'System sharing opened; you can save or send the backup';

  @override
  String get settingsRestoreTitle => 'Restore from backup';

  @override
  String get settingsRestoreSubtitleMerge =>
      'Merge safely, or replace local data after creating a safety backup';

  @override
  String get settingsRestoreSubtitleBlocked =>
      'Merging is allowed during a match; replacement requires ending it';

  @override
  String get settingsExportCsvTitle => 'Export CSV';

  @override
  String get settingsExportCsvSubtitle =>
      'Three files: matches, events, and player statistics';

  @override
  String get settingsExportCsvSuccess =>
      'System sharing opened; you can save the three CSV files';

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
      'Not selected; only folders you explicitly choose are accessed';

  @override
  String get settingsBackupNowTitle => 'Back up now';

  @override
  String get settingsBackupNever => 'No manual or automatic backup has run yet';

  @override
  String settingsBackupLastSuccess(Object date, Object time) {
    return 'Last success: $date $time';
  }

  @override
  String get settingsBackupRetentionTitle => 'Automatic backup retention';

  @override
  String get settingsBackupRetentionSubtitle =>
      'Only Hoopito automatic backups are cleaned up; manual and safety backups are kept';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsPrivacyTitle => 'Local data';

  @override
  String get settingsPrivacySubtitle =>
      'Personal data stays on this device and is never uploaded';

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
      'Open source, free forever, with license and contribution details';

  @override
  String get settingsRestoreDialogTitle => 'Choose backup import mode';

  @override
  String get settingsRestorePickerTitle => 'Choose a Hoopito backup';

  @override
  String get settingsMergeTitle => 'Merge import (recommended)';

  @override
  String get settingsMergeSubtitle =>
      'Keep local settings; conflicts are deterministically remapped and players are not merged by nickname';

  @override
  String get settingsReplaceTitle => 'Replace local data';

  @override
  String get settingsReplaceSubtitle =>
      'Create a safety backup first, then atomically replace all local data';

  @override
  String get settingsReplaceBlocked => 'End the current match first';

  @override
  String get settingsReplaceConfirmTitle => 'Replace all local data?';

  @override
  String get settingsReplaceConfirmBody =>
      'After validation, Hoopito will create a safety backup and atomically replace local data.';

  @override
  String get settingsReplaceConfirmAction => 'Choose backup';

  @override
  String get settingsRestoreNotSelected => 'No backup file selected';

  @override
  String get settingsMergeCompleted =>
      'Backup merged; local settings and the active match were kept';

  @override
  String get settingsReplaceCompleted =>
      'Backup restored; automatic backup location was reset';

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
  String get settingsBackupWritten =>
      'Local backup written to the selected folder';

  @override
  String settingsRetentionUpdated(Object count) {
    return 'The latest $count automatic backups will be kept';
  }

  @override
  String get settingsErrorChecksum =>
      'Backup verification failed; the file may be damaged or modified';

  @override
  String get settingsErrorFutureVersion =>
      'This backup was created by a newer version; upgrade Hoopito and try again';

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
      'The selected folder is not writable; choose it again';

  @override
  String get settingsErrorBackupWrite =>
      'Backup write failed; choose the backup folder again and retry';

  @override
  String get settingsErrorRestoreBlocked => 'End the current match first';

  @override
  String get settingsErrorGeneric => 'The operation failed. Try again later.';

  @override
  String get playerAnalyticsNoLocationData => 'No location data';

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
      'The match stays in local history but is removed from the active-match entry.';

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
      'Temporary players can still play immediately; save a profile to find them next time.';

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
      'This player could not be opened. Check the local data and try again.';

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
      'Create a custom rule template to define how the next game is scored.';

  @override
  String get rulesCreate => 'New rule';

  @override
  String get rulesLoadError => 'Could not load rule templates';

  @override
  String get rulesLoadErrorBody =>
      'Rule templates could not be loaded. Check the local data and try again.';

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
  String get ruleTimeLimitLabel => 'Time limit minutes (optional)';

  @override
  String get ruleFoulLimitLabel => 'Foul limit (optional)';

  @override
  String get ruleScoreButtonsLabel => 'Scoring buttons (comma-separated)';

  @override
  String get ruleCustomLabelsLabel => 'Custom event labels (comma-separated)';

  @override
  String get ruleWinByTwoTitle => 'Win by 2 points';

  @override
  String get rulePossessionHintTitle => 'Suggest possession after scoring';

  @override
  String get rulePossessionHintSubtitle =>
      'Suggestion only; manual scoring remains available';

  @override
  String get rulePossessionPolicyLabel => 'Possession policy after scoring';

  @override
  String get rulePossessionPolicyHelper =>
      'Automatic suggestions are available only when possession hints are enabled.';

  @override
  String get ruleSaveAction => 'Save rule';

  @override
  String rulePositiveInteger(Object label) {
    return '$label must be a positive integer';
  }

  @override
  String get ruleAtLeastOneInteger => 'Enter at least one positive integer';

  @override
  String get rulePolicyManual => 'Manual correction';

  @override
  String get rulePolicySwitchAfterMade => 'Switch after made shot';

  @override
  String get rulePolicyKeepAfterMade => 'Keep after made shot';

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
  String get pregameClockMode => 'Clock mode';

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
  String get pregameTimerDisabled => 'When off, match time is not recorded';

  @override
  String get pregameCountUp => 'Count up';

  @override
  String get pregameCountDown => 'Countdown';

  @override
  String get pregameCountdownLabel => 'Countdown minutes (1–180)';

  @override
  String get pregameCountdownHelper =>
      'Countdown must be between 1 and 180 minutes.';

  @override
  String get pregameMinutes => 'minutes';

  @override
  String get pregameProfileConflict =>
      'This player profile is already used by the other side.';

  @override
  String get pregameCountdownInvalid =>
      'Enter an integer number of minutes from 1 to 180.';

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
  String get pregameParticipationMode => 'Participation';

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
      'Changing this match name does not change the player profile.';

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
      'A player profile cannot be used on both sides.';

  @override
  String get pregameValidationRedMissing =>
      'The selected Red profile no longer exists; choose another or use a temporary name.';

  @override
  String get pregameValidationBlueMissing =>
      'The selected Blue profile no longer exists; choose another or use a temporary name.';

  @override
  String get pregameValidationModeRequired =>
      'Choose a recording mode before starting the match.';

  @override
  String get pregameValidationCountdownRequired =>
      'Turn on the timer before using countdown mode.';

  @override
  String get pregameValidationCountdownDuration =>
      'Countdown minutes must be from 1 to 180.';

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
      'Pause to step away, or confirm the current score and finish the match.';

  @override
  String get scoringReturnToScoring => 'Return to scoring';

  @override
  String get scoringPauseMatch => 'Pause match';

  @override
  String get scoringMatchPausedTitle => 'Match paused';

  @override
  String get scoringMatchPausedBody =>
      'Scoring is locked. Continue the match when you are ready to record again.';

  @override
  String get scoringReturnHome => 'Return home';

  @override
  String get scoringPendingPauseExitBody =>
      'An unfinished gray court marker is still active. Returning home or finishing will discard this draft.';

  @override
  String get scoringDiscardDraft => 'Discard draft';

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
  String get scoringPendingLocationTitle => 'A shot is waiting for a location';

  @override
  String get scoringPendingDraftTitle => 'A shot draft is not submitted';

  @override
  String get scoringPendingLocationBody =>
      'Cancel location, confirm it, or undo the shot before leaving.';

  @override
  String get scoringPendingDraftBody =>
      'Cancel or submit the current shot before leaving.';

  @override
  String get scoringStay => 'Stay in match';

  @override
  String get scoringCancelLocationLeave => 'Cancel location and leave';

  @override
  String get scoringCancelDraftLeave => 'Cancel draft and leave';

  @override
  String get scoringSubmitLeave => 'Submit and leave';

  @override
  String get scoringDraftCreateFailed => 'Could not create a shot draft';

  @override
  String get scoringMissTrackingDisabled =>
      'Misses are not recorded with the current tracking setting';

  @override
  String get scoringActionRejected =>
      'Action rejected; finish the location or draft first';

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
  String get scoringUndoFailed => 'The undo was not committed';

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
      'For example: timeout, tactic, or game situation';

  @override
  String get scoringRecordNote => 'Record note';

  @override
  String get scoringRecordCustom => 'Record custom event';

  @override
  String get scoringEventLabel => 'Event label';

  @override
  String get scoringRecordEvent => 'Record event';

  @override
  String get scoringNoTimer => 'No timer';

  @override
  String get scoringTimerNotConfigured => 'Timer not configured';

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
      'Confirm, skip, or undo the current location first';

  @override
  String get scoringReplay => 'Replay';

  @override
  String get courtReplayLabel => 'Replay court';

  @override
  String get courtEditLabel => 'Basketball court location editor';

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
  String get routeActiveMatchCheckError => 'Could not confirm the active match';

  @override
  String get routeActiveMatchCheckBody =>
      'Return home and try again so a new match is not started with an unknown state.';

  @override
  String get routeMatchLoadError => 'Could not load the match';

  @override
  String get routeMatchNotActive => 'Match is not active';

  @override
  String get routeMatchNotActiveBody => 'Resume an active match from home.';

  @override
  String get routeMatchRestoring => 'Restoring match';

  @override
  String get routeMatchRestoringBody =>
      'The match was read, but scoring is still being restored.';

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
      'Checking for an active match; try again shortly.';

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
  String get routeLeaveKeepRunning => 'Keep running';

  @override
  String get routeLeavePauseAndLeave => 'Pause and leave';

  @override
  String get routeClockCheckError =>
      'Could not confirm the timer; stay in the match and try again.';

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
      'Core scoring and replay features will never become paid features.';

  @override
  String get projectOpenSource => 'Open source forever';

  @override
  String get projectOpenSourceDetail =>
      'The source stays public for anyone to review and contribute to.';

  @override
  String get projectOffline => 'Local and offline';

  @override
  String get projectOfflineDetail =>
      'Record matches without an account or network.';

  @override
  String get projectPrivacy => 'Personal data stays local';

  @override
  String get projectPrivacyDetail =>
      'Player and match data stays on this device.';

  @override
  String get projectOpen => 'Open project';

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
  String get historyImportedIncompleteTitle => 'Imported incomplete match';

  @override
  String get historyImportedIncompleteBody =>
      'This match came from a backup and is unfinished; resume it to continue scoring.';

  @override
  String get historyResumeImportedIncomplete => 'Resume imported match';

  @override
  String get historyResumeImportedIncompleteFailed =>
      'Could not resume the imported match. Confirm that no other match is active.';

  @override
  String get historyImportedIncompleteLoadError =>
      'Could not check imported incomplete matches.';

  @override
  String get historyImportedIncompleteRetry => 'Retry';

  @override
  String get pregameTemplatesFallbackLoading =>
      'Rule templates are unavailable; built-in rules are shown while player profiles load.';

  @override
  String get pregamePlayersLoading =>
      'Player profiles are loading; you can enter temporary names now.';

  @override
  String get pregameTemplatesPlayersError =>
      'Rule templates and player profiles are unavailable; try temporary names and retry.';

  @override
  String get pregamePlayersError =>
      'Player profiles are unavailable; try temporary names and retry.';

  @override
  String get pregameTemplatesFallbackNotice =>
      'Rule templates are unavailable; built-in rules are shown.';

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
  String get scoringNotesCustomRecordsGroup => 'Notes/Custom Records';

  @override
  String get scoringMatchGroup => 'Match';

  @override
  String get scoringChooseScoringSide => 'Choose Blue or Red to score';

  @override
  String scoringSupplementPrompt(Object points, Object seconds, Object side) {
    return 'Add $side +$points location · ${seconds}s';
  }

  @override
  String scoringMissSupplementPrompt(Object seconds, Object side) {
    return 'Add $side miss location · ${seconds}s';
  }

  @override
  String get scoringSupplementExpired => 'Location supplement expired';

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
    return '$side +$points, location pending $seconds seconds';
  }

  @override
  String scoringMissSemantics(Object side) {
    return '$side miss';
  }

  @override
  String scoringMissLocationPendingSemantics(Object seconds, Object side) {
    return '$side miss, location pending $seconds seconds';
  }
}

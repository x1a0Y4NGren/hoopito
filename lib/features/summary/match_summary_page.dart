import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/design_system/score_flow_chart.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/practice/practice_coach.dart';

class MatchSummaryPage extends StatelessWidget {
  const MatchSummaryPage({
    required this.detail,
    required this.analytics,
    required this.onBack,
    required this.onRematch,
    required this.onReplay,
    required this.onShare,
    required this.onCorrectCoverage,
    required this.onSavePlayer,
    this.busy = false,
    this.seriesPanel,
    this.practice,
    this.onPracticeStartReal,
    this.onPracticeReturnMatch,

    super.key,
  });
  final PracticePresentation? practice;
  final VoidCallback? onPracticeStartReal, onPracticeReturnMatch;
  final MatchDetail detail;
  final MatchAnalytics analytics;
  final VoidCallback onBack, onRematch, onReplay, onShare, onCorrectCoverage;
  final ValueChanged<String> onSavePlayer;
  final bool busy;
  final Widget? seriesPanel;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = editorialThemeOf(context);
    final complete =
        detail.match.trackingCoverage.index >=
        TrackingCoverage.shotAttempts.index;
    String percentage(double? value) =>
        value == null ? l10n.replayNoData : '${(value * 100).round()}%';
    final page = EditorialScaffold(
      maxContentWidth: 800,
      masthead: PracticeAvoid(
        enabled: practice != null,
        child: EditorialMasthead(
          compact: true,
          title: practice == null ? l10n.v2Result : l10n.practiceFinished,
          leading: IconButton(
            tooltip: l10n.historyHomeTooltip,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('match-summary-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (detail.match.lifecycle == MatchLifecycle.finished ||
                      detail.match.lifecycle == MatchLifecycle.archived) ...[
                    PracticeAvoid(
                      enabled: practice != null,
                      child: Text(
                        l10n.summaryGameFinished,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PracticeAvoid(
                      enabled: practice != null,
                      child: Semantics(
                        header: true,
                        child: Text(
                          detail.redScore == detail.blueScore
                              ? l10n.historyDraw
                              : l10n.summaryWinner(
                                  detail.redScore > detail.blueScore
                                      ? detail.match.redName
                                      : detail.match.blueName,
                                ),
                          key: const Key('summary-outcome'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  PracticeTarget(
                    active: practice?.step == PracticeStep.result,
                    id: PracticeTargetId.summaryScore,
                    child: MatchScoreRow(
                      blueTeamName: detail.match.blueName,
                      blueScore: detail.blueScore,
                      redTeamName: detail.match.redName,
                      redScore: detail.redScore,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (practice == null && seriesPanel != null) seriesPanel!,
                  PracticeAvoid(
                    enabled: practice != null,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (seriesPanel == null || practice != null)
                          FilledButton.icon(
                            key: const Key('summary-rematch'),
                            onPressed: busy ? null : onRematch,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              practice == null
                                  ? l10n.v2Rematch
                                  : l10n.practiceReplay,
                            ),
                          ),
                        if (practice != null && onPracticeStartReal != null)
                          FilledButton(
                            key: const Key('practice-real-game'),
                            onPressed: busy ? null : onPracticeStartReal,
                            child: Text(l10n.practiceRealGame),
                          ),
                        if (practice != null && onPracticeReturnMatch != null)
                          OutlinedButton(
                            key: const Key('practice-return-match'),
                            onPressed: busy ? null : onPracticeReturnMatch,
                            child: Text(l10n.practiceReturnMatch),
                          ),
                        if (practice == null)
                          OutlinedButton.icon(
                            key: const Key('summary-share'),
                            onPressed: busy ? null : onShare,
                            icon: const Icon(Icons.ios_share),
                            label: Text(l10n.v2Share),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  EditorialSectionRule(label: l10n.replayAnalyticsScoringFlow),
                  const SizedBox(height: 12),
                  ScoreFlowChart(
                    entries: analytics.scoringFlow,
                    redName: detail.match.redName,
                    blueName: detail.match.blueName,
                  ),
                  const SizedBox(height: 24),
                  if (analytics.keyPossessions.isNotEmpty) ...[
                    EditorialSectionRule(label: l10n.replayAnalyticsKeyMoments),
                    for (final moment in analytics.keyPossessions.reversed.take(
                      2,
                    ))
                      ListTile(
                        key: ValueKey(
                          'summary-moment-${moment.eventId}-${moment.type.name}',
                        ),
                        contentPadding: EdgeInsets.zero,
                        title: Text(switch (moment.type) {
                          KeyPossessionType.tie => l10n.replayAnalyticsTie,
                          KeyPossessionType.overtake =>
                            l10n.replayAnalyticsOvertake,
                          KeyPossessionType.matchPoint =>
                            l10n.replayAnalyticsMatchPoint,
                          KeyPossessionType.scoringRun =>
                            l10n.replayAnalyticsScoringRun,
                        }),
                        subtitle: Text(
                          moment.side == TeamSide.red
                              ? detail.match.redName
                              : detail.match.blueName,
                        ),
                        trailing: Text(
                          '${moment.redScore} : ${moment.blueScore}',
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                  EditorialSectionRule(label: l10n.v2CoverageTitle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      complete
                          ? l10n.v2CoverageComplete
                          : l10n.v2CoverageScores,
                    ),
                    subtitle: Text(l10n.v2CoverageHelp),
                    trailing: practice != null
                        ? null
                        : IconButton(
                            key: const Key('summary-correct-coverage'),
                            tooltip: l10n.v2CorrectCoverage,
                            onPressed: busy ? null : onCorrectCoverage,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                  ),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${l10n.v2FieldGoalPercentage} ${percentage(analytics.reliableShootingPercentage)}',
                      ),
                      Text(
                        '${l10n.v2FreeThrowPercentage} ${percentage(analytics.reliableFreeThrowPercentage)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.v2LocationScope}: ${analytics.confirmedLocationCount}/${analytics.fieldGoalAttemptCount}',
                    style: TextStyle(color: theme.mutedInk),
                  ),
                  const SizedBox(height: 24),
                  for (final participant in detail.match.participants)
                    if (practice == null && participant.playerProfileId == null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(participant.nameSnapshot),
                        subtitle: Text(l10n.v2SavePlayer),
                        trailing: IconButton(
                          key: ValueKey('summary-save-${participant.id}'),
                          tooltip: l10n.v2SavePlayer,
                          onPressed: busy
                              ? null
                              : () => onSavePlayer(participant.id),
                          icon: const Icon(Icons.person_add_outlined),
                        ),
                      ),
                  const SizedBox(height: 16),
                  if (practice == null)
                    OutlinedButton(
                      key: const Key('summary-replay'),
                      onPressed: busy ? null : onReplay,
                      child: Text(l10n.v2Replay),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return practice == null
        ? page
        : PracticeCoachHost(presentation: practice!, child: page);
  }
}

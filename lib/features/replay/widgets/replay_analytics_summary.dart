import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

const _flowCardPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 7);
const _flowCardBorderWidth = 4.0;

class ReplayAnalyticsSummary extends StatelessWidget {
  const ReplayAnalyticsSummary({
    required this.analytics,
    required this.redName,
    required this.blueName,
    super.key,
  });

  final MatchAnalytics analytics;
  final String redName;
  final String blueName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final attempts = analytics.fieldGoalAttemptCount;
    final percentage = analytics.reliableShootingPercentage == null
        ? null
        : (analytics.reliableShootingPercentage! * 100).round();
    final largestLead = analytics.largestLeadSide == null
        ? l10n.replayNoData
        : '${_sideName(analytics.largestLeadSide!)} '
              '+${analytics.largestLeadPoints}';

    return Material(
      type: MaterialType.transparency,
      child: Column(
        key: const Key('replay-analytics-summary'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AnalyticsHeading(
            title: l10n.replayAnalyticsTitle,
            icon: Icons.insights_outlined,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AnalyticsMetric(
                label: l10n.replayAnalyticsLeadChanges,
                value: l10n.replayExportLeadChangesValue(analytics.leadChanges),
              ),
              _AnalyticsMetric(
                label: l10n.replayAnalyticsLargestLead,
                value: largestLead,
              ),
              _AnalyticsMetric(
                label: l10n.v2FieldGoalPercentage,
                value: _shootingValue(
                  analytics,
                  attempts: attempts,
                  percentage: percentage,
                  l10n: l10n,
                ),
              ),
              _AnalyticsMetric(
                label: l10n.v2FreeThrowPercentage,
                value: analytics.reliableFreeThrowPercentage == null
                    ? l10n.replayNoData
                    : '${(analytics.reliableFreeThrowPercentage! * 100).round()}% · ${analytics.freeThrowMadeCount}/${analytics.freeThrowAttemptCount}',
              ),
              _AnalyticsMetric(
                label: l10n.replayAnalyticsKeyMoments,
                value: l10n.replayExportKeyMomentsValue(
                  analytics.keyPossessions.length,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AnalyticsSubheading(title: l10n.replayAnalyticsShotRecord),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AnalyticsMetric(
                label: l10n.replayAnalyticsFieldGoals,
                value:
                    '${analytics.fieldGoalMadeCount}/${analytics.fieldGoalAttemptCount}',
              ),
              _AnalyticsMetric(
                label: l10n.replayAnalyticsFreeThrows,
                value:
                    '${analytics.freeThrowMadeCount}/${analytics.freeThrowAttemptCount}',
              ),
              _AnalyticsMetric(
                label: l10n.replayAnalyticsFouls,
                value: '${analytics.redFoulCount} · ${analytics.blueFoulCount}',
              ),
              _AnalyticsMetric(
                label: l10n.replayAnalyticsPossessions,
                value:
                    analytics.possessionCount?.toString() ?? l10n.replayNoData,
              ),
              _AnalyticsMetric(
                label: l10n.replayAnalyticsTrackingCoverage,
                value: _coverageLabel(analytics.trackingCoverage, l10n),
              ),
              _AnalyticsMetric(
                label: l10n.v2LocationScope,
                value: analytics.fieldGoalAttemptCount == 0
                    ? l10n.replayNoData
                    : '${analytics.confirmedLocationCount}/${analytics.fieldGoalAttemptCount}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(l10n.v2RecordedSample),
          _AnalyticsSubheading(title: l10n.replayAnalyticsScoringRun),
          const SizedBox(height: 8),
          if (analytics.scoringRuns.isEmpty)
            Text(l10n.replayAnalyticsNoScoringEvents)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analytics.scoringRuns
                  .map(
                    (run) => _AnalyticsIndexTag(
                      color: run.side == TeamSide.red
                          ? editorialThemeOf(context).teamRed
                          : editorialThemeOf(context).teamBlue,
                      label: '${_sideName(run.side)} +${run.points}',
                    ),
                  )
                  .toList(),
            ),
          if (analytics.zoneDistribution.isNotEmpty) ...[
            const SizedBox(height: 18),
            _AnalyticsSubheading(title: l10n.replayAnalyticsShotZones),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analytics.zoneDistribution.entries
                  .map(
                    (entry) => _AnalyticsIndexTag(
                      color: editorialThemeOf(context).rule,
                      label: '${_zoneLabel(entry.key, l10n)} · ${entry.value}',
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 18),
          _AnalyticsSubheading(title: l10n.replayAnalyticsScoringFlow),
          const SizedBox(height: 8),
          if (analytics.scoringFlow.isEmpty)
            Text(l10n.replayAnalyticsNoScoringEvents)
          else
            _scoringFlow(context, l10n),
          const SizedBox(height: 18),
          _AnalyticsSubheading(title: l10n.replayAnalyticsKeyPossessions),
          const SizedBox(height: 4),
          if (analytics.keyPossessions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.replayAnalyticsNoKeyPossessions),
            )
          else
            ...analytics.keyPossessions.map(
              (possession) => _KeyPossessionRow(
                possession: possession,
                sideName: _sideName(possession.side),
                l10n: l10n,
              ),
            ),
        ],
      ),
    );
  }

  String _sideName(TeamSide side) {
    return side == TeamSide.red ? redName : blueName;
  }

  Widget _scoringFlow(BuildContext context, AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    final scoreStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final sideStyle = textTheme.labelSmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure scaled text so the flow can grow while keeping lazy cards.
        final scorePainter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        );
        final sidePainter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
          ellipsis: '…',
        );
        var width = 80.0;
        var height = 72.0;
        try {
          for (final entry in analytics.scoringFlow) {
            scorePainter.text = TextSpan(
              text: '${entry.redScore} : ${entry.blueScore}',
              style: scoreStyle,
            );
            scorePainter.layout();
            width = math.max(
              width,
              scorePainter.width +
                  _flowCardPadding.horizontal +
                  _flowCardBorderWidth,
            );
          }
          width = math.min(width, constraints.maxWidth);
          for (final entry in analytics.scoringFlow) {
            scorePainter.text = TextSpan(
              text: '${entry.redScore} : ${entry.blueScore}',
              style: scoreStyle,
            );
            sidePainter.text = TextSpan(
              text: '${_sideName(entry.side)} +${entry.points}',
              style: sideStyle,
            );
            final textWidth = math.max(
              0.0,
              width - _flowCardPadding.horizontal - _flowCardBorderWidth,
            );
            scorePainter.layout(maxWidth: textWidth);
            sidePainter.layout(maxWidth: textWidth);
            height = math.max(
              height,
              scorePainter.height +
                  sidePainter.height +
                  _flowCardPadding.vertical,
            );
          }
        } finally {
          scorePainter.dispose();
          sidePainter.dispose();
        }
        return SizedBox(
          height: height,
          child: ListView.separated(
            key: const Key('replay-scoring-flow'),
            scrollDirection: Axis.horizontal,
            itemCount: analytics.scoringFlow.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 18),
            ),
            itemBuilder: (context, index) {
              final entry = analytics.scoringFlow[index];
              return _ScoringFlowItem(
                entry: entry,
                sideName: _sideName(entry.side),
                l10n: l10n,
                width: width,
                scoreStyle: scoreStyle,
                sideStyle: sideStyle,
              );
            },
          ),
        );
      },
    );
  }

  String _shootingValue(
    MatchAnalytics analytics, {
    required int attempts,
    required int? percentage,
    required AppLocalizations l10n,
  }) {
    if (attempts == 0) return l10n.replayAnalyticsNoAttempts;
    if (analytics.hasReliableShootingPercentage && percentage != null) {
      return '$percentage% · ${analytics.fieldGoalMadeCount}/$attempts';
    }
    return '${l10n.replayAnalyticsIncompleteShooting} · '
        '${l10n.replayAnalyticsRecordedAttempts} · $attempts';
  }

  String _coverageLabel(TrackingCoverage coverage, AppLocalizations l10n) {
    return switch (coverage) {
      TrackingCoverage.none => l10n.replayAnalyticsTrackingNone,
      TrackingCoverage.scoresOnly => l10n.replayAnalyticsTrackingScoresOnly,
      TrackingCoverage.shotAttempts => l10n.replayAnalyticsTrackingShotAttempts,
      TrackingCoverage.locations => l10n.replayAnalyticsTrackingLocations,
      TrackingCoverage.full => l10n.replayAnalyticsTrackingFull,
    };
  }

  String _zoneLabel(ShotZone zone, AppLocalizations l10n) {
    return switch (zone) {
      ShotZone.restrictedArea => l10n.replayAnalyticsZoneRestrictedArea,
      ShotZone.paint => l10n.replayAnalyticsZonePaint,
      ShotZone.midRange => l10n.replayAnalyticsZoneMidRange,
      ShotZone.cornerThree => l10n.replayAnalyticsZoneCornerThree,
      ShotZone.wingThree => l10n.replayAnalyticsZoneWingThree,
      ShotZone.topThree => l10n.replayAnalyticsZoneTopThree,
      ShotZone.unknown => l10n.replayAnalyticsZoneUnknown,
    };
  }
}

class _AnalyticsHeading extends StatelessWidget {
  const _AnalyticsHeading({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: editorialThemeOf(context).arenaAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsSubheading extends StatelessWidget {
  const _AnalyticsSubheading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 128, minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: editorialThemeOf(context).rule),
          bottom: BorderSide(color: editorialThemeOf(context).rule),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsIndexTag extends StatelessWidget {
  const _AnalyticsIndexTag({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: color, width: 4)),
    ),
    alignment: Alignment.centerLeft,
    child: Text(label),
  );
}

class _ScoringFlowItem extends StatelessWidget {
  const _ScoringFlowItem({
    required this.entry,
    required this.sideName,
    required this.l10n,
    required this.width,
    required this.scoreStyle,
    required this.sideStyle,
  });

  final ScoringFlowEntry entry;
  final String sideName;
  final AppLocalizations l10n;
  final double width;
  final TextStyle? scoreStyle;
  final TextStyle? sideStyle;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final color = entry.side == TeamSide.red
        ? editorial.teamRed
        : editorial.teamBlue;
    return Semantics(
      label: l10n.replayAnalyticsScoreSemantics(
        sideName,
        entry.points,
        entry.redScore,
        entry.blueScore,
      ),
      child: Container(
        width: width,
        padding: _flowCardPadding,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: _flowCardBorderWidth),
          ),
          color: color.withValues(alpha: 0.07),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.redScore} : ${entry.blueScore}', style: scoreStyle),
            Text(
              '$sideName +${entry.points}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sideStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyPossessionRow extends StatelessWidget {
  const _KeyPossessionRow({
    required this.possession,
    required this.sideName,
    required this.l10n,
  });

  final KeyPossession possession;
  final String sideName;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final color = possession.side == TeamSide.red
        ? editorial.teamRed
        : editorial.teamBlue;
    final label = Text(
      '$sideName · ${_label(possession.type, l10n)}',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    final score = Text('${possession.redScore} : ${possession.blueScore}');
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.16),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 240 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          return Row(
            children: [
              Container(width: 4, height: 28, color: color),
              const SizedBox(width: 10),
              if (compact)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 4), score],
                  ),
                )
              else ...[
                Expanded(child: label),
                score,
              ],
            ],
          );
        },
      ),
    );
  }

  String _label(KeyPossessionType type, AppLocalizations l10n) {
    return switch (type) {
      KeyPossessionType.tie => l10n.replayAnalyticsTie,
      KeyPossessionType.overtake => l10n.replayAnalyticsOvertake,
      KeyPossessionType.matchPoint => l10n.replayAnalyticsMatchPoint,
      KeyPossessionType.scoringRun => l10n.replayAnalyticsScoringRun,
    };
  }
}

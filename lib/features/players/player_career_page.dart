import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/player_career_aggregate.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/players/player_career_controller.dart';

class PlayerCareerPage extends StatelessWidget {
  const PlayerCareerPage({
    required this.controller,
    required this.player,
    required this.opponents,
    this.onCompare,
    this.onMatchTap,
    this.onBack,
    this.onEdit,
    super.key,
  });

  final PlayerCareerController controller;
  final Player player;
  final List<Player> opponents;
  final VoidCallback? onCompare;
  final ValueChanged<String>? onMatchTap;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return EditorialScaffold(
      maxContentWidth: 920,
      masthead: EditorialMasthead(
        title: _l10n(context).playerAnalyticsTitle,
        leading: canPop || onBack != null
            ? EditorialTapTarget(
                key: const Key('career-back'),
                onPressed: onBack ?? () => Navigator.maybePop(context),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: const Icon(Icons.arrow_back),
              )
            : null,
        trailing: onEdit == null
            ? null
            : EditorialTapTarget(
                key: const Key('career-edit'),
                onPressed: onEdit,
                tooltip: _l10n(context).playersEdit,
                label: _l10n(context).playersEdit,
                child: const Icon(Icons.edit_outlined),
              ),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, child) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
          child: _CareerBody(
            controller: controller,
            player: player,
            opponents: opponents,
            onCompare: onCompare,
            onMatchTap: onMatchTap,
          ),
        ),
      ),
    );
  }
}

class _CareerBody extends StatelessWidget {
  const _CareerBody({
    required this.controller,
    required this.player,
    required this.opponents,
    required this.onCompare,
    required this.onMatchTap,
  });

  final PlayerCareerController controller;
  final Player player;
  final List<Player> opponents;
  final VoidCallback? onCompare;
  final ValueChanged<String>? onMatchTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlayerIdentity(player: player),
        if (onCompare != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: ValueKey('player-comparison-${player.id}'),
              onPressed: onCompare,
              icon: const Icon(Icons.compare_arrows),
              label: Text(l10n.playerComparisonOpen),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _CareerFilters(controller: controller, opponents: opponents),
        const SizedBox(height: 24),
        if (controller.isLoading)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (controller.error != null)
          EditorialErrorState(
            title: l10n.playerAnalyticsLoadError,
            message: l10n.playerAnalyticsLoadErrorBody,
            actionLabel: l10n.playerAnalyticsRetry,
            onAction: controller.reload,
          )
        else if (controller.aggregate == null)
          const SizedBox.shrink()
        else
          _AggregateContent(
            aggregate: controller.aggregate!,
            l10n: l10n,
            query: controller.query,
            opponentLabel: opponents
                .where(
                  (opponent) =>
                      opponent.id == controller.query.opponentPlayerId,
                )
                .firstOrNull
                ?.nickname,
            onMatchTap: onMatchTap,
          ),
      ],
    );
  }
}

class _PlayerIdentity extends StatelessWidget {
  const _PlayerIdentity({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final avatarForeground = accessibleForegroundFor(editorial.inverseSurface);
    return Semantics(
      container: true,
      label: player.nickname,
      excludeSemantics: true,
      child: Row(
        children: [
          CircleAvatar(
            key: ValueKey('career-avatar-${player.id}'),
            radius: 32,
            backgroundColor: editorial.inverseSurface,
            foregroundColor: avatarForeground,
            child: Text(
              player.nickname.characters.first,
              style: TextStyle(
                color: avatarForeground,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.nickname,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: editorial.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (player.note case final note? when note.trim().isNotEmpty)
                  Text(
                    note,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: editorial.mutedInk),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerFilters extends StatelessWidget {
  const _CareerFilters({required this.controller, required this.opponents});

  final PlayerCareerController controller;
  final List<Player> opponents;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionRule(label: l10n.playerAnalyticsWindow),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final window in PlayerCareerWindow.values)
              _FilterChoice(
                key: ValueKey('career-window-${window.name}'),
                label: _windowLabel(window, l10n),
                selected: controller.query.window == window,
                onPressed: () => controller.setWindow(window),
              ),
          ],
        ),
        if (opponents.isNotEmpty) ...[
          const SizedBox(height: 20),
          EditorialSectionRule(label: l10n.playerAnalyticsOpponent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChoice(
                key: const Key('career-opponent-all'),
                label: l10n.playerAnalyticsOpponentNone,
                selected: controller.query.opponentPlayerId == null,
                onPressed: () => controller.setOpponent(null),
              ),
              for (final opponent in opponents)
                _FilterChoice(
                  key: ValueKey('career-opponent-${opponent.id}'),
                  label: opponent.nickname,
                  selected: controller.query.opponentPlayerId == opponent.id,
                  onPressed: () => controller.setOpponent(opponent.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
            ),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: selected
                  ? accessibleForegroundFor(editorial.inverseSurface)
                  : editorial.ink,
              backgroundColor: selected ? editorial.inverseSurface : null,
              side: BorderSide(
                color: selected ? editorial.inverseSurface : editorial.rule,
                width: selected ? 2 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AggregateContent extends StatelessWidget {
  const _AggregateContent({
    required this.aggregate,
    required this.l10n,
    required this.query,
    this.opponentLabel,
    this.onMatchTap,
  });

  final PlayerCareerAggregate aggregate;
  final AppLocalizations l10n;
  final PlayerCareerQuery query;
  final String? opponentLabel;
  final ValueChanged<String>? onMatchTap;

  @override
  Widget build(BuildContext context) {
    if (aggregate.matches == 0) {
      return EditorialEmptyState(
        title: l10n.playerAnalyticsNoMatches,
        message: l10n.playerAnalyticsNoReliablePercentage,
        icon: Icons.insights_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionRule(label: l10n.playerAnalyticsGrowth),
        const SizedBox(height: 12),
        _GrowthSummary(aggregate: aggregate, l10n: l10n),
        const SizedBox(height: 20),
        _CoreStatistics(aggregate: aggregate, l10n: l10n),
        const SizedBox(height: 24),
        EditorialSectionRule(label: l10n.playerAnalyticsShootingTrend),
        const SizedBox(height: 12),
        _TrendSection(
          aggregate: aggregate,
          l10n: l10n,
          query: query,
          opponentLabel: opponentLabel,
          onMatchTap: onMatchTap,
        ),
        const SizedBox(height: 24),
        EditorialSectionRule(label: l10n.playerAnalyticsZoneHeatmap),
        const SizedBox(height: 12),
        _ZoneSection(aggregate: aggregate, l10n: l10n),
      ],
    );
  }
}

class _GrowthSummary extends StatelessWidget {
  const _GrowthSummary({required this.aggregate, required this.l10n});

  final PlayerCareerAggregate aggregate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final pointsDelta = aggregate.recentChange.pointsDelta;
    final marginDelta = aggregate.recentChange.marginDelta;
    if (pointsDelta == null && marginDelta == null) {
      return Text(l10n.playerAnalyticsNoTrend);
    }
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        if (pointsDelta != null)
          _Delta(label: l10n.v2PointsDifference, value: pointsDelta),
        if (marginDelta != null)
          _Delta(label: l10n.v2MarginDifference, value: marginDelta),
      ],
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final positive = value >= 0;
    final color = positive ? editorial.success : editorial.danger;
    return Semantics(
      label: '$label ${positive ? '+' : ''}${value.toStringAsFixed(1)}',
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            positive ? Icons.trending_up : Icons.trending_down,
            color: color,
          ),
          Text(label),
          Text(
            '${positive ? '+' : ''}${value.toStringAsFixed(1)}',
            style: TextStyle(
              color: color,
              fontFamily: HoopitoTypography.displayFamily,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreStatistics extends StatelessWidget {
  const _CoreStatistics({required this.aggregate, required this.l10n});

  final PlayerCareerAggregate aggregate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CareerStat(
          label: l10n.playerAnalyticsAveragePoints,
          value: aggregate.averagePoints.toStringAsFixed(1),
        ),
        _CareerStat(
          label: l10n.playerAnalyticsAverageMargin,
          value: aggregate.averageMargin.toStringAsFixed(1),
        ),
        _CareerStat(
          label: l10n.playerAnalyticsRecord,
          value: '${aggregate.wins}/${aggregate.matches}',
          note: l10n.playerAnalyticsWins,
        ),
      ],
    );
  }
}

class _CareerStat extends StatelessWidget {
  const _CareerStat({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: editorial.rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: editorial.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (note != null) Text(note!),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ScoreNumeral(value: value, fontSize: 46),
        ],
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.aggregate,
    required this.l10n,
    required this.query,
    this.opponentLabel,
    this.onMatchTap,
  });

  final PlayerCareerAggregate aggregate;
  final AppLocalizations l10n;
  final PlayerCareerQuery query;
  final String? opponentLabel;
  final ValueChanged<String>? onMatchTap;

  @override
  Widget build(BuildContext context) {
    if (aggregate.shootingTrend.isEmpty) {
      return Text(l10n.playerAnalyticsNoTrend);
    }
    final allSamples = aggregate.shootingTrend;
    final start = allSamples.length > 30 ? allSamples.length - 30 : 0;
    final samples = allSamples.sublist(start);
    final dates = MaterialLocalizations.of(context);
    final editorial = editorialThemeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_windowLabel(query.window, l10n)} · '
          '${opponentLabel ?? l10n.playerAnalyticsOpponentNone}',
          key: const Key('career-growth-scope'),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.v2GrowthChartRange(samples.length, allSamples.length),
          key: const Key('career-growth-range'),
        ),
        const SizedBox(height: 4),
        Text(
          '${dates.formatShortDate(samples.first.playedAt.toLocal())} – '
          '${dates.formatShortDate(samples.last.playedAt.toLocal())}',
          key: const Key('career-growth-dates'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 64 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              height: 160,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('100%'), Text('50%'), Text('0%')],
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label:
                    '${l10n.playerAnalyticsFieldGoals}. ${l10n.v2GrowthSample}',
                image: true,
                child: RepaintBoundary(
                  key: const Key('career-growth-chart-image'),
                  child: CustomPaint(
                    key: const Key('career-growth-chart'),
                    painter: _ShootingTrendPainter(
                      percentages: [
                        for (final sample in samples)
                          sample.recordedShootingPercentage,
                      ],
                      lineColor: editorial.arenaAccent,
                      gridColor: editorial.rule,
                    ),
                    size: const Size(double.infinity, 160),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.v2GrowthSample, style: Theme.of(context).textTheme.bodySmall),
        if (samples.every(
          (sample) => sample.recordedShootingPercentage == null,
        )) ...[
          const SizedBox(height: 8),
          Text(l10n.playerAnalyticsNoReliablePercentage),
        ],
        const SizedBox(height: 12),
        for (final (index, trend) in samples.indexed)
          _TrendRow(
            index: start + index + 1,
            trend: trend,
            l10n: l10n,
            onTap: onMatchTap == null ? null : () => onMatchTap!(trend.matchId),
          ),
      ],
    );
  }
}

class _ShootingTrendPainter extends CustomPainter {
  const _ShootingTrendPainter({
    required this.percentages,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double?> percentages;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final width = size.width - inset * 2;
    final height = size.height - inset * 2;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final ratio in [0.0, 0.5, 1.0]) {
      final y = inset + height * ratio;
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), grid);
    }
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    Offset? previous;
    for (final (index, percentage) in percentages.indexed) {
      if (percentage == null) {
        previous = null;
        continue;
      }
      final x = percentages.length == 1
          ? size.width / 2
          : inset + width * index / (percentages.length - 1);
      final point = Offset(x, inset + height * (1 - percentage.clamp(0, 1)));
      if (previous != null) canvas.drawLine(previous, point, line);
      canvas.drawCircle(point, 4, line);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _ShootingTrendPainter oldDelegate) =>
      oldDelegate.percentages != percentages ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.index,
    required this.trend,
    required this.l10n,
    this.onTap,
  });

  final int index;
  final PlayerCareerShootingTrend trend;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final percentage = trend.recordedShootingPercentage;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: editorial.rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${l10n.playerAnalyticsFieldGoals} '),
                TextSpan(
                  text: '${trend.fieldGoalMade}/${trend.fieldGoalAttempts}',
                  style: const TextStyle(
                    fontFamily: HoopitoTypography.displayFamily,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(text: ' · ${l10n.playerAnalyticsFreeThrows} '),
                TextSpan(
                  text: '${trend.freeThrowMade}/${trend.freeThrowAttempts}',
                  style: const TextStyle(
                    fontFamily: HoopitoTypography.displayFamily,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          );
          final identity = Text(
            '${index.toString().padLeft(2, '0')}  '
            '${MaterialLocalizations.of(context).formatShortDate(trend.playedAt.toLocal())}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: editorial.mutedInk,
              fontFamily: HoopitoTypography.displayFamily,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
          final result = _TrendResult(
            percentage: percentage,
            freeThrowPercentage: trend.freeThrowPercentage,
            recordedAttempts: trend.recordedAttempts,
            l10n: l10n,
          );
          final compact =
              constraints.maxWidth < 520 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    if (onTap != null) const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 4),
                result,
                const SizedBox(height: 4),
                details,
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 132, child: identity),
              Expanded(child: details),
              const SizedBox(width: 16),
              result,
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          );
        },
      ),
    );
    return InkWell(
      key: ValueKey('career-trend-${trend.matchId}'),
      onTap: onTap,
      child: row,
    );
  }
}

class _TrendResult extends StatelessWidget {
  const _TrendResult({
    required this.percentage,
    required this.freeThrowPercentage,
    required this.recordedAttempts,
    required this.l10n,
  });

  final double? percentage;
  final double? freeThrowPercentage;
  final int recordedAttempts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final numericStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontFamily: HoopitoTypography.displayFamily,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final (label, value) in [
          (l10n.playerAnalyticsFieldGoals, percentage),
          (l10n.playerAnalyticsFreeThrows, freeThrowPercentage),
        ])
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value == null ? '—' : '${(value * 100).round()}%',
                style: numericStyle,
              ),
            ],
          ),
        if (percentage == null)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.playerAnalyticsRecordedShots,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text('$recordedAttempts', style: numericStyle),
            ],
          ),
      ],
    );
  }
}

class _ZoneSection extends StatelessWidget {
  const _ZoneSection({required this.aggregate, required this.l10n});

  final PlayerCareerAggregate aggregate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (aggregate.zoneHeatmap.isEmpty) {
      final editorial = editorialThemeOf(context);
      return Container(
        key: const Key('player-analytics-zone-empty'),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: editorial.mutedInk, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, color: editorial.mutedInk),
            const SizedBox(width: 10),
            Flexible(child: Text(l10n.playerAnalyticsNoLocationData)),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in aggregate.zoneHeatmap.entries)
          _ZoneMetric(label: _zoneLabel(entry.key, l10n), value: entry.value),
      ],
    );
  }
}

class _ZoneMetric extends StatelessWidget {
  const _ZoneMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 128),
      decoration: BoxDecoration(border: Border.all(color: editorial.rule)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: HoopitoTypography.displayFamily,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _windowLabel(PlayerCareerWindow window, AppLocalizations l10n) {
  return switch (window) {
    PlayerCareerWindow.sevenDays => l10n.playerAnalyticsSevenDays,
    PlayerCareerWindow.thirtyDays => l10n.playerAnalyticsThirtyDays,
    PlayerCareerWindow.ninetyDays => l10n.playerAnalyticsNinetyDays,
    PlayerCareerWindow.allTime => l10n.playerAnalyticsAllTime,
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

AppLocalizations _l10n(BuildContext context) {
  return AppLocalizations.of(context) ?? AppLocalizationsZh();
}

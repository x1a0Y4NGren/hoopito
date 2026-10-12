import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/players/player_comparison_controller.dart';

class PlayerComparisonPage extends StatelessWidget {
  const PlayerComparisonPage({
    required this.controller,
    required this.player,
    super.key,
  });

  final PlayerComparisonController controller;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final useCompactMasthead = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return EditorialScaffold(
      maxContentWidth: 1120,
      masthead: EditorialMasthead(
        title: _l10n(context).playerComparisonTitle,
        eyebrow: player.nickname,
        compact: useCompactMasthead,
        leading: canPop
            ? EditorialTapTarget(
                onPressed: () => Navigator.maybePop(context),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, child) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
          child: _ComparisonBody(controller: controller),
        ),
      ),
    );
  }
}

class _ComparisonBody extends StatelessWidget {
  const _ComparisonBody({required this.controller});

  final PlayerComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeControls(controller: controller),
        const SizedBox(height: HoopitoSpacing.section),
        if (controller.mode == PlayerComparisonMode.matchPair)
          _MatchControls(controller: controller)
        else
          _WindowControls(controller: controller),
        const SizedBox(height: HoopitoSpacing.section),
        if (controller.isLoading)
          _LoadingState(label: l10n.playerComparisonLoading)
        else if (controller.error != null)
          EditorialErrorState(
            title: l10n.playerComparisonLoadError,
            message: l10n.playerComparisonLoadErrorBody,
            actionLabel: l10n.playerComparisonRetry,
            onAction: controller.retry,
          )
        else
          _SettledContent(controller: controller),
      ],
    );
  }
}

class _ModeControls extends StatelessWidget {
  const _ModeControls({required this.controller});

  final PlayerComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final editorial = editorialThemeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionRule(label: l10n.playerComparisonMode),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChoiceButton(
              key: const Key('comparison-mode-matchPair'),
              label: l10n.playerComparisonMatchMode,
              icon: Icons.sports_basketball_outlined,
              selected: controller.mode == PlayerComparisonMode.matchPair,
              onPressed: () =>
                  controller.setMode(PlayerComparisonMode.matchPair),
            ),
            _ChoiceButton(
              key: const Key('comparison-mode-adjacentWindow'),
              label: l10n.playerComparisonWindowMode,
              icon: Icons.date_range_outlined,
              selected: controller.mode == PlayerComparisonMode.adjacentWindow,
              onPressed: () =>
                  controller.setMode(PlayerComparisonMode.adjacentWindow),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          controller.mode == PlayerComparisonMode.matchPair
              ? l10n.playerComparisonMatchModeHint
              : l10n.playerComparisonWindowModeHint,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: editorial.mutedInk),
        ),
      ],
    );
  }
}

class _MatchControls extends StatelessWidget {
  const _MatchControls({required this.controller});

  final PlayerComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    if (!controller.hasEnoughMatchesForPair) return const SizedBox.shrink();
    final baseline = _matchById(controller, controller.baselineMatchId);
    final current = _matchById(controller, controller.currentMatchId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final wide = constraints.maxWidth >= 720 && textScale <= 1.4;
        final baselineSelector = _MatchSelector(
          key: const Key('comparison-baseline-selector'),
          title: l10n.playerComparisonSelectBaseline,
          selected: baseline,
          matches: controller.matches,
          onSelected: controller.setBaselineMatch,
        );
        final currentSelector = _MatchSelector(
          key: const Key('comparison-current-selector'),
          title: l10n.playerComparisonSelectCurrent,
          selected: current,
          matches: controller.matches,
          onSelected: controller.setCurrentMatch,
        );
        final swap = EditorialTapTarget(
          key: const Key('comparison-swap'),
          onPressed: controller.swapMatches,
          label: l10n.playerComparisonSwap,
          tooltip: l10n.playerComparisonSwap,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.swap_horiz),
          ),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: baselineSelector),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: swap,
              ),
              Expanded(child: currentSelector),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            baselineSelector,
            Align(alignment: Alignment.center, child: swap),
            currentSelector,
          ],
        );
      },
    );
  }
}

class _MatchSelector extends StatelessWidget {
  const _MatchSelector({
    required this.title,
    required this.selected,
    required this.matches,
    required this.onSelected,
    super.key,
  });

  final String title;
  final PlayerComparisonMatch? selected;
  final List<PlayerComparisonMatch> matches;
  final ValueChanged<String> onSelected;

  Future<void> _openPicker(BuildContext context) async {
    final l10n = _l10n(context);
    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.playerComparisonChooseGame),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < matches.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  Builder(
                    builder: (context) {
                      final match = matches[index];
                      final isSelected = match.matchId == selected?.matchId;
                      return ListTile(
                        minTileHeight: 56,
                        selected: isSelected,
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(_matchLabel(dialogContext, match)),
                        onTap: () =>
                            Navigator.pop(dialogContext, match.matchId),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (selectedId != null) onSelected(selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: editorial.mutedInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => _openPicker(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 56),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected == null ? '—' : _matchLabel(context, selected!),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ],
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls({required this.controller});

  final PlayerComparisonController controller;

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
            for (final window in PlayerComparisonWindow.values)
              _ChoiceButton(
                key: ValueKey('comparison-window-${window.name}'),
                label: _windowLabel(window, l10n),
                icon: Icons.calendar_view_week_outlined,
                selected: controller.window == window,
                onPressed: () => controller.setWindow(window),
              ),
          ],
        ),
        if (controller.opponents.isNotEmpty) ...[
          const SizedBox(height: 20),
          EditorialSectionRule(label: l10n.playerAnalyticsOpponent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChoiceButton(
                key: const Key('comparison-opponent-all'),
                label: l10n.playerAnalyticsAllOpponents,
                icon: Icons.people_outline,
                selected: controller.opponentPlayerId == null,
                onPressed: () => controller.setOpponent(null),
              ),
              for (final opponent in controller.opponents)
                _ChoiceButton(
                  key: ValueKey('comparison-opponent-${opponent.playerId}'),
                  label: opponent.nameSnapshot,
                  icon: Icons.person_outline,
                  selected: controller.opponentPlayerId == opponent.playerId,
                  onPressed: () => controller.setOpponent(opponent.playerId),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final selectedForeground = accessibleForegroundFor(
      editorial.inverseSurface,
    );
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
            icon: Icon(icon, size: 20),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: selected ? selectedForeground : editorial.ink,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label),
        ],
      ),
    ),
  );
}

class _SettledContent extends StatelessWidget {
  const _SettledContent({required this.controller});

  final PlayerComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    if (controller.matches.isEmpty) {
      return EditorialEmptyState(
        title: l10n.playerComparisonNoMatches,
        message: l10n.playerComparisonNoMatchesBody,
        icon: Icons.sports_basketball_outlined,
      );
    }
    if (controller.mode == PlayerComparisonMode.matchPair &&
        !controller.hasEnoughMatchesForPair) {
      return EditorialEmptyState(
        title: l10n.playerComparisonNeedTwoMatches,
        message: l10n.playerComparisonNeedTwoMatchesBody,
        icon: Icons.compare_arrows_outlined,
      );
    }
    final report = controller.report;
    if (report == null) return const SizedBox.shrink();
    if (report.mode == PlayerComparisonMode.adjacentWindow &&
        report.baseline.isEmpty &&
        report.current.isEmpty) {
      return EditorialEmptyState(
        title: l10n.playerComparisonEmptyWindows,
        message: l10n.playerComparisonEmptyWindowsBody,
        icon: Icons.event_busy_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (report.mode == PlayerComparisonMode.adjacentWindow &&
            (report.baseline.isEmpty || report.current.isEmpty)) ...[
          _SingleSideNotice(
            message: report.baseline.isEmpty
                ? l10n.playerComparisonBaselineEmpty
                : l10n.playerComparisonCurrentEmpty,
          ),
          const SizedBox(height: 20),
        ],
        _ComparisonReportView(report: report),
      ],
    );
  }
}

class _SingleSideNotice extends StatelessWidget {
  const _SingleSideNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    return Semantics(
      key: const Key('comparison-single-side-empty'),
      container: true,
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: editorial.surface,
          border: Border(left: BorderSide(color: editorial.warning, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: editorial.warning),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ComparisonReportView extends StatelessWidget {
  const _ComparisonReportView({required this.report});

  final PlayerComparisonReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final primary = report.evidence
        .where(
          (item) => item.metric != PlayerComparisonMetric.confirmedZoneShare,
        )
        .toList(growable: false);
    final zones = report.evidence
        .where(
          (item) =>
              item.metric == PlayerComparisonMetric.confirmedZoneShare &&
              (item.baselineValue != null || item.currentValue != null),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionRule(label: l10n.playerComparisonSummary),
        const SizedBox(height: 12),
        _SampleRangeHeader(report: report),
        const SizedBox(height: 8),
        Text(l10n.v2RecordedSample),
        Text(l10n.v2LocationScope),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final wide = constraints.maxWidth >= 760 && textScale <= 1.4;
            return Column(
              children: [
                for (final item in primary)
                  _EvidenceRow(
                    key: ValueKey('comparison-metric-${item.metric.name}'),
                    evidence: item,
                    mode: report.mode,
                    wide: wide,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: HoopitoSpacing.section),
        EditorialSectionRule(label: l10n.playerComparisonConfirmedZones),
        const SizedBox(height: 8),
        Text(l10n.playerComparisonConfirmedZonesNote),
        const SizedBox(height: 12),
        if (zones.isEmpty)
          Text(l10n.playerComparisonInsufficientData)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final wide = constraints.maxWidth >= 760 && textScale <= 1.4;
              return Column(
                children: [
                  for (final item in zones)
                    _EvidenceRow(
                      key: ValueKey('comparison-zone-${item.zone?.name}'),
                      evidence: item,
                      mode: report.mode,
                      wide: wide,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _SampleRangeHeader extends StatelessWidget {
  const _SampleRangeHeader({required this.report});

  final PlayerComparisonReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final editorial = editorialThemeOf(context);
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          '${l10n.playerComparisonBaseline}: '
          '${_sampleRange(context, report.baseline, report.mode)}',
          style: TextStyle(color: editorial.mutedInk),
        ),
        Text(
          '${l10n.playerComparisonCurrent}: '
          '${_sampleRange(context, report.current, report.mode)}',
          style: TextStyle(color: editorial.mutedInk),
        ),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.evidence,
    required this.mode,
    required this.wide,
    super.key,
  });

  final PlayerComparisonEvidence evidence;
  final PlayerComparisonMode mode;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final label = _metricLabel(context, evidence, mode);
    final baseline = _valueLabel(context, evidence, evidence.baselineValue);
    final current = _valueLabel(context, evidence, evidence.currentValue);
    final difference = _differenceLabel(context, evidence);
    final differenceColor = switch (evidence.trend) {
      ComparisonTrend.increase => editorial.success,
      ComparisonTrend.decrease => editorial.danger,
      ComparisonTrend.equal => editorial.ink,
      ComparisonTrend.unavailable => editorial.mutedInk,
    };
    final differenceIcon = switch (evidence.trend) {
      ComparisonTrend.increase => Icons.arrow_upward,
      ComparisonTrend.decrease => Icons.arrow_downward,
      ComparisonTrend.equal => Icons.horizontal_rule,
      ComparisonTrend.unavailable => Icons.help_outline,
    };
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: editorial.ink,
      fontFamily: HoopitoTypography.displayFamily,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final differenceWidget = Semantics(
      label: difference,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: wide ? WrapAlignment.center : WrapAlignment.end,
          children: [
            Icon(differenceIcon, size: 18, color: differenceColor),
            Text(
              difference,
              style: valueStyle?.copyWith(color: differenceColor),
            ),
          ],
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: editorial.surface,
        border: Border(top: BorderSide(color: editorial.rule)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 2, child: Text(label)),
                Expanded(
                  child: _CenteredValue(
                    label: _l10n(context).playerComparisonBaseline,
                    value: baseline,
                    style: valueStyle,
                  ),
                ),
                Expanded(child: differenceWidget),
                Expanded(
                  child: _CenteredValue(
                    label: _l10n(context).playerComparisonCurrent,
                    value: current,
                    style: valueStyle,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _CompactValueLine(
                  label: _l10n(context).playerComparisonBaseline,
                  child: Text(baseline, style: valueStyle),
                ),
                const SizedBox(height: 8),
                _CompactValueLine(
                  label: _l10n(context).playerComparisonDifference,
                  child: differenceWidget,
                ),
                const SizedBox(height: 8),
                _CompactValueLine(
                  label: _l10n(context).playerComparisonCurrent,
                  child: Text(current, style: valueStyle),
                ),
              ],
            ),
    );
  }
}

class _CenteredValue extends StatelessWidget {
  const _CenteredValue({
    required this.label,
    required this.value,
    required this.style,
  });

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Text(value, textAlign: TextAlign.center, style: style),
  );
}

class _CompactValueLine extends StatelessWidget {
  const _CompactValueLine({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label)),
      const SizedBox(width: 12),
      Flexible(child: child),
    ],
  );
}

PlayerComparisonMatch? _matchById(
  PlayerComparisonController controller,
  String? id,
) {
  for (final match in controller.matches) {
    if (match.matchId == id) return match;
  }
  return null;
}

String _matchLabel(BuildContext context, PlayerComparisonMatch match) {
  final date = MaterialLocalizations.of(
    context,
  ).formatShortDate(match.playedAtUtc.toLocal());
  return '$date · ${match.opponentNameSnapshot} · '
      '${match.playerScore}–${match.opponentScore}';
}

String _sampleRange(
  BuildContext context,
  PlayerComparisonSample sample,
  PlayerComparisonMode mode,
) {
  final dates = MaterialLocalizations.of(context);
  if (mode == PlayerComparisonMode.matchPair) {
    return dates.formatShortDate(sample.startUtc.toLocal());
  }
  final start = dates.formatShortDate(sample.startUtc.toLocal());
  final end = dates.formatShortDate(sample.endUtc.toLocal());
  return '$start–$end';
}

String _metricLabel(
  BuildContext context,
  PlayerComparisonEvidence evidence,
  PlayerComparisonMode mode,
) {
  final l10n = _l10n(context);
  return switch (evidence.metric) {
    PlayerComparisonMetric.result => l10n.playerComparisonResult,
    PlayerComparisonMetric.matchCount => l10n.playerComparisonMatchCount,
    PlayerComparisonMetric.winRate => l10n.playerComparisonWinRate,
    PlayerComparisonMetric.points =>
      mode == PlayerComparisonMode.matchPair
          ? l10n.playerComparisonPoints
          : l10n.playerComparisonPointsPerGame,
    PlayerComparisonMetric.margin =>
      mode == PlayerComparisonMode.matchPair
          ? l10n.playerComparisonMargin
          : l10n.playerComparisonMarginPerGame,
    PlayerComparisonMetric.fieldGoalsMade =>
      l10n.playerComparisonFieldGoalsMade,
    PlayerComparisonMetric.fieldGoalAttempts =>
      l10n.playerComparisonFieldGoalAttempts,
    PlayerComparisonMetric.fieldGoalPercentage =>
      l10n.playerComparisonFieldGoalPercentage,
    PlayerComparisonMetric.freeThrowsMade =>
      l10n.playerComparisonFreeThrowsMade,
    PlayerComparisonMetric.freeThrowAttempts =>
      l10n.playerComparisonFreeThrowAttempts,
    PlayerComparisonMetric.freeThrowPercentage =>
      l10n.playerComparisonFreeThrowPercentage,
    PlayerComparisonMetric.locationCoverage =>
      l10n.playerComparisonLocationCoverage,
    PlayerComparisonMetric.confirmedZoneShare => _zoneLabel(
      evidence.zone!,
      l10n,
    ),
  };
}

String _valueLabel(
  BuildContext context,
  PlayerComparisonEvidence evidence,
  double? value,
) {
  final l10n = _l10n(context);
  if (value == null) return l10n.playerComparisonInsufficientData;
  if (evidence.metric == PlayerComparisonMetric.result) {
    if (value > 0) return l10n.playerComparisonWin;
    if (value < 0) return l10n.playerComparisonLoss;
    return l10n.playerComparisonTie;
  }
  final formatted = _number(value);
  return _isPercentageMetric(evidence.metric) ? '$formatted%' : formatted;
}

String _differenceLabel(
  BuildContext context,
  PlayerComparisonEvidence evidence,
) {
  final l10n = _l10n(context);
  if (evidence.availability == PlayerComparisonAvailability.unavailable ||
      evidence.delta == null) {
    return l10n.playerComparisonInsufficientData;
  }
  final trend = switch (evidence.trend) {
    ComparisonTrend.increase => l10n.playerComparisonIncrease,
    ComparisonTrend.decrease => l10n.playerComparisonDecrease,
    ComparisonTrend.equal => l10n.playerComparisonEqual,
    ComparisonTrend.unavailable => l10n.playerComparisonInsufficientData,
  };
  final delta = evidence.delta!;
  final sign = delta > 0 ? '+' : '';
  final unit = evidence.isPercentagePoints
      ? ' ${l10n.playerComparisonPercentagePoints}'
      : '';
  return '$sign${_number(delta)}$unit · $trend';
}

bool _isPercentageMetric(PlayerComparisonMetric metric) => {
  PlayerComparisonMetric.winRate,
  PlayerComparisonMetric.fieldGoalPercentage,
  PlayerComparisonMetric.freeThrowPercentage,
  PlayerComparisonMetric.locationCoverage,
  PlayerComparisonMetric.confirmedZoneShare,
}.contains(metric);

String _number(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

String _windowLabel(PlayerComparisonWindow window, AppLocalizations l10n) {
  return switch (window) {
    PlayerComparisonWindow.sevenDays => l10n.playerAnalyticsSevenDays,
    PlayerComparisonWindow.thirtyDays => l10n.playerAnalyticsThirtyDays,
    PlayerComparisonWindow.ninetyDays => l10n.playerAnalyticsNinetyDays,
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

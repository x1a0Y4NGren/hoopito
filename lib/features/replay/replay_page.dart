import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/design_system/recording_confirmation.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/replay_image_exporter.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/widgets/replay_analytics_summary.dart';
import 'package:hoopito/features/replay/widgets/replay_audit_sheet.dart';
import 'package:hoopito/features/replay/widgets/replay_event_editor.dart';
import 'package:hoopito/features/replay/widgets/replay_timeline.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';

class ReplayPage extends StatefulWidget {
  const ReplayPage({
    required this.controller,
    this.onExit,
    this.exitTooltip,
    this.onFinishMatch,
    this.onFinishWithCoverage,
    this.onShareSummary,
    this.captureBoundary,
    super.key,
  });

  final ReplayController controller;
  final VoidCallback? onExit;
  final String? exitTooltip;
  final FutureOr<void> Function(int redScore, int blueScore)? onFinishMatch;
  final FutureOr<void> Function(
    int redScore,
    int blueScore,
    TrackingCoverage coverage,
  )?
  onFinishWithCoverage;
  final Future<void> Function(Uint8List bytes, String matchId)? onShareSummary;
  final Future<Uint8List> Function(GlobalKey boundaryKey)? captureBoundary;

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

enum _ReplayAppBarAction { edit, finish }

class _ReplayPageState extends State<ReplayPage> {
  bool _finishBusy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant ReplayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _showAuditHistory() async {
    final logs = await widget.controller.loadAuditLogs?.call();
    if (!mounted || logs == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ReplayAuditSheet(logs: logs),
    );
  }

  Future<void> _showEventEditor(ReplayEventData event) async {
    final controller = widget.controller;
    controller.selectEvent(event.id);
    if (!controller.isEditing) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          ReplayEventEditorSheet(controller: controller, event: event),
    );
  }

  Future<void> _showExportPreview() async {
    final onShareSummary = widget.onShareSummary;
    if (onShareSummary == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ReplayExportDialog(
        controller: widget.controller,
        captureBoundary: widget.captureBoundary ?? ReplayImageExporter.capture,
        onShare: onShareSummary,
      ),
    );
  }

  Future<void> _confirmFinishMatch() async {
    final finish = widget.onFinishMatch;
    final coveredFinish = widget.onFinishWithCoverage;
    if (_finishBusy || (finish == null && coveredFinish == null)) return;
    final data = widget.controller.data;
    final l10n = _localizations(context);
    final coverage = await confirmRecordingCoverage(
      context,
      title: l10n.confirmFinalScoreTitle,
      scoreLine: l10n.finalScoreLine(
        data.blueName,
        data.blueScore,
        data.redName,
        data.redScore,
      ),
      confirmLabel: l10n.finishMatch,
      cancelKey: const Key('replay-finish-cancel'),
      confirmKey: const Key('replay-finish-confirm'),
    );
    if (coverage == null || !mounted) return;
    setState(() => _finishBusy = true);
    try {
      await Future<void>.sync(
        () => coveredFinish != null
            ? coveredFinish(data.redScore, data.blueScore, coverage)
            : finish!(data.redScore, data.blueScore),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.actionFailedRetry)));
      }
    } finally {
      if (mounted) setState(() => _finishBusy = false);
    }
  }

  AppLocalizations _localizations(BuildContext context) {
    return AppLocalizations.of(context) ?? AppLocalizationsZh();
  }

  List<Widget> _appBarActions(
    BuildContext context,
    ReplayController controller,
  ) {
    final l10n = _localizations(context);
    final compact =
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final actions = <Widget>[
      if (widget.onShareSummary != null)
        IconButton(
          key: const Key('replay-export-image'),
          tooltip: l10n.replayExportTooltip,
          onPressed: _showExportPreview,
          icon: const Icon(Icons.ios_share_outlined),
        ),
      if (controller.loadAuditLogs != null)
        IconButton(
          key: const Key('replay-audit-history'),
          tooltip: l10n.replayAuditTooltip,
          onPressed: _showAuditHistory,
          icon: const Icon(Icons.history),
        ),
    ];
    if (compact) {
      actions.add(
        PopupMenuButton<_ReplayAppBarAction>(
          key: const Key('replay-actions-menu'),
          tooltip: l10n.replayMoreActions,
          onSelected: (action) {
            switch (action) {
              case _ReplayAppBarAction.edit:
                if (controller.canEdit) {
                  controller.setEditing(!controller.isEditing);
                }
              case _ReplayAppBarAction.finish:
                if (!_finishBusy &&
                    (widget.onFinishMatch != null ||
                        widget.onFinishWithCoverage != null)) {
                  _confirmFinishMatch();
                }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ReplayAppBarAction.edit,
              enabled: controller.canEdit,
              child: Text(
                controller.isEditing
                    ? l10n.replayEditMode
                    : l10n.replayReadOnly,
              ),
            ),
            if (widget.onFinishMatch != null ||
                widget.onFinishWithCoverage != null)
              PopupMenuItem(
                value: _ReplayAppBarAction.finish,
                enabled: !_finishBusy,
                child: Text(l10n.finishMatch),
              ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      );
      return actions;
    }
    actions.add(
      SizedBox(
        height: 48,
        child: TextButton.icon(
          key: const Key('replay-edit-toggle'),
          onPressed: controller.canEdit
              ? () => controller.setEditing(!controller.isEditing)
              : null,
          icon: Icon(
            controller.isEditing ? Icons.lock_open : Icons.lock_outline,
          ),
          label: Text(
            controller.isEditing ? l10n.replayEditMode : l10n.replayReadOnly,
          ),
        ),
      ),
    );
    if (widget.onFinishMatch != null || widget.onFinishWithCoverage != null) {
      actions.add(
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('replay-finish-match'),
              onPressed: _finishBusy ? null : _confirmFinishMatch,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.finishMatch),
            ),
          ),
        ),
      );
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = _localizations(context);
    final viewport = MediaQuery.sizeOf(context);
    final compactLandscape =
        viewport.width > viewport.height && viewport.height < 500;
    final page = EditorialScaffold(
      maxContentWidth: 1440,
      masthead: EditorialMasthead(
        title: l10n.replayTitle,
        compact: compactLandscape,
        leading: widget.onExit == null
            ? null
            : IconButton(
                key: const Key('replay-exit'),
                tooltip: widget.exitTooltip ?? l10n.historyHomeTooltip,
                onPressed: widget.onExit,
                icon: const Icon(Icons.arrow_back),
              ),
        trailing: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _appBarActions(context, controller),
        ),
      ),
      body: Column(
        children: [
          _ScoreHeader(data: controller.data, compact: compactLandscape),
          SizedBox(
            height: compactLandscape
                ? HoopitoSpacing.compact
                : HoopitoSpacing.section,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape =
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                if (constraints.maxWidth >= 840 || landscape) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 24),
                          child: _ReplayOverview(
                            controller: controller,
                            courtMaxHeight: math.max(
                              120,
                              constraints.maxHeight,
                            ),
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: editorialThemeOf(context).rule,
                      ),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: ReplayTimelinePanel(
                            controller: controller,
                            onEventTap: _showEventEditor,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReplayOverview(controller: controller),
                      const SizedBox(height: HoopitoSpacing.section),
                      ReplayTimelinePanel(
                        controller: controller,
                        embedded: true,
                        onEventTap: _showEventEditor,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    final onExit = widget.onExit;
    if (onExit == null) return page;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onExit();
      },
      child: page,
    );
  }
}

Future<void> showMatchReportDialog(
  BuildContext context, {
  required ReplayController controller,
  required Future<void> Function(Uint8List bytes, String matchId) onShare,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ReplayExportDialog(
    controller: controller,
    captureBoundary: ReplayImageExporter.capture,
    onShare: onShare,
  ),
);

class _ReplayExportDialog extends StatefulWidget {
  const _ReplayExportDialog({
    required this.controller,
    required this.captureBoundary,
    required this.onShare,
  });

  final ReplayController controller;
  final Future<Uint8List> Function(GlobalKey boundaryKey) captureBoundary;
  final Future<void> Function(Uint8List bytes, String matchId) onShare;

  @override
  State<_ReplayExportDialog> createState() => _ReplayExportDialogState();
}

class _ReplayExportDialogState extends State<_ReplayExportDialog> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final l10n = _localizations(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: math.min(980, viewport.width - 40),
        height: math.min(720, viewport.height - 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: editorialThemeOf(context).arenaAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.replayExportTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.replayClose,
                            onPressed: _busy
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(l10n.replayExportDescription),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                        // Report typography belongs to the exported document.
                        // The dialog controls still follow system text size.
                        child: MediaQuery.withNoTextScaling(
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: _ReplayExportSummary(
                              controller: widget.controller,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: Text(l10n.cancelAction),
                  ),
                  FilledButton.icon(
                    key: const Key('replay-export-confirm'),
                    onPressed: _busy ? null : _export,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_outlined),
                    label: Text(
                      _busy ? l10n.replayGenerating : l10n.replayGenerateShare,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    final l10n = _localizations(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final bytes = await widget.captureBoundary(_boundaryKey);
      await widget.onShare(bytes, widget.controller.data.matchId);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.replayExportFailed;
        });
      }
    }
  }
}

class _ReplayExportSummary extends StatelessWidget {
  const _ReplayExportSummary({required this.controller});

  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final l10n = _localizations(context);
    final analytics = data.analytics;
    final attempts =
        analytics?.fieldGoalAttemptCount ?? controller.scoreEventCount;
    final shootingPercentage = analytics == null || attempts == 0
        ? l10n.replayNoData
        : analytics.hasReliableShootingPercentage
        ? '${(analytics.reliableShootingPercentage! * 100).round()}%'
        : '${l10n.replayAnalyticsRecordedAttempts} · $attempts';
    final largestLead = analytics?.largestLeadSide == null
        ? l10n.replayNoData
        : '${analytics!.largestLeadSide == TeamSide.red ? data.redName : data.blueName} '
              '+${analytics.largestLeadPoints}';

    return Container(
      key: const Key('replay-export-summary'),
      width: 900,
      padding: const EdgeInsets.all(26),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_basketball,
                color: editorialThemeOf(context).arenaAccent,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.appName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${l10n.replayTitle} · '
                '${data.isFinished ? l10n.replayFinished : l10n.replayInProgress}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ExportTeamScore(
                  name: data.blueName,
                  score: data.blueScore,
                  color: teamColorForScheme(
                    TeamSide.blue,
                    Theme.of(context).colorScheme,
                  ),
                  alignment: CrossAxisAlignment.start,
                ),
              ),
              Text(
                ':',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: _ExportTeamScore(
                  name: data.redName,
                  score: data.redScore,
                  color: teamColorForScheme(
                    TeamSide.red,
                    Theme.of(context).colorScheme,
                  ),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 15 / 14,
                  child: CourtView(
                    shotLocations: controller.shotLocations,
                    pendingLocation: null,
                    mode: CourtViewMode.readOnly,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.replayExportAnalysis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final metricWidth = (constraints.maxWidth - 10) / 2;
                        final metrics = [
                          _ExportMetric(
                            label: l10n.replayDuration,
                            value: _formatDuration(data.duration),
                          ),
                          _ExportMetric(
                            label: l10n.v2LocationScope,
                            value: analytics == null || attempts == 0
                                ? l10n.replayNoData
                                : '${analytics.confirmedLocationCount}/$attempts',
                          ),
                          _ExportMetric(
                            label: l10n.v2FieldGoalPercentage,
                            value: shootingPercentage,
                          ),
                          _ExportMetric(
                            label: l10n.v2FreeThrowPercentage,
                            value:
                                analytics?.reliableFreeThrowPercentage == null
                                ? l10n.replayNoData
                                : '${(analytics!.reliableFreeThrowPercentage! * 100).round()}%',
                          ),
                          _ExportMetric(
                            label: l10n.replayExportLeadChanges,
                            value: l10n.replayExportLeadChangesValue(
                              analytics?.leadChanges ?? 0,
                            ),
                          ),
                          _ExportMetric(
                            label: l10n.replayExportLargestLead,
                            value: largestLead,
                          ),
                          _ExportMetric(
                            label: l10n.v2CoverageTitle,
                            value:
                                analytics == null ||
                                    analytics.trackingCoverage.index <
                                        TrackingCoverage.shotAttempts.index
                                ? l10n.v2CoverageScores
                                : l10n.v2CoverageComplete,
                          ),
                        ];
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final metric in metrics)
                              SizedBox(width: metricWidth, child: metric),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.v2RecordedSample,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportTeamScore extends StatelessWidget {
  const _ExportTeamScore({
    required this.name,
    required this.score,
    required this.color,
    required this.alignment,
  });

  final String name;
  final int score;
  final Color color;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          name,
          textAlign: alignment == CrossAxisAlignment.end
              ? TextAlign.end
              : TextAlign.start,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '$score',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ExportMetric extends StatelessWidget {
  const _ExportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: editorialThemeOf(context).rule),
          bottom: BorderSide(color: editorialThemeOf(context).rule),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.data, this.compact = false});

  final ReplayMatchData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: _CompactTeamScore(
                name: data.blueName,
                score: data.blueScore,
                color: teamColorForScheme(
                  TeamSide.blue,
                  Theme.of(context).colorScheme,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                data.isFinished ? l10n.replayFinished : l10n.replayInProgress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ),
            Expanded(
              child: _CompactTeamScore(
                name: data.redName,
                score: data.redScore,
                color: teamColorForScheme(
                  TeamSide.red,
                  Theme.of(context).colorScheme,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _TeamScore(
              name: data.blueName,
              score: data.blueScore,
              color: teamColorForScheme(
                TeamSide.blue,
                Theme.of(context).colorScheme,
              ),
              alignment: CrossAxisAlignment.start,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              data.isFinished ? l10n.replayFinished : l10n.replayInProgress,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            child: _TeamScore(
              name: data.redName,
              score: data.redScore,
              color: teamColorForScheme(
                TeamSide.red,
                Theme.of(context).colorScheme,
              ),
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactTeamScore extends StatelessWidget {
  const _CompactTeamScore({
    required this.name,
    required this.score,
    required this.color,
    required this.textAlign,
  });

  final String name;
  final int score;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final alignEnd = textAlign == TextAlign.end;
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$score',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.name,
    required this.score,
    required this.color,
    required this.alignment,
  });

  final String name;
  final int score;
  final Color color;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
        Text(
          '$score',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ReplayOverview extends StatelessWidget {
  const _ReplayOverview({required this.controller, this.courtMaxHeight});

  final ReplayController controller;
  final double? courtMaxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final scoreCount = controller.scoreEventCount;
    final fieldGoalAttempts = controller.fieldGoalAttemptCount;
    final completeness = (controller.locationCoverage * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: l10n.replayCourt, icon: Icons.sports_basketball),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final naturalHeight = constraints.maxWidth * 14 / 15;
            final height = courtMaxHeight == null
                ? naturalHeight
                : math.min(naturalHeight, courtMaxHeight!);
            return Align(
              alignment: Alignment.center,
              child: SizedBox(
                key: const Key('replay-court-pane'),
                width: height * 15 / 14,
                height: height,
                child: _SelectableReplayCourt(controller: controller),
              ),
            );
          },
        ),
        if (controller.pendingShotLocation != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('replay-save-location'),
              onPressed: () => _saveLocation(context),
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.replaySaveLocation),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _SectionTitle(
          title: l10n.replayOverview,
          icon: Icons.assessment_outlined,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric(
              label: l10n.replayDuration,
              value: _formatDuration(controller.data.duration),
            ),
            _Metric(label: l10n.replayScoringEvents, value: '$scoreCount'),
            _Metric(
              label: l10n.replayFouls,
              value: '${controller.foulEventCount}',
            ),
            _Metric(
              key: const Key('replay-location-coverage'),
              label: l10n.replayLocationCompleteness,
              value: fieldGoalAttempts == 0
                  ? l10n.replayNoData
                  : '$completeness% · '
                        '${controller.confirmedLocationCount}/$fieldGoalAttempts',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.v2LocationScope,
          key: const Key('replay-location-coverage-scope'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        _PossessionSegmentsCard(data: controller.data),
        if (controller.data.analytics case final analytics?) ...[
          const SizedBox(height: 24),
          ReplayAnalyticsSummary(
            analytics: analytics,
            redName: controller.data.redName,
            blueName: controller.data.blueName,
          ),
        ],
      ],
    );
  }

  Future<void> _saveLocation(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ShotLocationReasonDialog(),
    );
    if (reason != null) {
      await controller.saveSelectedShot(reason: reason);
    }
  }
}

class _SelectableReplayCourt extends StatelessWidget {
  const _SelectableReplayCourt({required this.controller});

  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    final locations = controller.shotLocations;
    final eventsById = {
      for (final event in controller.data.events) event.id: event,
    };
    final selectedLocationId = _selectedLocationId(controller);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final court = HalfCourtGeometry.courtRectForSize(size);
        final courtStack = Stack(
          fit: StackFit.expand,
          children: [
            CourtView(
              shotLocations: locations,
              pendingLocation: controller.pendingShotLocation,
              highlightedShotLocationId: selectedLocationId,
              onPendingLocationChanged: controller.isEditing
                  ? controller.updatePendingShotPoint
                  : null,
              onShotLocationTap: controller.selectLocation,
              mode: controller.isEditing
                  ? CourtViewMode.editable
                  : CourtViewMode.readOnly,
            ),
            if (!controller.isEditing)
              for (final location in locations)
                _ReplayCourtMarkerTarget(
                  location: location,
                  event: eventsById[location.eventId]!,
                  center: _targetCenter(location.point, size, court),
                  selected: selectedLocationId == location.id,
                  onTap: () => controller.selectEvent(location.eventId),
                ),
          ],
        );
        if (!controller.isEditing) return courtStack;
        return Listener(
          onPointerMove: (event) => controller.updatePendingShotPoint(
            HalfCourtGeometry.pointFromLocal(event.localPosition, size),
          ),
          child: courtStack,
        );
      },
    );
  }

  String? _selectedLocationId(ReplayController controller) {
    final selected = controller.selectedEvent;
    if (selected == null || selected.shotPoint == null) return null;
    return selected.locationId ?? 'replay-shot-${selected.id}';
  }

  Offset _targetCenter(CourtPoint point, Size size, Rect court) {
    final paintedCenter = HalfCourtGeometry.pointToOffset(point, size);
    if (court.width < 48 || court.height < 48) return court.center;
    return Offset(
      paintedCenter.dx.clamp(court.left + 24, court.right - 24).toDouble(),
      paintedCenter.dy.clamp(court.top + 24, court.bottom - 24).toDouble(),
    );
  }
}

class _ReplayCourtMarkerTarget extends StatelessWidget {
  const _ReplayCourtMarkerTarget({
    required this.location,
    required this.event,
    required this.center,
    required this.selected,
    required this.onTap,
  });

  final ScoringShotLocation location;
  final ReplayEventData event;
  final Offset center;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    final sideLabel = location.side == TeamSide.red
        ? l10n.replayFilterRed
        : l10n.replayFilterBlue;
    return Positioned(
      left: center.dx - 24,
      top: center.dy - 24,
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '$sideLabel ${l10n.replayActionScore(location.points)}, '
            '${_formatDuration(event.elapsed)}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('replay-court-marker-${location.eventId}'),
            onTap: onTap,
            customBorder: const CircleBorder(),
          ),
        ),
      ),
    );
  }
}

class _ShotLocationReasonDialog extends StatefulWidget {
  const _ShotLocationReasonDialog();

  @override
  State<_ShotLocationReasonDialog> createState() =>
      _ShotLocationReasonDialogState();
}

class _ShotLocationReasonDialogState extends State<_ShotLocationReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return AlertDialog(
      title: Text(l10n.replayLocationEditTitle),
      content: TextField(
        controller: _reason,
        decoration: InputDecoration(
          labelText: l10n.replayEditorReason,
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text),
          child: Text(l10n.replayLocationSaveAction),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 108, minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: editorialThemeOf(context).rule),
          bottom: BorderSide(color: editorialThemeOf(context).rule),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PossessionSegmentsCard extends StatelessWidget {
  const _PossessionSegmentsCard({required this.data});

  final ReplayMatchData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Container(
      key: const Key('replay-possession-segments'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: editorialThemeOf(context).rule),
          bottom: BorderSide(color: editorialThemeOf(context).rule),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final boundary = Text(
                data.isFinished
                    ? l10n.replayFinishedBoundary
                    : l10n.replayInProgressBoundary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              );
              final compact =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(
                      title: l10n.replayPossession,
                      icon: Icons.swap_horiz_outlined,
                    ),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerLeft, child: boundary),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _SectionTitle(
                      title: l10n.replayPossession,
                      icon: Icons.swap_horiz_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: boundary),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          if (data.possessionSegments.isEmpty)
            Text(l10n.replayNoPossession)
          else
            ...data.possessionSegments.map(
              (segment) => _PossessionSegmentRow(
                data: segment,
                redName: data.redName,
                blueName: data.blueName,
              ),
            ),
        ],
      ),
    );
  }
}

class _PossessionSegmentRow extends StatelessWidget {
  const _PossessionSegmentRow({
    required this.data,
    required this.redName,
    required this.blueName,
  });

  final ReplayPossessionSegmentData data;
  final String redName;
  final String blueName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final sideColor = teamColorForScheme(
      data.side,
      Theme.of(context).colorScheme,
    );
    final sideName = data.side == TeamSide.red ? redName : blueName;
    final sourceLabel = data.source == PossessionSource.manual
        ? l10n.replayPossessionManual
        : l10n.replayPossessionSuggested;
    final reason = data.source == PossessionSource.suggested
        ? l10n.replaySuggestedReason
        : (data.reason == null || data.reason!.isEmpty
              ? l10n.replayNoReason
              : data.reason!);
    final boundary = data.isOpen
        ? l10n.replayPossessionCurrent
        : data.endedAt == null
        ? l10n.replayPossessionEnded(l10n.replayNoData)
        : l10n.replayPossessionEnded(_formatDuration(data.endedAt!));

    return Container(
      key: Key('replay-possession-${data.id}'),
      constraints: const BoxConstraints(minHeight: 64),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 42, color: sideColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sideName · $sourceLabel',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_formatDuration(data.startedAt)} · $boundary',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  l10n.replayPossessionReason(reason),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: editorialThemeOf(context).arenaAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

AppLocalizations _localizations(BuildContext context) {
  return AppLocalizations.of(context) ?? AppLocalizationsZh();
}

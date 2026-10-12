import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/app/l10n/rule_template_localizations.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/history/history_controller.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.controller,
    required this.onMatchTap,
    this.onHome,
    this.activeMatch,
    this.onResumeActive,
    this.importedIncompleteMatches = const [],
    this.onResumeImportedIncomplete,
    this.importedIncompleteLoadError = false,
    this.onRetryImportedIncomplete,
    this.onArchive,
    this.onUnarchive,
    this.onDelete,
    super.key,
  });

  final HistoryController controller;
  final ValueChanged<String> onMatchTap;
  final VoidCallback? onHome;
  final HistoryMatchSummary? activeMatch;
  final VoidCallback? onResumeActive;
  final List<HistoryMatchSummary> importedIncompleteMatches;
  final ValueChanged<String>? onResumeImportedIncomplete;
  final bool importedIncompleteLoadError;
  final VoidCallback? onRetryImportedIncomplete;
  final Future<void> Function(String matchId)? onArchive;
  final Future<void> Function(String matchId)? onUnarchive;
  final Future<void> Function(String matchId)? onDelete;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final TextEditingController _searchController;

  HistoryController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: controller.filters.search);
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showAdvancedFilters(BuildContext context) async {
    final l10n = _historyL10n(context);
    final current = controller.filters;
    var ruleName = current.ruleName ?? '';
    String? recordingMode = current.recordingMode;
    var from = current.from;
    var to = current.to;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => EditorialSheet(
          title: l10n.historyAdvancedTitle,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: ruleName,
                  onChanged: (value) => ruleName = value,
                  decoration: InputDecoration(
                    labelText: l10n.historyRuleLabel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  key: const Key('history-filter-recording-mode'),
                  initialValue: recordingMode,
                  decoration: InputDecoration(
                    labelText: l10n.historyRecordingModeLabel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.historyAllModes),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'simple',
                      child: Text(l10n.historySimpleMode),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'detailed',
                      child: Text(l10n.historyDetailedMode),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => recordingMode = value),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('history-filter-from'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: from ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => from = picked);
                        }
                      },
                      child: Text(
                        from == null
                            ? l10n.historyStartDate
                            : _formatDateOnly(from!),
                      ),
                    ),
                    OutlinedButton(
                      key: const Key('history-filter-to'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: to ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => to = picked);
                        }
                      },
                      child: Text(
                        to == null ? l10n.historyEndDate : _formatDateOnly(to!),
                      ),
                    ),
                    TextButton(
                      key: const Key('history-filter-clear-dates'),
                      onPressed: () => setSheetState(() {
                        from = null;
                        to = null;
                      }),
                      child: Text(l10n.historyClearDates),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('history-filter-apply'),
                  onPressed: () {
                    controller.updateFilters(
                      current.copyWith(
                        from: from,
                        to: to,
                        ruleName: ruleName.trim(),
                        recordingMode: recordingMode,
                        clearFrom: from == null,
                        clearTo: to == null,
                        clearRuleName: ruleName.trim().isEmpty,
                        clearRecordingMode: recordingMode == null,
                      ),
                    );
                    Navigator.pop(sheetContext);
                  },
                  child: Text(l10n.historyApplyFilters),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = controller.matches;
    final l10n = _historyL10n(context);
    final groups = _groupMatchesByLocalDate(matches);
    return EditorialScaffold(
      masthead: EditorialMasthead(
        title: l10n.historyTitle,
        trailing: widget.onHome == null
            ? null
            : IconButton(
                onPressed: widget.onHome,
                tooltip: l10n.historyHomeTooltip,
                icon: const Icon(Icons.home_outlined),
              ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 720 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.5;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HistoryToolbar(
                  searchController: _searchController,
                  filter: controller.filters.lifecycle,
                  onSearchChanged: controller.updateSearch,
                  onReset: () {
                    controller.resetFilters();
                    _searchController.clear();
                  },
                  onAdvanced: () => _showAdvancedFilters(context),
                  onFilterChanged: (filter) => controller.updateFilters(
                    controller.filters.copyWith(lifecycle: filter),
                  ),
                ),
              ),
              if (widget.activeMatch != null && widget.onResumeActive != null)
                SliverToBoxAdapter(
                  child: _RecoveryBanner(
                    match: widget.activeMatch!,
                    onResume: widget.onResumeActive!,
                  ),
                ),
              if (widget.importedIncompleteLoadError)
                SliverToBoxAdapter(
                  child: _ImportedIncompleteLoadError(
                    onRetry: widget.onRetryImportedIncomplete,
                  ),
                ),
              for (final imported in widget.importedIncompleteMatches)
                if (widget.onResumeImportedIncomplete != null)
                  SliverToBoxAdapter(
                    child: _ImportedIncompleteBanner(
                      match: imported,
                      onResume: () =>
                          widget.onResumeImportedIncomplete!(imported.matchId),
                    ),
                  ),
              if (matches.isEmpty && controller.isLoadingPage)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (matches.isEmpty && controller.loadError != null)
                SliverToBoxAdapter(
                  child: _HistoryLoadError(onRetry: controller.refresh),
                )
              else if (matches.isEmpty)
                const SliverToBoxAdapter(child: _EmptyHistory())
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  sliver: SliverList.list(
                    children: [
                      for (final group in groups) ...[
                        _HistoryDateHeader(date: group.date),
                        for (final match in group.matches)
                          _HistoryMatchRow(
                            match: match,
                            wide: wide,
                            onTap: () => widget.onMatchTap(match.matchId),
                            onArchive: widget.onArchive,
                            onUnarchive: widget.onUnarchive,
                            onDelete: widget.onDelete,
                          ),
                      ],
                      if (controller.dataSource != null &&
                          (controller.hasMore || controller.loadError != null))
                        _LoadMoreButton(
                          loading: controller.isLoadingPage,
                          error: controller.loadError,
                          onPressed: controller.isLoadingPage
                              ? null
                              : controller.loadError != null
                              ? controller.retryLoad
                              : controller.loadNextPage,
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryDateGroup {
  const _HistoryDateGroup({required this.date, required this.matches});

  final DateTime date;
  final List<HistoryMatchSummary> matches;
}

List<_HistoryDateGroup> _groupMatchesByLocalDate(
  List<HistoryMatchSummary> matches,
) {
  final groups = <DateTime, List<HistoryMatchSummary>>{};
  for (final match in matches) {
    final local = match.playedAt.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    groups.putIfAbsent(date, () => []).add(match);
  }
  return groups.entries
      .map((entry) => _HistoryDateGroup(date: entry.key, matches: entry.value))
      .toList(growable: false);
}

class _HistoryDateHeader extends StatelessWidget {
  const _HistoryDateHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = _formatDateOnly(date);
    return Padding(
      key: Key('history-date-$label'),
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: EditorialSectionRule(label: label),
    );
  }
}

class _HistoryToolbar extends StatelessWidget {
  const _HistoryToolbar({
    required this.searchController,
    required this.filter,
    required this.onSearchChanged,
    required this.onReset,
    required this.onAdvanced,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final HistoryLifecycleFilter filter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onReset;
  final VoidCallback onAdvanced;
  final ValueChanged<HistoryLifecycleFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = _historyL10n(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          TextField(
            key: const Key('history-search'),
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: l10n.historySearchHint,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip(
                  l10n.historyCompleted,
                  HistoryLifecycleFilter.finished,
                ),
                _filterChip(
                  l10n.historyArchived,
                  HistoryLifecycleFilter.archived,
                ),
                _filterChip(l10n.historyAll, HistoryLifecycleFilter.all),
                TextButton(
                  key: const Key('history-reset-filters'),
                  onPressed: onReset,
                  child: Text(l10n.historyResetFilters),
                ),
                TextButton.icon(
                  key: const Key('history-advanced-filters'),
                  onPressed: onAdvanced,
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(l10n.historyMoreFilters),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _filterChip(String label, HistoryLifecycleFilter value) {
    return SizedBox(
      height: 48,
      child: ChoiceChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (_) => onFilterChanged(value),
      ),
    );
  }
}

class _RecoveryBanner extends StatelessWidget {
  const _RecoveryBanner({required this.match, required this.onResume});

  final HistoryMatchSummary match;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = _historyL10n(context);
    final editorial = editorialThemeOf(context);
    final compact =
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.historyActiveMatch,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${match.blueName} ${match.blueScore} : ${match.redScore} ${match.redName}',
        ),
      ],
    );
    final action = SizedBox(
      height: 48,
      child: FilledButton(onPressed: onResume, child: Text(l10n.historyResume)),
    );
    return Container(
      key: const Key('history-active-recovery'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: editorial.surface,
        border: Border(top: BorderSide(color: editorial.arenaAccent, width: 4)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            )
          : Row(
              children: [
                Icon(Icons.play_circle_outline, color: editorial.arenaAccent),
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 12),
                action,
              ],
            ),
    );
  }
}

class _ImportedIncompleteBanner extends StatelessWidget {
  const _ImportedIncompleteBanner({
    required this.match,
    required this.onResume,
  });

  final HistoryMatchSummary match;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = _historyL10n(context);
    final editorial = editorialThemeOf(context);
    return Container(
      key: Key('history-imported-${match.matchId}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: editorial.surface,
        border: Border(top: BorderSide(color: editorial.arenaAccent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.historyImportedIncompleteTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${match.blueName} ${match.blueScore} : ${match.redScore} ${match.redName}',
          ),
          const SizedBox(height: 4),
          Text(l10n.historyImportedIncompleteBody),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: Key('history-resume-imported-${match.matchId}'),
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.historyResumeImportedIncomplete),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportedIncompleteLoadError extends StatelessWidget {
  const _ImportedIncompleteLoadError({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = _historyL10n(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('history-imported-load-error'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Row(
          children: [
            Expanded(child: Text(l10n.historyImportedIncompleteLoadError)),
            if (onRetry != null)
              TextButton(
                key: const Key('history-imported-retry'),
                onPressed: onRetry,
                child: Text(l10n.historyImportedIncompleteRetry),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final l10n = _historyL10n(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: EditorialEmptyState(
        title: l10n.historyEmpty,
        message: l10n.historyEmptyDescription,
        icon: Icons.history_toggle_off,
      ),
    );
  }
}

class _HistoryLoadError extends StatelessWidget {
  const _HistoryLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = _historyL10n(context);
    return Center(
      key: const Key('history-load-error'),
      child: EditorialErrorState(
        title: l10n.historyLoadError,
        message: l10n.actionFailedRetry,
        actionLabel: l10n.historyRetry,
        onAction: onRetry,
        icon: Icons.error_outline,
      ),
    );
  }
}

enum _HistoryAction { archive, unarchive, delete }

class _HistoryMatchRow extends StatelessWidget {
  const _HistoryMatchRow({
    required this.match,
    required this.wide,
    required this.onTap,
    this.onArchive,
    this.onUnarchive,
    this.onDelete,
  });

  final HistoryMatchSummary match;
  final bool wide;
  final VoidCallback onTap;
  final Future<void> Function(String)? onArchive;
  final Future<void> Function(String)? onUnarchive;
  final Future<void> Function(String)? onDelete;

  @override
  Widget build(BuildContext context) {
    final actions =
        onArchive != null || onUnarchive != null || onDelete != null;
    final editorial = editorialThemeOf(context);
    return Semantics(
      button: true,
      label:
          '${match.blueName} ${match.blueScore} : ${match.redScore} ${match.redName}',
      child: InkWell(
        key: Key('history-match-${match.matchId}'),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: wide ? 80 : 104),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: editorial.surface,
            border: Border(bottom: BorderSide(color: editorial.rule)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: wide
                ? Row(
                    children: [
                      SizedBox(width: 64, child: _time(context)),
                      Expanded(flex: 4, child: _teamsAndScore(context)),
                      Expanded(flex: 2, child: _winner(context)),
                      Expanded(
                        flex: 2,
                        child: _Meta(
                          label: _historyL10n(context).historyRule,
                          value: localizedStoredRuleTemplateName(
                            match.ruleName,
                            _historyL10n(context),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 78,
                        child: _Meta(
                          label: _historyL10n(context).historyDuration,
                          value: _formatDuration(match.duration),
                        ),
                      ),
                      SizedBox(width: 88, child: _completeness(context)),
                      if (actions) _boundedActions(context),
                      const Icon(Icons.chevron_right),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _time(context)),
                          if (actions) _boundedActions(context),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _teamsAndScore(context),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _winner(context),
                          _Meta(
                            label: _historyL10n(context).historyRule,
                            value: localizedStoredRuleTemplateName(
                              match.ruleName,
                              _historyL10n(context),
                            ),
                          ),
                          _Meta(
                            label: _historyL10n(context).historyDuration,
                            value: _formatDuration(match.duration),
                          ),
                          _completeness(context),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final l10n = _historyL10n(context);
    return PopupMenuButton<_HistoryAction>(
      key: Key('history-actions-${match.matchId}'),
      tooltip: l10n.historyActions,
      onSelected: (action) async {
        switch (action) {
          case _HistoryAction.archive:
            await _runAction(
              context,
              () async => onArchive?.call(match.matchId),
            );
            return;
          case _HistoryAction.unarchive:
            await _runAction(
              context,
              () async => onUnarchive?.call(match.matchId),
            );
            return;
          case _HistoryAction.delete:
            if (onDelete == null || !context.mounted) return;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.historyDeleteTitle),
                content: Text(l10n.historyDeleteBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancelAction),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.historyDeletePermanently),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              if (!context.mounted) return;
              await _runAction(context, () => onDelete!.call(match.matchId));
            }
            return;
        }
      },
      itemBuilder: (context) => [
        if (match.isArchived && onUnarchive != null)
          PopupMenuItem(
            value: _HistoryAction.unarchive,
            child: Text(l10n.historyUnarchive),
          ),
        if (!match.isArchived && onArchive != null)
          PopupMenuItem(
            value: _HistoryAction.archive,
            child: Text(l10n.historyArchive),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: _HistoryAction.delete,
            child: Text(l10n.historyDeletePermanently),
          ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object {
      if (!context.mounted) return;
      final l10n = _historyL10n(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.actionFailedRetry)));
    }
  }

  Widget _boundedActions(BuildContext context) =>
      SizedBox(width: 48, height: 48, child: _actions(context));

  Widget _time(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          _formatTime(match.playedAt.toLocal()),
          maxLines: 1,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
      if (match.isArchived) ...[
        const SizedBox(width: 6),
        Chip(
          label: Text(_historyL10n(context).historyArchived),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ],
    ],
  );

  Widget _teamsAndScore(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          match.blueName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: teamColorForScheme(
              TeamSide.blue,
              Theme.of(context).colorScheme,
            ),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          '${match.blueScore} : ${match.redScore}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      Expanded(
        child: Text(
          match.redName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: teamColorForScheme(
              TeamSide.red,
              Theme.of(context).colorScheme,
            ),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _winner(BuildContext context) {
    final l10n = _historyL10n(context);
    return _Meta(
      label: l10n.historyResult,
      value: match.winnerName == null
          ? l10n.historyDraw
          : l10n.historyWinner(match.winnerName!),
    );
  }

  Widget _completeness(BuildContext context) => _Meta(
    label: _historyL10n(context).historyLocationCompleteness,
    value: '${(match.locationCompleteness * 100).round()}%',
  );
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.loading,
    required this.error,
    required this.onPressed,
  });

  final bool loading;
  final Object? error;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = _historyL10n(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : error != null
            ? Column(
                key: const Key('history-load-more-error'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.historyLoadError, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('history-load-more-retry'),
                    onPressed: onPressed,
                    child: Text(l10n.historyRetry),
                  ),
                ],
              )
            : TextButton(
                key: const Key('history-load-more'),
                onPressed: onPressed,
                child: Text(l10n.historyLoadMore),
              ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.68),
        ),
      ),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

AppLocalizations _historyL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsZh();

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatDateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';

const Set<EventKind> _otherEventKinds = {
  EventKind.reward,
  EventKind.pause,
  EventKind.interruption,
  EventKind.note,
  EventKind.custom,
  EventKind.possession,
};

/// Timeline and filter controls are kept separate from the replay overview so
/// the dense review surface remains testable at large text scales.
class ReplayTimelinePanel extends StatelessWidget {
  const ReplayTimelinePanel({
    required this.controller,
    required this.onEventTap,
    this.embedded = false,
    super.key,
  });

  final ReplayController controller;
  final bool embedded;
  final ValueChanged<ReplayEventData> onEventTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    Widget content({required bool inlineEvents}) {
      final events = controller.visibleEvents;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: inlineEvents ? MainAxisSize.min : MainAxisSize.max,
        children: [
          _SectionTitle(title: l10n.replayTimeline, icon: Icons.timeline),
          const SizedBox(height: 10),
          ReplayTimelineFilters(controller: controller),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(l10n.replayNoEvents)),
            )
          else if (inlineEvents)
            ...events.map(
              (event) => ReplayTimelineEvent(
                event: event,
                data: controller.data,
                selected: controller.selectedEventId == event.id,
                editing: controller.isEditing,
                onTap: () => onEventTap(event),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                key: const Key('replay-timeline-scroll'),
                itemCount: events.length,
                itemBuilder: (context, index) => ReplayTimelineEvent(
                  event: events[index],
                  data: controller.data,
                  selected: controller.selectedEventId == events[index].id,
                  editing: controller.isEditing,
                  onTap: () => onEventTap(events[index]),
                ),
              ),
            ),
        ],
      );
    }

    if (embedded) {
      return Container(
        key: const Key('replay-timeline-pane'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: editorialThemeOf(context).surface,
          border: Border(
            top: BorderSide(
              color: editorialThemeOf(context).arenaAccent,
              width: 4,
            ),
          ),
        ),
        child: content(inlineEvents: true),
      );
    }
    return Container(
      key: const Key('replay-timeline-pane'),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: editorialThemeOf(context).surface,
        border: Border(
          top: BorderSide(
            color: editorialThemeOf(context).arenaAccent,
            width: 4,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 420;
          final compactWidth = constraints.maxWidth < 360;
          final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          final compact = compactHeight || compactWidth || largeText;
          if (compact) {
            final events = controller.visibleEvents;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SectionTitle(
                          title: l10n.replayTimeline,
                          icon: Icons.timeline,
                        ),
                      ),
                      Semantics(
                        key: const Key('replay-compact-filter-action'),
                        label: l10n.replayFilters,
                        button: true,
                        excludeSemantics: true,
                        child: IconButton(
                          tooltip: l10n.replayFilters,
                          onPressed: () => _showCompactFilters(context),
                          icon: const Icon(Icons.tune),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (events.isEmpty)
                    Expanded(child: Center(child: Text(l10n.replayNoEvents)))
                  else
                    Expanded(
                      child: ListView.builder(
                        key: const Key('replay-timeline-scroll'),
                        itemCount: events.length,
                        itemBuilder: (context, index) => ReplayTimelineEvent(
                          event: events[index],
                          data: controller.data,
                          compact: true,
                          selected:
                              controller.selectedEventId == events[index].id,
                          editing: controller.isEditing,
                          onTap: () => onEventTap(events[index]),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          final child = Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: content(inlineEvents: false),
          );
          return child;
        },
      ),
    );
  }

  Future<void> _showCompactFilters(BuildContext context) {
    final l10n = _localizations(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: EditorialSheet(
          title: l10n.replayFilters,
          child: SingleChildScrollView(
            child: ReplayTimelineFilters(controller: controller),
          ),
        ),
      ),
    );
  }
}

class ReplayTimelineFilters extends StatelessWidget {
  const ReplayTimelineFilters({required this.controller, super.key});

  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    final eventFilter = controller.eventFilter;
    final points =
        controller.data.events
            .map((event) => event.points)
            .where((value) => value > 0)
            .toSet()
            .toList()
          ..sort();
    void setKinds(Set<EventKind> kinds) {
      controller.setEventFilter(eventFilter.copyWith(kinds: kinds));
    }

    void setSides(Set<TeamSide> sides) {
      controller.setEventFilter(eventFilter.copyWith(sides: sides));
    }

    void setOutcomes(Set<ShotOutcome?> outcomes) {
      controller.setEventFilter(eventFilter.copyWith(outcomes: outcomes));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              key: const Key('replay-kind-all'),
              label: l10n.replayFilterAll,
              selected: eventFilter.kinds.isEmpty,
              onSelected: () => setKinds(const {}),
            ),
            _FilterChip(
              key: const Key('replay-kind-scores'),
              label: l10n.replayFilterScores,
              selected:
                  eventFilter.kinds.contains(EventKind.score) &&
                  eventFilter.kinds.length == 3,
              onSelected: () => setKinds(const {
                EventKind.score,
                EventKind.fieldGoal,
                EventKind.freeThrow,
              }),
            ),
            _FilterChip(
              key: const Key('replay-kind-fouls'),
              label: l10n.replayFilterFouls,
              selected:
                  eventFilter.kinds.length == 1 &&
                  eventFilter.kinds.contains(EventKind.foul),
              onSelected: () => setKinds(const {EventKind.foul}),
            ),
            _FilterChip(
              key: const Key('replay-kind-misses'),
              label: l10n.replayFilterMisses,
              selected:
                  eventFilter.kinds.length == 1 &&
                  eventFilter.kinds.contains(EventKind.miss),
              onSelected: () => setKinds(const {EventKind.miss}),
            ),
            _FilterChip(
              key: const Key('replay-kind-other'),
              label: l10n.replayFilterOther,
              selected:
                  eventFilter.kinds.length == _otherEventKinds.length &&
                  eventFilter.kinds.containsAll(_otherEventKinds),
              onSelected: () => setKinds(_otherEventKinds),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: l10n.replayFilterBoth,
              selected: eventFilter.sides.isEmpty,
              onSelected: () => setSides(const {}),
            ),
            _FilterChip(
              label: l10n.replayFilterRed,
              selected:
                  eventFilter.sides.contains(TeamSide.red) &&
                  eventFilter.sides.length == 1,
              selectedColor: teamColorForScheme(
                TeamSide.red,
                Theme.of(context).colorScheme,
              ).withValues(alpha: 0.18),
              onSelected: () => setSides(const {TeamSide.red}),
            ),
            _FilterChip(
              label: l10n.replayFilterBlue,
              selected:
                  eventFilter.sides.contains(TeamSide.blue) &&
                  eventFilter.sides.length == 1,
              selectedColor: teamColorForScheme(
                TeamSide.blue,
                Theme.of(context).colorScheme,
              ).withValues(alpha: 0.18),
              onSelected: () => setSides(const {TeamSide.blue}),
            ),
            _FilterChip(
              label: eventFilter.includeDeleted
                  ? l10n.replayFilterShowDeleted
                  : l10n.replayFilterHideDeleted,
              selected: eventFilter.includeDeleted,
              onSelected: () => controller.setEventFilter(
                eventFilter.copyWith(
                  includeDeleted: !eventFilter.includeDeleted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: l10n.replayFilterMade,
              selected:
                  eventFilter.outcomes.contains(ShotOutcome.made) &&
                  eventFilter.outcomes.length == 1,
              onSelected: () {
                final current = controller.eventFilter;
                setOutcomes(
                  current.outcomes.contains(ShotOutcome.made) &&
                          current.outcomes.length == 1
                      ? const {}
                      : const {ShotOutcome.made},
                );
              },
            ),
            _FilterChip(
              label: l10n.replayFilterMissed,
              selected:
                  eventFilter.outcomes.contains(ShotOutcome.missed) &&
                  eventFilter.outcomes.length == 1,
              onSelected: () {
                final current = controller.eventFilter;
                setOutcomes(
                  current.outcomes.contains(ShotOutcome.missed) &&
                          current.outcomes.length == 1
                      ? const {}
                      : const {ShotOutcome.missed},
                );
              },
            ),
            for (final value in points)
              _FilterChip(
                label: '${l10n.replayFilterPoints} $value',
                selected:
                    eventFilter.points.length == 1 &&
                    eventFilter.points.contains(value),
                onSelected: () {
                  final current = controller.eventFilter;
                  controller.setEventFilter(
                    current.copyWith(
                      points:
                          current.points.length == 1 &&
                              current.points.contains(value)
                          ? const {}
                          : {value},
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class ReplayTimelineEvent extends StatelessWidget {
  const ReplayTimelineEvent({
    required this.event,
    required this.data,
    this.selected = false,
    this.editing = false,
    this.compact = false,
    this.onTap,
    super.key,
  });

  final ReplayEventData event;
  final ReplayMatchData data;
  final bool selected;
  final bool editing;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    final sideColor = event.side == null
        ? Theme.of(context).colorScheme.onSurface
        : teamColorForScheme(event.side!, Theme.of(context).colorScheme);
    final sideName = event.side == TeamSide.red
        ? data.redName
        : event.side == TeamSide.blue
        ? data.blueName
        : l10n.replayMatchSide;
    final action = switch (event.kind) {
      ReplayEventKind.score => l10n.replayActionScore(event.points),
      ReplayEventKind.foul => l10n.replayActionFoul,
      ReplayEventKind.miss => l10n.replayActionMiss,
      ReplayEventKind.other => l10n.replayActionRecord,
    };
    final details = <String>[
      if (event.outcome == ShotOutcome.made) l10n.replayFilterMade,
      if (event.outcome == ShotOutcome.missed) l10n.replayFilterMissed,
      if (event.matchClockPositionSeconds case final seconds?)
        l10n.replayClockPosition(seconds),
    ];
    final eventTile = InkWell(
      key: Key('replay-event-${event.id}'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
              : null,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.16),
            ),
          ),
        ),
        child: compact
            ? Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      _formatDuration(event.elapsed),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Container(width: 4, height: 32, color: sideColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$sideName · $action',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: sideColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.radio_button_checked, size: 20),
                    ),
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      _formatDuration(event.elapsed),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Container(width: 4, height: 32, color: sideColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '$sideName · $action',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: sideColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (event.isDeleted)
                              Chip(
                                label: Text(l10n.replayDeleted),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                        if (details.isNotEmpty)
                          Text(details.join(' · '), maxLines: 1),
                        if (event.customLabel case final label?)
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (event.note != null && event.note!.isNotEmpty)
                          Text(
                            event.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.radio_button_checked, size: 20),
                    )
                  else if (editing)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.edit_outlined, size: 20),
                    )
                  else if (event.shotPoint != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.location_on_outlined, size: 20),
                    ),
                ],
              ),
      ),
    );
    return Semantics(
      selected: selected,
      button: onTap != null,
      container: true,
      child: eventTile,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: selectedColor,
        onSelected: (_) => onSelected(),
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

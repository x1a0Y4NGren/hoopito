import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';

/// Focused editor for replay corrections.  It deliberately depends on the
/// controller's command-shaped callbacks rather than a repository, keeping
/// completed-match writes inside the application command kernel.
class ReplayEventEditorSheet extends StatefulWidget {
  const ReplayEventEditorSheet({
    required this.controller,
    required this.event,
    super.key,
  });

  final ReplayController controller;
  final ReplayEventData event;

  @override
  State<ReplayEventEditorSheet> createState() => _ReplayEventEditorSheetState();
}

class _ReplayEventEditorSheetState extends State<ReplayEventEditorSheet> {
  late final TextEditingController _note;
  late final TextEditingController _customLabel;
  late final TextEditingController _points;
  late final TextEditingController _clock;
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _reason;
  late TeamSide? _side;
  late EventKind _type;
  late ShotOutcome? _outcome;
  bool _busy = false;
  String? _error;

  bool get _richEditor => widget.controller.onCorrectEvent != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _note = TextEditingController(text: event.note ?? '');
    _customLabel = TextEditingController(text: event.customLabel ?? '');
    _points = TextEditingController(text: event.points.toString());
    _clock = TextEditingController(
      text: event.matchClockPositionSeconds?.toString() ?? '',
    );
    _x = TextEditingController(text: event.shotPoint?.x.toString() ?? '');
    _y = TextEditingController(text: event.shotPoint?.y.toString() ?? '');
    _reason = TextEditingController();
    _side = event.side;
    _type = event.rawKind ?? _legacyType(event.kind);
    _outcome = event.outcome;
  }

  @override
  void dispose() {
    _note.dispose();
    _customLabel.dispose();
    _points.dispose();
    _clock.dispose();
    _x.dispose();
    _y.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    final event = widget.event;
    final bottom = MediaQuery.viewInsetsOf(context).bottom + 20;
    return SafeArea(
      child: EditorialSheet(
        title: l10n.replayEditorTitle,
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('replay-editor-note'),
                controller: _note,
                decoration: InputDecoration(
                  labelText: l10n.replayEditorNote,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_richEditor) ...[
                DropdownButtonFormField<TeamSide?>(
                  key: const Key('replay-editor-side'),
                  initialValue: _side,
                  decoration: InputDecoration(
                    labelText: l10n.replayEditorSide,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<TeamSide?>(
                      value: null,
                      child: Text(l10n.replayMatchSide),
                    ),
                    DropdownMenuItem<TeamSide?>(
                      value: TeamSide.red,
                      child: Text(l10n.replayFilterRed),
                    ),
                    DropdownMenuItem<TeamSide?>(
                      value: TeamSide.blue,
                      child: Text(l10n.replayFilterBlue),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _side = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EventKind>(
                  key: const Key('replay-editor-kind'),
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: l10n.replayEditorEventKind,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final kind in EventKind.values)
                      DropdownMenuItem<EventKind>(
                        value: kind,
                        child: Text(_eventKindLabel(kind, l10n)),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('replay-editor-points'),
                        controller: _points,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.replayEditorPoints,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<ShotOutcome?>(
                        key: const Key('replay-editor-outcome'),
                        initialValue: _outcome,
                        decoration: InputDecoration(
                          labelText: l10n.replayEditorOutcome,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<ShotOutcome?>(
                            value: null,
                            child: Text(l10n.replayAuditValueNone),
                          ),
                          DropdownMenuItem<ShotOutcome?>(
                            value: ShotOutcome.made,
                            child: Text(l10n.replayFilterMade),
                          ),
                          DropdownMenuItem<ShotOutcome?>(
                            value: ShotOutcome.missed,
                            child: Text(l10n.replayFilterMissed),
                          ),
                          DropdownMenuItem<ShotOutcome?>(
                            value: ShotOutcome.notApplicable,
                            child: Text(l10n.replayFilterOther),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _outcome = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('replay-editor-custom-label'),
                  controller: _customLabel,
                  decoration: InputDecoration(
                    labelText: l10n.replayEditorCustomLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('replay-editor-clock'),
                  controller: _clock,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.replayEditorClock,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (event.shotPoint != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('replay-editor-x'),
                          controller: _x,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.replayEditorLocationX,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('replay-editor-y'),
                          controller: _y,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.replayEditorLocationY,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('replay-editor-reason'),
                controller: _reason,
                decoration: InputDecoration(
                  labelText: l10n.replayEditorReason,
                  border: const OutlineInputBorder(),
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
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: event.isDeleted
                            ? const Key('replay-editor-restore')
                            : const Key('replay-editor-delete'),
                        onPressed: _busy
                            ? null
                            : event.isDeleted
                            ? _restoreEvent
                            : _deleteEvent,
                        icon: Icon(
                          event.isDeleted
                              ? Icons.restore_outlined
                              : Icons.delete_outline,
                        ),
                        label: Text(
                          event.isDeleted
                              ? l10n.replayEditorRestore
                              : l10n.replayEditorDelete,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const Key('replay-editor-save'),
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _richEditor
                              ? l10n.replayEditorSave
                              : l10n.replayEditorSaveNote,
                        ),
                      ),
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

  Future<void> _save() async {
    final l10n = _localizations(context);
    final points = int.tryParse(_points.text.trim());
    final clockText = _clock.text.trim();
    final clock = clockText.isEmpty ? null : int.tryParse(clockText);
    if (_richEditor &&
        (points == null || (clockText.isNotEmpty && clock == null))) {
      _showError(l10n.replayEditorInvalidNumber);
      return;
    }
    final xText = _x.text.trim();
    final yText = _y.text.trim();
    final x = xText.isEmpty ? null : double.tryParse(xText);
    final y = yText.isEmpty ? null : double.tryParse(yText);
    if (_richEditor &&
        (x != null || y != null) &&
        (x == null || y == null || x < 0 || x > 1 || y < 0 || y > 1)) {
      _showError(l10n.replayEditorLocationRange);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_richEditor) {
        await widget.controller.correctSelectedEvent(
          type: _type,
          side: _side,
          points: points,
          outcome: _outcome,
          note: _note.text,
          customLabel: _customLabel.text,
          matchClockPositionSeconds: clock,
          reason: _reason.text,
        );
        if (x != null &&
            y != null &&
            widget.controller.onCorrectShotLocation != null) {
          await widget.controller.correctSelectedShotLocation(
            CourtPoint(x: x, y: y),
            reason: _reason.text,
          );
        }
      } else {
        await widget.controller.updateSelectedNote(
          _note.text,
          reason: _reason.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.actionFailedRetry;
        });
      }
    }
  }

  Future<void> _deleteEvent() async {
    final l10n = _localizations(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.replayEditorDeleteTitle),
        content: Text(l10n.replayEditorDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.replayEditorConfirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(widget.controller.deleteSelectedEvent);
  }

  Future<void> _restoreEvent() async {
    final l10n = _localizations(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.replayEditorRestoreTitle),
        content: Text(l10n.replayEditorRestoreBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.replayEditorConfirmRestore),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(widget.controller.restoreSelectedEvent);
  }

  Future<void> _runAction(
    Future<void> Function({String? reason}) action,
  ) async {
    final l10n = _localizations(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(reason: _reason.text);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.actionFailedRetry;
        });
      }
    }
  }

  void _showError(String value) {
    if (!mounted) return;
    setState(() => _error = value);
  }
}

EventKind _legacyType(ReplayEventKind kind) {
  return switch (kind) {
    ReplayEventKind.score => EventKind.score,
    ReplayEventKind.foul => EventKind.foul,
    ReplayEventKind.miss => EventKind.miss,
    ReplayEventKind.other => EventKind.custom,
  };
}

String _eventKindLabel(EventKind kind, AppLocalizations l10n) {
  return switch (kind) {
    EventKind.score ||
    EventKind.fieldGoal ||
    EventKind.freeThrow => l10n.replayFilterScores,
    EventKind.foul => l10n.replayFilterFouls,
    EventKind.miss => l10n.replayFilterMisses,
    _ => l10n.replayFilterOther,
  };
}

AppLocalizations _localizations(BuildContext context) {
  return AppLocalizations.of(context) ?? AppLocalizationsZh();
}

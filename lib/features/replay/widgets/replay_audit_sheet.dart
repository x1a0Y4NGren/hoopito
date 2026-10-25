import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/audit/audit_diff.dart';
import 'package:hoopito/core/audit/audit_log_entry.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

/// Audit history is a review surface, so it owns its presentation rather than
/// leaking storage action names or JSON keys into the timeline UI.
class ReplayAuditSheet extends StatelessWidget {
  const ReplayAuditSheet({required this.logs, super.key});

  final List<AuditLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    return SafeArea(
      child: EditorialSheet(
        title: l10n.replayAuditTitle,
        child: SizedBox(
          height: math.max(
            120,
            math.min(MediaQuery.sizeOf(context).height * 0.8, 620) - 80,
          ),
          child: logs.isEmpty
              ? Center(child: Text(l10n.replayAuditEmpty))
              : ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _AuditEntryTile(log: logs[index], l10n: l10n),
                ),
        ),
      ),
    );
  }
}

class _AuditEntryTile extends StatelessWidget {
  const _AuditEntryTile({required this.log, required this.l10n});

  final AuditLogEntry log;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final action = ReplayAuditFormatter.action(log.action, l10n);
    final target = ReplayAuditFormatter.target(log, l10n);
    final date = MaterialLocalizations.of(
      context,
    ).formatCompactDate(log.createdAt.toLocal());
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(log.createdAt.toLocal()));
    final changes = ReplayAuditFormatter.diffLines(log.diff, l10n);
    return ListTile(
      minTileHeight: 72,
      leading: Icon(
        log.action == AuditAction.delete || log.action == AuditAction.undo
            ? Icons.delete_outline
            : log.action == AuditAction.restore
            ? Icons.restore_outlined
            : Icons.edit_outlined,
        color: editorialThemeOf(context).arenaAccent,
      ),
      title: Text('$action · $target'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$date $time'),
          for (final line in changes) Text(line),
          Text(
            log.reason == null || log.reason!.trim().isEmpty
                ? l10n.replayAuditNoReason
                : l10n.replayAuditReason(log.reason!),
          ),
        ],
      ),
    );
  }
}

class ReplayAuditFormatter {
  const ReplayAuditFormatter._();

  static String action(AuditAction value, AppLocalizations l10n) {
    return switch (value) {
      AuditAction.create => l10n.replayAuditActionCreate,
      AuditAction.undo => l10n.replayAuditActionUndo,
      AuditAction.edit => l10n.replayAuditActionEdit,
      AuditAction.delete => l10n.replayAuditActionDelete,
      AuditAction.import => l10n.replayAuditActionImport,
      AuditAction.restore => l10n.replayAuditActionRestore,
      AuditAction.command => l10n.replayAuditActionCommand,
      AuditAction.locate => l10n.replayAuditActionLocate,
      AuditAction.possession => l10n.replayAuditActionPossession,
      AuditAction.possession_suggestion =>
        l10n.replayAuditActionPossessionSuggestion,
      AuditAction.unknown => l10n.replayAuditActionUnknown,
    };
  }

  static String target(AuditLogEntry log, AppLocalizations l10n) {
    final keys = {...log.diff.before.keys, ...log.diff.after.keys};
    final label = keys.contains('x') || keys.contains('y')
        ? l10n.replayAuditTargetLocation
        : keys.contains('commandType') || log.action == AuditAction.command
        ? l10n.replayAuditTargetCommand
        : log.targetId == log.matchId
        ? l10n.replayAuditTargetMatch
        : l10n.replayAuditTargetEvent;
    return '$label · ${log.targetId}';
  }

  static List<String> diffLines(AuditDiff diff, AppLocalizations l10n) {
    final keys = {...diff.before.keys, ...diff.after.keys}.toList()..sort();
    return [
      for (final key in keys)
        if (_isDisplayField(key))
          '${_fieldName(key, l10n)}: '
              '${_value(key, diff.before[key], l10n)} → '
              '${_value(key, diff.after[key], l10n)}',
    ];
  }

  static bool _isDisplayField(String key) {
    return const {
      'type',
      'side',
      'points',
      'outcome',
      'note',
      'customLabel',
      'matchClockPositionSeconds',
      'isDeleted',
      'x',
      'y',
      'trackingCoverage',
    }.contains(key);
  }

  static String _fieldName(String key, AppLocalizations l10n) {
    return switch (key) {
      'type' => l10n.replayAuditFieldType,
      'side' => l10n.replayAuditFieldSide,
      'points' => l10n.replayAuditFieldPoints,
      'outcome' => l10n.replayAuditFieldOutcome,
      'note' => l10n.replayAuditFieldNote,
      'customLabel' => l10n.replayAuditFieldCustomLabel,
      'matchClockPositionSeconds' => l10n.replayAuditFieldClock,
      'isDeleted' => l10n.replayAuditFieldDeleted,
      'x' => l10n.replayAuditFieldX,
      'y' => l10n.replayAuditFieldY,
      'trackingCoverage' => l10n.v2CoverageTitle,
      _ => l10n.replayAuditFieldType,
    };
  }

  static String _value(String key, Object? value, AppLocalizations l10n) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return l10n.replayAuditValueNone;
    }
    if (key == 'isDeleted' && value is bool) {
      return value ? l10n.replayAuditValueDeleted : l10n.replayAuditValueActive;
    }
    if (key == 'trackingCoverage') {
      return switch (value) {
        'scoresOnly' => l10n.v2CoverageScores,
        'shotAttempts' => l10n.v2CoverageComplete,
        'locations' => l10n.replayAnalyticsTrackingLocations,
        'full' => l10n.replayAnalyticsTrackingFull,
        _ => l10n.replayNoData,
      };
    }
    if (key == 'side' && value is String) {
      return value == TeamSide.red.name
          ? l10n.replayFilterRed
          : value == TeamSide.blue.name
          ? l10n.replayFilterBlue
          : l10n.replayMatchSide;
    }
    if (key == 'outcome' && value is String) {
      return switch (value) {
        'made' => l10n.replayFilterMade,
        'missed' => l10n.replayFilterMissed,
        _ => value,
      };
    }
    if (key == 'type' && value is String) {
      return switch (value) {
        'score' || 'fieldGoal' || 'freeThrow' => l10n.replayFilterScores,
        'foul' => l10n.replayFilterFouls,
        'miss' => l10n.replayFilterMisses,
        _ => l10n.replayFilterOther,
      };
    }
    return value.toString();
  }
}

AppLocalizations _localizations(BuildContext context) {
  return AppLocalizations.of(context) ?? AppLocalizationsZh();
}

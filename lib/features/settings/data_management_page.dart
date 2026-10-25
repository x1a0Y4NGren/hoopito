import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/safety_backup_store.dart';
import 'package:hoopito/features/settings/settings_action_tile.dart';
import 'package:hoopito/features/settings/settings_controller.dart';
import 'package:hoopito/features/settings/settings_error_message.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({
    required this.controller,
    this.onBack,
    this.onDataRestored,
    super.key,
  });

  final SettingsController controller;
  final VoidCallback? onBack;
  final VoidCallback? onDataRestored;

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

enum _ManualExportFormat { json, csv }

class _DataManagementPageState extends State<DataManagementPage> {
  AppLocalizations _l10n(BuildContext context) =>
      AppLocalizations.of(context) ?? AppLocalizationsZh();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant DataManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      _scheduleLoad();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _scheduleLoad() {
    if (widget.controller.initialized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.controller.initialized) unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      await widget.controller.load();
    } on Object {
      if (mounted) _showMessage(_l10n(context).settingsErrorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    final backup = widget.controller.backupState;
    return EditorialScaffold(
      masthead: EditorialMasthead(
        title: l10n.settingsDataManagementTitle,
        compact: true,
        leading: EditorialTapTarget(
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
          label: MaterialLocalizations.of(context).backButtonTooltip,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          child: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          if (widget.controller.busy)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
              children: [
                EditorialSectionRule(label: l10n.settingsManualDataSection),
                EditorialIndexRow(
                  key: const Key('data-export-row'),
                  index: '01',
                  title: l10n.settingsExportDataTitle,
                  subtitle: l10n.settingsExportDataSubtitle,
                  onTap: widget.controller.busy ? null : _chooseExport,
                ),
                EditorialIndexRow(
                  key: const Key('data-restore-row'),
                  index: '02',
                  title: l10n.settingsRestoreTitle,
                  subtitle: widget.controller.canRestoreBackup
                      ? l10n.settingsRestoreSubtitleMerge
                      : l10n.settingsRestoreSubtitleBlocked,
                  onTap: widget.controller.busy ? null : _chooseRestoreMode,
                ),
                const SizedBox(height: HoopitoSpacing.section),
                EditorialSectionRule(label: l10n.v2SafetyTitle),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.v2SafetyHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (widget.controller.safetyBackupError != null)
                  SettingsActionTile(
                    key: const Key('safety-backup-retry'),
                    icon: Icons.refresh,
                    title: l10n.retryAction,
                    subtitle: l10n.v2SafetyLoadError,
                    enabled: !widget.controller.busy,
                    onTap: () =>
                        unawaited(widget.controller.refreshSafetyBackups()),
                  )
                else if (widget.controller.safetyBackups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.v2SafetyEmpty),
                  ),
                for (final safety in widget.controller.safetyBackups)
                  SettingsActionTile(
                    key: Key('safety-backup-${safety.id}'),
                    icon: Icons.restore,
                    title: l10n.v2SafetyRestore,
                    subtitle: widget.controller.canRestoreBackup
                        ? _safetyBackupDate(safety)
                        : l10n.settingsReplaceBlocked,
                    enabled:
                        !widget.controller.busy &&
                        widget.controller.canRestoreBackup,
                    onTap: () => unawaited(_restoreSafetyBackup(safety)),
                  ),
                const SizedBox(height: HoopitoSpacing.section),
                EditorialSectionRule(
                  label: l10n.settingsAutomaticBackupSection,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: editorialThemeOf(context).rule),
                    ),
                  ),
                  child: SwitchListTile(
                    key: const Key('automatic-backup-switch'),
                    minTileHeight: 64,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.backup_outlined),
                    title: Text(l10n.settingsAutomaticBackupTitle),
                    subtitle: Text(
                      backup.enabled
                          ? l10n.settingsAutomaticBackupEnabled
                          : l10n.settingsAutomaticBackupDisabled,
                    ),
                    value: backup.enabled,
                    onChanged: widget.controller.busy
                        ? null
                        : _setAutomaticBackupEnabled,
                  ),
                ),
                EditorialIndexRow(
                  key: const Key('data-backup-directory-row'),
                  index: '01',
                  title: l10n.settingsBackupDirectoryTitle,
                  subtitle:
                      backup.directoryLabel ??
                      backup.directory ??
                      l10n.settingsBackupDirectoryUnselected,
                  onTap: widget.controller.busy ? null : _configureDirectory,
                ),
                SettingsActionTile(
                  key: const Key('settings-backup-now-row'),
                  icon: Icons.backup_outlined,
                  title: l10n.settingsBackupNowTitle,
                  subtitle: backup.isConfigured
                      ? _lastBackupLabel(backup, l10n)
                      : l10n.settingsErrorDirectoryRequired,
                  enabled: !widget.controller.busy && backup.isConfigured,
                  onTap: _runBackupNow,
                ),
                EditorialIndexRow(
                  key: const Key('backup-retention-limit'),
                  index: '03',
                  title: l10n.settingsBackupRetentionTitle,
                  subtitle: l10n.settingsBackupRetentionSubtitle,
                  trailing: DropdownButton<int>(
                    key: const Key('backup-retention-dropdown'),
                    value: backup.retentionLimit,
                    items: _retentionOptions(backup.retentionLimit)
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.controller.busy
                        ? null
                        : (value) {
                            if (value != null) {
                              unawaited(_setRetentionLimit(value));
                            }
                          },
                  ),
                ),
                EditorialIndexRow(
                  index: '04',
                  title: l10n.settingsPrivacyTitle,
                  subtitle: l10n.settingsPrivacySubtitle,
                  trailing: const Icon(Icons.lock_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseExport() async {
    final l10n = _l10n(context);
    final format = await showModalBottomSheet<_ManualExportFormat>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => EditorialSheet(
        title: l10n.settingsExportDataDialogTitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(l10n.cancelAction),
          ),
        ],
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EditorialIndexRow(
                  key: const Key('data-export-json'),
                  index: '01',
                  title: l10n.settingsExportBackupTitle,
                  subtitle: l10n.settingsExportBackupSubtitle,
                  onTap: () =>
                      Navigator.pop(sheetContext, _ManualExportFormat.json),
                ),
                EditorialIndexRow(
                  key: const Key('data-export-csv'),
                  index: '02',
                  title: l10n.settingsExportCsvTitle,
                  subtitle: l10n.settingsExportCsvSubtitle,
                  onTap: () =>
                      Navigator.pop(sheetContext, _ManualExportFormat.csv),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (format == null || !mounted) return;
    try {
      if (format == _ManualExportFormat.json) {
        await widget.controller.shareJsonBackup(
          subject: l10n.exportFullBackupSubject,
        );
        _showMessage(l10n.settingsExportBackupSuccess);
      } else {
        await widget.controller.shareCsvExports(subject: l10n.exportCsvSubject);
        _showMessage(l10n.settingsExportCsvSuccess);
      }
    } on Object catch (error) {
      if (mounted) _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  Future<void> _chooseRestoreMode() async {
    final l10n = _l10n(context);
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.settingsRestoreDialogTitle),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('backup-mode-merge'),
              leading: const Icon(Icons.merge_type),
              title: Text(l10n.settingsMergeTitle),
              subtitle: Text(l10n.settingsMergeSubtitle),
              onTap: () => Navigator.pop(dialogContext, RestoreMode.merge),
            ),
            ListTile(
              key: const Key('backup-mode-replace'),
              enabled: widget.controller.canRestoreBackup,
              leading: const Icon(Icons.find_replace_outlined),
              title: Text(l10n.settingsReplaceTitle),
              subtitle: Text(
                widget.controller.canRestoreBackup
                    ? l10n.settingsReplaceSubtitle
                    : l10n.settingsReplaceBlocked,
              ),
              onTap: widget.controller.canRestoreBackup
                  ? () => Navigator.pop(dialogContext, RestoreMode.replace)
                  : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelAction),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    if (mode == RestoreMode.replace && !await _confirmReplace()) return;
    try {
      final restored = await widget.controller.restoreBackup(
        mode: mode,
        pickerDialogTitle: l10n.settingsRestorePickerTitle,
      );
      if (!mounted) return;
      if (!restored) {
        _showMessage(l10n.settingsRestoreNotSelected);
        return;
      }
      _showMessage(
        mode == RestoreMode.merge
            ? l10n.settingsMergeCompleted
            : l10n.settingsReplaceCompleted,
      );
      widget.onDataRestored?.call();
    } on Object catch (error) {
      if (mounted) _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  Future<void> _restoreSafetyBackup(SafetyBackup backup) async {
    final l10n = _l10n(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.v2SafetyRestore),
        content: Text(l10n.v2SafetyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            key: const Key('safety-backup-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.v2SafetyRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.restoreSafetyBackup(backup);
      if (!mounted) return;
      _showMessage(l10n.settingsReplaceCompleted);
      widget.onDataRestored?.call();
    } on Object catch (error) {
      if (mounted) _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  String _safetyBackupDate(SafetyBackup backup) {
    final local = backup.exportedAt.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Future<bool> _confirmReplace() async {
    final l10n = _l10n(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.settingsReplaceConfirmTitle),
            content: Text(l10n.settingsReplaceConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancelAction),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.settingsReplaceConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _configureDirectory() async {
    final l10n = _l10n(context);
    try {
      final selected = await widget.controller.configureBackupDirectory(
        dialogTitle: l10n.settingsBackupDirectoryPickerTitle,
      );
      if (!mounted) return;
      _showMessage(
        selected
            ? l10n.settingsDirectoryUpdated
            : l10n.settingsDirectoryNotSelected,
      );
    } on Object catch (error) {
      if (mounted) _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  Future<void> _setAutomaticBackupEnabled(bool enabled) async {
    final l10n = _l10n(context);
    try {
      final changed = await widget.controller.setAutomaticBackupEnabled(
        enabled,
        dialogTitle: l10n.settingsBackupDirectoryPickerTitle,
      );
      if (!mounted) return;
      _showMessage(
        !changed
            ? l10n.settingsAutomaticBackupNotConfigured
            : enabled
            ? l10n.settingsAutomaticBackupTurnedOn
            : l10n.settingsAutomaticBackupTurnedOff,
      );
    } on Object catch (error) {
      if (mounted) _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  Future<void> _runBackupNow() async {
    final l10n = _l10n(context);
    try {
      await widget.controller.runBackupNow();
      if (mounted) _showMessage(l10n.settingsBackupWritten);
    } on Object catch (error) {
      if (mounted) _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  Future<void> _setRetentionLimit(int value) async {
    final l10n = _l10n(context);
    try {
      await widget.controller.setBackupRetentionLimit(value);
      if (mounted) _showMessage(l10n.settingsRetentionUpdated(value));
    } on Object catch (error) {
      if (mounted) _showMessage(settingsFriendlyError(error, l10n));
    }
  }

  static String _lastBackupLabel(
    AutomaticBackupState state,
    AppLocalizations l10n,
  ) {
    final value = state.lastBackupAt?.toLocal();
    if (value == null) return l10n.settingsBackupNever;
    String two(int number) => number.toString().padLeft(2, '0');
    return l10n.settingsBackupLastSuccess(
      '${value.year}-${two(value.month)}-${two(value.day)}',
      '${two(value.hour)}:${two(value.minute)}',
    );
  }

  static List<int> _retentionOptions(int current) =>
      (<int>{1, 5, 10, 20, 30, 50, current}.toList()..sort());

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

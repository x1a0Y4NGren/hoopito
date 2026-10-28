import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hoopito/app/app_metadata.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/update/app_update.dart';

String updateByteSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';

class SoftwareUpdatePage extends StatefulWidget {
  const SoftwareUpdatePage({
    required this.controller,
    required this.canInstall,
    required this.canInstallNow,
    super.key,
  });

  final UpdateController controller;
  final bool canInstall;
  final bool Function() canInstallNow;

  @override
  State<SoftwareUpdatePage> createState() => _SoftwareUpdatePageState();
}

class _SoftwareUpdatePageState extends State<SoftwareUpdatePage>
    with WidgetsBindingObserver {
  bool _installing = false;
  bool _returningFromSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_refresh);
    unawaited(widget.controller.initialize());
  }

  @override
  void didUpdateWidget(covariant SoftwareUpdatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      unawaited(widget.controller.initialize());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _returningFromSettings) {
      _returningFromSettings = false;
      unawaited(_install(allowPermissionPrompt: false));
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _canInstallNow() =>
      mounted &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      ModalRoute.of(context)?.isCurrent == true &&
      widget.canInstallNow();

  Future<void> _install({bool allowPermissionPrompt = true}) async {
    if (_installing || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_canInstallNow()) {
      _message(l10n.updateInstallBlocked);
      return;
    }
    setState(() => _installing = true);
    try {
      final result = await widget.controller.requestInstall(
        canInstallNow: _canInstallNow,
      );
      if (!mounted || !_canInstallNow()) return;
      switch (result) {
        case UpdateInstallResult.permissionRequired:
          if (!allowPermissionPrompt) {
            _message(l10n.updateInstallFailed);
            break;
          }
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.updatePermissionTitle),
              content: SingleChildScrollView(
                child: Text(l10n.updatePermissionBody),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.updateLater),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.updateOpenSettings),
                ),
              ],
            ),
          );
          if (openSettings == true && mounted) {
            _returningFromSettings = true;
            await widget.controller.openInstallSettings();
          }
        case UpdateInstallResult.installerLaunched:
          _message(l10n.updateInstallerOpened);
        case UpdateInstallResult.unavailable:
        case UpdateInstallResult.prepared:
          _message(l10n.updateInstallFailed);
      }
    } on Object {
      _returningFromSettings = false;
      _message(l10n.updateInstallFailed);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final download = controller.download;
    final release = download.release ?? controller.availableRelease;
    final downloading = switch (download.phase) {
      UpdateDownloadPhase.queued ||
      UpdateDownloadPhase.downloading ||
      UpdateDownloadPhase.paused ||
      UpdateDownloadPhase.verifying => true,
      _ => false,
    };
    final version = controller.installedApp == null
        ? (controller.supported ? '…' : hoopitoAppVersion)
        : '${controller.installedApp!.versionName}+${controller.installedApp!.versionCode}';
    return EditorialScaffold(
      masthead: EditorialMasthead(
        title: l10n.updateTitle,
        compact: true,
        leading: Navigator.canPop(context)
            ? EditorialTapTarget(
                onPressed: () => Navigator.maybePop(context),
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
        children: [
          Text(
            'Hoopito · 球豆',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(l10n.updateCurrentVersion(version)),
          const SizedBox(height: HoopitoSpacing.section),
          SwitchListTile.adaptive(
            key: const Key('update-auto-check'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.updateAutoCheck),
            subtitle: Text(l10n.updateAutoCheckDetail),
            value: controller.autoCheckEnabled,
            onChanged: controller.supported && controller.initialized
                ? (enabled) async {
                    try {
                      await controller.setAutoCheckEnabled(enabled);
                    } on Object {
                      _message(l10n.updateSettingsFailed);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 16),
          Semantics(
            key: const Key('update-check-announcement'),
            liveRegion: controller.checking,
            child: OutlinedButton(
              key: const Key('update-check'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: controller.supported && !controller.checking
                  ? controller.checkForUpdates
                  : null,
              child: Text(
                controller.checking ? l10n.updateChecking : l10n.updateCheck,
              ),
            ),
          ),
          if (_checkMessage(l10n).isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(_checkMessage(l10n))),
          ],
          if (release != null) ...[
            const SizedBox(height: HoopitoSpacing.section),
            Semantics(
              key: const Key('update-release-announcement'),
              liveRegion: true,
              child: Text(
                l10n.updateAvailable(
                  '${release.versionName}+${release.versionCode}',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              release.notesFor(Localizations.localeOf(context).languageCode),
            ),
            const SizedBox(height: 12),
            Text(l10n.updateDownloadSize(updateByteSize(release.apkBytes))),
          ],
          const SizedBox(height: 16),
          if (download.phase != UpdateDownloadPhase.idle) ...[
            Semantics(liveRegion: true, child: Text(_downloadMessage(l10n))),
            const SizedBox(height: 12),
          ],
          if (downloading) ...[
            LinearProgressIndicator(
              value:
                  download.phase == UpdateDownloadPhase.verifying ||
                      download.bytesTotal <= 0
                  ? null
                  : (download.bytesReceived / download.bytesTotal).clamp(0, 1),
            ),
            if (download.usedFallback) ...[
              const SizedBox(height: 8),
              Text(l10n.updateFallback),
            ],
            const SizedBox(height: 12),
            TextButton(
              key: const Key('update-cancel-download'),
              onPressed: controller.cancelDownload,
              child: Text(l10n.updateCancelDownload),
            ),
          ] else if (download.phase == UpdateDownloadPhase.ready) ...[
            if (!widget.canInstall) ...[
              Text(l10n.updateInstallBlocked),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const Key('update-install'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: widget.canInstall && !_installing
                  ? () => _install()
                  : null,
              child: Text(l10n.updateInstall),
            ),
          ] else if (release != null &&
              controller.checkStatus != UpdateCheckStatus.incompatible) ...[
            FilledButton(
              key: const Key('update-download'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: controller.startDownload,
              child: Text(
                download.phase == UpdateDownloadPhase.failed
                    ? l10n.updateRetryDownload
                    : l10n.updateDownload,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _checkMessage(AppLocalizations l10n) =>
      switch (widget.controller.checkStatus) {
        UpdateCheckStatus.idle ||
        UpdateCheckStatus.checking ||
        UpdateCheckStatus.updateAvailable => '',
        UpdateCheckStatus.upToDate => l10n.updateUpToDate,
        UpdateCheckStatus.incompatible => l10n.updateIncompatible,
        UpdateCheckStatus.failed => l10n.updateCheckFailed,
        UpdateCheckStatus.unsupported => l10n.updateUnsupported,
      };

  String _downloadMessage(AppLocalizations l10n) =>
      switch (widget.controller.download.phase) {
        UpdateDownloadPhase.idle => '',
        UpdateDownloadPhase.queued => l10n.updateDownloadQueued,
        UpdateDownloadPhase.downloading => l10n.updateDownloading(
          updateByteSize(widget.controller.download.bytesReceived),
          updateByteSize(widget.controller.download.bytesTotal),
        ),
        UpdateDownloadPhase.paused => l10n.updateDownloadPaused,
        UpdateDownloadPhase.verifying => l10n.updateVerifying,
        UpdateDownloadPhase.ready => l10n.updateReady,
        UpdateDownloadPhase.failed =>
          switch (widget.controller.download.error) {
            'verification' => l10n.updateVerificationFailed,
            'missing' => l10n.updateFileMissing,
            _ => l10n.updateDownloadFailed,
          },
      };
}

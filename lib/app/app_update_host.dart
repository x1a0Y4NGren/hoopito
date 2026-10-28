import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/update_providers.dart';
import 'package:hoopito/core/update/app_update.dart';
import 'package:hoopito/features/settings/software_update_page.dart';

/// Network work begins only after local readiness and the decorative entry
/// handoff. Its state never feeds back into database startup or entry playback.
class AppUpdateHost extends ConsumerStatefulWidget {
  const AppUpdateHost({
    required this.ready,
    required this.entryRevealed,
    required this.router,
    required this.child,
    super.key,
  });

  final bool ready;
  final ValueListenable<bool> entryRevealed;
  final GoRouter? router;
  final Widget child;

  @override
  ConsumerState<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends ConsumerState<AppUpdateHost>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _pendingReminder = false;
  bool _showingReminder = false;
  bool _scheduled = false;
  Timer? _poll;
  AppLifecycleState? _lifecycle;
  UpdateNavigationObserver? _observer;

  bool get _foreground =>
      _lifecycle == null || _lifecycle == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    widget.entryRevealed.addListener(_schedule);
    widget.router?.routeInformationProvider.addListener(_schedule);
  }

  @override
  void didUpdateWidget(covariant AppUpdateHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryRevealed != widget.entryRevealed) {
      oldWidget.entryRevealed.removeListener(_schedule);
      widget.entryRevealed.addListener(_schedule);
    }
    if (oldWidget.router != widget.router) {
      oldWidget.router?.routeInformationProvider.removeListener(_schedule);
      widget.router?.routeInformationProvider.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _observer?.removeListener(_schedule);
    widget.entryRevealed.removeListener(_schedule);
    widget.router?.routeInformationProvider.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _poll?.cancel();
    _poll = null;
    if (state == AppLifecycleState.resumed &&
        widget.ready &&
        ref.read(updatePlatformProvider).supported) {
      final controller = ref.read(updateControllerProvider);
      if (controller.supported) unawaited(controller.refreshDownload());
      _schedule();
    }
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _advance();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _advance() {
    if (!widget.ready || !widget.entryRevealed.value || !_foreground) return;
    final controller = ref.read(updateControllerProvider);
    if (!controller.supported) return;
    if (!_started) {
      _started = true;
      unawaited(_startupCheck(controller));
    }
    final phase = controller.download.phase;
    if (_poll == null &&
        (phase == UpdateDownloadPhase.queued ||
            phase == UpdateDownloadPhase.downloading ||
            phase == UpdateDownloadPhase.paused ||
            phase == UpdateDownloadPhase.verifying)) {
      _poll = Timer(const Duration(seconds: 1), () async {
        _poll = null;
        if (!mounted || !_foreground) return;
        await controller.refreshDownload();
        _schedule();
      });
    }
    final router = widget.router;
    if (router == null) return;
    if (router.routeInformationProvider.value.uri.path == '/settings/update') {
      _pendingReminder = false;
    }
    if (!_pendingReminder || _showingReminder || !controller.autoCheckEnabled) {
      return;
    }
    if (!canRestoreBackupFor(ref.read(activeMatchProvider)) ||
        _observer?.hasPopup == true) {
      return;
    }
    final release = controller.availableRelease;
    final navigatorContext = router.routerDelegate.navigatorKey.currentContext;
    if (release == null || navigatorContext == null) return;
    _pendingReminder = false;
    _showingReminder = true;
    unawaited(_showReminder(navigatorContext, router, controller, release));
  }

  Future<void> _startupCheck(UpdateController controller) async {
    await controller.initialize();
    if (!mounted || !controller.initialized || !controller.autoCheckEnabled) {
      return;
    }
    try {
      if (!await ref.read(updatePlatformProvider).claimStartupCheck()) return;
      await controller.checkForUpdates();
      if (!mounted) return;
      _pendingReminder =
          controller.checkStatus == UpdateCheckStatus.updateAvailable;
      _schedule();
    } on Object {
      // Optional startup checks stay silent; the settings page can retry.
    }
  }

  Future<void> _showReminder(
    BuildContext navigatorContext,
    GoRouter router,
    UpdateController controller,
    UpdateRelease release,
  ) async {
    final l10n = AppLocalizations.of(navigatorContext)!;
    try {
      final update = await showDialog<bool>(
        context: navigatorContext,
        builder: (context) => AlertDialog(
          key: const Key('startup-update-dialog'),
          scrollable: true,
          title: Text(l10n.updateAvailable(release.versionName)),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                release.notesFor(Localizations.localeOf(context).languageCode),
              ),
              const SizedBox(height: 12),
              Text(l10n.updateDownloadSize(updateByteSize(release.apkBytes))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.updateLater),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.updateNow),
            ),
          ],
        ),
      );
      if (mounted && update == true) {
        router.push('/settings/update');
        await controller.startDownload();
      }
    } finally {
      _showingReminder = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ready && ref.watch(updatePlatformProvider).supported) {
      ref.watch(updateControllerProvider);
      ref.watch(activeMatchProvider);
      final observer = ref.watch(updateNavigationObserverProvider);
      if (!identical(_observer, observer)) {
        _observer?.removeListener(_schedule);
        _observer = observer..addListener(_schedule);
      }
      _schedule();
    }
    return widget.child;
  }
}

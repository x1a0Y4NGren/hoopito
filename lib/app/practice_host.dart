import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/practice_providers.dart';
import 'package:hoopito/app/update_providers.dart';

/// Optional onboarding runs after local startup; it never feeds entry readiness.
class PracticeHost extends ConsumerStatefulWidget {
  const PracticeHost({
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
  ConsumerState<PracticeHost> createState() => _PracticeHostState();
}

class _PracticeHostState extends ConsumerState<PracticeHost>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _pending = false;
  bool _showing = false;
  bool _scheduled = false;
  AppLifecycleState? _lifecycle;
  UpdateNavigationObserver? _observer;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    widget.entryRevealed.addListener(_schedule);
    widget.router?.routerDelegate.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant PracticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryRevealed != widget.entryRevealed) {
      oldWidget.entryRevealed.removeListener(_schedule);
      widget.entryRevealed.addListener(_schedule);
    }
    if (oldWidget.router != widget.router) {
      oldWidget.router?.routerDelegate.removeListener(_schedule);
      widget.router?.routerDelegate.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    widget.entryRevealed.removeListener(_schedule);
    widget.router?.routerDelegate.removeListener(_schedule);
    _observer?.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) _schedule();
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
    if (!widget.ready || !widget.entryRevealed.value) return;
    if (_lifecycle != null && _lifecycle != AppLifecycleState.resumed) return;
    if (!_showing && ref.read(practiceInvitationHandledInMemoryProvider)) {
      _pending = false;
      ref.read(practiceInvitationBlockingProvider.notifier).state = false;
      return;
    }
    if (!_started) {
      _started = true;
      if (ref.read(practiceInvitationHandledInMemoryProvider)) return;
      ref.read(practiceInvitationBlockingProvider.notifier).state = true;
      unawaited(_load());
    }
    final router = widget.router;
    if (!_pending ||
        _showing ||
        router == null ||
        ref.read(practiceFlowVisibleProvider) ||
        !canRestoreBackupFor(ref.read(activeMatchProvider)) ||
        _observer?.hasPopup == true ||
        router.routerDelegate.currentConfiguration.isEmpty ||
        router.routerDelegate.currentConfiguration.last.matchedLocation !=
            '/') {
      return;
    }
    final navigatorContext = router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _showing = true;
    unawaited(_invite(navigatorContext, router));
  }

  Future<void> _load() async {
    try {
      final progress = await ref
          .read(practicePreferencesProvider)
          .load()
          .timeout(const Duration(seconds: 2));
      if (!mounted) return;
      if (progress.invitationHandled) {
        _finishInvitation();
      } else {
        _pending = true;
        _schedule();
      }
    } on Object {
      // An unavailable preference must not block updates or normal navigation.
      if (mounted) _finishInvitation();
    }
  }

  void _finishInvitation() {
    _pending = false;
    ref.read(practiceInvitationHandledInMemoryProvider.notifier).state = true;
    ref.read(practiceInvitationBlockingProvider.notifier).state = false;
  }

  Future<void> _invite(BuildContext navigatorContext, GoRouter router) async {
    final l10n = AppLocalizations.of(navigatorContext)!;
    try {
      final start = await showDialog<bool>(
        context: navigatorContext,
        builder: (context) => AlertDialog(
          key: const Key('practice-invitation-dialog'),
          scrollable: true,
          title: Text(l10n.practiceInviteTitle),
          content: Text(l10n.practiceInviteBody),
          actions: [
            TextButton(
              key: const Key('practice-invite-later'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.practiceUseApp),
            ),
            FilledButton(
              key: const Key('practice-invite-start'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.practiceStart),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // Persist independently of navigation; failed writes cannot trap the user.
      unawaited(_saveHandled());
      if (start == true) unawaited(router.push('/practice'));
    } finally {
      _showing = false;
      if (mounted) _finishInvitation();
    }
  }

  Future<void> _saveHandled() async {
    try {
      await ref.read(practicePreferencesProvider).markInvitationHandled();
    } on Object {
      // The in-memory guard has already consumed this process's invitation.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ready) {
      ref.watch(activeMatchProvider);
      ref.watch(practiceFlowVisibleProvider);
      ref.watch(practiceInvitationHandledInMemoryProvider);
      final observer = ref.watch(updateNavigationObserverProvider);
      if (!identical(observer, _observer)) {
        _observer?.removeListener(_schedule);
        _observer = observer..addListener(_schedule);
      }
      _schedule();
    }
    return widget.child;
  }
}

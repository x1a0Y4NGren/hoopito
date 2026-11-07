import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/practice_entry.dart';
import 'package:hoopito/app/practice_providers.dart';
import 'package:hoopito/app/route_status.dart';
import 'package:hoopito/features/practice/practice_flow_page.dart';

class PracticeRoute extends ConsumerStatefulWidget {
  const PracticeRoute({super.key});
  @override
  ConsumerState<PracticeRoute> createState() => _PracticeRouteState();
}

class _PracticeRouteState extends ConsumerState<PracticeRoute> {
  bool _loading = true;
  bool _entered = false;
  bool _failed = false;
  String? _pauseId;
  String? _returnId;
  late final void Function() _release;

  @override
  void initState() {
    super.initState();
    // Capture notifier ownership while the route is alive; ref is invalid after dispose.
    final visible = ref.read(practiceFlowVisibleProvider.notifier);
    _release = () {
      // The whole app's ProviderScope may be gone before this microtask runs.
      if (visible.mounted) {
        visible.state = false;
      }
    };
    Future.microtask(() {
      if (!mounted) return;
      visible.state = true;
      ref.read(practiceInvitationHandledInMemoryProvider.notifier).state = true;
      unawaited(_markHandled());
      unawaited(_enter());
    });
  }

  Future<void> _markHandled() async {
    try {
      await ref.read(practicePreferencesProvider).markInvitationHandled();
    } on Object {
      /* Optional preference. */
    }
  }

  @override
  void dispose() {
    Future.microtask(_release);
    super.dispose();
  }

  Future<void> _enter({String? pauseId}) async {
    if (!_loading) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final detail = await PracticeEntry(
        ref.read(matchRepositoryProvider),
        ref.read(matchCommandServiceProvider),
      ).enter(pauseMatchId: pauseId);
      if (!mounted) return;
      setState(() {
        _entered = true;
        _returnId = detail?.match.id;
        _loading = false;
      });
    } on PracticePauseRequired catch (required) {
      if (!mounted) return;
      setState(() {
        _pauseId = required.matchId;
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _exit() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_entered) {
      return PracticeFlowPage(
        onExit: _exit,
        onStartReal: () => context.go('/pregame'),
        onCompleted: () =>
            ref.read(practicePreferencesProvider).markPracticeCompleted(),
        onReturnMatch: _returnId == null
            ? null
            : () => context.go('/scoring/$_returnId'),
      );
    }
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.practiceTitle),
          leading: IconButton(
            onPressed: _exit,
            tooltip: l10n.practiceExit,
            icon: const Icon(Icons.close),
          ),
        ),
        body: const RouteLoading(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.practiceTitle),
        leading: IconButton(
          onPressed: _exit,
          tooltip: l10n.practiceExit,
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _failed ? l10n.practiceLoadFailed : l10n.practicePauseTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (!_failed) Text(l10n.practicePauseBody),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('practice-pause-confirm'),
                onPressed: () => _enter(pauseId: _failed ? null : _pauseId),
                child: Text(
                  _failed ? l10n.practiceRetry : l10n.practicePauseAction,
                ),
              ),
              TextButton(
                key: const Key('practice-entry-exit'),
                onPressed: _exit,
                child: Text(l10n.practiceExit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

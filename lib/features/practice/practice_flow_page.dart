import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/orientation_shell.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/practice/practice_session.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

/// Hosts the ordinary match surfaces with ephemeral command-backed records.
/// Process death intentionally loses this lesson; only completion is persisted
/// by the caller after the final command has committed.
class PracticeFlowPage extends StatefulWidget {
  const PracticeFlowPage({
    required this.onExit,
    required this.onStartReal,
    required this.onCompleted,
    this.onReturnMatch,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onStartReal;
  final Future<void> Function() onCompleted;
  final VoidCallback? onReturnMatch;

  @override
  State<PracticeFlowPage> createState() => _PracticeFlowPageState();
}

class _PracticeFlowPageState extends State<PracticeFlowPage> {
  late PracticeSession _session;
  MatchSetup? _setup;
  bool _leaving = false;
  bool _completionReported = false;

  @override
  void initState() {
    super.initState();
    _session = PracticeSession()..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    unawaited(_session.close());
    super.dispose();
  }

  Future<void> _start(MatchSetup setup) async {
    _setup = setup;
    try {
      await _session.start(setup);
    } on Object {
      // Session exposes the error for retry without creating another match.
    }
  }

  Future<void> _finish(int red, int blue, TrackingCoverage coverage) async {
    await _session.finish(red, blue, coverage);
    if (!mounted ||
        _leaving ||
        _session.step != PracticeStep.result ||
        _completionReported) {
      return;
    }
    _completionReported = true;
    try {
      await widget.onCompleted();
    } on Object {
      // A preference failure must not trap the user after a successful lesson.
    }
  }

  Future<void> _leave([VoidCallback? destination]) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await _session.close();
    if (mounted) (destination ?? widget.onExit)();
  }

  Future<void> _restart() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    final old = _session;
    old.removeListener(_changed);
    await old.close();
    if (!mounted) return;
    setState(() {
      _session = PracticeSession()..addListener(_changed);
      _setup = null;
      _completionReported = false;
      _leaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final practice = PracticePresentation(
      step: _session.step,
      onExit: () => unawaited(_leave()),
    );
    final detail = _session.result;
    final scoring = _session.controller;
    final Widget page;
    if (detail != null) {
      page = MatchSummaryPage(
        detail: detail,
        analytics: MatchAnalyticsCalculator().calculate(
          detail.events,
          trackingCoverage: detail.match.trackingCoverage,
          shotLocations: detail.shotLocations,
        ),
        practice: practice,
        busy: _leaving,
        onBack: () => unawaited(_leave()),
        onRematch: () => unawaited(_restart()),
        onPracticeStartReal: widget.onReturnMatch == null
            ? () => unawaited(_leave(widget.onStartReal))
            : null,
        onPracticeReturnMatch: widget.onReturnMatch == null
            ? null
            : () => unawaited(_leave(widget.onReturnMatch)),
        onReplay: () {},
        onShare: () {},
        onCorrectCoverage: () {},
        onSavePlayer: (_) {},
      );
    } else if (scoring != null) {
      page = ScoringPage(
        controller: scoring,
        practice: practice,
        onRequestLeave: _leave,
        onFinishWithCoverage: _finish,
      );
    } else if (_session.error != null) {
      page = Scaffold(
        appBar: AppBar(title: Text(l10n.practiceTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.practiceLoadFailed),
              FilledButton(
                onPressed: _session.busy
                    ? null
                    : () => unawaited(_start(_setup!)),
                child: Text(l10n.practiceRetry),
              ),
              TextButton(
                onPressed: () => unawaited(_leave()),
                child: Text(l10n.practiceExit),
              ),
            ],
          ),
        ),
      );
    } else {
      page = PregamePage(
        practice: practice,
        onStartMatch: _start,
        onCancel: () => unawaited(_leave()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: OrientationShell(
        mode: scoring != null && detail == null
            ? HoopitoOrientationMode.landscapeRequired
            : HoopitoOrientationMode.portraitFriendly,
        child: AbsorbPointer(absorbing: _leaving, child: page),
      ),
    );
  }
}

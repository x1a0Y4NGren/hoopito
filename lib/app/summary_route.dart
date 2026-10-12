import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/design_system/recording_confirmation.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/match_view_data_mapper.dart';
import 'package:hoopito/app/route_status.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

class SummaryRoute extends ConsumerStatefulWidget {
  const SummaryRoute({super.key, required this.matchId});
  final String matchId;
  @override
  ConsumerState<SummaryRoute> createState() => SummaryRouteState();
}

class SummaryRouteState extends ConsumerState<SummaryRoute> {
  bool _busy = false;
  bool _choosingPlayer = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ref
        .watch(liveMatchProvider(widget.matchId))
        .when(
          loading: () => const RouteLoading(),
          error: (error, stack) => RouteMessage(
            title: l10n.routeMatchLoadError,
            message: l10n.actionFailedRetry,
            onHome: _back,
            homeLabel: l10n.replayHistory,
            onRetry: () => ref.invalidate(liveMatchProvider(widget.matchId)),
          ),
          data: (detail) {
            if (detail == null) {
              return RouteMessage(
                title: l10n.routeReplayNotFound,
                message: l10n.routeReplayNotFoundBody,
                onHome: _back,
                homeLabel: l10n.replayHistory,
              );
            }
            if (detail.match.lifecycle != MatchLifecycle.finished &&
                detail.match.lifecycle != MatchLifecycle.archived) {
              return RouteMessage(
                title: detail.match.lifecycle == MatchLifecycle.active
                    ? l10n.routeActiveMatchTitle
                    : l10n.v2AbandonedMatch,
                message: detail.match.lifecycle == MatchLifecycle.active
                    ? l10n.homeActiveMatch
                    : l10n.v2AbandonedMatchHelp,
                onHome: _back,
                homeLabel: l10n.replayHistory,
                replayLabel: detail.match.lifecycle == MatchLifecycle.active
                    ? l10n.continueMatch
                    : null,
                onReplay: () => context.replace(
                  detail.match.lifecycle == MatchLifecycle.active
                      ? '/scoring/${widget.matchId}'
                      : '/matches/${widget.matchId}/replay',
                ),
              );
            }
            final data = replayDataFromDetail(detail);
            return MatchSummaryPage(
              detail: detail,
              analytics: data.analytics!,
              busy: _busy || _choosingPlayer,
              onBack: _back,
              onRematch: () => context.push(
                '/pregame',
                extra: MatchSetupPreset.fromMatchDetail(detail),
              ),
              onReplay: () => context.push('/matches/${widget.matchId}/replay'),
              onShare: () => unawaited(_share(detail)),
              onCorrectCoverage: () => unawaited(_correctCoverage(detail)),
              onSavePlayer: (participantId) =>
                  unawaited(_linkPlayer(detail, participantId)),
            );
          },
        );
  }

  void _back() => context.canPop() ? context.pop() : context.go('/history');

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } on Object {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.actionFailedRetry),
            action: SnackBarAction(
              label: l10n.v2Retry,
              onPressed: () => unawaited(_run(operation)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(MatchDetail detail) async {
    final controller = ReplayController(data: replayDataFromDetail(detail));
    try {
      await showMatchReportDialog(
        context,
        controller: controller,
        onShare: (bytes, matchId) => ref
            .read(exportCoordinatorProvider)
            .shareReplayImage(
              bytes,
              matchId: matchId,
              subject: AppLocalizations.of(context)!.exportReplaySubject,
            ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _correctCoverage(MatchDetail detail) async {
    final l10n = AppLocalizations.of(context)!;
    final coverage = await confirmRecordingCoverage(
      context,
      title: l10n.v2CorrectCoverage,
      confirmLabel: l10n.v2CorrectCoverage,
      initial: detail.match.trackingCoverage,
    );
    if (coverage == null || !mounted) return;
    final command = SetTrackingCoverageCommand(
      matchId: detail.match.id,
      trackingCoverage: coverage,
      reason: l10n.v2CoverageReason,
    );
    await _run(() async {
      await ref.read(matchCommandServiceProvider).setTrackingCoverage(command);
    });
  }

  Future<void> _linkPlayer(MatchDetail detail, String participantId) async {
    if (_busy || _choosingPlayer) return;
    setState(() => _choosingPlayer = true);
    try {
      await _selectAndLinkPlayer(detail, participantId);
    } on Object {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.actionFailedRetry),
            action: SnackBarAction(
              label: l10n.v2Retry,
              onPressed: () => unawaited(_linkPlayer(detail, participantId)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _choosingPlayer = false);
    }
  }

  Future<void> _selectAndLinkPlayer(
    MatchDetail detail,
    String participantId,
  ) async {
    final participant = detail.match.participants.firstWhere(
      (p) => p.id == participantId,
    );
    final excluded = detail.match.participants
        .map((p) => p.playerId)
        .whereType<String>()
        .toSet();
    final profiles = (await ref.read(playerRepositoryProvider).watchAll().first)
        .where((p) => !excluded.contains(p.id))
        .toList();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(
      text: participant.nameSnapshot,
    );
    final route = DialogRoute<({String? playerId, String? nickname})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.v2SavePlayer),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(participant.nameSnapshot),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l10n.playerNicknameLabel,
                ),
              ),
              FilledButton(
                onPressed: () {
                  final nickname = nameController.text.trim();
                  if (nickname.isNotEmpty) {
                    Navigator.pop(dialogContext, (
                      playerId: null,
                      nickname: nickname,
                    ));
                  }
                },
                child: Text(l10n.v2CreatePlayer),
              ),
              if (profiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.v2SelectPlayer),
                SizedBox(
                  height: 192,
                  child: ListView(
                    children: [
                      for (final player in profiles)
                        ListTile(
                          title: Text(player.nickname),
                          onTap: () => Navigator.pop(dialogContext, (
                            playerId: player.id,
                            nickname: null,
                          )),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelAction),
          ),
        ],
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    nameController.dispose();
    if (result == null || !mounted) return;
    final playerId = result.playerId ?? const Uuid().v4();
    final newPlayer = result.nickname == null
        ? null
        : Player(
            id: playerId,
            nickname: result.nickname!,
            createdAt: DateTime.now().toUtc(),
          );
    final command = LinkMatchParticipantCommand(
      matchId: detail.match.id,
      participantId: participantId,
      playerProfileId: playerId,
    );
    await _run(() async {
      await ref.read(appDatabaseProvider).transaction(() async {
        if (newPlayer != null) {
          await ref.read(playerRepositoryProvider).save(newPlayer);
        }
        await ref.read(matchCommandServiceProvider).linkParticipant(command);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.v2PlayerSaved)));
      }
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/players/player_career_page.dart';
import 'package:hoopito/features/players/player_comparison_page.dart';
import 'package:hoopito/features/players/player_editor_page.dart';
import 'package:hoopito/features/players/player_list_page.dart';

List<RouteBase> buildPlayerRoutes() => [
  GoRoute(
    path: '/players',
    builder: (context, state) => Consumer(
      builder: (context, ref, child) => PlayerListPage(
        repository: ref.watch(playerRepositoryProvider),
        onCreate: () => context.push('/players/new'),
        onEdit: (player) => context.push('/players/${player.id}/edit'),
        onViewAnalytics: (player) =>
            context.push('/players/${player.id}/analytics'),
      ),
    ),
  ),
  GoRoute(
    path: '/players/new',
    builder: (context, state) => Consumer(
      builder: (context, ref, child) => PlayerEditorPage(
        repository: ref.watch(playerRepositoryProvider),
        onSaved: () => context.pop(),
      ),
    ),
  ),
  GoRoute(
    path: '/players/:playerId/edit',
    builder: (context, state) => Consumer(
      builder: (context, ref, child) => PlayerEditorPage(
        repository: ref.watch(playerRepositoryProvider),
        playerId: state.pathParameters['playerId']!,
        onSaved: () => context.pop(),
        onDeleted: () => context.pop(),
      ),
    ),
  ),
  GoRoute(
    path: '/players/:playerId/analytics',
    builder: (context, state) => _PlayerProfileRoute(
      playerId: state.pathParameters['playerId']!,
      builder: (context, ref, playerId, player, opponents) => PlayerCareerPage(
        controller: ref.watch(playerCareerControllerProvider(playerId)),
        player: player,
        opponents: opponents,
        onBack: () => context.canPop() ? context.pop() : context.go('/players'),
        onEdit: () => context.push('/players/$playerId/edit'),
        onMatchTap: (matchId) => context.push('/matches/$matchId/summary'),
        onCompare: () => context.push('/players/$playerId/analytics/compare'),
      ),
    ),
  ),
  GoRoute(
    path: '/players/:playerId/analytics/compare',
    builder: (context, state) => _PlayerProfileRoute(
      playerId: state.pathParameters['playerId']!,
      builder: (context, ref, playerId, player, opponents) =>
          PlayerComparisonPage(
            controller: ref.watch(playerComparisonControllerProvider(playerId)),
            player: player,
          ),
    ),
  ),
];

typedef _PlayerProfileBuilder =
    Widget Function(
      BuildContext context,
      WidgetRef ref,
      String playerId,
      Player player,
      List<Player> opponents,
    );

class _PlayerProfileRoute extends ConsumerWidget {
  const _PlayerProfileRoute({required this.playerId, required this.builder});

  final String playerId;
  final _PlayerProfileBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = _l10n(context);
    final players = ref.watch(playerProfilesProvider);
    return players.when(
      loading: () => const _PlayerRouteLoading(),
      error: (error, stackTrace) => _PlayerRouteMessage(
        title: l10n.playerAnalyticsLoadError,
        message: l10n.actionFailedRetry,
        actionLabel: l10n.playerAnalyticsRetry,
        onAction: () => ref.invalidate(playerProfilesProvider),
      ),
      data: (values) {
        final player = values
            .where((value) => value.id == playerId)
            .firstOrNull;
        if (player == null) {
          return _PlayerRouteMessage(
            title: l10n.playerAnalyticsNotFound,
            message: l10n.playerAnalyticsNotFoundBody,
          );
        }
        return builder(
          context,
          ref,
          playerId,
          player,
          values.where((value) => value.id != playerId).toList(growable: false),
        );
      },
    );
  }
}

class _PlayerRouteLoading extends StatelessWidget {
  const _PlayerRouteLoading();

  @override
  Widget build(BuildContext context) =>
      const EditorialScaffold(body: Center(child: CircularProgressIndicator()));
}

class _PlayerRouteMessage extends StatelessWidget {
  const _PlayerRouteMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => EditorialScaffold(
    body: Center(
      child: EditorialErrorState(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    ),
  );
}

AppLocalizations _l10n(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsZh();

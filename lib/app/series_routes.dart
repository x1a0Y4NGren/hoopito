import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/route_status.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/pregame/start_match_mapper.dart';
import 'package:hoopito/features/series/series_detail_page.dart';

final _seriesNextIntentsProvider = Provider<Map<String, StartMatchCommand>>(
  (ref) => {},
);
final _seriesLifecycleIntentsProvider = Provider<Map<String, String>>(
  (ref) => {},
);
Future<StartMatchCommand> seriesNextIntent(
  WidgetRef ref,
  MatchSeries series,
) async {
  final intents = ref.read(_seriesNextIntentsProvider);
  final key = '${series.id}:${series.revision}:${series.nextGameNumber}';
  return intents[key] ??= await prepareSeriesNextForSnapshot(
    ref.read(seriesRepositoryProvider),
    series,
  );
}

Future<StartMatchCommand> prepareSeriesNextForSnapshot(
  MatchSeriesRepository repository,
  MatchSeries series,
) async {
  final command = await repository.prepareNext(series.id);
  final context = command.seriesContext;
  if (context == null ||
      context.seriesId != series.id ||
      context.expectedRevision != series.revision ||
      context.gameNumber != series.nextGameNumber) {
    throw const SeriesFailure('stale');
  }
  return command;
}

String seriesLifecycleIntent(
  WidgetRef ref,
  MatchSeries series,
  String action,
) => ref
    .read(_seriesLifecycleIntentsProvider)
    .putIfAbsent(
      '${series.id}:${series.revision}:$action',
      () => const Uuid().v4(),
    );

final seriesRepositoryProvider = Provider(
  (ref) => MatchSeriesRepository(ref.watch(appDatabaseProvider)),
);
final openSeriesProvider = StreamProvider(
  (ref) => ref.watch(seriesRepositoryProvider).watchOpenSeries(),
);
final seriesListProvider = StreamProvider(
  (ref) => ref.watch(seriesRepositoryProvider).watchSeriesList(),
);
final seriesProvider = StreamProvider.family<MatchSeries?, String>(
  (ref, id) => ref.watch(seriesRepositoryProvider).watchSeries(id),
);
final matchSeriesProvider = Provider.family<AsyncValue<MatchSeries?>, String>(
  (ref, id) => ref
      .watch(seriesListProvider)
      .whenData(
        (list) =>
            list.where((s) => s.games.any((g) => g.matchId == id)).firstOrNull,
      ),
);

class SeriesRoute extends ConsumerStatefulWidget {
  const SeriesRoute({super.key, required this.id});
  final String id;
  @override
  ConsumerState<SeriesRoute> createState() => _SeriesRouteState();
}

class _SeriesRouteState extends ConsumerState<SeriesRoute> {
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (error is SeriesFailure && error.reason == 'stale') {
        ref.invalidate(seriesListProvider);
        ref.invalidate(openSeriesProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.actionFailedRetry),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final activeState = ref.watch(activeMatchProvider);
    final openState = ref.watch(openSeriesProvider);
    final page = ref
        .watch(seriesProvider(widget.id))
        .when(
          loading: () => const RouteLoading(),
          error: (e, s) => RouteMessage(
            title: l.seriesLoadError,
            message: l.actionFailedRetry,
            onRetry: () => ref.invalidate(seriesProvider(widget.id)),
          ),
          data: (series) {
            if (series == null) {
              return RouteMessage(
                title: l.seriesLoadError,
                message: l.actionFailedRetry,
              );
            }
            final settled =
                !activeState.isLoading &&
                !activeState.hasError &&
                activeState.hasValue &&
                !openState.isLoading &&
                !openState.hasError &&
                openState.hasValue;
            final active = activeState.valueOrNull;
            final canStart = settled && active == null;
            return SeriesDetailPage(
              series: series,
              busy: busy || !settled,
              activeMatchId: active?.match.id,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/history'),
              onMatch: (id) => context.push(
                active?.match.id == id
                    ? '/scoring/$id'
                    : '/matches/$id/summary',
              ),
              onNext: canStart
                  ? () => run(() async {
                      final command = await seriesNextIntent(ref, series);
                      await ref
                          .read(matchCommandServiceProvider)
                          .start(command);
                      if (context.mounted) {
                        context.push('/scoring/${command.matchId}');
                      }
                    })
                  : null,
              onSettings: canStart
                  ? () => context.push('/series/${series.id}/next')
                  : null,
              onClose: canStart
                  ? () => run(() async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(l.seriesClose),
                          content: Text(l.seriesCloseBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(l.cancelAction),
                            ),
                            FilledButton(
                              key: const Key('series-close-confirm'),
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(l.seriesClose),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(seriesRepositoryProvider)
                            .close(
                              seriesId: series.id,
                              expectedRevision: series.revision,
                              intentId: seriesLifecycleIntent(
                                ref,
                                series,
                                'close',
                              ),
                            );
                      }
                    })
                  : null,
              onReopen: canStart && openState.valueOrNull == null
                  ? () => run(
                      () => ref
                          .read(seriesRepositoryProvider)
                          .reopen(
                            seriesId: series.id,
                            expectedRevision: series.revision,
                            intentId: seriesLifecycleIntent(
                              ref,
                              series,
                              'reopen',
                            ),
                          ),
                    )
                  : null,
            );
          },
        );
    return PopScope<void>(
      canPop: ModalRoute.canPopOf(context) ?? false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/history');
      },
      child: page,
    );
  }
}

final _nextCommandProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(seriesRepositoryProvider).prepareNext(id),
);

class SeriesNextRoute extends ConsumerStatefulWidget {
  const SeriesNextRoute({super.key, required this.id});
  final String id;
  @override
  ConsumerState<SeriesNextRoute> createState() => _SeriesNextRouteState();
}

class _SeriesNextRouteState extends ConsumerState<SeriesNextRoute> {
  bool swapped = false;
  final Map<String, StartMatchCommand> pendingStarts = {};
  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeMatchProvider);
    if (active.isLoading) return const RouteLoading();
    if (active.hasError || active.valueOrNull != null) {
      return RouteMessage(
        title: AppLocalizations.of(context)!.routeActiveMatchTitle,
        message: AppLocalizations.of(context)!.seriesActiveHelp,
        onHome: () => context.go('/'),
      );
    }
    final players = ref.watch(playerProfilesProvider);
    if (players.isLoading) return const RouteLoading();
    if (players.hasError) {
      return RouteMessage(
        title: AppLocalizations.of(context)!.pregamePlayersError,
        message: AppLocalizations.of(context)!.actionFailedRetry,
        onRetry: () => ref.invalidate(playerProfilesProvider),
      );
    }
    return ref
        .watch(_nextCommandProvider(widget.id))
        .when(
          loading: () => const RouteLoading(),
          error: (e, s) => RouteMessage(
            title: AppLocalizations.of(context)!.seriesLoadError,
            message: AppLocalizations.of(context)!.actionFailedRetry,
          ),
          data: (command) => PregamePage(
            lockedPair: true,
            initialPreset: MatchSetupPreset(
              red: SetupParticipantPreset(
                nameSnapshot: command.redName,
                playerId: command.redPlayerProfileId,
              ),
              blue: SetupParticipantPreset(
                nameSnapshot: command.blueName,
                playerId: command.bluePlayerProfileId,
              ),
              rules: command.ruleTemplate,
              timerEnabled: command.timerEnabled,
              clockMode: command.clockMode,
              timeLimitMinutes: (command.regulationSeconds ?? 600) ~/ 60,
            ),
            players: players.valueOrNull ?? const [],
            onSwapSides: () => swapped = !swapped,
            onCancel: () => context.pop(),
            onStartMatch: (setup) async {
              final c = command.seriesContext!;
              final side = swapped
                  ? (c.slotASide == TeamSide.red ? TeamSide.blue : TeamSide.red)
                  : c.slotASide;
              await ref
                  .read(matchCommandServiceProvider)
                  .start(
                    pendingStarts.putIfAbsent(
                      setup.matchId,
                      () => buildStartMatchCommand(
                        setup,
                        seriesContext: SeriesStartContext(
                          seriesId: c.seriesId,
                          expectedRevision: c.expectedRevision,
                          gameNumber: c.gameNumber,
                          slotASide: side,
                        ),
                      ),
                    ),
                  );
              if (context.mounted) {
                context.pushReplacement('/scoring/${setup.matchId}');
              }
            },
          ),
        );
  }
}

class SeriesSummaryPanel extends ConsumerStatefulWidget {
  const SeriesSummaryPanel({super.key, required this.series});
  final MatchSeries series;
  @override
  ConsumerState<SeriesSummaryPanel> createState() => _SeriesSummaryPanelState();
}

class _SeriesSummaryPanelState extends ConsumerState<SeriesSummaryPanel> {
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (error is SeriesFailure && error.reason == 'stale') {
        ref.invalidate(seriesListProvider);
        ref.invalidate(openSeriesProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.actionFailedRetry),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = widget.series;
    final active = ref.watch(activeMatchProvider);
    final canStart =
        !busy &&
        active.hasValue &&
        !active.isLoading &&
        !active.hasError &&
        active.valueOrNull == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeriesOverview(
          series: s,
          onOpen: () => context.push('/series/${s.id}'),
        ),
        if (s.isOpen)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('summary-series-next'),
                onPressed: canStart
                    ? () => run(() async {
                        final command = await seriesNextIntent(ref, s);
                        await ref
                            .read(matchCommandServiceProvider)
                            .start(command);
                        if (context.mounted) {
                          context.push('/scoring/${command.matchId}');
                        }
                      })
                    : null,
                child: Text(l.seriesNext),
              ),
              OutlinedButton(
                key: const Key('summary-series-settings'),
                onPressed: canStart
                    ? () => context.push('/series/${s.id}/next')
                    : null,
                child: Text(l.seriesNextSettings),
              ),
              OutlinedButton(
                key: const Key('summary-series-close'),
                onPressed: canStart
                    ? () => run(() async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(l.seriesClose),
                            content: Text(l.seriesCloseBody),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text(l.cancelAction),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                key: const Key('series-close-confirm'),
                                child: Text(l.seriesClose),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(seriesRepositoryProvider)
                              .close(
                                seriesId: s.id,
                                expectedRevision: s.revision,
                                intentId: seriesLifecycleIntent(
                                  ref,
                                  s,
                                  'close',
                                ),
                              );
                          if (context.mounted) {
                            context.go('/series/${s.id}');
                          }
                        }
                      })
                    : null,
                child: Text(l.seriesClose),
              ),
            ],
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';

class SeriesOverview extends StatelessWidget {
  const SeriesOverview({super.key, required this.series, this.onOpen});
  final MatchSeries series;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final outcome = series.completedGames == 0
        ? l.seriesNoGames
        : series.isOpen
        ? l.seriesOpen
        : series.slotAWins == series.slotBWins
        ? l.historyDraw
        : l.summaryWinner(
            series.slotAWins > series.slotBWins
                ? series.slotAName
                : series.slotBName,
          );
    return InkWell(
      key: ValueKey('series-${series.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${series.slotAName} · ${series.slotBName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.isOpen ? l.seriesOpen : l.seriesClosed,
                    key: const Key('series-status'),
                  ),
                  if (outcome !=
                      (series.isOpen ? l.seriesOpen : l.seriesClosed))
                    Text(outcome, key: const Key('series-outcome')),
                  const SizedBox(height: 4),
                  Text(
                    '${l.seriesWins} ${series.slotAWins} : ${series.slotBWins} · ${l.seriesDraws} ${series.draws}',
                  ),
                ],
              ),
            ),
            if (onOpen != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class SeriesDetailPage extends StatelessWidget {
  const SeriesDetailPage({
    super.key,
    required this.series,
    required this.onBack,
    required this.onMatch,
    this.onNext,
    this.onSettings,
    this.onClose,
    this.onReopen,
    this.activeMatchId,
    this.busy = false,
  });
  final MatchSeries series;
  final VoidCallback onBack;
  final ValueChanged<String> onMatch;
  final VoidCallback? onNext, onSettings, onClose, onReopen;
  final String? activeMatchId;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return EditorialScaffold(
      maxContentWidth: 800,
      masthead: EditorialMasthead(
        title: l.seriesTitle,
        compact: true,
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: l.historyHomeTooltip,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SeriesOverview(series: series),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (activeMatchId != null)
                  FilledButton(
                    key: const Key('series-resume'),
                    onPressed: busy ? null : () => onMatch(activeMatchId!),
                    child: Text(l.continueMatch),
                  ),
                if (series.isOpen && activeMatchId == null) ...[
                  FilledButton(
                    key: const Key('series-next'),
                    onPressed: busy ? null : onNext,
                    child: Text(l.seriesNext),
                  ),
                  OutlinedButton(
                    key: const Key('series-settings'),
                    onPressed: busy ? null : onSettings,
                    child: Text(l.seriesNextSettings),
                  ),
                ],
                if (series.isOpen)
                  OutlinedButton(
                    key: const Key('series-close'),
                    onPressed: busy || activeMatchId != null ? null : onClose,
                    child: Text(l.seriesClose),
                  ),
                if (!series.isOpen)
                  OutlinedButton(
                    key: const Key('series-reopen'),
                    onPressed: busy ? null : onReopen,
                    child: Text(l.seriesReopen),
                  ),
              ],
            ),
            if (activeMatchId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.seriesActiveHelp),
              ),
            const SizedBox(height: 24),
            EditorialSectionRule(label: l.seriesGames),
            for (final g in series.games.reversed)
              ListTile(
                key: ValueKey('series-game-${g.gameNumber}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '#${g.gameNumber}  ${g.detail.match.redName} ${g.detail.redScore} : ${g.detail.blueScore} ${g.detail.match.blueName}',
                ),
                subtitle: Text(
                  g.detail.match.lifecycle == MatchLifecycle.abandoned
                      ? l.v2AbandonedMatch
                      : g.detail.match.lifecycle == MatchLifecycle.active
                      ? l.seriesOpen
                      : l.summaryGameFinished,
                ),
                onTap: () => onMatch(g.matchId),
                trailing: const Icon(Icons.chevron_right),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_history_entry.dart';

const homeResumeCardKey = Key('home-resume-card');
const homeResumeKey = Key('home-resume');
const homeStartScoringKey = Key('home-start-scoring');
const homeAbandonKey = Key('active-abandon');
const homeHistoryShortcutKey = Key('home-history-shortcut');
const homePlayersShortcutKey = Key('home-players-shortcut');
const homeRulesShortcutKey = Key('home-rules-shortcut');
const homeSettingsShortcutKey = Key('home-settings-shortcut');

/// Retained for source compatibility. Project details now live under Settings.
const homeProjectShortcutKey = Key('home-project-shortcut');

class HomePage extends StatelessWidget {
  const HomePage({
    required this.activeMatch,
    required this.onStartScoring,
    required this.onContinue,
    required this.onAbandon,
    required this.onOpenHistory,
    required this.onOpenPlayers,
    required this.onOpenRules,
    required this.onOpenSettings,
    required this.onOpenProject,
    this.latestFinishedMatch,
    this.recentMatches = const [],
    this.onRecentMatchTap,
    this.onRecentPreset,
    this.showDirectory = true,
    super.key,
  });

  final MatchDetail? activeMatch;
  final MatchDetail? latestFinishedMatch;
  final List<MatchHistoryEntry> recentMatches;
  final ValueChanged<String>? onRecentMatchTap;
  final VoidCallback? onRecentPreset;
  final bool showDirectory;
  final VoidCallback onStartScoring;
  final VoidCallback onContinue;
  final Future<void> Function() onAbandon;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenPlayers;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenSettings;

  /// Kept until the router moves the old project route under Settings/About.
  final VoidCallback onOpenProject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return EditorialScaffold(
      maxContentWidth: 920,
      masthead: EditorialMasthead(
        title: showDirectory ? l10n.appName.toUpperCase() : l10n.v2Matches,
        compact: !showDirectory,
      ),
      body: SingleChildScrollView(
        key: const PageStorageKey('home-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeHero(
              detail: activeMatch,
              onStartScoring: onStartScoring,
              onContinue: onContinue,
              onAbandon: onAbandon,
            ),
            if (onRecentPreset != null && activeMatch == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  key: const Key('home-recent-preset'),
                  onPressed: onRecentPreset,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.v2RecentPreset),
                ),
              ),
            if (recentMatches.isNotEmpty) ...[
              const SizedBox(height: HoopitoSpacing.section),
              EditorialSectionRule(label: l10n.v2RecentMatches),
              for (final match in recentMatches.take(3))
                MatchScoreRow(
                  key: ValueKey('home-result-${match.id}'),
                  blueTeamName: match.blueName,
                  blueScore: match.blueScore,
                  redTeamName: match.redName,
                  redScore: match.redScore,
                  contextLabel: match.ruleName,
                  onTap: onRecentMatchTap == null
                      ? null
                      : () => onRecentMatchTap!(match.id),
                ),
            ],
            if (latestFinishedMatch != null) ...[
              const SizedBox(height: HoopitoSpacing.section),
              EditorialSectionRule(label: l10n.historyTitle),
              KeyedSubtree(
                key: const Key('home-latest-result'),
                child: MatchScoreRow(
                  blueTeamName: latestFinishedMatch!.match.blueName,
                  blueScore: latestFinishedMatch!.blueScore,
                  redTeamName: latestFinishedMatch!.match.redName,
                  redScore: latestFinishedMatch!.redScore,
                  contextLabel: l10n.homeVersus,
                  onTap: onOpenHistory,
                ),
              ),
            ],
            const SizedBox(height: HoopitoSpacing.section),
            if (showDirectory)
              _HomeDirectory(
                onOpenHistory: onOpenHistory,
                onOpenPlayers: onOpenPlayers,
                onOpenRules: onOpenRules,
                onOpenSettings: onOpenSettings,
                l10n: l10n,
              ),
            const SizedBox(height: HoopitoSpacing.section),
          ],
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.detail,
    required this.onStartScoring,
    required this.onContinue,
    required this.onAbandon,
  });

  final MatchDetail? detail;
  final VoidCallback onStartScoring;
  final VoidCallback onContinue;
  final Future<void> Function() onAbandon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final editorial = editorialThemeOf(context);
    final active = detail;
    return Semantics(
      container: true,
      label: active == null ? l10n.startScoring : l10n.homeActiveMatch,
      child: Container(
        key: const Key('home-editorial-hero'),
        constraints: const BoxConstraints(minHeight: 288),
        color: editorial.inverseSurface,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                left: MediaQuery.sizeOf(context).width * 0.34,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: EditorialCourtLinesPainter(
                      color: editorial.canvas.withValues(alpha: 0.24),
                      strokeWidth: 1.4,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(HoopitoSpacing.section),
                child: active == null
                    ? _StartHero(onStartScoring: onStartScoring)
                    : _ActiveHero(
                        detail: active,
                        onContinue: onContinue,
                        onAbandon: onAbandon,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartHero extends StatelessWidget {
  const _StartHero({required this.onStartScoring});

  final VoidCallback onStartScoring;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final editorial = editorialThemeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.sports_basketball_outlined,
          size: 40,
          color: editorial.arenaAccent,
        ),
        const SizedBox(height: 18),
        Text(
          l10n.startScoring,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: editorial.canvas,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: homeStartScoringKey,
            onPressed: onStartScoring,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.startScoring),
          ),
        ),
      ],
    );
  }
}

class _ActiveHero extends StatelessWidget {
  const _ActiveHero({
    required this.detail,
    required this.onContinue,
    required this.onAbandon,
  });

  final MatchDetail detail;
  final VoidCallback onContinue;
  final Future<void> Function() onAbandon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final editorial = editorialThemeOf(context);
    final clock = detail.clock;
    final clockStatus = !detail.match.timerEnabled || clock == null
        ? l10n.homeClockNotConfigured
        : clock.isRegulationExpired
        ? l10n.homeClockRegulationExpired
        : clock.isRunning
        ? l10n.homeClockRunning
        : l10n.homeClockPaused;
    final persisted = detail.lastPersistedAt?.toLocal();
    final persistedLabel = persisted == null
        ? l10n.homeLastPersistedUnknown
        : l10n.homeLastPersisted(
            '${persisted.year}-${persisted.month.toString().padLeft(2, '0')}-'
            '${persisted.day.toString().padLeft(2, '0')} '
            '${persisted.hour.toString().padLeft(2, '0')}:'
            '${persisted.minute.toString().padLeft(2, '0')}',
          );
    return Column(
      key: homeResumeCardKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.homeActiveMatch.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: editorial.canvas,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _HeroTeamScore(
                name: detail.match.blueName,
                score: detail.blueScore,
                identityColor: editorial.inverseTeamBlue,
                identityKey: const Key('home-blue-identity-rule'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                l10n.homeVersus.toUpperCase(),
                style: TextStyle(color: editorial.canvas),
              ),
            ),
            Expanded(
              child: _HeroTeamScore(
                name: detail.match.redName,
                score: detail.redScore,
                identityColor: editorial.inverseTeamRed,
                identityKey: const Key('home-red-identity-rule'),
                alignEnd: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$clockStatus · $persistedLabel',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: editorial.canvas),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: homeResumeKey,
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.homeResumeMatch),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: homeAbandonKey,
          onPressed: () => _confirmAbandon(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: editorial.canvas,
            side: BorderSide(color: editorial.canvas),
          ),
          child: Text(l10n.homeAbandonMatch),
        ),
      ],
    );
  }

  Future<void> _confirmAbandon(BuildContext context) async {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.homeAbandonTitle),
        content: Text(l10n.homeAbandonBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.homeConfirmAbandon),
          ),
        ],
      ),
    );
    if (confirmed == true) await onAbandon();
  }
}

class _HeroTeamScore extends StatelessWidget {
  const _HeroTeamScore({
    required this.name,
    required this.score,
    required this.identityColor,
    required this.identityKey,
    this.alignEnd = false,
  });

  final String name;
  final int score;
  final Color identityColor;
  final Key identityKey;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final foreground = editorialThemeOf(context).canvas;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
        ScoreNumeral(value: score, color: foreground),
        const SizedBox(height: 4),
        Container(key: identityKey, width: 48, height: 4, color: identityColor),
      ],
    );
  }
}

class _HomeDirectory extends StatelessWidget {
  const _HomeDirectory({
    required this.onOpenHistory,
    required this.onOpenPlayers,
    required this.onOpenRules,
    required this.onOpenSettings,
    required this.l10n,
  });

  final VoidCallback onOpenHistory;
  final VoidCallback onOpenPlayers;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenSettings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionRule(label: l10n.replayHistory),
        EditorialIndexRow(
          key: homeHistoryShortcutKey,
          index: '01',
          title: l10n.replayHistory,
          semanticLabel: l10n.replayHistory,
          trailing: const _DirectoryIcon(icon: Icons.history),
          onTap: onOpenHistory,
        ),
        EditorialIndexRow(
          key: homePlayersShortcutKey,
          index: '02',
          title: l10n.playersTitle,
          semanticLabel: l10n.playersTitle,
          trailing: const _DirectoryIcon(icon: Icons.person_outline),
          onTap: onOpenPlayers,
        ),
        EditorialIndexRow(
          key: homeRulesShortcutKey,
          index: '03',
          title: l10n.rulesTitle,
          semanticLabel: l10n.rulesTitle,
          trailing: const _DirectoryIcon(icon: Icons.rule_outlined),
          onTap: onOpenRules,
        ),
        EditorialIndexRow(
          key: homeSettingsShortcutKey,
          index: '04',
          title: l10n.settings,
          semanticLabel: l10n.settings,
          trailing: const _DirectoryIcon(icon: Icons.settings_outlined),
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}

class _DirectoryIcon extends StatelessWidget {
  const _DirectoryIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, size: 20),
      ],
    );
  }
}

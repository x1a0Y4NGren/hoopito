import 'package:flutter/material.dart';

import 'package:hoopito/app/design_system/editorial_primitives.dart';
import 'package:hoopito/app/design_system/editorial_tokens.dart';

class ScoreNumeral extends StatelessWidget {
  const ScoreNumeral({
    required this.value,
    this.color,
    this.fontSize,
    this.semanticLabel,
    super.key,
  });

  final Object value;
  final Color? color;
  final double? fontSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final width = MediaQuery.sizeOf(context).width;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Text(
        '$value',
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          color: color ?? editorial.ink,
          fontFamily: HoopitoTypography.displayFamily,
          fontSize: fontSize ?? HoopitoTypography.scoreFor(width),
          fontWeight: FontWeight.w700,
          height: 0.9,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class MatchScoreRow extends StatelessWidget {
  const MatchScoreRow({
    required this.blueTeamName,
    required this.blueScore,
    required this.redTeamName,
    required this.redScore,
    this.contextLabel,
    this.onTap,
    super.key,
  });

  final String blueTeamName;
  final int blueScore;
  final String redTeamName;
  final int redScore;
  final String? contextLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 88),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: editorial.rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _TeamScore(
              name: blueTeamName,
              score: blueScore,
              color: editorial.teamBlue,
              alignEnd: false,
            ),
          ),
          if (contextLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                contextLabel!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: editorial.mutedInk,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          Expanded(
            child: _TeamScore(
              name: redTeamName,
              score: redScore,
              color: editorial.teamRed,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.name,
    required this.score,
    required this.color,
    required this.alignEnd,
  });

  final String name;
  final int score;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(width: 12, height: 3, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ScoreNumeral(value: score, color: color, fontSize: 40),
      ],
    );
  }
}

@immutable
class TeamActionRailItem {
  const TeamActionRailItem({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
}

class TeamActionRail extends StatelessWidget {
  const TeamActionRail({
    required this.teamLabel,
    required this.teamColor,
    required this.actions,
    this.axis = Axis.horizontal,
    super.key,
  });

  final String teamLabel;
  final Color teamColor;
  final List<TeamActionRailItem> actions;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final controls = actions.indexed
        .map((entry) {
          final (index, action) = entry;
          return ConstrainedBox(
            key: Key('team-action-$index'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton.icon(
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 20),
              label: Text(action.label),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: action.onPressed == null ? editorial.rule : teamColor,
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
    final actionLayout = controls.isEmpty
        ? const SizedBox.shrink()
        : axis == Axis.horizontal
        ? Wrap(spacing: 8, runSpacing: 8, children: controls)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                controls
                    .expand((item) => [item, const SizedBox(height: 8)])
                    .toList()
                  ..removeLast(),
          );
    return Semantics(
      container: true,
      label: teamLabel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: teamColor, width: 4)),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              teamLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: editorial.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            actionLayout,
          ],
        ),
      ),
    );
  }
}

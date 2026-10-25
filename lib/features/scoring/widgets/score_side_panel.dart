import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

class ScoreSidePanel extends StatelessWidget {
  const ScoreSidePanel({
    required this.side,
    required this.name,
    this.teamLabel,
    required this.score,
    required this.fouls,
    required this.onScore,
    required this.onMiss,
    this.scoreButtons = const [1, 2, 3],
    this.scoreEnabled = true,
    this.missEnabled = true,
    this.locationPoints,
    this.locationRemainingSeconds,
    this.locationRevealDuration = Duration.zero,
    this.reduceMotion = false,
    this.scoreButtonKeys,
    this.missButtonKey,
    this.foulStamp = false,
    this.foulStampVersion = 0,
    super.key,
  });

  final TeamSide side;
  final String name;
  final String? teamLabel;
  final int score;
  final int fouls;
  final ValueChanged<int> onScore;
  final VoidCallback onMiss;
  final List<int> scoreButtons;
  final bool scoreEnabled;
  final bool missEnabled;
  final int? locationPoints;
  final int? locationRemainingSeconds;
  final Duration locationRevealDuration;
  final bool reduceMotion;

  /// Optional geometry handles for the live scoring overlay. Public semantic
  /// ValueKeys remain on the actual buttons and are never replaced.
  final Map<int, GlobalKey>? scoreButtonKeys;
  final GlobalKey? missButtonKey;
  final bool foulStamp;
  final int foulStampVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final editorial = editorialThemeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final railSurface = dark ? editorial.surface : editorial.canvas;
    final buttonSurface = dark
        ? Color.alphaBlend(
            editorial.ink.withValues(alpha: 0.045),
            editorial.surface,
          )
        : editorial.surface;
    final color = teamColorForScheme(
      side,
      Theme.of(context).colorScheme,
      background: buttonSurface,
    );

    return Material(
      key: Key('${side.name}-action-rail'),
      color: railSurface,
      shape: side == TeamSide.blue
          ? Border(right: BorderSide(color: editorial.rule, width: 1))
          : Border(left: BorderSide(color: editorial.rule, width: 1)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 560;
          const buttonHeight = 48.0;

          if (compact) {
            final availableWidth = (constraints.maxWidth - 8).clamp(
              48.0,
              double.infinity,
            );
            final actionWidth = availableWidth;
            final actions = <Widget>[
              for (final points in scoreButtons)
                _ScoreAction(
                  side: side,
                  teamLabel: teamLabel ?? name,
                  points: points,
                  width: actionWidth,
                  height: buttonHeight,
                  color: color,
                  buttonSurface: buttonSurface,
                  ruleColor: editorial.rule,
                  compact: true,
                  enabled: scoreEnabled,
                  locationActive: locationPoints == points,
                  locationRemainingSeconds: locationPoints == points
                      ? locationRemainingSeconds
                      : null,
                  locationRevealDuration: locationRevealDuration,
                  reduceMotion: reduceMotion,
                  geometryKey: scoreButtonKeys?[points],
                  onPressed: () => onScore(points),
                ),
              _MissAction(
                side: side,
                teamLabel: teamLabel ?? name,
                width: actionWidth,
                height: buttonHeight,
                color: color,
                buttonSurface: buttonSurface,
                ruleColor: editorial.rule,
                compact: true,
                enabled: missEnabled,
                locationActive: locationPoints == 0,
                locationRemainingSeconds: locationPoints == 0
                    ? locationRemainingSeconds
                    : null,
                locationRevealDuration: locationRevealDuration,
                reduceMotion: reduceMotion,
                geometryKey: missButtonKey,
                onPressed: onMiss,
              ),
            ];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RailFoulSummary(
                    foulsLabel: '${l10n.scoringFoul} $fouls',
                    foulStamp: foulStamp,
                    foulStampVersion: foulStampVersion,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, actionConstraints) {
                        final requiredHeight =
                            actions.length * buttonHeight +
                            (actions.length - 1) * 4;
                        if (actionConstraints.maxHeight >= requiredHeight) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: actions,
                          );
                        }
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < actions.length;
                                index++
                              ) ...[
                                actions[index],
                                if (index < actions.length - 1)
                                  const SizedBox(height: 4),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: compact ? 6 : 8,
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (compact ? 12 : 16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RailFoulSummary(
                      foulsLabel: '${l10n.scoringFoul} $fouls',
                      foulStamp: foulStamp,
                      foulStampVersion: foulStampVersion,
                      reduceMotion: reduceMotion,
                    ),
                    for (final points in scoreButtons)
                      _ScoreAction(
                        side: side,
                        teamLabel: teamLabel ?? name,
                        points: points,
                        width: double.infinity,
                        height: buttonHeight,
                        color: color,
                        buttonSurface: buttonSurface,
                        ruleColor: editorial.rule,
                        compact: false,
                        enabled: scoreEnabled,
                        locationActive: locationPoints == points,
                        locationRemainingSeconds: locationPoints == points
                            ? locationRemainingSeconds
                            : null,
                        locationRevealDuration: locationRevealDuration,
                        reduceMotion: reduceMotion,
                        geometryKey: scoreButtonKeys?[points],
                        onPressed: () => onScore(points),
                      ),
                    _MissAction(
                      side: side,
                      teamLabel: teamLabel ?? name,
                      width: double.infinity,
                      height: buttonHeight,
                      color: color,
                      buttonSurface: buttonSurface,
                      ruleColor: editorial.rule,
                      compact: false,
                      enabled: missEnabled,
                      locationActive: locationPoints == 0,
                      locationRemainingSeconds: locationPoints == 0
                          ? locationRemainingSeconds
                          : null,
                      locationRevealDuration: locationRevealDuration,
                      reduceMotion: reduceMotion,
                      geometryKey: missButtonKey,
                      onPressed: onMiss,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MissAction extends StatelessWidget {
  const _MissAction({
    required this.side,
    required this.teamLabel,
    required this.width,
    required this.height,
    required this.color,
    required this.buttonSurface,
    required this.ruleColor,
    required this.compact,
    required this.enabled,
    required this.locationActive,
    required this.locationRemainingSeconds,
    required this.locationRevealDuration,
    required this.reduceMotion,
    required this.geometryKey,
    required this.onPressed,
  });

  final TeamSide side;
  final String teamLabel;
  final double width;
  final double height;
  final Color color;
  final Color buttonSurface;
  final Color ruleColor;
  final bool compact;
  final bool enabled;
  final bool locationActive;
  final int? locationRemainingSeconds;
  final Duration locationRevealDuration;
  final bool reduceMotion;
  final GlobalKey? geometryKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final remaining = locationRemainingSeconds;
    final semantic = locationActive && remaining != null
        ? l10n.scoringMissLocationPendingSemantics(remaining, teamLabel)
        : l10n.scoringMissSemantics(teamLabel);
    final label = _TeamActionLabel(
      side: side,
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.close, size: 17),
          const SizedBox(width: 4),
          _CompactActionLabel(l10n.scoringMissed),
          if (locationActive) ...[
            const SizedBox(width: 4),
            const Icon(Icons.location_on_outlined, size: 17),
            if (remaining != null) Text('$remaining'),
          ],
        ],
      ),
    );
    final button = SizedBox(
      key: geometryKey,
      width: width,
      height: height,
      child: Semantics(
        label: semantic,
        button: true,
        enabled: enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: OutlinedButton(
            key: Key('${side.name}-miss'),
            onPressed: enabled ? onPressed : null,
            style: _editorialRailButtonStyle(
              color,
              backgroundColor: buttonSurface,
              ruleColor: ruleColor,
              disabledColor: editorialThemeOf(context).mutedInk,
              height: height,
              padding: compact ? EdgeInsets.zero : null,
              emphasizedBorder: locationActive,
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: label),
          ),
        ),
      ),
    );
    if (!locationActive) return button;
    return AnimatedContainer(
      key: Key('${side.name}-miss-location-affordance'),
      duration: locationRevealDuration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      ),
      child: button,
    );
  }
}

class _ScoreAction extends StatefulWidget {
  const _ScoreAction({
    required this.side,
    required this.teamLabel,
    required this.points,
    required this.width,
    required this.height,
    required this.color,
    required this.buttonSurface,
    required this.ruleColor,
    required this.compact,
    required this.enabled,
    required this.locationActive,
    required this.locationRemainingSeconds,
    required this.locationRevealDuration,
    required this.reduceMotion,
    this.geometryKey,
    required this.onPressed,
  });

  final TeamSide side;
  final String teamLabel;
  final int points;
  final double width;
  final double height;
  final Color color;
  final Color buttonSurface;
  final Color ruleColor;
  final bool compact;
  final bool enabled;
  final bool locationActive;
  final int? locationRemainingSeconds;
  final Duration locationRevealDuration;
  final bool reduceMotion;
  final GlobalKey? geometryKey;
  final VoidCallback onPressed;

  @override
  State<_ScoreAction> createState() => _ScoreActionState();
}

class _ScoreActionState extends State<_ScoreAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final team = widget.teamLabel;
    final remaining = widget.locationRemainingSeconds;
    final disabledColor = editorialThemeOf(context).mutedInk;
    final semantic = widget.locationActive && remaining != null
        ? l10n.scoringLocationPendingSemantics(widget.points, remaining, team)
        : l10n.scoringScoreSemantics(widget.points, team);
    final label = _TeamActionLabel(
      side: widget.side,
      color: widget.color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('+${widget.points}'),
          if (widget.locationActive) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.location_on_outlined,
              key: Key('${widget.side.name}-score-${widget.points}-location'),
              size: 17,
            ),
            if (remaining != null) Text('$remaining'),
          ],
        ],
      ),
    );
    final button = SizedBox(
      key: widget.geometryKey,
      width: widget.width,
      height: widget.height,
      child: Semantics(
        label: semantic,
        button: true,
        enabled: widget.enabled,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.48,
          child: FilledButton(
            key: Key('${widget.side.name}-score-${widget.points}'),
            style: _editorialRailButtonStyle(
              widget.color,
              backgroundColor: widget.buttonSurface,
              ruleColor: widget.ruleColor,
              disabledColor: disabledColor,
              height: widget.height,
              padding: widget.compact ? EdgeInsets.zero : null,
              emphasizedBorder: widget.locationActive,
            ),
            onPressed: widget.enabled ? widget.onPressed : null,
            child: FittedBox(fit: BoxFit.scaleDown, child: label),
          ),
        ),
      ),
    );
    final feedback = Listener(
      onPointerDown: widget.enabled && !widget.reduceMotion
          ? (_) => setState(() => _pressed = true)
          : null,
      onPointerUp: widget.enabled && !widget.reduceMotion
          ? (_) => setState(() => _pressed = false)
          : null,
      onPointerCancel: widget.enabled && !widget.reduceMotion
          ? (_) => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration:
            Theme.of(context).extension<HoopitoMotionTheme>()?.press ??
            const Duration(milliseconds: 90),
        child: button,
      ),
    );
    if (!widget.locationActive) return feedback;
    return AnimatedContainer(
      key: Key(
        '${widget.side.name}-score-${widget.points}-location-affordance',
      ),
      duration: widget.locationRevealDuration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.locationActive
              ? widget.color.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: feedback,
    );
  }
}

ButtonStyle _editorialRailButtonStyle(
  Color color, {
  required Color backgroundColor,
  required Color ruleColor,
  required Color disabledColor,
  required double height,
  EdgeInsetsGeometry? padding,
  bool emphasizedBorder = false,
}) {
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(48, height)),
    padding: WidgetStatePropertyAll(
      padding ?? const EdgeInsets.symmetric(horizontal: 8),
    ),
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStatePropertyAll(backgroundColor),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)
          ? color.withValues(alpha: 0.1)
          : Colors.transparent,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? disabledColor : color,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? disabledColor
            : emphasizedBorder
            ? color
            : ruleColor,
        width: emphasizedBorder ? 2 : 1,
      ),
    ),
    shape: const WidgetStatePropertyAll(
      BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
    ),
  );
}

class _TeamActionLabel extends StatelessWidget {
  const _TeamActionLabel({
    required this.side,
    required this.color,
    required this.child,
  });

  final TeamSide side;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final identityLine = Container(
      key: Key('${side.name}-action-identity-line'),
      width: 3,
      height: 20,
      color: color,
    );
    final content = <Widget>[
      identityLine,
      const SizedBox(width: 8),
      Flexible(child: child),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: side == TeamSide.blue ? content : content.reversed.toList(),
    );
  }
}

class _CompactActionLabel extends StatelessWidget {
  const _CompactActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, softWrap: false),
    );
  }
}

class _RailFoulSummary extends StatelessWidget {
  const _RailFoulSummary({
    required this.foulsLabel,
    required this.foulStamp,
    required this.foulStampVersion,
    required this.reduceMotion,
  });

  final String foulsLabel;
  final bool foulStamp;
  final int foulStampVersion;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              foulsLabel,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: editorialThemeOf(context).mutedInk,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (foulStamp)
            Positioned(
              right: 0,
              child: _FoulStamp(
                key: ValueKey('foul-stamp-$foulStampVersion'),
                reduceMotion: reduceMotion,
              ),
            ),
        ],
      ),
    );
  }
}

class _FoulStamp extends StatelessWidget {
  const _FoulStamp({required this.reduceMotion, super.key});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final stamp = DecoratedBox(
      key: const Key('scoring-foul-stamp'),
      decoration: BoxDecoration(
        color: editorial.arenaAccent,
        border: Border.all(color: editorial.ink, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          '+1',
          style: TextStyle(
            color: const Color(0xFF101112),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
    if (reduceMotion) return IgnorePointer(child: stamp);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        duration:
            Theme.of(context).extension<HoopitoMotionTheme>()?.foulStamp ??
            const Duration(milliseconds: 180),
        tween: Tween(begin: 0.65, end: 1),
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          alignment: Alignment.topRight,
          child: child,
        ),
        child: stamp,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:hoopito/app/design_system/editorial_color_helpers.dart';
import 'package:hoopito/app/design_system/editorial_motion.dart';
import 'package:hoopito/app/design_system/editorial_theme.dart';
import 'package:hoopito/app/design_system/editorial_tokens.dart';

HoopitoEditorialTheme editorialThemeOf(BuildContext context) =>
    Theme.of(context).extension<HoopitoEditorialTheme>() ??
    (Theme.of(context).brightness == Brightness.dark
        ? const HoopitoEditorialTheme.dark()
        : const HoopitoEditorialTheme.light());

Duration editorialMotionDuration(
  BuildContext context, {
  required Duration standard,
  Duration reduced = Duration.zero,
}) {
  final media = MediaQuery.maybeOf(context);
  if (media?.disableAnimations == true) return Duration.zero;
  if (media?.accessibleNavigation == true) return reduced;
  return standard;
}

class EditorialSurface extends StatelessWidget {
  const EditorialSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? editorial.surface,
        border: Border.all(color: editorial.rule),
        borderRadius: borderRadius ?? BorderRadius.circular(HoopitoRadii.card),
      ),
      child: child,
    );
    if (semanticLabel == null) return content;
    return Semantics(container: true, label: semanticLabel, child: content);
  }
}

class EditorialFocusOutline extends StatelessWidget {
  const EditorialFocusOutline({
    required this.focused,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final bool focused;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final transparent = editorial.focus.withValues(alpha: 0);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(
                  color: focused
                      ? accessibleForegroundFor(editorial.focus)
                      : transparent,
                  width: 2,
                ),
                borderRadius: borderRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: focused ? editorial.focus : transparent,
                      width: 2,
                    ),
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EditorialTapTarget extends StatefulWidget {
  const EditorialTapTarget({
    required this.child,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? label;
  final String? tooltip;
  final bool enabled;

  @override
  State<EditorialTapTarget> createState() => _EditorialTapTargetState();
}

class _EditorialTapTargetState extends State<EditorialTapTarget> {
  bool _focused = false;
  bool _pressed = false;

  bool get _isEnabled => widget.enabled && widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_isEnabled || _pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final motion = Theme.of(context).extension<HoopitoMotionTheme>();
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: EditorialFocusOutline(
        focused: _focused,
        borderRadius: BorderRadius.circular(HoopitoRadii.control),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isEnabled ? widget.onPressed : null,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onFocusChange: (focused) => setState(() => _focused = focused),
            borderRadius: BorderRadius.circular(HoopitoRadii.control),
            focusColor: editorial.focus.withValues(alpha: 0.18),
            splashColor: editorial.arenaAccent.withValues(alpha: 0.14),
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1,
              duration: editorialMotionDuration(
                context,
                standard: motion?.press ?? const Duration(milliseconds: 90),
              ),
              curve: Curves.easeOut,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
    final semantics = Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.label,
      child: content,
    );
    if (widget.tooltip == null) return semantics;
    return Tooltip(message: widget.tooltip!, child: semantics);
  }
}

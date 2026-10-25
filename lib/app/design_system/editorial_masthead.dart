import 'package:flutter/material.dart';

import 'package:hoopito/app/design_system/editorial_primitives.dart';
import 'package:hoopito/app/design_system/editorial_tokens.dart';

class EditorialMasthead extends StatelessWidget {
  const EditorialMasthead({
    required this.title,
    this.eyebrow,
    this.leading,
    this.trailing,
    this.showRule = true,
    this.compact = false,
    this.textAlign,
    this.titleStyle,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final Widget? leading;
  final Widget? trailing;
  final bool showRule;
  final bool compact;
  final TextAlign? textAlign;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final useDisplayFamily = locale?.languageCode == 'en';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final style =
            (compact
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.displaySmall)
                ?.copyWith(
                  color: editorial.ink,
                  fontFamily: useDisplayFamily
                      ? HoopitoTypography.displayFamily
                      : null,
                  fontSize: compact
                      ? HoopitoTypography.title
                      : HoopitoTypography.mastheadFor(width),
                  fontWeight: FontWeight.w700,
                  height: compact ? 1.1 : 0.92,
                  letterSpacing: useDisplayFamily ? 0.3 : 0,
                )
                .merge(titleStyle);
        final titleWidget = Text(title, style: style, textAlign: textAlign);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: editorial.mutedInk,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(child: titleWidget),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            if (showRule) ...[
              const SizedBox(height: 12),
              EditorialSectionRule(color: editorial.ink),
            ],
          ],
        );
      },
    );
  }
}

class EditorialSectionRule extends StatelessWidget {
  const EditorialSectionRule({
    this.label,
    this.color,
    this.thickness = 1,
    super.key,
  });

  final String? label;
  final Color? color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final ruleColor = color ?? editorial.rule;
    final rule = Expanded(
      child: Divider(color: ruleColor, thickness: thickness),
    );
    if (label == null) return Row(children: [rule]);
    return Row(
      children: [
        Flexible(
          child: Text(
            label!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: editorial.mutedInk,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        rule,
      ],
    );
  }
}

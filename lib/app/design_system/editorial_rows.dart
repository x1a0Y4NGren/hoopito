import 'package:flutter/material.dart';

import 'package:hoopito/app/design_system/editorial_primitives.dart';

class EditorialIndexRow extends StatefulWidget {
  const EditorialIndexRow({
    required this.index,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String index;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<EditorialIndexRow> createState() => _EditorialIndexRowState();
}

class _EditorialIndexRowState extends State<EditorialIndexRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: EditorialFocusOutline(
        focused: _focused,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          focusColor: editorial.focus.withValues(alpha: 0.18),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: editorial.rule)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    widget.index,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: editorial.mutedInk,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: editorial.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: editorial.mutedInk),
                        ),
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 12),
                  widget.trailing!,
                ] else if (widget.onTap != null)
                  Icon(Icons.arrow_forward, color: editorial.ink, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.semanticLabel == null) return row;
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      excludeSemantics: true,
      child: row,
    );
  }
}

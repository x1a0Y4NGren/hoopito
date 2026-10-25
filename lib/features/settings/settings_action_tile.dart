import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';

/// A settings action with a visible and announced unavailable state.
class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final editorial = editorialThemeOf(context);
    final actionable = onTap != null;
    final tile = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: InkWell(
        onTap: enabled ? onTap : null,
        excludeFromSemantics: actionable,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: editorial.rule)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 48, child: Icon(icon)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: enabled ? editorial.ink : editorial.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: editorial.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionable) ...[
                const SizedBox(width: 8),
                SizedBox.square(
                  dimension: 48,
                  child: Icon(
                    enabled ? Icons.arrow_forward : Icons.block,
                    key: enabled ? null : const Key('setting-disabled-cue'),
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!actionable) return tile;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: '$title. $subtitle',
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: tile,
    );
  }
}

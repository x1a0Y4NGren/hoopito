import 'package:flutter/material.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/rules/scoring_convention.dart';

/// Match scoring meaning, independent of the target score and recording scope.
class ScoringConventionSettings extends StatelessWidget {
  const ScoringConventionSettings({
    required this.convention,
    required this.onChanged,
    required this.keyPrefix,
    this.allowLegacy = false,
    super.key,
  });

  final ScoringConvention? convention;
  final ValueChanged<ScoringConvention?> onChanged;
  final String keyPrefix;
  final bool allowLegacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final baskets =
        convention == ScoringConvention.onePerBasket ||
        convention == ScoringConvention.oneAndTwo;

    Widget choice(String id, String label, bool selected, VoidCallback onTap) {
      return Semantics(
        key: Key('$keyPrefix-scoring-$id'),
        selected: selected,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
          ),
          onPressed: onTap,
          child: Text(label),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.scoringMethodLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            choice(
              'standard',
              l10n.scoringMethodStandard,
              convention == ScoringConvention.standard,
              () => onChanged(ScoringConvention.standard),
            ),
            choice(
              'baskets',
              l10n.scoringMethodBaskets,
              baskets,
              () => onChanged(
                baskets ? convention : ScoringConvention.onePerBasket,
              ),
            ),
            if (allowLegacy)
              choice(
                'legacy',
                l10n.scoringMethodLegacy,
                convention == null,
                () => onChanged(null),
              ),
          ],
        ),
        if (baskets)
          SwitchListTile(
            key: Key('$keyPrefix-three-point-bonus'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.scoringThreePointCountsAsTwo),
            subtitle: Text(l10n.scoringThreePointCountsAsTwoHelp),
            value: convention == ScoringConvention.oneAndTwo,
            onChanged: (enabled) => onChanged(
              enabled
                  ? ScoringConvention.oneAndTwo
                  : ScoringConvention.onePerBasket,
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';

class PendingLocationBar extends StatelessWidget {
  const PendingLocationBar({
    required this.onConfirm,
    required this.onSkip,
    required this.onUndo,
    super.key,
  });

  final VoidCallback onConfirm;
  final VoidCallback onSkip;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('confirm-location'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onConfirm,
              icon: const Icon(Icons.check),
              label: Text(l10n.scoringConfirmLocation),
            ),
            OutlinedButton(
              key: const Key('cancel-location'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onSkip,
              child: Text(l10n.scoringSkipLocation),
            ),
            TextButton.icon(
              key: const Key('pending-location-undo'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
              label: Text(l10n.scoringUndo),
            ),
          ],
        ),
      ),
    );
  }
}

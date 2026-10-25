import 'package:flutter/material.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

/// One confirmation contract for scoring, replay and later corrections.
Future<TrackingCoverage?> confirmRecordingCoverage(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? scoreLine,
  String? draftNotice,
  TrackingCoverage initial = TrackingCoverage.scoresOnly,
  Key? cancelKey,
  Key? confirmKey,
}) {
  var complete = initial.index >= TrackingCoverage.shotAttempts.index;
  return showDialog<TrackingCoverage>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scoreLine != null) Text(scoreLine),
              if (draftNotice != null) Text(draftNotice),
              const SizedBox(height: 16),
              Text(
                l10n.v2CoverageTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SwitchListTile.adaptive(
                key: const Key('confirm-complete-recording'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  complete ? l10n.v2CoverageComplete : l10n.v2CoverageScores,
                ),
                value: complete,
                onChanged: (value) => setState(() => complete = value),
              ),
              Text(l10n.v2CoverageHelp),
            ],
          ),
          actions: [
            TextButton(
              key: cancelKey,
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancelAction),
            ),
            FilledButton(
              key: confirmKey,
              onPressed: () => Navigator.pop(
                dialogContext,
                complete
                    ? (initial.index > TrackingCoverage.shotAttempts.index
                          ? initial
                          : TrackingCoverage.shotAttempts)
                    : TrackingCoverage.scoresOnly,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}

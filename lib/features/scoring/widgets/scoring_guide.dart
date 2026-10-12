import 'package:flutter/material.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';

/// An inline hint, leaving both scoring rails available throughout.
class ScoringGuide extends StatefulWidget {
  const ScoringGuide({required this.onDismiss, super.key});
  final VoidCallback onDismiss;
  @override
  State<ScoringGuide> createState() => _ScoringGuideState();
}

class _ScoringGuideState extends State<ScoringGuide> {
  int _step = 0;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titles = [l10n.v2GuideScore, l10n.v2GuideLocation, l10n.v2GuideUndo];
    final bodies = [
      l10n.v2GuideScoreBody,
      l10n.v2GuideLocationBody,
      l10n.v2GuideUndoBody,
    ];
    return Card(
      key: const Key('scoring-guide'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_step + 1}/3 · ${titles[_step]}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(bodies[_step]),
                  ],
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  key: const Key('scoring-guide-skip'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: widget.onDismiss,
                  child: Text(l10n.v2GuideSkip),
                ),
                TextButton(
                  key: const Key('scoring-guide-next'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () =>
                      _step == 2 ? widget.onDismiss() : setState(() => _step++),
                  child: Text(_step == 2 ? l10n.v2GuideDone : l10n.v2GuideNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

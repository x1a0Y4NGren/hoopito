import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/design_system/recording_confirmation.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final initial in [TrackingCoverage.locations, TrackingCoverage.full]) {
      testWidgets(
        '${platform.name} confirmation preserves ${initial.name} unless explicitly downgraded',
        (tester) async {
          TrackingCoverage? result;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async =>
                        result = await confirmRecordingCoverage(
                          context,
                          title: 'Coverage',
                          confirmLabel: 'Save',
                          initial: initial,
                        ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          expect(result, initial);
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('confirm-complete-recording')));
          await tester.pump();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          expect(result, TrackingCoverage.scoresOnly);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

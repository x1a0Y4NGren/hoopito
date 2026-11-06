import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('practice keeps scoring geometry at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScoringController(matchId: 'geometry');
      Future<void> show({required bool practice}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHoopitoTheme(brightness: Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ScoringPage(
              controller: controller,
              practice: practice
                  ? PracticePresentation(
                      step: PracticeStep.scoreBlueTwo,
                      onExit: () {},
                    )
                  : null,
              onFinishWithCoverage: (_, _, _) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(practice: false);
      final ordinary = {
        for (final key in ['scoring-court', 'blue-score-2', 'scoring-finish'])
          key: tester.getRect(find.byKey(Key(key))),
      };
      await show(practice: true);
      for (final entry in ordinary.entries) {
        expect(
          tester.getRect(find.byKey(Key(entry.key))),
          entry.value,
          reason: '${entry.key} must retain the ordinary scoring geometry',
        );
      }
      expect(
        find.byKey(const Key('practice-exit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}

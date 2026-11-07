import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/practice/practice_coach.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final stage in ['controls', 'coverage']) {
        for (final large in [false, true]) {
          final variant = large ? 'large' : 'normal';
          final name =
              'practice_dialog_${stage}_${variant}_${language}_${brightness.name}';
          testWidgets(name, (tester) async {
            tester.view.physicalSize = large
                ? const Size(640, 360)
                : const Size(844, 390);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final controller = ScoringController(matchId: name);
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox());
              controller.dispose();
            });

            // Capture the Navigator's overlay as well as its page: a boundary
            // inside home would omit both the dialog and its local coach.
            await tester.pumpWidget(
              RepaintBoundary(
                key: const Key('practice-dialog-golden'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildHoopitoTheme(brightness: brightness),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                    child: child!,
                  ),
                  home: ScoringPage(
                    controller: controller,
                    practice: PracticePresentation(
                      step: PracticeStep.finish,
                      onExit: () {},
                    ),
                    onFinishWithCoverage: (_, _, _) async {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('scoring-finish')));
            await tester.pumpAndSettle();
            if (stage == 'coverage') {
              await tester.tap(find.byKey(const Key('match-controls-finish')));
              await tester.pumpAndSettle();
            }

            final dialog = find.byType(AlertDialog);
            expect(dialog, findsOneWidget);
            final localHost = find.ancestor(
              of: dialog,
              matching: find.byType(PracticeCoachHost),
            );
            expect(localHost, findsOneWidget);
            expect(find.byKey(const Key('practice-coach')), findsOneWidget);
            expect(
              find.descendant(
                of: localHost,
                matching: find.byKey(const Key('practice-coach')),
              ),
              findsOneWidget,
            );
            final exit = find.byKey(const Key('practice-exit'));
            expect(exit.hitTestable(), findsOneWidget);
            final exitSize = tester.getSize(exit);
            expect(exitSize.width, greaterThanOrEqualTo(48));
            expect(exitSize.height, greaterThanOrEqualTo(48));
            final finishKey = stage == 'coverage'
                ? 'scoring-finish-confirm'
                : 'match-controls-finish';
            final cancelKey = stage == 'coverage'
                ? 'scoring-finish-cancel'
                : 'match-controls-return';
            expect(find.byKey(Key(finishKey)).hitTestable(), findsOneWidget);
            expect(find.byKey(Key(cancelKey)).hitTestable(), findsOneWidget);
            if (stage == 'coverage') {
              expect(
                tester
                    .widget<SwitchListTile>(
                      find.byKey(const Key('confirm-complete-recording')),
                    )
                    .value,
                isFalse,
              );
            }
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(const Key('practice-dialog-golden')),
              matchesGoldenFile(hoopitoGoldenFile(name)),
            );
          });
        }
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  for (final language in ['zh', 'en']) {
    for (final size in [const Size(731, 411), const Size(844, 390)]) {
      testWidgets(
        'finish guidance uses available landscape space $language $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = ScoringController(matchId: 'dialog-space');
          controller.addScore(side: TeamSide.red, points: 2);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            controller.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHoopitoTheme(),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.symmetric(vertical: 24)),
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
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('scoring-finish')));
          await tester.pumpAndSettle();
          final controlsBubble = tester.getRect(
            find.byKey(const Key('practice-coach')),
          );
          final controlsDialog = tester.widget<AlertDialog>(
            find.byType(AlertDialog),
          );
          for (final text in [controlsDialog.title!, controlsDialog.content!]) {
            expect(
              controlsBubble.overlaps(tester.getRect(find.byWidget(text))),
              isFalse,
              reason: 'Guidance must leave the first confirmation readable',
            );
          }
          await tester.tap(find.byKey(const Key('match-controls-finish')));
          await tester.pumpAndSettle();

          // Enough space exists beside this real confirmation dialog. The
          // instruction must be readable immediately, without another tap.
          final hint = find.byKey(const Key('practice-coach-hint'));
          expect(hint, findsOneWidget);
          expect(find.byKey(const Key('practice-coach-toggle')), findsNothing);
          final bubble = tester.getRect(
            find.byKey(const Key('practice-coach')),
          );
          expect(bubble.contains(tester.getRect(hint).topLeft), isTrue);
          expect(bubble.contains(tester.getRect(hint).bottomRight), isTrue);
          for (final key in [
            'scoring-finish-confirm',
            'scoring-finish-cancel',
            'confirm-complete-recording',
          ]) {
            final control = find.byKey(Key(key));
            expect(control.hitTestable(), findsOneWidget);
            expect(bubble.overlaps(tester.getRect(control)), isFalse);
          }
          final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
          expect(
            bubble.overlaps(tester.getRect(find.byWidget(dialog.title!))),
            isFalse,
          );
          final exit = tester.getRect(find.byKey(const Key('practice-exit')));
          expect(exit.width, greaterThanOrEqualTo(48));
          expect(exit.height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

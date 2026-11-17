import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);
  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final scene in [
        'outside',
        'all_baskets',
        'inside_baskets',
        'free_throw',
      ]) {
        final name = 'scoring_region_${scene}_${language}_${brightness.name}';
        testWidgets(name, (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = scene == 'all_baskets'
              ? const Size(390, 844)
              : const Size(844, 390);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final convention = switch (scene) {
            'all_baskets' => ScoringConvention.onePerBasket,
            'inside_baskets' => ScoringConvention.oneAndTwo,
            _ => ScoringConvention.standard,
          };
          final anchor = DateTime.utc(2026, 11, 16, 10);
          final controller = ScoringController(
            nowUtc: () => anchor,
            setup: MatchSetup(
              matchId: 'region-golden',
              redName: 'Red',
              blueName: 'Blue',
              ruleTemplateId: 'region-rules',
              targetScore: null,
              timerEnabled: false,
              timeLimitMinutes: 10,
              winByTwo: false,
              scoringConvention: convention,
              scoreButtons: convention.scoreButtons,
            ),
          );
          addTearDown(controller.dispose);
          if (scene != 'free_throw') {
            controller.addScore(
              side: TeamSide.red,
              points: scene == 'outside' ? 3 : 1,
            );
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHoopitoTheme(brightness: brightness),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const Key('region-golden'),
                child: ScoringPage(
                  controller: controller,
                  clockNowUtc: () => anchor,
                  motionPreference: MotionPreference.reduced,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          if (scene == 'free_throw') {
            await tester.tap(find.byKey(const Key('blue-score-1')));
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('region-golden')),
            matchesGoldenFile(hoopitoGoldenFile(name)),
          );
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}

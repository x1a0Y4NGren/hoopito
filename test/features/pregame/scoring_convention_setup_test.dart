import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/pregame/start_match_mapper.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'advanced scoring choices share the settings left edge at $size / $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const PregamePage(),
            ),
          );
          final advanced = find.byKey(const Key('pregame-advanced'));
          await tester.ensureVisible(advanced);
          await tester.tap(advanced);
          await tester.pumpAndSettle();
          final standard = find.byKey(const Key('pregame-scoring-standard'));
          final freeGoal = find.byKey(const Key('pregame-goal-mode-free'));
          await tester.ensureVisible(standard);
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(standard).dx,
            closeTo(tester.getTopLeft(freeGoal).dx, .1),
          );
          final baskets = find.byKey(const Key('pregame-scoring-baskets'));
          await tester.ensureVisible(baskets);
          await tester.tap(baskets);
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(standard).dx,
            closeTo(tester.getTopLeft(freeGoal).dx, .1),
          );
          expect(
            tester
                .getTopLeft(find.byKey(const Key('pregame-three-point-bonus')))
                .dx,
            closeTo(tester.getTopLeft(freeGoal).dx, .1),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test(
    'refreshing an edited template updates its scoring method unless overridden',
    () {
      const oldRule = RuleTemplate(
        id: 'custom',
        name: 'Custom',
        scoreButtons: [1, 2, 3],
      );
      const editedRule = RuleTemplate(
        id: 'custom',
        name: 'Custom',
        scoreButtons: [1, 2],
        scoringConvention: ScoringConvention.oneAndTwo,
      );
      final controller = PregameController(templates: [oldRule])
        ..setRuleTemplateId('custom');
      controller.setTemplates([editedRule]);
      expect(
        controller.createMatchSetup().scoringConvention,
        ScoringConvention.oneAndTwo,
      );
      expect(controller.createMatchSetup().scoreButtons, [1, 2]);
      controller.setScoringConvention(ScoringConvention.onePerBasket);
      controller.setTemplates([oldRule]);
      expect(
        controller.createMatchSetup().scoringConvention,
        ScoringConvention.onePerBasket,
      );
      expect(controller.createMatchSetup().scoreButtons, [1]);
      controller.setRuleTemplateId('custom');
      controller.setTemplates([editedRule]);
      expect(
        controller.createMatchSetup().scoringConvention,
        ScoringConvention.oneAndTwo,
      );
    },
  );

  test(
    'template refresh preserves a preset snapshot even if its source was edited',
    () {
      const snapshot = RuleTemplate(
        id: 'custom',
        name: 'Old snapshot',
        scoreButtons: [1, 3, 5],
      );
      const edited = RuleTemplate(
        id: 'custom',
        name: 'Updated',
        scoreButtons: [1, 2],
        scoringConvention: ScoringConvention.oneAndTwo,
      );
      final controller = PregameController(
        initialPreset: const MatchSetupPreset(
          red: SetupParticipantPreset(nameSnapshot: 'Red'),
          blue: SetupParticipantPreset(nameSnapshot: 'Blue'),
          rules: snapshot,
        ),
      );
      controller.setTemplates([edited]);
      expect(controller.createMatchSetup().scoringConvention, isNull);
      expect(controller.createMatchSetup().scoreButtons, [1, 3, 5]);
    },
  );

  test(
    'new setup defaults to standard and maps a basket bonus into its snapshot',
    () {
      final controller = PregameController();
      expect(
        controller.createMatchSetup().scoringConvention,
        ScoringConvention.standard,
      );
      controller.setScoringConvention(ScoringConvention.onePerBasket);
      expect(controller.createMatchSetup().scoreButtons, [1]);
      controller.setThreePointCountsAsTwo(true);
      final setup = controller.createMatchSetup();
      expect(setup.scoreButtons, [1, 2]);
      final command = buildStartMatchCommand(setup);
      expect(
        command.ruleTemplate.scoringConvention,
        ScoringConvention.oneAndTwo,
      );
      expect(command.ruleTemplate.scoreButtons, [1, 2]);
      controller.swapSides();
      expect(
        controller.createMatchSetup().scoringConvention,
        ScoringConvention.oneAndTwo,
      );
      controller.setThreePointCountsAsTwo(false);
      expect(controller.createMatchSetup().scoreButtons, [1]);
    },
  );

  test(
    'selecting an old template and reusing it preserve unrestricted semantics',
    () {
      const legacy = RuleTemplate(
        id: 'old',
        name: 'Old custom',
        scoreButtons: [1, 3, 5],
      );
      final controller = PregameController(templates: [legacy])
        ..setRuleTemplateId('old');
      expect(controller.createMatchSetup().scoringConvention, isNull);
      expect(controller.createMatchSetup().scoreButtons, [1, 3, 5]);
      final rematch = PregameController(
        initialPreset: const MatchSetupPreset(
          red: SetupParticipantPreset(nameSnapshot: 'Red'),
          blue: SetupParticipantPreset(nameSnapshot: 'Blue'),
          rules: legacy,
        ),
      );
      expect(rematch.createMatchSetup().scoringConvention, isNull);
      expect(rematch.createMatchSetup().scoreButtons, [1, 3, 5]);
      rematch.setScoringConvention(ScoringConvention.standard);
      expect(rematch.createMatchSetup().scoreButtons, [1, 2, 3]);
      expect(legacy.scoringConvention, isNull);
    },
  );

  testWidgets('basket scoring exposes one optional outside-arc bonus switch', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      MatchSetup? started;
      await tester.pumpWidget(
        MaterialApp(
          home: PregamePage(
            onStartMatch: (setup) {
              started = setup;
            },
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('pregame-advanced')));
      await tester.tap(find.byKey(const Key('pregame-advanced')));
      await tester.pumpAndSettle();

      final baskets = find.byKey(const Key('pregame-scoring-baskets'));
      expect(baskets, findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const Key('pregame-scoring-standard')))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      expect(find.byKey(const Key('pregame-three-point-bonus')), findsNothing);
      await tester.ensureVisible(baskets);
      await tester.tap(baskets);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(baskets).flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      final bonus = find.byKey(const Key('pregame-three-point-bonus'));
      expect(bonus, findsOneWidget);
      expect(tester.widget<SwitchListTile>(bonus).value, isFalse);
      await tester.ensureVisible(bonus);
      await tester.tap(bonus);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(bonus).value, isTrue);
      await tester.ensureVisible(baskets);
      await tester.tap(baskets);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(bonus).value, isTrue);
      await tester.tap(find.byKey(const Key('pregame-start-match')));
      await tester.pumpAndSettle();
      expect(started!.scoringConvention, ScoringConvention.oneAndTwo);
      expect(started!.scoreButtons, [1, 2]);
    } finally {
      semantics.dispose();
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';

void main() {
  testWidgets('single is default and continuous mode can be selected', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PregamePage()));
    expect(find.byKey(const Key('pregame-mode-single')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pregame-mode-series')));
    await tester.pumpAndSettle();
    expect(find.text('固定两人，累计胜场；可随时结束本次对局。'), findsOneWidget);
  });

  testWidgets('mode is mapped to start setup and defaults to single', (
    tester,
  ) async {
    MatchSetup? started;
    await tester.pumpWidget(
      MaterialApp(home: PregamePage(onStartMatch: (setup) => started = setup)),
    );
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    await tester.pumpAndSettle();
    expect(started!.continuous, isFalse);
    await tester.tap(find.byKey(const Key('pregame-mode-series')));
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    await tester.pumpAndSettle();
    expect(started!.continuous, isTrue);
  });
  testWidgets('next settings fixes pair but permits swapping sides', (
    tester,
  ) async {
    MatchSetup? started;
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          lockedPair: true,
          initialPreset: MatchSetupPreset(
            red: const SetupParticipantPreset(nameSnapshot: 'Alex'),
            blue: const SetupParticipantPreset(nameSnapshot: 'Bo'),
            rules: RuleTemplateRepository.builtIns.first,
          ),
          onStartMatch: (setup) => started = setup,
        ),
      ),
    );
    expect(find.byKey(const Key('pregame-red-name')), findsNothing);
    expect(find.byKey(const Key('pregame-mode-single')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('pregame-swap-sides')));
    await tester.tap(find.byKey(const Key('pregame-swap-sides')));
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    await tester.pumpAndSettle();
    expect(started!.redName, 'Bo');
    expect(started!.blueName, 'Alex');
  });
}

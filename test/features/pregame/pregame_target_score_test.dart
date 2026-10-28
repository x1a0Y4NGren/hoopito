import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/pregame/start_match_mapper.dart';

import '../../test_helpers/test_database.dart';

const _edit = Key('pregame-target-edit');
const _input = Key('pregame-target-input');
const _confirm = Key('pregame-target-confirm');
const _cancel = Key('pregame-target-cancel');

void main() {
  testWidgets(
    'real template reload preserves displayed mode and start command',
    (tester) async {
      final repository = RuleTemplateRepository(createTestDatabase());
      final starts = <MatchSetup>[];
      Future<void> render(List<RuleTemplate> templates) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PregamePage(templates: templates, onStartMatch: starts.add),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render(const []);
      await tester.tap(find.byKey(const Key('pregame-start-match')));
      await tester.pumpAndSettle();
      expect(
        buildStartMatchCommand(starts.last).ruleTemplate.targetScore,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('pregame-advanced')));
      await tester.tap(find.byKey(const Key('pregame-advanced')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('pregame-goal-mode-target')),
      );
      await tester.tap(find.byKey(const Key('pregame-goal-mode-target')));
      await tester.pumpAndSettle();

      await repository.ensureBuiltIns();
      await render(await repository.listAll());
      expect(find.text('11分'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregame-start-match')));
      await tester.pumpAndSettle();
      expect(buildStartMatchCommand(starts.last).ruleTemplate.targetScore, 11);
      expect(
        buildStartMatchCommand(starts.last).ruleTemplate.winByTwo,
        isFalse,
      );

      final dropdown = find.byKey(const Key('pregame-rule-template'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('21 分制').last);
      await tester.pumpAndSettle();
      expect(find.text('21分'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('pregame-goal-mode-free')),
      );
      await tester.tap(find.byKey(const Key('pregame-goal-mode-free')));
      await tester.pumpAndSettle();
      await render(await repository.listAll());
      expect(find.byKey(_edit), findsNothing);
      await tester.tap(find.byKey(const Key('pregame-start-match')));
      await tester.pumpAndSettle();
      expect(
        buildStartMatchCommand(starts.last).ruleTemplate.targetScore,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('free mode hides target and mode toggling retains last target', (
    tester,
  ) async {
    MatchSetup? started;
    await tester.pumpWidget(
      MaterialApp(home: PregamePage(onStartMatch: (setup) => started = setup)),
    );
    await tester.ensureVisible(find.byKey(const Key('pregame-advanced')));
    await tester.tap(find.byKey(const Key('pregame-advanced')));
    await tester.pumpAndSettle();
    expect(find.byKey(_edit), findsNothing);
    expect(find.byKey(const Key('pregame-win-by-two')), findsNothing);
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    expect(started!.targetScore, isNull);
    final targetMode = find.byKey(const Key('pregame-goal-mode-target'));
    await tester.ensureVisible(targetMode);
    await tester.tap(targetMode);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(_edit));
    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_input), '37');
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    final freeMode = find.byKey(const Key('pregame-goal-mode-free'));
    await tester.ensureVisible(freeMode);
    await tester.tap(freeMode);
    await tester.pumpAndSettle();
    expect(find.byKey(_edit), findsNothing);
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    expect(started!.targetScore, isNull);
    await tester.ensureVisible(targetMode);
    await tester.tap(targetMode);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    expect(started!.targetScore, 37);
  });

  for (final score in [1, 99, 100, 999]) {
    test('target $score reaches the start configuration unchanged', () {
      final controller = PregameController()
        ..setGoalScoringMode(GoalScoringMode.target)
        ..setTargetScore(score);
      expect(controller.createMatchSetup().targetScore, score);
    });
  }

  test('controller bounds target score edits to 1 through 999', () {
    final controller = PregameController()
      ..setGoalScoringMode(GoalScoringMode.target)
      ..setTargetScore(1000);
    expect(controller.createMatchSetup().targetScore, 999);
    controller.setTargetScore(0);
    expect(controller.createMatchSetup().targetScore, 1);
  });

  testWidgets('target score is a labelled actionable accessibility button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _openSettings(tester);
      final node = tester.getSemantics(find.bySemanticsLabel('编辑目标分'));
      final data = node.getSemanticsData();
      expect(data.value, '11分');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('manual target is selected, confirmed and passed to start', (
    tester,
  ) async {
    MatchSetup? started;
    await _openSettings(tester, onStart: (setup) => started = setup);
    expect(tester.getSize(find.byKey(_edit)).height, greaterThanOrEqualTo(48));
    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(find.byKey(_input));
    expect(field.controller!.text, '11');
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byKey(_input), '100');
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(find.text('100分'), findsOneWidget);
    expect(find.textContaining('目标 100 分'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pregame-start-match')));
    await tester.pumpAndSettle();
    expect(started?.targetScore, 100);
  });

  testWidgets('incrementing 99 crosses into 100 and can decrement again', (
    tester,
  ) async {
    await _openSettings(tester);
    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_input), '99');
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pregame-target-increase')));
    await tester.pumpAndSettle();
    expect(find.text('100分'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pregame-target-decrease')));
    await tester.pumpAndSettle();
    expect(find.text('99分'), findsOneWidget);
  });

  testWidgets('keyboard done submits and boundary buttons disable', (
    tester,
  ) async {
    await _openSettings(tester);
    for (final score in [1, 999]) {
      await tester.tap(find.byKey(_edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_input), '$score');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(
                Key(
                  score == 1
                      ? 'pregame-target-decrease'
                      : 'pregame-target-increase',
                ),
              ),
            )
            .onPressed,
        isNull,
      );
    }
    await tester.tap(find.byKey(const Key('pregame-target-decrease')));
    await tester.pumpAndSettle();
    expect(find.text('998分'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pregame-target-increase')));
    await tester.pumpAndSettle();
    expect(find.text('999分'), findsOneWidget);
  });

  testWidgets('invalid targets retain input and leave the dialog open', (
    tester,
  ) async {
    await _openSettings(tester);
    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    for (final invalid in ['', '0', '-1', '1.5', 'abc', '1000']) {
      await tester.enterText(find.byKey(_input), invalid);
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byKey(_input));
      expect(field.controller!.text, invalid);
      expect(find.text('请输入 1～999 的整数'), findsWidgets);
    }
    await tester.enterText(find.byKey(_input), '99');
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(find.text('99分'), findsOneWidget);
  });

  for (final completion in [
    'confirm twice',
    'done twice',
    'confirm then cancel',
  ]) {
    testWidgets('$completion closes only the target dialog', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home route')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const PregamePage()),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('pregame-advanced')));
      await tester.tap(find.byKey(const Key('pregame-advanced')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('pregame-goal-mode-target')),
      );
      await tester.tap(find.byKey(const Key('pregame-goal-mode-target')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_edit));
      await tester.tap(find.byKey(_edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_input), '100');
      // Deliver callbacks already queued before the dialog reverse transition.
      final confirm = tester
          .widget<FilledButton>(find.byKey(_confirm))
          .onPressed!;
      final cancel = tester.widget<TextButton>(find.byKey(_cancel)).onPressed!;
      final done = tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(_input),
              matching: find.byType(EditableText),
            ),
          )
          .onSubmitted!;
      if (completion == 'done twice') {
        done('100');
        done('100');
      } else {
        confirm();
        (completion == 'confirm twice' ? confirm : cancel)();
      }
      await tester.pumpAndSettle();
      expect(find.byType(PregamePage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('100分'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
    });
  }

  for (final dismissal in ['cancel', 'back', 'outside']) {
    testWidgets(
      '$dismissal preserves target and repeated taps open one dialog',
      (tester) async {
        await _openSettings(tester);
        await tester.tap(find.byKey(_edit));
        await tester.tap(find.byKey(_edit), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.enterText(find.byKey(_input), '999');
        switch (dismissal) {
          case 'cancel':
            await tester.tap(find.byKey(_cancel));
          case 'back':
            await tester.binding.handlePopRoute();
          case 'outside':
            await tester.tapAt(const Offset(2, 2));
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('11分'), findsOneWidget);
        await tester.tap(find.byKey(_edit));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(find.byKey(_input)).controller!.text,
          '11',
        );
      },
    );
  }

  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$language $brightness compact keyboard layout at 200% text',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(360, 640);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);
          await _openSettings(
            tester,
            language: language,
            brightness: brightness,
            textScale: 2,
          );
          await tester.tap(find.byKey(_edit));
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(_input), '999');
          await tester.ensureVisible(find.byKey(_confirm));
          await tester.tap(find.byKey(_confirm));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            find.text(language == 'zh' ? '999分' : '999points'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _openSettings(
  WidgetTester tester, {
  void Function(MatchSetup)? onStart,
  String language = 'zh',
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHoopitoTheme(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PregamePage(onStartMatch: onStart),
    ),
  );
  await tester.pumpAndSettle();
  final advanced = find.byKey(const Key('pregame-advanced'));
  await tester.ensureVisible(advanced);
  await tester.tap(advanced);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('pregame-goal-mode-target')));
  await tester.tap(find.byKey(const Key('pregame-goal-mode-target')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(language == 'zh' ? '11分' : '11points'));
  await tester.pumpAndSettle();
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/rules/rule_template_editor_page.dart';
import 'package:hoopito/features/rules/rule_template_list_page.dart';

import '../../test_helpers/test_database.dart';

void main() {
  testWidgets('rule target accepts blank or 1 through 999 only', (
    tester,
  ) async {
    final repository = RuleTemplateRepository(createTestDatabase());
    await tester.pumpWidget(
      MaterialApp(home: RuleTemplateEditorPage(repository: repository)),
    );
    await tester.enterText(find.byKey(const Key('rule-name')), 'Target rule');
    for (final invalid in ['0', '1000', '1.5']) {
      await tester.ensureVisible(find.byKey(const Key('rule-target-score')));
      await tester.enterText(
        find.byKey(const Key('rule-target-score')),
        invalid,
      );
      await tester.ensureVisible(find.byKey(const Key('rule-save')));
      await tester.tap(find.byKey(const Key('rule-save')));
      await tester.pumpAndSettle();
      expect(find.text('请输入 1～999 的整数'), findsOneWidget);
      expect(await repository.listAll(), isEmpty);
    }
    final target = tester.state<FormFieldState<String>>(
      find.byKey(const Key('rule-target-score')),
    );
    for (final valid in ['', '1', '999']) {
      await tester.ensureVisible(find.byKey(const Key('rule-target-score')));
      await tester.enterText(find.byKey(const Key('rule-target-score')), valid);
      expect(target.validate(), isTrue);
      await tester.pump();
    }
  });

  testWidgets('rules list and editor stay usable across visual matrix', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);
    await repository.ensureBuiltIns();
    const locales = [Locale('zh'), Locale('en')];
    const sizes = [
      Size(390, 844),
      Size(731, 411),
      Size(1095, 616),
      Size(1920, 1080),
    ];
    for (final brightness in Brightness.values) {
      for (final locale in locales) {
        for (final size in sizes) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: MaterialApp(
                theme: buildHoopitoTheme(brightness: brightness),
                locale: locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: RuleTemplateListPage(repository: repository),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(EditorialMasthead), findsOneWidget);
          expect(
            tester.getSize(find.byType(EditorialIndexRow).first).height,
            greaterThanOrEqualTo(48),
          );

          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: MaterialApp(
                theme: buildHoopitoTheme(brightness: brightness),
                locale: locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: RuleTemplateEditorPage(repository: repository),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const Key('rule-name'))).height,
            greaterThanOrEqualTo(48),
          );
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('rule list row has one semantic action owner', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);
    await repository.ensureBuiltIns();
    await repository.save(
      const RuleTemplate(
        id: 'custom-semantic',
        name: '自定义规则',
        scoreButtons: [1, 2, 3],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: RuleTemplateListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('rule-template-custom-semantic'));
    expect(row, findsOneWidget);
    _expectSingleTapOwner(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(RuleTemplateEditorPage), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets('rule editor save has one semantic action owner', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final database = createTestDatabase();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: RuleTemplateEditorPage(
          repository: RuleTemplateRepository(database),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rule-save')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final save = find.byKey(const Key('rule-save'));
    expect(save, findsOneWidget);
    _expectSingleTapOwner(tester, save);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rule-name')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('rule-name')), '自定义规则');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rule-save')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('rule-save')));
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const Key('rule-save'));
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.byType(RuleTemplateEditorPage), findsNothing);
    semanticsHandle.dispose();
  });

  testWidgets('built-in rule names follow the active locale', (tester) async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);
    await repository.save(
      const RuleTemplate(
        id: 'custom-identity',
        name: 'Custom practice',
        scoreButtons: [1, 2],
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: RuleTemplateListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Default rules'), findsOneWidget);
    expect(find.byType(EditorialMasthead), findsOneWidget);
    expect(find.byType(EditorialIndexRow), findsAtLeastNWidgets(4));
    expect(find.byIcon(Icons.lock_outline), findsAtLeastNWidgets(4));
    expect(find.text('Built-in'), findsAtLeastNWidgets(4));
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('11-point game'), findsOneWidget);
    expect(find.text('21-point game'), findsOneWidget);
    expect(find.text('10-minute timed'), findsOneWidget);
    expect(find.text('自由计分'), findsNothing);
  });

  testWidgets('rule list exposes an empty state that opens the editor', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = _SequencedRuleRepository(
      database,
      streams: [Stream.value(const <RuleTemplate>[])],
    );

    await tester.pumpWidget(
      MaterialApp(home: RuleTemplateListPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditorialEmptyState), findsOneWidget);
    expect(find.text('暂无规则模板'), findsOneWidget);
    expect(find.text('创建一套常用规则，下场比赛直接选。'), findsOneWidget);
    await tester.tap(find.text('新建规则').last);
    await tester.pumpAndSettle();
    expect(find.byType(RuleTemplateEditorPage), findsOneWidget);
  });

  testWidgets('rule list exposes error and retries into populated content', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = _SequencedRuleRepository(
      database,
      streams: [
        Stream<List<RuleTemplate>>.error(StateError('offline')),
        Stream.value(const [
          RuleTemplate(id: 'retry-rule', name: '恢复规则', scoreButtons: [1, 2]),
        ]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: RuleTemplateListPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditorialErrorState), findsOneWidget);
    expect(find.text('规则模板读取失败'), findsOneWidget);
    expect(find.text('暂时读不到规则模板，请重试。'), findsOneWidget);
    expect(repository.watchCalls, 1);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(repository.watchCalls, 2);
    expect(repository.ensureCalls, greaterThanOrEqualTo(2));
    expect(find.byType(EditorialErrorState), findsNothing);
    expect(find.text('恢复规则'), findsOneWidget);
  });

  testWidgets('rule retry resubscribes before built-in repair completes', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repair = Completer<void>();
    final repository = _SequencedRuleRepository(
      database,
      streams: [
        Stream<List<RuleTemplate>>.error(StateError('offline')),
        Stream.value(const [
          RuleTemplate(id: 'retry-fast', name: '立即恢复', scoreButtons: [1]),
        ]),
      ],
      retryEnsure: repair.future,
    );

    await tester.pumpWidget(
      MaterialApp(home: RuleTemplateListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();

    expect(repository.watchCalls, 2);
    expect(find.text('立即恢复'), findsOneWidget);
    repair.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('lists built-ins and persists a custom template from editor', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);
    await repository.ensureBuiltIns();

    await tester.pumpWidget(
      MaterialApp(home: RuleTemplateListPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('默认规则'), findsOneWidget);
    expect(find.text('11 分制'), findsOneWidget);
    expect(find.text('21 分制'), findsOneWidget);
    expect(find.text('10 分钟计时'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rule-add-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rule-name')), '训练规则');
    await tester.enterText(find.byKey(const Key('rule-target-score')), '15');
    await tester.enterText(find.byKey(const Key('rule-time-limit')), '7');
    await tester.enterText(find.byKey(const Key('rule-foul-limit')), '4');
    await tester.enterText(
      find.byKey(const Key('rule-score-buttons')),
      '1,3,5',
    );
    await tester.enterText(find.byKey(const Key('rule-event-types')), '抢断,盖帽');
    expect(find.byKey(const Key('rule-win-by-two')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('rule-possession-hint')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-possession-hint')));
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -800),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditorialSectionRule), findsAtLeastNWidgets(2));
    expect(find.byType(EditorialTapTarget), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('rule-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-save')));
    await tester.pumpAndSettle();

    final custom = (await repository.listAll()).singleWhere(
      (template) => template.name == '训练规则',
    );
    expect(custom.targetScore, 15);
    expect(custom.timeLimitSeconds, 420);
    expect(custom.foulLimit, 4);
    expect(custom.scoreButtons, [1, 3, 5]);
    expect(custom.winByTwo, isFalse);
    expect(custom.possessionHintEnabled, isTrue);
    expect(custom.customEventTypes, ['抢断', '盖帽']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'policy selection is disabled without hints and persists when enabled',
    (tester) async {
      final database = createTestDatabase();
      final repository = RuleTemplateRepository(database);

      await tester.pumpWidget(
        MaterialApp(home: RuleTemplateEditorPage(repository: repository)),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('rule-possession-policy')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        tester
            .widget<DropdownButtonFormField<PossessionPolicy>>(
              find.byKey(const Key('rule-possession-policy')),
            )
            .onChanged,
        isNull,
      );

      await tester.ensureVisible(find.byKey(const Key('rule-possession-hint')));
      await tester.tap(find.byKey(const Key('rule-possession-hint')));
      await tester.pump();

      expect(
        tester
            .widget<DropdownButtonFormField<PossessionPolicy>>(
              find.byKey(const Key('rule-possession-policy')),
            )
            .onChanged,
        isNotNull,
      );

      await tester.ensureVisible(
        find.byKey(const Key('rule-possession-policy')),
      );
      await tester.tap(find.byKey(const Key('rule-possession-policy')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('命中后交换球权'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('rule-possession-hint')));
      await tester.tap(find.byKey(const Key('rule-possession-hint')));
      await tester.pump();
      expect(
        tester
            .widget<DropdownButtonFormField<PossessionPolicy>>(
              find.byKey(const Key('rule-possession-policy')),
            )
            .onChanged,
        isNull,
      );
      expect(find.text('手动设置'), findsOneWidget);
      expect(find.text('命中后交换球权'), findsNothing);

      await tester.tap(find.byKey(const Key('rule-possession-hint')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('rule-possession-policy')),
      );
      await tester.tap(find.byKey(const Key('rule-possession-policy')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('命中后交换球权'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('rule-name')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('rule-name')), '命中后交换规则');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('rule-save')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('rule-save')));
      await tester.pumpAndSettle();

      final saved = (await repository.listAll()).single;
      expect(saved.possessionHintEnabled, isTrue);
      expect(saved.possessionPolicy, PossessionPolicy.switchAfterMade);
    },
  );

  testWidgets('rule editor rejects missing and non-positive specification', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);

    await tester.pumpWidget(
      MaterialApp(home: RuleTemplateEditorPage(repository: repository)),
    );
    await tester.enterText(find.byKey(const Key('rule-target-score')), '0');
    await tester.enterText(find.byKey(const Key('rule-score-buttons')), '0');
    await tester.scrollUntilVisible(
      find.byKey(const Key('rule-save')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('rule-save')));
    await tester.pump();

    expect(find.text('请输入名称'), findsOneWidget);
    expect(find.text('请输入 1～999 的整数'), findsOneWidget);
    expect(find.text('至少填写一个正整数'), findsOneWidget);
    expect(await repository.listAll(), isEmpty);
  });
}

void _expectSingleTapOwner(WidgetTester tester, Finder target) {
  final targetNode = tester.getSemantics(target);
  final tapNodes = <SemanticsNode>[];

  void visit(SemanticsNode node) {
    if (node.getSemanticsData().hasAction(ui.SemanticsAction.tap)) {
      tapNodes.add(node);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(targetNode);
  expect(tapNodes, hasLength(1));
  expect(tapNodes.single, same(targetNode));
}

class _SequencedRuleRepository extends RuleTemplateRepository {
  _SequencedRuleRepository(
    super.database, {
    required this.streams,
    this.retryEnsure,
  });

  final List<Stream<List<RuleTemplate>>> streams;
  var watchCalls = 0;
  var ensureCalls = 0;
  final Future<void>? retryEnsure;

  @override
  Future<void> ensureBuiltIns() async {
    ensureCalls++;
    final future = retryEnsure;
    if (ensureCalls > 1 && future != null) await future;
  }

  @override
  Stream<List<RuleTemplate>> watchAll() {
    final index = watchCalls++;
    return streams[index < streams.length ? index : streams.length - 1];
  }
}

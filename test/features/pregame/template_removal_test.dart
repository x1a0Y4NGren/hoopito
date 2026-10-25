import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

void main() {
  testWidgets('falls back when the selected custom template is removed', (
    tester,
  ) async {
    const custom = RuleTemplate(
      id: 'custom-15',
      name: '15 point game',
      scoreButtons: [1, 2],
      targetScore: 15,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: PregamePage(
          templates: [...RuleTemplateRepository.builtIns, custom],
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('pregame-rule-template')));
    await tester.tap(find.byKey(const Key('pregame-rule-template')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 point game').last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: PregamePage()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

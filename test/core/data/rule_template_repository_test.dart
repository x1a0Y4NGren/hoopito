import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('seeds all built-in rule templates', () async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);

    await repository.ensureBuiltIns();
    final templates = await repository.listAll();

    expect(
      templates.map((template) => template.id),
      containsAll(['free', 'eleven_win_by_two', 'twenty_one', 'timed_ten']),
    );
    expect(
      templates.singleWhere((template) => template.id == 'free').targetScore,
      isNull,
    );
    final eleven = templates.singleWhere(
      (template) => template.id == 'eleven_win_by_two',
    );
    expect(eleven.targetScore, 11);
    expect(eleven.winByTwo, isTrue);
    expect(
      templates
          .singleWhere((template) => template.id == 'timed_ten')
          .timeLimitSeconds,
      600,
    );
  });

  test('round trips every custom rule setting through Drift', () async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);
    const template = RuleTemplate(
      id: 'custom-1',
      name: '训练局',
      scoreButtons: [1, 3, 5],
      targetScore: 15,
      timeLimitSeconds: 420,
      winByTwo: true,
      foulLimit: 4,
      possessionHintEnabled: true,
      customEventTypes: ['抢断', '盖帽'],
    );

    await repository.save(template);

    expect(await repository.getById(template.id), template);
  });
}

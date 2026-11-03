import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/start_match_mapper.dart';

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
    expect(eleven.winByTwo, isFalse);
    expect(
      templates
          .singleWhere((template) => template.id == 'timed_ten')
          .timeLimitSeconds,
      600,
    );
  });

  test(
    'reseed changes future rules while preserving an old match snapshot',
    () async {
      final database = createTestDatabase();
      final repository = RuleTemplateRepository(database);
      const legacy = RuleTemplate(
        id: 'eleven_win_by_two',
        name: '11 分制（领先 2 分）',
        scoreButtons: [1, 2, 3],
        targetScore: 11,
        winByTwo: true,
      );
      await repository.save(legacy, isBuiltIn: true);
      await MatchCommandService(database).start(
        StartMatchCommand(
          matchId: 'old-match',
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplate: legacy,
          recordingMode: RecordingMode.simple,
        ),
      );

      await repository.ensureBuiltIns();
      final oldMatch = (await MatchRepository(
        database,
      ).getMatchDetail('old-match'))!;
      expect(oldMatch.match.ruleTemplateSnapshot, legacy);
      expect((await repository.getById(legacy.id))!.winByTwo, isFalse);
      final controller = PregameController(
        templates: await repository.listAll(),
      )..setRuleTemplateId(legacy.id);
      final newRule = buildStartMatchCommand(
        controller.createMatchSetup(),
      ).ruleTemplate;
      expect(newRule.id, legacy.id);
      expect(newRule.name, '11 分制');
      expect(newRule.targetScore, 11);
      expect(newRule.winByTwo, isFalse);
      expect(oldMatch.match.ruleTemplateSnapshot.winByTwo, isTrue);
    },
  );

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

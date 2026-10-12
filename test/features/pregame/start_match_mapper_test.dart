import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/start_match_mapper.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('maps all pre-game identity, mode, clock, and rule fields', () {
    final setup = const MatchSetup(
      matchId: 'match-mapped',
      redName: 'Red snapshot',
      blueName: 'Blue snapshot',
      redPlayerProfileId: 'player-red',
      bluePlayerProfileId: 'player-blue',
      ruleTemplateId: 'custom-rule',
      ruleTemplateName: 'Custom Rule',
      targetScore: 15,
      timerEnabled: true,
      timeLimitMinutes: 7,
      winByTwo: true,
      scoreButtons: [1, 2, 3],
      foulLimit: 5,
      possessionHintEnabled: true,
      possessionPolicy: PossessionPolicy.switchAfterMade,
      customEventTypes: ['screen'],
      recordingMode: RecordingMode.detailed,
      trackingCoverage: TrackingCoverage.full,
      clockMode: ClockMode.countdown,
    );

    final command = buildStartMatchCommand(
      setup,
      now: DateTime.utc(2026, 8, 23, 10),
    );

    expect(command.matchId, setup.matchId);
    expect(command.redName, setup.redName);
    expect(command.blueName, setup.blueName);
    expect(command.redPlayerProfileId, setup.redPlayerProfileId);
    expect(command.bluePlayerProfileId, setup.bluePlayerProfileId);
    expect(command.recordingMode, RecordingMode.detailed);
    expect(command.trackingCoverage, TrackingCoverage.full);
    expect(command.clockMode, ClockMode.countdown);
    expect(command.timerEnabled, isTrue);
    expect(command.regulationSeconds, 420);
    expect(
      command.ruleTemplate,
      const RuleTemplate(
        id: 'custom-rule',
        name: 'Custom Rule',
        scoreButtons: [1, 2, 3],
        targetScore: 15,
        timeLimitSeconds: 420,
        winByTwo: true,
        foulLimit: 5,
        possessionHintEnabled: true,
        possessionPolicy: PossessionPolicy.switchAfterMade,
        customEventTypes: ['screen'],
      ),
    );
    expect(command.createdAt, DateTime.utc(2026, 8, 23, 10));
    expect(command.startedAt, DateTime.utc(2026, 8, 23, 10));
  });

  test('count-up timer can be enabled without a regulation duration', () {
    final command = buildStartMatchCommand(
      const MatchSetup(
        matchId: 'match-count-up',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplateId: 'free',
        targetScore: null,
        timerEnabled: true,
        timeLimitMinutes: 10,
        winByTwo: false,
        recordingMode: RecordingMode.simple,
        trackingCoverage: TrackingCoverage.scoresOnly,
        clockMode: ClockMode.countUp,
      ),
      now: DateTime.utc(2026, 8, 23, 10),
    );

    expect(command.timerEnabled, isTrue);
    expect(command.clockMode, ClockMode.countUp);
    expect(command.regulationSeconds, isNull);
  });

  test('omitted recording metadata maps to compatibility defaults', () {
    final setup = const MatchSetup(
      matchId: 'match-no-mode',
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplateId: 'free',
      targetScore: null,
      timerEnabled: false,
      timeLimitMinutes: 10,
      winByTwo: false,
      recordingMode: null,
    );

    final command = buildStartMatchCommand(setup);

    expect(command.recordingMode, RecordingMode.simple);
    expect(command.trackingCoverage, TrackingCoverage.scoresOnly);
  });

  test('clearing legacy recording mode still maps compatibility defaults', () {
    final controller = PregameController()..clearRecordingMode();

    expect(controller.state.recordingMode, isNull);
    final setup = controller.createMatchSetup();
    expect(setup.recordingMode, RecordingMode.simple);

    final command = buildStartMatchCommand(setup);
    expect(command.recordingMode, RecordingMode.simple);
    expect(command.trackingCoverage, TrackingCoverage.scoresOnly);
  });

  test('countdown must be enabled with a valid duration', () {
    final setup = const MatchSetup(
      matchId: 'match-invalid-clock',
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplateId: 'free',
      targetScore: null,
      timerEnabled: false,
      timeLimitMinutes: 0,
      winByTwo: false,
      recordingMode: RecordingMode.simple,
      clockMode: ClockMode.countdown,
    );

    expect(
      () => buildStartMatchCommand(setup),
      throwsA(
        isA<PregameSetupValidationException>().having(
          (error) => error.result.errors,
          'errors',
          contains(PregameValidationError.invalidCountdownDuration),
        ),
      ),
    );
  });

  test('validation exception uses readable labels instead of enum names', () {
    const setup = MatchSetup(
      matchId: 'match-readable-error',
      redName: '',
      blueName: 'Blue',
      ruleTemplateId: 'free',
      targetScore: null,
      timerEnabled: false,
      timeLimitMinutes: 10,
      winByTwo: false,
    );

    expect(
      () => buildStartMatchCommand(setup),
      throwsA(
        isA<PregameSetupValidationException>().having(
          (error) => error.toString(),
          'message',
          allOf(contains('请输入红方姓名'), isNot(contains('redParticipantRequired'))),
        ),
      ),
    );
  });

  test('a target override is persisted into the mapped rule snapshot', () {
    final controller =
        PregameController(
            templates: const [
              RuleTemplate(
                id: 'target-template',
                name: 'Target template',
                scoreButtons: [1, 2, 3],
                targetScore: 11,
              ),
            ],
          )
          ..setRuleTemplateId('target-template')
          ..setTargetScore(17)
          ..setRecordingMode(RecordingMode.detailed);

    final command = buildStartMatchCommand(
      controller.createMatchSetup(),
      now: DateTime.utc(2026, 8, 23, 10),
    );

    expect(command.ruleTemplate.targetScore, 17);
  });

  for (final policy in [
    PossessionPolicy.switchAfterMade,
    PossessionPolicy.keepAfterMade,
  ]) {
    test(
      'preserves $policy from a persisted template through match start',
      () async {
        final database = createTestDatabase();
        final repository = RuleTemplateRepository(database);
        final template = RuleTemplate(
          id: 'policy-${policy.name}',
          name: '球权规则 ${policy.name}',
          scoreButtons: const [1, 2, 3],
          possessionHintEnabled: true,
          possessionPolicy: policy,
        );
        await repository.save(template);

        final loaded = await repository.getById(template.id);
        final controller = PregameController(templates: [loaded!])
          ..setRuleTemplateId(template.id)
          ..setRecordingMode(RecordingMode.simple);
        final setup = controller.createMatchSetup();

        final command = buildStartMatchCommand(
          setup,
          now: DateTime.utc(2026, 8, 23, 10),
        );

        expect(setup.possessionPolicy, policy);
        expect(command.ruleTemplate.possessionHintEnabled, isTrue);
        expect(command.ruleTemplate.possessionPolicy, policy);
      },
    );
  }
}

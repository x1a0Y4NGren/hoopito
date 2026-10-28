import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

void main() {
  for (final target in [0, 1000]) {
    test('loaded target $target is bounded only for a new match', () {
      final rules = RuleTemplate(
        id: 'legacy-target',
        name: 'Old custom target',
        scoreButtons: const [1, 2, 3],
        targetScore: target,
        winByTwo: true,
      );
      final controller = PregameController(templates: [rules])
        ..setRuleTemplateId(rules.id);
      final expected = target.clamp(1, 999);
      expect(controller.state.targetScore, expected);
      expect(controller.createMatchSetup().targetScore, expected);
      final rematch = PregameController(
        initialPreset: MatchSetupPreset(
          red: const SetupParticipantPreset(nameSnapshot: 'Red'),
          blue: const SetupParticipantPreset(nameSnapshot: 'Blue'),
          rules: rules,
        ),
      );
      expect(rematch.state.targetScore, expected);
      expect(rematch.createMatchSetup().targetScore, expected);
      expect(rules.targetScore, target);
      expect(rules.winByTwo, isTrue);
    });
  }

  test('mode toggling retains target but only target mode starts with it', () {
    final controller = PregameController();
    expect(controller.state.goalScoringMode, GoalScoringMode.free);
    controller.setGoalScoringMode(GoalScoringMode.target);
    expect(controller.createMatchSetup().targetScore, 11);
    controller.setTargetScore(37);
    controller.setGoalScoringMode(GoalScoringMode.free);
    expect(controller.createMatchSetup().targetScore, isNull);
    controller.setGoalScoringMode(GoalScoringMode.target);
    expect(controller.createMatchSetup().targetScore, 37);
  });

  test(
    'real templates derive modes while refresh preserves manual selection',
    () {
      final controller = PregameController(
        templates: RuleTemplateRepository.builtIns,
      );
      for (final entry in {'eleven_win_by_two': 11, 'twenty_one': 21}.entries) {
        controller.setRuleTemplateId(entry.key);
        expect(controller.createMatchSetup().targetScore, entry.value);
        expect(controller.createMatchSetup().winByTwo, isFalse);
        controller.setGoalScoringMode(GoalScoringMode.free);
        controller.setTemplates(List.of(RuleTemplateRepository.builtIns));
        expect(controller.createMatchSetup().targetScore, isNull);
      }
      for (final id in ['free', 'timed_ten']) {
        controller.setRuleTemplateId(id);
        expect(controller.createMatchSetup().targetScore, isNull);
      }
      controller.setGoalScoringMode(GoalScoringMode.target);
      controller.setTargetScore(77);
      controller.setTemplates(List.of(RuleTemplateRepository.builtIns));
      expect(controller.createMatchSetup().targetScore, 77);
    },
  );

  test('free setup has no ghost target while templates are loading', () {
    final controller = PregameController();
    expect(controller.createMatchSetup().targetScore, isNull);
    controller.setTemplates(RuleTemplateRepository.builtIns);
    expect(controller.createMatchSetup().targetScore, isNull);
  });

  test('legacy target template never enables win by two for a new setup', () {
    final controller = PregameController(
      templates: const [
        RuleTemplate(
          id: 'legacy',
          name: 'Legacy',
          scoreButtons: [1, 2, 3],
          targetScore: 11,
          winByTwo: true,
        ),
      ],
    )..setRuleTemplateId('legacy');
    expect(controller.createMatchSetup().targetScore, 11);
    expect(controller.createMatchSetup().winByTwo, isFalse);
  });

  test(
    'built in eleven keeps identity and stored name without new win by two',
    () {
      final eleven = RuleTemplateRepository.builtIns.firstWhere(
        (template) => template.id == 'eleven_win_by_two',
      );
      expect(eleven.name, '11 分制（领先 2 分）');
      expect(eleven.winByTwo, isFalse);
    },
  );

  test('pre-game state starts with default red and blue players', () {
    final controller = PregameController();

    expect(controller.state.redName, '红方');
    expect(controller.state.blueName, '蓝方');
    expect(controller.state.targetScore, 11);
    expect(controller.state.timerEnabled, isFalse);
  });

  test('new matches default to simple score-only recording metadata', () {
    final controller = PregameController();

    expect(controller.validate().isValid, isTrue);
    final setup = controller.createMatchSetup();
    expect(setup.recordingMode, RecordingMode.simple);
    expect(setup.trackingCoverage, TrackingCoverage.scoresOnly);
  });

  test('pre-game controller creates an in-memory match setup', () {
    final controller = PregameController()
      ..setRedName('A Li')
      ..setBlueName('Bo')
      ..setGoalScoringMode(GoalScoringMode.target)
      ..setTargetScore(21)
      ..setTimerEnabled(true);

    final setup = controller.createMatchSetup();

    expect(setup.matchId, startsWith('match-'));
    expect(setup.redName, 'A Li');
    expect(setup.blueName, 'Bo');
    expect(setup.targetScore, 21);
    expect(setup.timerEnabled, isTrue);
    expect(setup.winByTwo, isFalse);
  });

  test('timed template keeps a null target score in match setup', () {
    final controller = PregameController(
      templates: RuleTemplateRepository.builtIns,
    )..setRuleTemplateId('timed_ten');

    final setup = controller.createMatchSetup();

    expect(setup.targetScore, isNull);
  });

  test('timed templates enable their countdown default consistently', () {
    final controller = PregameController(
      templates: RuleTemplateRepository.builtIns,
    )..setRuleTemplateId('timed_ten');

    expect(controller.state.timerEnabled, isTrue);
    expect(controller.state.clockMode, ClockMode.countdown);
    expect(controller.state.timeLimitMinutes, 10);
  });

  test('profile selection stores the profile id and current name snapshot', () {
    final player = Player(
      id: 'player-red',
      nickname: 'Old Red',
      createdAt: DateTime.utc(2026, 8, 23),
    );
    final controller = PregameController(players: [player]);

    expect(controller.selectRedProfile(player.id), isTrue);

    final setup = controller.createMatchSetup();
    expect(setup.redPlayerProfileId, player.id);
    expect(setup.redName, 'Old Red');
  });

  test('the same profile cannot be selected for both sides', () {
    final player = Player(
      id: 'player-1',
      nickname: 'Player One',
      createdAt: DateTime.utc(2026, 8, 23),
    );
    final controller = PregameController(players: [player]);

    expect(controller.selectRedProfile(player.id), isTrue);
    expect(controller.selectBlueProfile(player.id), isFalse);
    expect(controller.state.bluePlayerProfileId, isNull);
    expect(
      controller.validate().errors,
      isNot(contains(PregameValidationError.duplicatePlayerProfile)),
    );
  });

  test('duplicate temporary names remain valid because sides are explicit', () {
    final controller = PregameController()
      ..setRedName('Alex')
      ..setBlueName('Alex')
      ..setRecordingMode(RecordingMode.simple);

    final result = controller.validate();

    expect(result.isValid, isTrue);
    expect(controller.createMatchSetup().redPlayerProfileId, isNull);
    expect(controller.createMatchSetup().bluePlayerProfileId, isNull);
  });

  test('countdown requires a positive duration within the supported range', () {
    final controller = PregameController(
      state: const PregameState(
        clockMode: ClockMode.countdown,
        timeLimitMinutes: 0,
        recordingMode: RecordingMode.simple,
      ),
    );

    expect(
      controller.validate().errors,
      contains(PregameValidationError.invalidCountdownDuration),
    );

    controller.setTimeLimitMinutes(15);
    expect(
      controller.validate().errors,
      isNot(contains(PregameValidationError.invalidCountdownDuration)),
    );
  });

  test('clock mode and timer enablement remain independent', () {
    final controller = PregameController()
      ..setTimerEnabled(true)
      ..setClockMode(ClockMode.countUp);

    expect(controller.state.clockMode, ClockMode.countUp);
    expect(controller.state.timerEnabled, isTrue);
    final setup = controller.createMatchSetup();
    expect(setup.clockMode, ClockMode.countUp);
    expect(setup.timerEnabled, isTrue);
  });

  test('changing a selected profile to a temporary name clears its id', () {
    final player = Player(
      id: 'player-red',
      nickname: 'Profile Name',
      createdAt: DateTime.utc(2026, 8, 23),
    );
    final controller = PregameController(players: [player]);

    controller.selectRedProfile(player.id);
    controller.setRedName('Temporary Red');

    expect(controller.state.redPlayerProfileId, isNull);
    expect(controller.state.redName, 'Temporary Red');
  });

  test('selected profile snapshot does not follow later profile rename', () {
    final original = Player(
      id: 'player-red',
      nickname: 'Before Rename',
      createdAt: DateTime.utc(2026, 8, 23),
    );
    final controller = PregameController(players: [original])
      ..selectRedProfile(original.id)
      ..setRecordingMode(RecordingMode.simple);

    controller.setPlayers([
      Player(
        id: original.id,
        nickname: 'After Rename',
        createdAt: original.createdAt,
      ),
    ]);

    final setup = controller.createMatchSetup();
    expect(setup.redPlayerProfileId, original.id);
    expect(setup.redName, 'Before Rename');
  });

  test('unknown profile selections are rejected without changing the side', () {
    final controller = PregameController();

    expect(controller.selectRedProfile('missing'), isFalse);
    expect(controller.state.redPlayerProfileId, isNull);
    expect(controller.state.redName, defaultRedPlayerName);
  });

  test('clearing a participant name remains empty and requires validation', () {
    final controller = PregameController()
      ..setRedName('')
      ..setBlueName('')
      ..setRecordingMode(RecordingMode.simple);

    expect(controller.state.redName, isEmpty);
    expect(controller.state.blueName, isEmpty);
    expect(
      controller.validate().errors,
      containsAll([
        PregameValidationError.redParticipantRequired,
        PregameValidationError.blueParticipantRequired,
      ]),
    );
  });

  test('disabling timer normalizes clock mode to count-up', () {
    final controller = PregameController()
      ..setTimerEnabled(true)
      ..setClockMode(ClockMode.countdown)
      ..setTimerEnabled(false);

    expect(controller.state.timerEnabled, isFalse);
    expect(controller.state.clockMode, ClockMode.countUp);
  });

  test('countdown input preserves raw values and rejects invalid text', () {
    final controller =
        PregameController(
            state: const PregameState(recordingMode: RecordingMode.simple),
          )
          ..setTimerEnabled(true)
          ..setClockMode(ClockMode.countdown);

    controller.setTimeLimitMinutes(181);
    expect(controller.state.timeLimitMinutes, 181);
    expect(
      controller.validate().errors,
      contains(PregameValidationError.invalidCountdownDuration),
    );

    controller.setCountdownMinutesText('');
    expect(controller.state.countdownMinutesText, isEmpty);
    expect(
      controller.validate().errors,
      contains(PregameValidationError.invalidCountdownDuration),
    );

    controller.setCountdownMinutesText('abc');
    expect(controller.state.countdownMinutesText, 'abc');
    expect(
      controller.validate().errors,
      contains(PregameValidationError.invalidCountdownDuration),
    );
  });

  test(
    'target score edits are per-match overrides and template changes clear them',
    () {
      final templates = [
        const RuleTemplate(
          id: 'eleven',
          name: 'Eleven',
          scoreButtons: [1, 2, 3],
          targetScore: 11,
        ),
        const RuleTemplate(
          id: 'untimed',
          name: 'Untimed',
          scoreButtons: [1, 2, 3],
        ),
      ];
      final controller = PregameController(templates: templates)
        ..setRuleTemplateId('eleven')
        ..setTargetScore(17);

      expect(controller.createMatchSetup().targetScore, 17);

      controller.setRuleTemplateId('untimed');
      expect(controller.createMatchSetup().targetScore, isNull);

      controller.setRuleTemplateId('eleven');
      expect(controller.createMatchSetup().targetScore, 11);
    },
  );
}

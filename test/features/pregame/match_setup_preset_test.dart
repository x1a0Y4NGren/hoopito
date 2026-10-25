import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/start_match_mapper.dart';

import '../../test_helpers/test_database.dart';

void main() {
  for (final target in [100, 999]) {
    test(
      'stored target $target survives recent setup and rematch with end hint',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final now = DateTime.utc(2026, 10, 5);
        final controller = PregameController(
          matchIdFactory: () => 'target-$target',
        )..setTargetScore(target);
        await MatchCommandService(database, now: () => now).start(
          buildStartMatchCommand(controller.createMatchSetup(), now: now),
        );
        final stored = (await MatchRepository(
          database,
        ).getMatchDetail('target-$target'))!;
        expect(stored.match.ruleTemplateSnapshot.targetScore, target);
        final preset = MatchSetupPreset.fromMatchDetail(stored);
        for (final reused in [preset, preset.swapped()]) {
          final setup = PregameController(
            initialPreset: reused,
          ).createMatchSetup();
          expect(setup.targetScore, target);
          expect(setup.matchId, isNot('target-$target'));
        }
        final hints = RuleEngine().evaluate(
          template: stored.match.ruleTemplateSnapshot,
          score: ScoreState(redScore: target - 1, blueScore: 0),
          scoringSide: TeamSide.red,
          scoringPoints: 1,
        );
        expect(
          hints.map((hint) => hint.type),
          contains(RuleHintType.targetReached),
        );
        expect(hints.every((hint) => !hint.isBlocking), isTrue);
      },
    );
  }

  test('rematch copies setup fields and allocates identity only at start', () {
    final detail = _finishedMatch();
    final preset = MatchSetupPreset.fromMatchDetail(detail);
    var allocatedIds = 0;
    final controller = PregameController(
      initialPreset: preset,
      players: [
        Player(
          id: 'red-player',
          nickname: 'Renamed',
          createdAt: DateTime(2026),
        ),
      ],
      matchIdFactory: () => 'new-match-${++allocatedIds}',
    );

    expect(allocatedIds, 0);
    expect(controller.state.redName, 'Red snapshot');
    expect(controller.state.blueName, 'Blue temporary');
    expect(controller.state.redPlayerProfileId, 'red-player');
    expect(controller.state.bluePlayerProfileId, isNull);
    expect(controller.state.trackingCoverage, TrackingCoverage.scoresOnly);
    expect(controller.state.recordingMode, RecordingMode.simple);
    expect(controller.state.timerEnabled, isTrue);
    expect(controller.state.clockMode, ClockMode.countdown);
    expect(controller.state.timeLimitMinutes, 7);

    final setup = controller.createMatchSetup();
    expect(allocatedIds, 1);
    expect(setup.matchId, 'new-match-1');
    expect(setup.matchId, isNot(detail.match.id));
    expect(setup.scoreButtons, [1, 2]);
    expect(setup.targetScore, 15);
    expect(setup.winByTwo, isTrue);
    expect(setup.possessionPolicy, PossessionPolicy.keepAfterMade);
    expect(setup.trackingCoverage, TrackingCoverage.scoresOnly);
  });

  test('swap moves participant snapshots and identity together', () {
    final controller = PregameController(
      initialPreset: MatchSetupPreset.fromMatchDetail(_finishedMatch()),
    )..swapSides();

    expect(controller.state.redName, 'Blue temporary');
    expect(controller.state.redPlayerProfileId, isNull);
    expect(controller.state.blueName, 'Red snapshot');
    expect(controller.state.bluePlayerProfileId, 'red-player');
    expect(controller.state.targetScore, 15);
  });

  test('preset keeps stored rules when the template was edited or deleted', () {
    final controller = PregameController(
      initialPreset: MatchSetupPreset.fromMatchDetail(_finishedMatch()),
      templates: const [
        RuleTemplate(id: 'old-rule', name: 'Changed rule', scoreButtons: [3]),
      ],
    );
    controller.setTemplates(const [
      RuleTemplate(id: 'free', name: 'Free scoring', scoreButtons: [1, 2, 3]),
    ]);

    expect(controller.createMatchSetup().scoreButtons, [1, 2]);
    expect(controller.createMatchSetup().targetScore, 15);
  });

  test(
    'confirmed rematch starts empty with a fresh regulation clock',
    () async {
      final previous = _finishedMatch();
      final player = Player(
        id: 'red-player',
        nickname: 'Renamed',
        createdAt: DateTime(2026),
      );
      final database = createTestDatabase();
      await PlayerRepository(database).save(player);
      final controller = PregameController(
        initialPreset: MatchSetupPreset.fromMatchDetail(previous),
        players: [player],
        matchIdFactory: () => 'new-match',
      );
      final startedAt = DateTime.utc(2026, 10, 2, 9);
      final detail = await MatchCommandService(database, now: () => startedAt)
          .start(
            buildStartMatchCommand(
              controller.createMatchSetup(),
              now: startedAt,
            ),
          );

      expect(detail.match.id, 'new-match');
      expect(detail.match.lifecycle, MatchLifecycle.active);
      expect(detail.match.redName, 'Red snapshot');
      expect(detail.redScore, 0);
      expect(detail.blueScore, 0);
      expect(detail.redFouls, 0);
      expect(detail.blueFouls, 0);
      expect(detail.events, isEmpty);
      expect(detail.shotLocations, isEmpty);
      expect(detail.possessionSegments, isEmpty);
      expect(detail.match.note, isNull);
      expect(detail.match.trackingCoverage, TrackingCoverage.scoresOnly);
      expect(detail.match.recordingMode, RecordingMode.simple);
      expect(detail.clock?.elapsedSeconds, 0);
      expect(detail.clock?.phase, ClockPhase.regulation);
      expect(detail.clock?.isRunning, isTrue);
      expect(detail.clock?.runningSinceUtc, detail.match.startedAt);
      expect(
        detail.clock?.runningSinceUtc,
        isNot(previous.clock?.runningSinceUtc),
      );
      expect(detail.clock?.state.regulationSeconds, 420);
      expect(
        detail.match.participants.map((participant) => participant.id),
        isNot(contains('old-red')),
      );
    },
  );
}

MatchDetail _finishedMatch() {
  final now = DateTime.utc(2026, 9, 30);
  final match = Match(
    id: 'old-match',
    createdAt: now,
    endedAt: now.add(const Duration(minutes: 8)),
    lifecycle: MatchLifecycle.finished,
    recordingMode: RecordingMode.detailed,
    trackingCoverage: TrackingCoverage.full,
    timerEnabled: true,
    note: 'Old match note',
    participants: const [
      MatchParticipant(
        id: 'old-red',
        matchId: 'old-match',
        side: TeamSide.red,
        nameSnapshot: 'Red snapshot',
        playerProfileId: 'red-player',
      ),
      MatchParticipant(
        id: 'old-blue',
        matchId: 'old-match',
        side: TeamSide.blue,
        nameSnapshot: 'Blue temporary',
      ),
    ],
    ruleTemplateSnapshot: const RuleTemplate(
      id: 'old-rule',
      name: 'Stored rule',
      scoreButtons: [1, 2],
      targetScore: 15,
      timeLimitSeconds: 420,
      winByTwo: true,
      possessionHintEnabled: true,
      possessionPolicy: PossessionPolicy.keepAfterMade,
    ),
  );
  return MatchDetail(
    match: match,
    events: [
      MatchEvent.score(
        id: 'old-event',
        matchId: match.id,
        side: TeamSide.red,
        points: 2,
        occurredAt: now,
      ),
    ],
    shotLocations: const [],
    redScore: 17,
    blueScore: 15,
    redFouls: 2,
    blueFouls: 1,
    shotAttemptCount: 40,
    locatedShotCount: 5,
    clock: const ClockEngine().project(
      state: ClockState(
        id: 'old-clock',
        matchId: match.id,
        mode: ClockMode.countdown,
        phase: ClockPhase.overtime,
        accumulatedSeconds: 490,
        runningSinceUtc: now,
        regulationSeconds: 420,
      ),
      now: now,
    ),
  );
}

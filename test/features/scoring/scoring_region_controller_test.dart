import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'legacy local scoring keeps arbitrary positive field-goal values',
    () async {
      final controller = ScoringController(setup: _setup(null));
      addTearDown(controller.dispose);
      expect(
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2),
        isTrue,
      );
      expect(controller.state.score.redScore, 2);
      expect(controller.locationSupplementWindow, isNotNull);
    },
  );

  test(
    'standard +1 preserves an explicitly supplied event timestamp',
    () async {
      final recordedAt = DateTime.utc(2026, 11, 16, 9, 59);
      final controller = ScoringController(
        matchId: 'free-throw-time',
        nowUtc: () => DateTime.utc(2026, 11, 16, 10),
      );
      addTearDown(controller.dispose);
      expect(
        await controller.recordScoreCommitted(
          side: TeamSide.blue,
          points: 1,
          occurredAt: recordedAt,
        ),
        isTrue,
      );
      expect(controller.state.events.single.occurredAt, recordedAt);
    },
  );
  test('a new local match records +1 as a free throw without a supplement', () {
    final controller = ScoringController(matchId: 'standard-free-throw');
    addTearDown(controller.dispose);

    expect(controller.addScore(side: TeamSide.blue, points: 1), isTrue);

    expect(controller.state.score.blueScore, 1);
    expect(controller.state.events.single.type, EventKind.freeThrow);
    expect(controller.state.events.single.outcome, ShotOutcome.made);
    expect(controller.locationSupplementWindow, isNull);
    expect(controller.state.shotLocations, isEmpty);
  });

  test(
    'an invalid +3 supplement preserves the score and its deadline',
    () async {
      final now = DateTime.utc(2026, 11, 16, 10);
      final controller = ScoringController(
        matchId: 'standard-region',
        nowUtc: () => now,
      );
      addTearDown(controller.dispose);
      controller.addScore(side: TeamSide.red, points: 3);
      final window = controller.locationSupplementWindow;

      expect(
        await controller.attachSupplementLocation(CourtPoint(x: .5, y: .3)),
        isFalse,
      );
      expect(controller.state.score.redScore, 3);
      expect(controller.state.shotLocations, isEmpty);
      expect(controller.locationSupplementWindow, same(window));
      expect(
        await controller.attachSupplementLocation(CourtPoint(x: .5, y: .9)),
        isTrue,
      );
      expect(controller.state.score.redScore, 3);
      expect(controller.state.shotLocations, hasLength(1));
    },
  );

  test(
    'court-first +2 outside the arc cannot commit or consume the draft',
    () async {
      final controller = ScoringController(matchId: 'standard-court-first');
      addTearDown(controller.dispose);
      controller.beginOrMoveCourtFirstShot(
        CourtPoint(x: .5, y: .9),
        side: TeamSide.red,
        points: 2,
      );

      expect(await controller.commitCourtFirstShot(), isFalse);
      expect(controller.state.events, isEmpty);
      expect(controller.courtFirstShotDraft, isNotNull);
      controller.updateCourtFirstShot(points: 3);
      expect(await controller.commitCourtFirstShot(), isTrue);
      expect(controller.state.score.redScore, 3);
    },
  );

  test(
    'explicit +3 capture starts with a confirmable outside location',
    () async {
      final controller = ScoringController(matchId: 'explicit-outside');
      addTearDown(controller.dispose);
      controller.addScore(side: TeamSide.red, points: 3);
      expect(controller.beginLocateLastUnlocatedShot(), isTrue);
      await controller.confirmPendingLocation();
      expect(controller.state.shotLocations, hasLength(1));
      expect(controller.state.shotLocations.single.point.y, greaterThan(.6));
      expect(controller.state.score.redScore, 3);
    },
  );

  for (final convention in [
    ScoringConvention.onePerBasket,
    ScoringConvention.oneAndTwo,
  ]) {
    test(
      '$convention applies its basket value to an outside location',
      () async {
        final controller = ScoringController(setup: _setup(convention));
        addTearDown(controller.dispose);
        controller.beginOrMoveCourtFirstShot(
          CourtPoint(x: .5, y: .9),
          side: TeamSide.blue,
        );
        expect(
          controller.enabledScorePoints,
          convention == ScoringConvention.onePerBasket ? {1} : {2},
        );
        controller.updateCourtFirstShot(
          points: convention == ScoringConvention.onePerBasket ? 1 : 2,
        );
        expect(await controller.commitCourtFirstShot(), isTrue);
        expect(controller.state.events.single.type, EventKind.fieldGoal);
        expect(controller.state.shotLocations, hasLength(1));
      },
    );
  }

  test(
    'court-first free throw preserves draft on failure and clears on retry',
    () async {
      final db = createTestDatabase();
      var failWrite = false;
      final now = DateTime.utc(2026, 11, 16, 10);
      final service = MatchCommandService(
        db,
        now: () => now,
        failureInjector: (point) {
          if (failWrite &&
              point == MatchCommandFailurePoint.afterEventWritten) {
            throw StateError('write failed');
          }
        },
      );
      final started = await service.start(
        StartMatchCommand(
          recordingMode: RecordingMode.detailed,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplate: const RuleTemplate(
            id: 'standard',
            name: 'Standard',
            scoreButtons: [1, 2, 3],
            scoringConvention: ScoringConvention.standard,
          ),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
        nowUtc: () => now,
      );
      addTearDown(controller.dispose);
      controller.beginOrMoveCourtFirstShot(
        CourtPoint(x: .5, y: 5.8 / 14),
        freeThrowEligible: true,
      );
      failWrite = true;
      MatchCommandFailure? failure;
      try {
        await controller.commitCourtFirstFreeThrow(side: TeamSide.red);
        fail('Expected a failed write');
      } on MatchCommandFailure catch (error) {
        failure = error;
      }
      expect(controller.courtFirstShotDraft, isNotNull);
      expect(await db.select(db.matchEvents).get(), isEmpty);
      failWrite = false;
      final retry = await controller.retryCommandWithReceipt(failure);
      expect(retry.accepted, isTrue);
      expect(retry.receipt, isNull);
      expect(controller.courtFirstShotDraft, isNull);
      expect(controller.state.events.single.type, EventKind.freeThrow);
      expect(controller.locationSupplementWindow, isNull);
      expect(controller.state.shotLocations, isEmpty);
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.score.redScore, 0);
    },
  );
}

MatchSetup _setup(ScoringConvention? convention) => MatchSetup(
  matchId: 'basket-test',
  redName: 'Red',
  blueName: 'Blue',
  ruleTemplateId: 'baskets',
  targetScore: null,
  timerEnabled: false,
  timeLimitMinutes: 10,
  winByTwo: false,
  scoringConvention: convention,
  scoreButtons: convention?.scoreButtons ?? const [1],
);

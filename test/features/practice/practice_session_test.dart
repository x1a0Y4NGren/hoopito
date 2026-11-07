import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/practice/practice_session.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

const setup = MatchSetup(
  matchId: 'ignored-real-id',
  redName: 'Red',
  blueName: 'Blue',
  ruleTemplateId: 'target',
  targetScore: 11,
  timerEnabled: true,
  timeLimitMinutes: 10,
  winByTwo: true,
);

Future<void> reachFinish(PracticeSession session) async {
  await session.start(setup);
  final controller = session.controller!;
  await controller.recordScoreCommitted(side: TeamSide.blue, points: 2);
  expect(session.step, PracticeStep.undo);
  await controller.undoLastScoringActionCommitted();
  expect(session.step, PracticeStep.courtPoint);
  controller.beginDetailedShot(CourtPoint(x: .5, y: .5));
  expect(session.step, PracticeStep.scoreRedTwo);
  controller.updateDetailedShot(side: TeamSide.red, points: 2);
  await controller.commitDetailedShot();
  expect(session.step, PracticeStep.missBlue);
  await controller.recordMissCommitted(side: TeamSide.blue);
  expect(session.step, PracticeStep.finish);
}

void main() {
  test(
    'a different score and a failed write cannot advance the lesson',
    () async {
      var fail = false;
      final session = PracticeSession(
        failureInjector: (point) {
          if (fail && point == MatchCommandFailurePoint.beforeCommit) {
            throw StateError('injected');
          }
        },
      );
      addTearDown(session.close);
      await session.start(setup);
      fail = true;
      await expectLater(
        session.controller!.recordScoreCommitted(
          side: TeamSide.blue,
          points: 2,
        ),
        throwsA(isA<MatchCommandFailure>()),
      );
      expect(session.step, PracticeStep.scoreBlueTwo);
      expect(session.controller!.state.score.blueScore, 0);
      fail = false;
      await session.controller!.recordScoreCommitted(
        side: TeamSide.red,
        points: 2,
      );
      expect(session.step, PracticeStep.scoreBlueTwo);
    },
  );

  test(
    'uses isolated command storage and advances from committed projections',
    () async {
      final session = PracticeSession();
      addTearDown(session.close);
      await reachFinish(session);
      expect(session.controller!.isCommandBacked, isTrue);
      expect(session.controller!.timerEnabled, isFalse);
      expect(session.controller!.state.ruleTemplate.targetScore, isNull);
      expect(session.controller!.state.matchId, isNot(setup.matchId));
      await session.finish(2, 0, TrackingCoverage.shotAttempts);
      expect(session.step, PracticeStep.result);
      expect(session.result!.match.lifecycle, MatchLifecycle.finished);
      expect(
        session.result!.match.trackingCoverage,
        TrackingCoverage.shotAttempts,
      );
    },
  );

  test(
    'finish failure preserves step and can retry the stable command',
    () async {
      var fail = false;
      final session = PracticeSession(
        failureInjector: (point) {
          if (fail && point == MatchCommandFailurePoint.beforeCommit) {
            throw StateError('injected');
          }
        },
      );
      addTearDown(session.close);
      await reachFinish(session);
      fail = true;
      await expectLater(
        session.finish(2, 0, TrackingCoverage.scoresOnly),
        throwsA(isA<MatchCommandFailure>()),
      );
      expect(session.step, PracticeStep.finish);
      expect(session.result, isNull);
      fail = false;
      await session.finish(2, 0, TrackingCoverage.scoresOnly);
      expect(session.step, PracticeStep.result);
    },
  );

  test('closing waits for an outstanding controller transaction', () async {
    final gate = Completer<void>();
    var delay = false;
    final session = PracticeSession(
      failureInjector: (point) async {
        if (delay && point == MatchCommandFailurePoint.beforeCommit) {
          await gate.future;
        }
      },
    );
    await session.start(setup);
    delay = true;
    final write = session.controller!.recordScoreCommitted(
      side: TeamSide.blue,
      points: 2,
    );
    var closed = false;
    final closing = session.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    gate.complete();
    await write;
    await closing;
    expect(closed, isTrue);
  });
}

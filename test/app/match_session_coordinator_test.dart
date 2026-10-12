import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/match_session_coordinator.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

import '../test_helpers/test_database.dart';

void main() {
  test('persists the latest scoring snapshot including undo', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    final coordinator = MatchSessionCoordinator(repository);
    addTearDown(coordinator.dispose);
    const setup = MatchSetup(
      matchId: 'match-session',
      redName: '红方',
      blueName: '蓝方',
      ruleTemplateId: 'free',
      targetScore: 11,
      timerEnabled: false,
      timeLimitMinutes: 10,
      winByTwo: false,
    );

    final controller = coordinator.beginMatch(setup);
    controller.addScore(side: TeamSide.red, points: 2);
    controller.skipPendingLocation();
    controller.undoLastEvent();
    controller.addScore(side: TeamSide.blue, points: 3);
    controller.skipPendingLocation();
    await coordinator.saveCurrent(setup.matchId);

    final detail = await repository.getMatchDetail(setup.matchId);
    expect(detail, isNotNull);
    expect(detail!.events, hasLength(1));
    expect(detail.redScore, 0);
    expect(detail.blueScore, 3);
  });

  test('finished sessions do not overwrite later replay edits', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    final coordinator = MatchSessionCoordinator(repository);
    addTearDown(coordinator.dispose);
    const setup = MatchSetup(
      matchId: 'finished-session',
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplateId: 'free',
      targetScore: null,
      timerEnabled: false,
      timeLimitMinutes: 10,
      winByTwo: false,
    );
    final controller = coordinator.beginMatch(setup);
    controller.addScore(side: TeamSide.red, points: 2);
    controller.skipPendingLocation();
    await coordinator.finishMatch(setup.matchId);
    await repository.updateEventNote(
      eventId: 'finished-session-event-1',
      note: 'Reviewed',
    );

    await coordinator.saveCurrent(setup.matchId);

    final detail = (await repository.getMatchDetail(setup.matchId))!;
    expect(detail.events.single.note, 'Reviewed');
  });
}

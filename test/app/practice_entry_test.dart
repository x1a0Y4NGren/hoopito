import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/practice_entry.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import '../test_helpers/test_database.dart';

void main() {
  test(
    'clock rollback needs consent and a durable stop before practice',
    () async {
      final database = createTestDatabase();
      // Keep the persisted anchor ahead of the repository's real wall clock.
      final anchor = DateTime.now().toUtc().add(const Duration(days: 1));
      var commandNow = anchor;
      final service = MatchCommandService(database, now: () => commandNow);
      await service.start(
        StartMatchCommand(
          matchId: 'rollback',
          startedAt: anchor,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: 'Free',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          timerEnabled: true,
        ),
      );
      commandNow = anchor.subtract(const Duration(seconds: 1));
      final repository = MatchRepository(database);
      final entry = PracticeEntry(repository, service);
      final projected = (await repository.getActiveMatch())!;
      expect(projected.clock!.isRunning, isFalse);
      expect(projected.clock!.requiresPersistence, isTrue);
      expect(projected.clock!.state.runningSinceUtc, isNotNull);

      await expectLater(entry.enter(), throwsA(isA<PracticePauseRequired>()));
      // Merely opening the confirmation must not mutate the real match.
      expect(
        (await database.select(database.matchClocks).getSingle())
            .runningSinceUtc,
        isNotNull,
      );
      await expectLater(
        entry.enter(pauseMatchId: 'rollback'),
        throwsA(isA<ClockRecoveryFailure>()),
      );
      expect(
        (await database.select(database.matchClocks).getSingle())
            .runningSinceUtc,
        isNull,
      );
      final recovered = (await repository.getActiveMatch())!;
      expect(recovered.events.last.customLabel, 'pause');
      expect(recovered.events.last.id, startsWith('clock-recovery-'));
      final stopped = (await entry.enter())!;
      expect(stopped.clock!.state.runningSinceUtc, isNull);
      expect(stopped.clock!.requiresPersistence, isFalse);
      expect(
        stopped.events.map((event) => event.id),
        recovered.events.map((event) => event.id),
      );
      // Passing the former running anchor later cannot restart this real timer.
      commandNow = anchor.add(const Duration(minutes: 1));
      expect((await service.readClock('rollback'))!.isRunning, isFalse);
    },
  );

  test(
    'projected countdown expiry needs a durable decision before entry',
    () async {
      final database = createTestDatabase();
      final anchor = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      var commandNow = anchor;
      final service = MatchCommandService(database, now: () => commandNow);
      await service.start(
        StartMatchCommand(
          matchId: 'expired',
          startedAt: anchor,
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplate: const RuleTemplate(
            id: 'timed',
            name: 'Timed',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          timerEnabled: true,
          clockMode: ClockMode.countdown,
          regulationSeconds: 60,
        ),
      );
      commandNow = anchor.add(const Duration(minutes: 2));
      final repository = MatchRepository(database);
      final entry = PracticeEntry(repository, service);
      final projected = (await repository.getActiveMatch())!;
      expect(projected.decision!.reason, MatchDecisionReason.regulationExpired);
      expect(projected.clock!.requiresPersistence, isTrue);
      expect(projected.clock!.state.runningSinceUtc, isNotNull);
      await expectLater(entry.enter(), throwsA(isA<PracticePauseRequired>()));
      expect(
        (await database.select(database.matchClocks).getSingle())
            .runningSinceUtc,
        isNotNull,
      );
      // Production normalization preserves the decision and asks the route to retry.
      await expectLater(
        entry.enter(pauseMatchId: 'expired'),
        throwsA(isA<EndConditionFailure>()),
      );
      final durable = (await entry.enter())!;
      expect(durable.decision!.reason, MatchDecisionReason.regulationExpired);
      expect(durable.clock!.requiresPersistence, isFalse);
      expect(durable.clock!.state.runningSinceUtc, isNull);
      final eventIds = durable.events.map((event) => event.id).toList();
      // Correcting the clock back inside regulation must not revive its old anchor.
      commandNow = anchor.add(const Duration(seconds: 30));
      final corrected = (await service.readClock('expired'))!;
      expect(corrected.isRunning, isFalse);
      expect(corrected.phase, ClockPhase.regulationExpired);
      final reentered = (await entry.enter())!;
      expect(reentered.decision!.reason, MatchDecisionReason.regulationExpired);
      expect(reentered.events.map((event) => event.id), eventIds);
    },
  );

  test('practice requires consent then pauses the real match once', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    await service.start(
      StartMatchCommand(
        matchId: 'real',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        timerEnabled: true,
      ),
    );
    final entry = PracticeEntry(MatchRepository(database), service);
    await expectLater(entry.enter(), throwsA(isA<PracticePauseRequired>()));
    expect(
      (await MatchRepository(
        database,
      ).getMatchDetail('real'))!.clock!.isRunning,
      isTrue,
    );
    expect((await entry.enter(pauseMatchId: 'real'))!.match.id, 'real');
    final paused = (await MatchRepository(database).getMatchDetail('real'))!;
    expect(paused.clock!.isRunning, isFalse);
    final count = paused.events.length;
    await entry.enter();
    expect(
      (await MatchRepository(database).getMatchDetail('real'))!.events.length,
      count,
    );
  });
  test('entry retains a pending goal decision without writing pause', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    await service.start(
      StartMatchCommand(
        matchId: 'real',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplate: const RuleTemplate(
          id: 'target',
          name: 'Target',
          scoreButtons: [1, 2, 3],
          targetScore: 2,
        ),
        recordingMode: RecordingMode.simple,
      ),
    );
    final before = await service.record(
      RecordMatchEventCommand(
        matchId: 'real',
        side: TeamSide.blue,
        points: 2,
        occurredAt: DateTime.now().toUtc(),
      ),
    );
    final detail = await PracticeEntry(
      MatchRepository(database),
      service,
    ).enter();
    expect(detail!.decision!.reason, MatchDecisionReason.targetReached);
    expect(detail.events.length, before.events.length);
  });
  test('pause failure leaves real match active and running', () async {
    final database = createTestDatabase();
    await MatchCommandService(database).start(
      StartMatchCommand(
        matchId: 'real',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        timerEnabled: true,
      ),
    );
    final failing = MatchCommandService(
      database,
      failureInjector: (point) {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          throw StateError('failure');
        }
      },
    );
    await expectLater(
      PracticeEntry(
        MatchRepository(database),
        failing,
      ).enter(pauseMatchId: 'real'),
      throwsA(isA<MatchCommandFailure>()),
    );
    expect(
      (await MatchRepository(
        database,
      ).getMatchDetail('real'))!.clock!.isRunning,
      isTrue,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart' hide ShotLocation;
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'start atomically persists complete pre-game identity and configuration',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-red', 'Red profile');
        await _insertPlayer(database, 'player-blue', 'Blue profile');
        final command = StartMatchCommand(
          commandId: 'task7-start-complete',
          matchId: 'task7-match-complete',
          redName: 'Red at start',
          blueName: 'Blue at start',
          redPlayerProfileId: 'player-red',
          bluePlayerProfileId: 'player-blue',
          recordingMode: RecordingMode.detailed,
          trackingCoverage: TrackingCoverage.full,
          clockMode: ClockMode.countdown,
          regulationSeconds: 420,
          timerEnabled: true,
          ruleTemplate: const RuleTemplate(
            id: 'task7-rule',
            name: 'Task 7 Rule',
            scoreButtons: [1, 2, 3],
            targetScore: 15,
            timeLimitSeconds: 420,
            winByTwo: true,
            foulLimit: 5,
            possessionHintEnabled: true,
            customEventTypes: ['screen'],
          ),
          createdAt: DateTime.utc(2026, 8, 23, 10),
          startedAt: DateTime.utc(2026, 8, 23, 10),
        );

        final detail = await MatchCommandService(database).start(command);

        expect(detail.match.recordingMode, RecordingMode.detailed);
        expect(detail.match.trackingCoverage, TrackingCoverage.full);
        expect(detail.match.ruleTemplateSnapshot, command.ruleTemplate);
        expect(detail.match.redName, 'Red at start');
        expect(detail.match.blueName, 'Blue at start');
        final participants = await (database.select(
          database.matchParticipants,
        )..where((row) => row.matchId.equals(command.matchId))).get();
        expect(participants, hasLength(2));
        expect(
          participants.singleWhere((row) => row.side == TeamSide.red.name),
          isA<MatchParticipant>()
              .having((row) => row.playerProfileId, 'profile', 'player-red')
              .having((row) => row.nameSnapshot, 'snapshot', 'Red at start'),
        );
        expect(
          participants.singleWhere((row) => row.side == TeamSide.blue.name),
          isA<MatchParticipant>()
              .having((row) => row.playerProfileId, 'profile', 'player-blue')
              .having((row) => row.nameSnapshot, 'snapshot', 'Blue at start'),
        );
        final clock = await (database.select(
          database.matchClocks,
        )..where((row) => row.matchId.equals(command.matchId))).getSingle();
        expect(clock.mode, ClockMode.countdown.name);
        expect(clock.regulationSeconds, 420);
        expect(clock.runningSinceUtc?.toUtc(), command.startedAt);
        expect(await database.select(database.matches).get(), hasLength(1));
        expect(
          await database.select(database.activeSessions).get(),
          hasLength(1),
        );
        expect(
          await (database.select(
            database.auditLogs,
          )..where((row) => row.id.equals(command.commandId))).get(),
          hasLength(1),
        );
      });
    },
  );

  test(
    'count-up timer persists as enabled without a regulation duration',
    () async {
      await withTestDatabase((database) async {
        final command = _command(
          commandId: 'task7-start-count-up',
          matchId: 'task7-match-count-up',
          timerEnabled: true,
          clockMode: ClockMode.countUp,
          regulationSeconds: null,
        );

        await MatchCommandService(database).start(command);

        final match = await database.select(database.matches).getSingle();
        final clock = await database.select(database.matchClocks).getSingle();
        expect(match.timerEnabled, isTrue);
        expect(clock.mode, ClockMode.countUp.name);
        expect(clock.regulationSeconds, isNull);
        expect(clock.runningSinceUtc?.toUtc(), command.startedAt);
      });
    },
  );

  test('missing profile rejects before any start row is written', () async {
    await withTestDatabase((database) async {
      final command = _command(
        commandId: 'task7-start-missing-profile',
        matchId: 'task7-match-missing-profile',
        redPlayerProfileId: 'missing-profile',
      );

      await expectLater(
        MatchCommandService(database).start(command),
        throwsA(isA<CommandValidationFailure>()),
      );

      await _expectNoStartRows(database);
    });
  });

  test('duplicate profile rejects before any start row is written', () async {
    await withTestDatabase((database) async {
      await _insertPlayer(database, 'player-same', 'Same profile');
      final command = _command(
        commandId: 'task7-start-duplicate-profile',
        matchId: 'task7-match-duplicate-profile',
        redPlayerProfileId: 'player-same',
        bluePlayerProfileId: 'player-same',
      );

      await expectLater(
        MatchCommandService(database).start(command),
        throwsA(isA<CommandValidationFailure>()),
      );

      await _expectNoStartRows(database);
    });
  });

  test('invalid countdown rejects before any start row is written', () async {
    await withTestDatabase((database) async {
      final command = _command(
        commandId: 'task7-start-invalid-countdown',
        matchId: 'task7-match-invalid-countdown',
        clockMode: ClockMode.countdown,
        timerEnabled: false,
        regulationSeconds: 0,
      );

      await expectLater(
        MatchCommandService(database).start(command),
        throwsA(isA<CommandValidationFailure>()),
      );

      await _expectNoStartRows(database);
    });
  });

  test(
    'countdown durations require whole minutes within strict boundaries',
    () async {
      for (final seconds in [1, 59, 90, 10801]) {
        await withTestDatabase((database) async {
          final command = _command(
            commandId: 'task7-start-invalid-seconds-$seconds',
            matchId: 'task7-match-invalid-seconds-$seconds',
            clockMode: ClockMode.countdown,
            timerEnabled: true,
            regulationSeconds: seconds,
          );

          await expectLater(
            MatchCommandService(database).start(command),
            throwsA(isA<CommandValidationFailure>()),
          );
          await _expectNoStartRows(database);
        });
      }

      for (final seconds in [60, 10800]) {
        await withTestDatabase((database) async {
          final command = _command(
            commandId: 'task7-start-valid-seconds-$seconds',
            matchId: 'task7-match-valid-seconds-$seconds',
            clockMode: ClockMode.countdown,
            timerEnabled: true,
            regulationSeconds: seconds,
          );

          await MatchCommandService(database).start(command);
          expect(
            (await database.select(database.matchClocks).getSingle())
                .regulationSeconds,
            seconds,
          );
        });
      }
    },
  );
}

StartMatchCommand _command({
  required String commandId,
  required String matchId,
  String? redPlayerProfileId,
  String? bluePlayerProfileId,
  ClockMode clockMode = ClockMode.countUp,
  int? regulationSeconds,
  bool timerEnabled = false,
}) {
  return StartMatchCommand(
    commandId: commandId,
    matchId: matchId,
    redName: 'Red snapshot',
    blueName: 'Blue snapshot',
    redPlayerProfileId: redPlayerProfileId,
    bluePlayerProfileId: bluePlayerProfileId,
    recordingMode: RecordingMode.simple,
    trackingCoverage: TrackingCoverage.scoresOnly,
    clockMode: clockMode,
    regulationSeconds: regulationSeconds,
    timerEnabled: timerEnabled,
    ruleTemplate: const RuleTemplate(
      id: 'free',
      name: 'Free',
      scoreButtons: [1, 2, 3],
    ),
    createdAt: DateTime.utc(2026, 8, 23, 10),
    startedAt: DateTime.utc(2026, 8, 23, 10),
  );
}

Future<void> _insertPlayer(AppDatabase database, String id, String nickname) {
  return database
      .into(database.players)
      .insert(
        PlayersCompanion.insert(
          id: id,
          nickname: nickname,
          createdAt: DateTime.utc(2026, 8, 23),
        ),
      );
}

Future<void> _expectNoStartRows(AppDatabase database) async {
  expect(await database.select(database.matches).get(), isEmpty);
  expect(await database.select(database.matchParticipants).get(), isEmpty);
  expect(await database.select(database.matchClocks).get(), isEmpty);
  expect(await database.select(database.activeSessions).get(), isEmpty);
  expect(await database.select(database.auditLogs).get(), isEmpty);
}

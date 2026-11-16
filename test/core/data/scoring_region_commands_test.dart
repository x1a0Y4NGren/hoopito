import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'a legacy Start command retains its exact payload, fingerprint and retry identity',
    () async {
      // Frozen from the pre-convention payload layout (main@bb7241c).
      final legacy =
          jsonDecode(
                File(
                  'test/fixtures/legacy_start_command.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final command = StartMatchCommand(
        commandId: 'legacy-start',
        matchId: 'legacy-match',
        redName: 'Red',
        blueName: 'Blue',
        recordingMode: RecordingMode.simple,
        redParticipantId: 'legacy-red',
        blueParticipantId: 'legacy-blue',
        clockId: 'legacy-clock',
        createdAt: DateTime.utc(2026, 11, 16, 10),
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
      );
      expect({'commandType': command.commandType, ...command.payload}, legacy);
      expect(
        command.fingerprint,
        '471ea5b57676e6acb0670b6f155f3ec51314c3a51ba33a21582b342ecc521a48',
      );
      final db = createTestDatabase();
      await MatchCommandService(db).start(command);
      final retry = await MatchCommandService(db).start(command);
      expect(retry.match.ruleTemplateSnapshot.scoringConvention, isNull);
      expect(await db.select(db.matches).get(), hasLength(1));
      expect(await db.select(db.auditLogs).get(), hasLength(1));
    },
  );
  for (final convention in ScoringConvention.values) {
    test(
      '$convention validates new located scores inside the transaction',
      () async {
        final db = createTestDatabase();
        final now = DateTime.utc(2026, 11, 16, 10);
        final service = MatchCommandService(db, now: () => now);
        final started = await service.start(
          StartMatchCommand(
            recordingMode: RecordingMode.detailed,
            redName: 'Red',
            blueName: 'Blue',
            ruleTemplate: RuleTemplate(
              id: 'rules',
              name: 'Rules',
              scoreButtons: convention.scoreButtons,
              scoringConvention: convention,
            ),
          ),
        );
        final invalidPoints = switch (convention) {
          ScoringConvention.standard => 2,
          ScoringConvention.onePerBasket => 2,
          ScoringConvention.oneAndTwo => 1,
        };
        final invalid = RecordMatchEventCommand(
          matchId: started.match.id,
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: invalidPoints,
          outcome: ShotOutcome.made,
          occurredAt: now,
          shotLocation: const MatchShotLocationInput(x: .5, y: .9),
        );
        final beforeAudit = await db.select(db.auditLogs).get();
        await expectLater(
          service.record(invalid),
          throwsA(isA<CommandValidationFailure>()),
        );
        expect(await db.select(db.matchEvents).get(), isEmpty);
        expect(await db.select(db.shotLocations).get(), isEmpty);
        expect(
          await db.select(db.auditLogs).get(),
          hasLength(beforeAudit.length),
        );
      },
    );
  }

  test(
    'bad supplements do not consume the score or receipt and valid retry is idempotent',
    () async {
      final db = createTestDatabase();
      final now = DateTime.utc(2026, 11, 16, 10);
      final service = MatchCommandService(db, now: () => now);
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
      final score = RecordMatchEventCommand(
        matchId: started.match.id,
        type: EventKind.fieldGoal,
        side: TeamSide.blue,
        points: 3,
        outcome: ShotOutcome.made,
        occurredAt: now,
      );
      await service.record(score);
      final beforeAudit = await db.select(db.auditLogs).get();
      await expectLater(
        service.confirmShotLocation(
          ConfirmShotLocationCommand(
            matchId: started.match.id,
            eventId: score.eventId,
            point: CourtPoint(x: .5, y: .3),
            requestedAtUtc: now,
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );
      expect(await db.select(db.shotLocations).get(), isEmpty);
      expect(
        await db.select(db.auditLogs).get(),
        hasLength(beforeAudit.length),
      );
      final valid = ConfirmShotLocationCommand(
        matchId: started.match.id,
        eventId: score.eventId,
        point: CourtPoint(x: .5, y: .9),
        requestedAtUtc: now,
      );
      await service.confirmShotLocation(valid);
      final again = await service.confirmShotLocation(valid);
      expect(again.blueScore, 3);
      expect(again.shotLocations, hasLength(1));
    },
  );
}

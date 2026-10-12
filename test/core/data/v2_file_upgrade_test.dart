import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../generated_migrations/schema_v2.dart' as v2;

void main() {
  test(
    'official schema 2 file upgrades without changing canonical rows or undo',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hoopito-v2-upgrade-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/synthetic.sqlite');
      final source = AppDatabase.inMemory();
      addTearDown(source.close);
      AppDatabase? opened;
      addTearDown(() async => opened?.close());
      final started = DateTime.utc(2026, 8, 28, 12);
      var now = started;
      final service = MatchCommandService(source, now: () => now);
      const rules = RuleTemplate(
        id: 'synthetic-custom-rules',
        name: 'Synthetic rule snapshot',
        scoreButtons: [1, 2, 3],
        targetScore: 21,
        winByTwo: true,
        foulLimit: 5,
        customEventTypes: ['Synthetic custom event'],
      );
      await source
          .into(source.players)
          .insert(
            PlayersCompanion.insert(
              id: 'synthetic-player',
              nickname: 'Synthetic renamed profile',
              createdAt: started,
            ),
          );
      final historicalStart = StartMatchCommand(
        commandId: 'synthetic-history-start',
        matchId: 'synthetic-history',
        redName: 'Synthetic original name',
        blueName: 'Synthetic opponent',
        redPlayerProfileId: 'synthetic-player',
        ruleTemplate: rules,
        recordingMode: RecordingMode.detailed,
        trackingCoverage: TrackingCoverage.locations,
        createdAt: started,
      );
      await service.start(historicalStart);
      now = now.add(const Duration(seconds: 10));
      await service.record(
        RecordMatchEventCommand(
          commandId: 'synthetic-history-score',
          matchId: historicalStart.matchId,
          eventId: 'synthetic-history-event',
          side: TeamSide.red,
          points: 2,
          occurredAt: now,
        ),
      );
      final historicalFinish = FinishMatchCommand(
        commandId: 'synthetic-history-finish',
        matchId: historicalStart.matchId,
        endedAt: now,
        confirmFinalScore: true,
        expectedRedScore: 2,
        expectedBlueScore: 0,
      );
      await service.finish(historicalFinish);
      now = now.add(const Duration(minutes: 1));
      final activeStart = StartMatchCommand(
        commandId: 'synthetic-active-start',
        matchId: 'synthetic-active',
        redName: 'Synthetic active red',
        blueName: 'Synthetic active blue',
        ruleTemplate: rules,
        recordingMode: RecordingMode.simple,
        trackingCoverage: TrackingCoverage.full,
        timerEnabled: true,
        clockMode: ClockMode.countdown,
        regulationSeconds: 600,
        createdAt: now,
      );
      await service.start(activeStart);
      now = now.add(const Duration(seconds: 2));
      final first = RecordMatchEventCommand(
        commandId: 'synthetic-first',
        matchId: activeStart.matchId,
        eventId: 'synthetic-first-event',
        type: EventKind.fieldGoal,
        side: TeamSide.red,
        points: 2,
        outcome: ShotOutcome.made,
        occurredAt: now,
        shotLocation: const MatchShotLocationInput(x: .25, y: .75),
      );
      await service.record(first);
      now = now.add(const Duration(seconds: 2));
      // Event time deliberately differs from the durable command order.
      final second = RecordMatchEventCommand(
        commandId: 'synthetic-second',
        matchId: activeStart.matchId,
        eventId: 'synthetic-second-event',
        side: TeamSide.blue,
        points: 3,
        occurredAt: first.occurredAt.subtract(const Duration(seconds: 1)),
      );
      await service.record(second);
      await source
          .into(source.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'synthetic.upgrade.preference',
              valueJson: 'true',
              updatedAt: now,
            ),
          );

      // Create the actual checked-in v1.0 schema, rather than relabeling a v3
      // file. Copy raw values to preserve audit insertion order and receipts.
      final legacy = v2.DatabaseAtV2(NativeDatabase(file));
      await legacy.customSelect('SELECT 1').get();
      final tableNames = source.allTables
          .map((table) => table.actualTableName)
          .where((name) => name != 'player_analytics_snapshots')
          .toList();
      final before = <String, List<Map<String, Object?>>>{};
      await legacy.transaction(() async {
        // The canonical table declaration order is not foreign-key order.
        await legacy.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final name in tableNames) {
          final rows = await source
              .customSelect('SELECT * FROM "$name" ORDER BY rowid')
              .get();
          before[name] = rows.map((row) => row.data).toList();
          for (final row in rows) {
            final columns = row.data.keys.map((key) => '"$key"').join(', ');
            final slots = List.filled(row.data.length, '?').join(', ');
            await legacy.customStatement(
              'INSERT INTO "$name" ($columns) VALUES ($slots)',
              row.data.values.toList(),
            );
          }
        }
      });
      expect(
        (await legacy.customSelect('PRAGMA user_version').getSingle()).data,
        {'user_version': 2},
      );
      await legacy.close();
      await source.close();

      final upgraded = opened = openAppDatabaseAt(file);
      await upgraded.assertCompatible();
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle()).data,
        {'user_version': 3},
      );
      for (final name in tableNames) {
        expect(
          (await upgraded
                  .customSelect('SELECT * FROM "$name" ORDER BY rowid')
                  .get())
              .map((row) => row.data)
              .toList(),
          before[name],
          reason: '$name must remain unchanged during schema 2 migration',
        );
      }
      final repository = MatchRepository(upgraded);
      final historical = (await repository.getMatchDetail(
        historicalStart.matchId,
      ))!;
      expect(historical.match.redName, 'Synthetic original name');
      expect(historical.match.ruleTemplateSnapshot, rules);
      expect(historical.match.trackingCoverage, TrackingCoverage.locations);
      final active = (await repository.getActiveMatch())!;
      expect(active.match.id, activeStart.matchId);
      expect(active.match.trackingCoverage, TrackingCoverage.full);
      expect(active.match.ruleTemplateSnapshot, rules);
      expect(active.shotLocations.single.point.x, .25);
      expect(active.redScore, 2);
      expect(active.blueScore, 3);

      final upgradedService = MatchCommandService(upgraded, now: () => now);
      await upgradedService.finish(historicalFinish);
      await upgradedService.record(second);
      expect(
        (await upgraded
                .customSelect('SELECT * FROM audit_logs ORDER BY rowid')
                .get())
            .map((row) => row.data)
            .toList(),
        before['audit_logs'],
      );
      final undo = UndoLastScoringActionCommand(
        commandId: 'synthetic-upgraded-undo',
        matchId: activeStart.matchId,
      );
      final undone = await upgradedService.undoLastScoringAction(undo);
      expect(undone.redScore, 2);
      expect(undone.blueScore, 0);
      expect(
        undone.events.singleWhere((e) => e.id == second.eventId).isDeleted,
        isTrue,
      );
      expect(
        undone.events.singleWhere((e) => e.id == first.eventId).isDeleted,
        isFalse,
      );
      final afterUndo =
          (await upgraded
                  .customSelect('SELECT * FROM audit_logs ORDER BY rowid')
                  .get())
              .map((row) => row.data)
              .toList();
      await upgraded.close();
      opened = null;

      final reopened = opened = openAppDatabaseAt(file);
      await MatchCommandService(
        reopened,
        now: () => now,
      ).undoLastScoringAction(undo);
      expect(
        (await reopened
                .customSelect('SELECT * FROM audit_logs ORDER BY rowid')
                .get())
            .map((row) => row.data)
            .toList(),
        afterUndo,
      );
      expect((await MatchRepository(reopened).getActiveMatch())!.blueScore, 0);
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}

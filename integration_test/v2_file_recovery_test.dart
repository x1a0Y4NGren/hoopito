import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/data/repositories/player_career_repository.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // This closes and reopens an actual SQLite file and rebuilds the app's
  // provider scope. It does not claim to exercise an Android process restart.
  testWidgets(
    'recovers commands and an active match after file database reopen',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('hoopito-v2-file-recovery-'),
      ))!;
      final file = File(
        '${directory.path}${Platform.pathSeparator}synthetic.sqlite',
      );
      AppDatabase? openDatabase;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(() async {
          await openDatabase?.close();
          await directory.delete(recursive: true);
        });
      });

      const matchId = 'synthetic-file-match';
      const redName = 'Synthetic 红方';
      const blueName = 'Synthetic 蓝方';
      const playerId = 'synthetic-file-player';
      const rules = RuleTemplate(
        id: 'synthetic-file-rules',
        name: 'Synthetic rules snapshot',
        scoreButtons: [1, 2, 3],
        targetScore: 21,
        winByTwo: true,
        foulLimit: 5,
        customEventTypes: ['Synthetic marker'],
      );
      final startedAt = DateTime.utc(2026, 9, 24, 10);
      var commandTime = startedAt;
      final start = StartMatchCommand(
        commandId: 'synthetic-start',
        matchId: matchId,
        redParticipantId: 'synthetic-red-participant',
        blueParticipantId: 'synthetic-blue-participant',
        redName: redName,
        blueName: blueName,
        ruleTemplate: rules,
        recordingMode: RecordingMode.simple,
        createdAt: startedAt,
        startedAt: startedAt,
      );
      final firstScore = RecordMatchEventCommand(
        commandId: 'synthetic-record-red',
        matchId: matchId,
        eventId: 'synthetic-red-score',
        type: EventKind.fieldGoal,
        side: TeamSide.red,
        points: 2,
        outcome: ShotOutcome.made,
        occurredAt: startedAt.add(const Duration(seconds: 20)),
        shotLocation: const MatchShotLocationInput(x: .3, y: .6),
      );
      // Earlier event time intentionally disagrees with the command/audit order.
      final secondScore = RecordMatchEventCommand(
        commandId: 'synthetic-record-blue',
        matchId: matchId,
        eventId: 'synthetic-blue-score',
        side: TeamSide.blue,
        points: 3,
        occurredAt: startedAt.add(const Duration(seconds: 10)),
      );
      final undo = UndoLastScoringActionCommand(
        commandId: 'synthetic-undo',
        auditId: 'synthetic-undo-audit',
        matchId: matchId,
        reason: 'Synthetic recovery check',
      );
      final finish = FinishMatchCommand(
        commandId: 'synthetic-finish',
        matchId: matchId,
        endedAt: startedAt.add(const Duration(minutes: 1)),
        confirmFinalScore: true,
        expectedRedScore: 2,
        expectedBlueScore: 0,
        trackingCoverage: TrackingCoverage.shotAttempts,
      );
      final link = LinkMatchParticipantCommand(
        commandId: 'synthetic-link',
        auditId: 'synthetic-link-audit',
        matchId: matchId,
        participantId: start.redParticipantId,
        playerProfileId: playerId,
      );

      await tester.runAsync(() async {
        final database = openDatabase = openAppDatabaseAt(file);
        final service = MatchCommandService(database, now: () => commandTime);
        await service.start(start);
        commandTime = commandTime.add(const Duration(seconds: 1));
        await service.record(firstScore);
        commandTime = commandTime.add(const Duration(seconds: 1));
        final scored = await service.record(secondScore);
        expect(scored.redScore, 2);
        expect(scored.blueScore, 3);
        final auditBefore = await _auditRows(database);
        expect(
          auditBefore
              .where((row) => row['action'] == 'create')
              .map((row) => row['target_id'])
              .where(
                (id) => id == firstScore.eventId || id == secondScore.eventId,
              ),
          [firstScore.eventId, secondScore.eventId],
        );
        await database.close();
        openDatabase = null;
        expect(await file.exists(), isTrue);

        final reopened = openDatabase = openAppDatabaseAt(file);
        final recoveredService = MatchCommandService(
          reopened,
          now: () => commandTime,
        );
        expect(await _auditRows(reopened), auditBefore);
        final duplicateStart = await recoveredService.start(start);
        expect(duplicateStart.redScore, 0);
        expect(duplicateStart.blueScore, 0);
        final duplicateScore = await recoveredService.record(firstScore);
        expect(duplicateScore.redScore, 2);
        expect(duplicateScore.blueScore, 0);
        await expectLater(
          recoveredService.record(
            RecordMatchEventCommand(
              commandId: firstScore.commandId,
              matchId: matchId,
              eventId: firstScore.eventId,
              type: EventKind.fieldGoal,
              side: TeamSide.red,
              points: 3,
              outcome: ShotOutcome.made,
              occurredAt: firstScore.occurredAt,
            ),
          ),
          throwsA(isA<CommandConflictFailure>()),
        );
        expect(await _auditRows(reopened), auditBefore);
        expect(await reopened.select(reopened.matchEvents).get(), hasLength(2));

        final active = (await MatchRepository(reopened).getActiveMatch())!;
        expect(active.match.id, matchId);
        expect(active.match.redName, redName);
        expect(active.match.blueName, blueName);
        expect(active.match.ruleTemplateSnapshot, rules);
        expect(active.redScore, 2);
        expect(active.blueScore, 3);
        expect(active.shotLocations.single.point.x, .3);
        expect(active.shotLocations.single.point.y, .6);

        commandTime = commandTime.add(const Duration(seconds: 1));
        final undone = await recoveredService.undoLastScoringAction(undo);
        expect(undone.redScore, 2);
        expect(undone.blueScore, 0);
        expect(
          undone.events
              .singleWhere((e) => e.id == firstScore.eventId)
              .isDeleted,
          isFalse,
        );
        expect(
          undone.events
              .singleWhere((e) => e.id == secondScore.eventId)
              .isDeleted,
          isTrue,
        );
        final auditAfterUndo = await _auditRows(reopened);
        final duplicateUndo = await recoveredService.undoLastScoringAction(
          undo,
        );
        expect(duplicateUndo.redScore, 2);
        expect(duplicateUndo.blueScore, 0);
        expect(await _auditRows(reopened), auditAfterUndo);
        final receipts = await reopened.select(reopened.auditLogs).get();
        final receipt = receipts.singleWhere(
          (row) => row.id == firstScore.commandId,
        );
        expect(receipt.action, 'command');
        expect(
          (jsonDecode(receipt.beforeJson) as Map)['fingerprint'],
          firstScore.fingerprint,
        );
      });

      await tester.pumpWidget(
        HoopitoApp(database: openDatabase!, showEntryAnimation: false),
      );
      await _waitFor(tester, find.byKey(homeResumeKey));
      expect(find.textContaining(redName), findsAtLeastNWidgets(1));
      expect(find.textContaining(blueName), findsAtLeastNWidgets(1));
      await _tap(tester, find.byKey(homeResumeKey));
      await _waitFor(tester, find.byType(ScoringPage));
      await _waitForLandscape(tester);
      expect(find.text('2 $redName'), findsOneWidget);
      expect(find.text('$blueName 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.runAsync(() async {
        final reopened = openDatabase!;
        final service = MatchCommandService(reopened, now: () => commandTime);
        commandTime = startedAt.add(const Duration(minutes: 1));
        await service.finish(finish);
        await PlayerRepository(reopened).save(
          Player(
            id: playerId,
            nickname: 'Synthetic renamed profile',
            createdAt: startedAt,
          ),
        );
        await service.linkParticipant(link);
        final terminalAudits = await _auditRows(reopened);
        await reopened.close();
        openDatabase = null;

        final terminal = openDatabase = openAppDatabaseAt(file);
        expect(await _auditRows(terminal), terminalAudits);
        expect(await MatchRepository(terminal).getActiveMatch(), isNull);
        final detail = (await MatchRepository(
          terminal,
        ).getMatchDetail(matchId))!;
        expect(detail.match.lifecycle, MatchLifecycle.finished);
        expect(detail.match.trackingCoverage, TrackingCoverage.shotAttempts);
        expect(detail.match.ruleTemplateSnapshot, rules);
        expect(detail.match.redName, redName);
        expect(detail.match.blueName, blueName);
        expect(
          detail.match.participants
              .singleWhere((p) => p.id == start.redParticipantId)
              .playerProfileId,
          playerId,
        );
        expect(detail.redScore, 2);
        expect(detail.blueScore, 0);
        expect(detail.shotLocations, hasLength(1));
        final terminalService = MatchCommandService(
          terminal,
          now: () => commandTime,
        );
        await terminalService.finish(finish);
        await terminalService.linkParticipant(link);
        expect(await _auditRows(terminal), terminalAudits);
        final career = await PlayerCareerRepository(
          terminal,
        ).getByPlayerId(playerId);
        expect(career.matches, 1);
        expect(career.totalPoints, 2);
      });
      expect(tester.takeException(), isNull);
    },
  );
}

Future<List<Map<String, Object?>>> _auditRows(AppDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT id, action, target_id, before_json, after_json '
        'FROM audit_logs ORDER BY rowid',
      )
      .get();
  return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 180; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for $finder.');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 180; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(finder.hitTestable());
      await tester.pump();
      return;
    }
    if (finder.evaluate().isNotEmpty) await tester.ensureVisible(finder.first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for $finder to become hit-testable.');
}

Future<void> _waitForLandscape(WidgetTester tester) async {
  for (var attempt = 0; attempt < 180; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (tester.view.physicalSize.width > tester.view.physicalSize.height) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for landscape after active-match recovery.');
}

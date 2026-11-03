// Explicit manual Android acceptance entrypoint. Never shipped as the app.
// adb force-stop / cold-launch happens outside this process between actions.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:path_provider/path_provider.dart';

const _files = '/data/data/io.github.x1a0y4ngren.hooptrace/files';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: TargetScoringDeviceFixture()));
}

class TargetScoringDeviceFixture extends StatefulWidget {
  const TargetScoringDeviceFixture({super.key});

  @override
  State<TargetScoringDeviceFixture> createState() => _FixtureState();
}

class _FixtureState extends State<TargetScoringDeviceFixture> {
  AppDatabase? _database;
  String _output = 'Ready: execute adb-selected action';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    var action = 'unread';
    try {
      action = (await File(
        '$_files/target-scoring-action.txt',
      ).readAsString()).trim();
      final runId = (await File(
        '$_files/target-scoring-run-id.txt',
      ).readAsString()).trim();
      _check(RegExp(r'^[a-z0-9-]+$').hasMatch(runId), 'Invalid fixture run ID');
      final documents = await getApplicationDocumentsDirectory();
      final db = _database ??= openAppDatabaseAt(
        File('${documents.path}/target-scoring-fixture.sqlite'),
      );
      final service = MatchCommandService(db);
      final repository = MatchRepository(db);
      MatchDetail? detail;
      Map<String, Object?>? recoveredState;
      final matchId = action.contains('goal')
          ? '$runId-goal'
          : '$runId-continue';
      if (action == 'seed-goal' || action == 'seed-continue') {
        final active = await repository.getActiveMatch();
        if (active != null) {
          await service.abandon(
            AbandonMatchCommand(
              matchId: active.match.id,
              endedAt: DateTime.now(),
            ),
          );
        }
        await service.start(
          StartMatchCommand(
            matchId: matchId,
            redName: 'Synthetic Falcons',
            blueName: 'Synthetic Waves',
            ruleTemplate: const RuleTemplate(
              id: 'device-target',
              name: 'Device target',
              scoreButtons: [1, 2, 3],
              targetScore: 3,
            ),
            recordingMode: RecordingMode.simple,
            trackingCoverage: TrackingCoverage.locations,
            timerEnabled: true,
            clockMode: ClockMode.countdown,
            regulationSeconds: 600,
          ),
        );
        for (final shot in [
          (TeamSide.red, 1),
          (TeamSide.blue, 2),
          (TeamSide.red, 3),
        ]) {
          detail = await service.record(
            RecordMatchEventCommand(
              matchId: matchId,
              side: shot.$1,
              points: shot.$2,
              occurredAt: DateTime.now(),
            ),
          );
        }
        _check(
          detail!.decision?.reason == MatchDecisionReason.targetReached,
          'Winning score must create target decision',
        );
        _check(!detail.clock!.isRunning, 'Target decision must pause clock');
        if (action == 'seed-goal') {
          final event = detail.events.lastWhere((e) => e.points == 3);
          detail = await service.confirmShotLocation(
            ConfirmShotLocationCommand(
              matchId: matchId,
              eventId: event.id,
              point: CourtPoint(x: 0.4, y: 0.6),
              requestedAtUtc: DateTime.now(),
            ),
          );
          _check(
            detail.shotLocations.length == 1,
            'Winning score location must persist before process death',
          );
        }
        if (action == 'seed-continue') {
          detail = await service.continueMatch(
            ContinueMatchCommand(matchId: matchId, occurredAt: DateTime.now()),
          );
          _check(
            detail.decision == null && detail.clock!.isRunning,
            'Continue must clear decision and resume timer',
          );
        }
      } else {
        detail = await repository.getMatchDetail(matchId);
        _check(
          detail != null,
          'Real file database must retain match after death',
        );
        _check(
          detail!.match.redName == 'Synthetic Falcons' &&
              detail.match.blueName == 'Synthetic Waves',
          'Names must survive death',
        );
        _check(
          detail.redScore == 4 && detail.blueScore == 2,
          'Actual overshoot score 4:2 must survive death',
        );
        recoveredState = {
          'score': '${detail.redScore}:${detail.blueScore}',
          'decision': detail.decision?.reason.name,
          'clockRunning': detail.clock?.isRunning,
          'locations': detail.shotLocations.length,
          'continuedTarget': detail.events.any(
            (event) =>
                !event.isDeleted && event.customLabel == 'continueTarget',
          ),
        };
        if (action == 'recover-goal-undo') {
          _check(
            detail.decision?.reason == MatchDecisionReason.targetReached &&
                !detail.clock!.isRunning,
            'Paused goal decision must survive death',
          );
          _check(
            detail.shotLocations.length == 1,
            'Winning score location must survive process death',
          );
          detail = await service.undoLastScoringAction(
            UndoLastScoringActionCommand(
              matchId: matchId,
              undoTargetScore: true,
            ),
          );
          _check(
            detail.redScore == 1 &&
                detail.blueScore == 2 &&
                detail.decision == null &&
                detail.clock!.isRunning &&
                detail.shotLocations.isEmpty,
            'Undo winning score must remove location, clear decision and restore clock',
          );
        } else if (action == 'recover-continue-score') {
          _check(
            detail.decision == null && detail.clock!.isRunning,
            'Target continuation must survive death',
          );
          detail = await service.record(
            RecordMatchEventCommand(
              matchId: matchId,
              side: TeamSide.red,
              points: 1,
              occurredAt: DateTime.now(),
            ),
          );
          _check(
            detail.redScore == 5 && detail.decision == null,
            'Later above-target score must not repeat decision',
          );
          detail = await service.undoLastScoringAction(
            UndoLastScoringActionCommand(matchId: matchId),
          );
          _check(
            detail.redScore == 4 && detail.decision == null,
            'Undo later score must preserve continuation',
          );
        } else if (action == 'expire-continue') {
          // Explicit future projection exercises real countdown normalization;
          // it does not claim ten minutes of actual wall-clock waiting.
          final at = detail.clock!.runningSinceUtc!.add(
            const Duration(seconds: 601),
          );
          await service.readClock(matchId, at: at);
          detail = await repository.getMatchDetail(matchId);
          _check(
            detail!.decision?.reason == MatchDecisionReason.regulationExpired &&
                !detail.clock!.isRunning,
            'Continuation must retain timer expiry decision',
          );
        } else {
          throw StateError('Unknown action: $action');
        }
      }
      _output = jsonEncode({
        'action': action,
        'status': 'PASS',
        'pid': pid,
        'database': '${documents.path}/target-scoring-fixture.sqlite',
        'matchId': detail.match.id,
        'red': detail.match.redName,
        'blue': detail.match.blueName,
        'score': '${detail.redScore}:${detail.blueScore}',
        'decision': detail.decision?.reason.name,
        'clockRunning': detail.clock?.isRunning,
        'locations': detail.shotLocations.length,
        'schema': db.schemaVersion,
        'events': detail.events.length,
        'recoveredState': ?recoveredState,
      });
    } catch (error, stack) {
      _output = jsonEncode({
        'action': action,
        'status': 'FAIL',
        'pid': pid,
        'error': '$error',
        'stack': '$stack',
      });
    }
    debugPrint('TARGET_DEVICE $_output');
    await File(
      '$_files/target-scoring-result.json',
    ).writeAsString(_output, flush: true);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Target scoring device fixture')),
    body: Column(
      children: [
        SizedBox(
          height: 80,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _run,
            child: const Text('Execute action'),
          ),
        ),
        Expanded(child: SingleChildScrollView(child: SelectableText(_output))),
      ],
    ),
  );
}

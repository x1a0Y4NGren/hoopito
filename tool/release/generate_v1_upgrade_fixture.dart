// Run only against the extracted v1.0.0 lib tree; see the Python wrapper.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
// This generator compiles against the authentic archived v1 source, whose
// Dart package name and on-device database filename remain hooptrace.
import 'package:hooptrace/core/data/app_database.dart';
import 'package:hooptrace/core/data/commands/match_command_service.dart';
import 'package:hooptrace/core/domain/domain_enums.dart';
import 'package:hooptrace/core/domain/entities/rule_template.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

Future<void> main(List<String> arguments) async {
  final output = Directory(arguments.single);
  final database = AppDatabase(
    NativeDatabase(File('${output.path}/hooptrace.sqlite')),
  );
  var now = DateTime.utc(2026, 8, 28, 12);
  final service = MatchCommandService(database, now: () => now);
  final commands = <Map<String, Object?>>[];
  const rules = RuleTemplate(
    id: 'upgrade-rules',
    name: 'Synthetic original rules',
    scoreButtons: [1, 2, 3],
    targetScore: 21,
    winByTwo: true,
    foulLimit: 5,
    customEventTypes: ['Synthetic custom event'],
  );

  void remember(MatchCommand command) {
    commands.add({
      'commandType': command.commandType,
      'fingerprint': command.fingerprint,
      'payload': command.payload,
    });
    now = now.add(const Duration(seconds: 2));
  }

  Future<void> start(
    String id,
    TrackingCoverage coverage, {
    bool timed = false,
  }) async {
    final command = StartMatchCommand(
      commandId: '$id:start',
      matchId: id,
      redName: 'Synthetic original red',
      blueName: 'Synthetic blue opponent',
      redParticipantId: '$id:red',
      blueParticipantId: '$id:blue',
      redPlayerProfileId: 'upgrade-player',
      clockId: '$id:clock',
      ruleTemplate: rules,
      recordingMode: RecordingMode.detailed,
      trackingCoverage: coverage,
      timerEnabled: timed,
      clockMode: timed ? ClockMode.countdown : ClockMode.countUp,
      regulationSeconds: timed ? 600 : null,
      createdAt: now,
      startedAt: now,
    );
    await service.start(command);
    remember(command);
  }

  Future<void> record(
    String id,
    String matchId,
    TeamSide side,
    int points, {
    EventKind type = EventKind.score,
    ShotOutcome? outcome,
    bool located = false,
    DateTime? occurredAt,
  }) async {
    final command = RecordMatchEventCommand(
      commandId: id,
      eventId: '$id:event',
      auditId: '$id:audit',
      matchId: matchId,
      side: side,
      points: points,
      type: type,
      outcome: outcome,
      occurredAt: occurredAt ?? now,
      shotLocation: located
          ? const MatchShotLocationInput(x: .25, y: .75)
          : null,
      shotLocationId: located ? '$id:location' : null,
    );
    await service.record(command);
    remember(command);
  }

  Future<void> finish(String id, int red, int blue) async {
    final command = FinishMatchCommand(
      commandId: '$id:finish',
      matchId: id,
      endedAt: now,
      confirmFinalScore: true,
      expectedRedScore: red,
      expectedBlueScore: blue,
    );
    await service.finish(command);
    remember(command);
  }

  try {
    if (database.schemaVersion != 2) {
      throw StateError('Fixture generation requires genuine v1 schema 2.');
    }
    await database
        .into(database.players)
        .insert(
          PlayersCompanion.insert(
            id: 'upgrade-player',
            nickname: 'Synthetic original red',
            createdAt: now,
          ),
        );
    await database
        .into(database.ruleTemplates)
        .insert(
          RuleTemplatesCompanion.insert(
            id: rules.id,
            name: rules.name,
            scoreButtonsJson: '[1,2,3]',
            targetScore: const Value(21),
            winByTwo: const Value(true),
            foulLimit: const Value(5),
            customEventTypesJson: const Value('["Synthetic custom event"]'),
          ),
        );

    const scores = 'upgrade-history-scores';
    await start(scores, TrackingCoverage.scoresOnly);
    await record(
      'upgrade-history-made',
      scores,
      TeamSide.red,
      2,
      type: EventKind.fieldGoal,
      outcome: ShotOutcome.made,
      located: true,
    );
    await record(
      'upgrade-history-miss',
      scores,
      TeamSide.red,
      0,
      type: EventKind.fieldGoal,
      outcome: ShotOutcome.missed,
    );
    await record(
      'upgrade-history-ft',
      scores,
      TeamSide.blue,
      1,
      type: EventKind.freeThrow,
      outcome: ShotOutcome.made,
    );
    await record('upgrade-history-undone', scores, TeamSide.blue, 3);
    final undo = UndoLastScoringActionCommand(
      commandId: 'upgrade-history-undo',
      matchId: scores,
      auditId: 'upgrade-history-undo:audit',
      reason: 'Synthetic mistaken score',
    );
    await service.undoLastScoringAction(undo);
    remember(undo);
    await finish(scores, 2, 1);

    const locations = 'upgrade-history-locations';
    await start(locations, TrackingCoverage.locations);
    await record(
      'upgrade-locations-made',
      locations,
      TeamSide.blue,
      3,
      type: EventKind.fieldGoal,
      outcome: ShotOutcome.made,
      located: true,
    );
    await record(
      'upgrade-locations-miss',
      locations,
      TeamSide.red,
      0,
      type: EventKind.fieldGoal,
      outcome: ShotOutcome.missed,
    );
    await finish(locations, 0, 3);

    const active = 'upgrade-active';
    await start(active, TrackingCoverage.full, timed: true);
    final firstTime = now;
    await record(
      'upgrade-active-first',
      active,
      TeamSide.red,
      2,
      type: EventKind.fieldGoal,
      outcome: ShotOutcome.made,
      located: true,
    );
    // Undo must follow durable audit order, rather than client event time.
    await record(
      'upgrade-active-second',
      active,
      TeamSide.blue,
      3,
      occurredAt: firstTime.subtract(const Duration(seconds: 1)),
    );
    final pause = PauseMatchCommand(
      commandId: 'upgrade-active-pause',
      matchId: active,
      occurredAt: now,
    );
    await service.pause(pause);
    remember(pause);

    await (database.update(
      database.players,
    )..where((row) => row.id.equals('upgrade-player'))).write(
      const PlayersCompanion(nickname: Value('Synthetic renamed profile')),
    );
    await (database.update(
      database.ruleTemplates,
    )..where((row) => row.id.equals(rules.id))).write(
      const RuleTemplatesCompanion(
        name: Value('Synthetic edited template'),
        targetScore: Value(31),
      ),
    );
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'synthetic.upgrade.preference',
            valueJson: 'true',
            updatedAt: now,
          ),
        );

    final tables = <String, Object?>{};
    for (final table in database.allTables) {
      final name = table.actualTableName;
      tables[name] =
          (await database
                  .customSelect(
                    'SELECT rowid AS _rowid_, * FROM "$name" ORDER BY rowid',
                  )
                  .get())
              .map((row) => row.data)
              .toList();
    }
    await File('${output.path}/baseline.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'fixture_format': 1,
        'schema': 2,
        'synthetic_only': true,
        'commands': commands,
        'tables': tables,
        'expected': {
          'history_scores': {'red': 2, 'blue': 1, 'coverage': 'scoresOnly'},
          'history_locations': {
            'red': 0,
            'blue': 3,
            'coverage': 'locations',
            'confirmed_fg_locations': 1,
            'recorded_fg_attempts': 2,
          },
          'active_match': active,
          'active_score': {'red': 2, 'blue': 3},
          'active_coverage': 'full',
          'next_undo_event': 'upgrade-active-second:event',
          'after_next_undo': {'red': 2, 'blue': 0},
          'second_undo_event': 'upgrade-active-first:event',
          'after_second_undo': {'red': 0, 'blue': 0},
        },
      }),
    );
  } finally {
    await database.close();
  }
}

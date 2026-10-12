import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:uuid/uuid.dart';

import '../../test_helpers/test_database.dart';

void main() {
  late _LongMatch fixture;
  setUpAll(() async {
    fixture = await withTestDatabase(_generateLongMatch);
  });

  test(
    '135 real commands round trip receipts, audit chronology and live undo',
    () async {
      final database = createTestDatabase();
      final codec = JsonBackupCodec(database, appVersion: '2.0.0');
      await codec.restore(fixture.finishedBackup);
      final document = codec.decodeAndValidate(await codec.export());
      final source = codec.decodeAndValidate(fixture.finishedBackup);
      final receipts = document.audits
          .where((row) => row.action == 'command')
          .toList();

      expect(receipts, hasLength(135));
      expect(document.events, hasLength(120));
      expect(document.events.where((event) => event.isDeleted), hasLength(12));
      expect(
        document.audits.map((row) => row.id),
        source.audits.map((row) => row.id),
      );
      expect(
        document.audits.map((row) => row.beforeJson),
        source.audits.map((row) => row.beforeJson),
      );
      expect(
        document.audits.map((row) => row.afterJson),
        source.audits.map((row) => row.afterJson),
      );
      final detail = await MatchRepository(
        database,
      ).getMatchDetail(fixture.matchId);
      expect(detail!.redScore, 120);
      expect(detail.blueScore, 32);
      expect(detail.match.trackingCoverage, TrackingCoverage.scoresOnly);
      expect(document.snapshots, hasLength(2));
      expect(
        document.snapshots.every((row) => row.trackingCoverage == 'scoresOnly'),
        isTrue,
      );

      final service = MatchCommandService(database);
      await service.record(fixture.lastRecord);
      await service.finish(fixture.finish);
      await service.setTrackingCoverage(fixture.correction);
      expect(
        await database.select(database.auditLogs).get(),
        hasLength(document.audits.length),
      );
      expect(
        (await database.select(database.matchEvents).get()).where(
          (event) => event.isDeleted,
        ),
        hasLength(12),
      );

      // A second restore exercises the active session and real persisted undo
      // order after process restart, including twelve existing tombstones.
      await codec.restore(fixture.activeBackup);
      final undone = await MatchCommandService(database).undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: _id('after-restore-undo'),
          matchId: fixture.matchId,
        ),
      );
      expect(
        undone.events
            .singleWhere((event) => event.id == _id('event-118'))
            .isDeleted,
        isTrue,
      );
      expect(undone.redScore, 117);
      expect(undone.blueScore, 32);

      final counts = source.manifest.recordCounts;
      // Release evidence measures the actual exported command projections. It
      // deliberately retains every receipt rather than estimating row sizes.
      debugPrint(
        'v2 long-match capacity: ${utf8.encode(fixture.finishedBackup).length} bytes; 135 commands; rows=$counts; total=${counts.values.fold(0, (sum, count) => sum + count)}',
      );
    },
  );

  test('real-command backup round trips at exact capacity limits', () async {
    final database = createTestDatabase();
    final source = JsonBackupCodec(
      database,
      appVersion: '2.0.0',
    ).decodeAndValidate(fixture.finishedBackup);
    final counts = source.manifest.recordCounts.values;
    final measured = utf8.encode(fixture.finishedBackup).length;
    final largestTable = counts.reduce(
      (left, right) => left > right ? left : right,
    );
    final totalRows = counts.fold(0, (sum, count) => sum + count);
    final codec = JsonBackupCodec(
      database,
      appVersion: '2.0.0',
      now: () => DateTime.utc(2026, 9, 24, 12),
      maxPayloadBytes: measured,
      maxRowsPerTable: largestTable,
      maxTotalRows: totalRows,
    );

    await codec.restore(fixture.finishedBackup);
    final exported = await codec.export();
    expect(utf8.encode(exported).length, measured);
    expect(exported, fixture.finishedBackup);
    await codec.restore(exported);
    expect(await codec.export(), exported);

    final gateway = _Gateway();
    await ExportCoordinator(
      database,
      codec,
      gateway: gateway,
      automaticBackup: AutomaticBackupService(database, codec),
    ).shareJsonBackup(subject: 'backup');
    expect(gateway.shares, 1);

    for (final limits in [
      (
        table: largestTable - 1,
        total: totalRows,
        kind: BackupCapacityLimit.rowsPerTable,
      ),
      (
        table: largestTable,
        total: totalRows - 1,
        kind: BackupCapacityLimit.totalRows,
      ),
    ]) {
      final overLimit = JsonBackupCodec(
        database,
        appVersion: '2.0.0',
        maxRowsPerTable: limits.table,
        maxTotalRows: limits.total,
      );
      await expectLater(
        overLimit.export(),
        throwsA(
          isA<BackupCapacityException>().having(
            (error) => error.limitKind,
            'limitKind',
            limits.kind,
          ),
        ),
      );
      await expectLater(
        overLimit.restore(exported),
        throwsA(
          isA<BackupCapacityException>().having(
            (error) => error.limitKind,
            'limitKind',
            limits.kind,
          ),
        ),
      );
      expect(await codec.export(), exported);
    }
  });

  test(
    'the same long-match payload rejects lower byte budgets before import or sharing',
    () async {
      final database = createTestDatabase();
      final fullCodec = JsonBackupCodec(database, appVersion: '2.0.0');
      await fullCodec.restore(fixture.finishedBackup);
      final measured = utf8.encode(fixture.finishedBackup).length;
      final bounded = JsonBackupCodec(
        database,
        appVersion: '2.0.0',
        now: () => DateTime.utc(2026, 9, 24, 12),
        maxPayloadBytes: measured - 1,
      );
      expect(
        () => bounded.decodeAndValidate(fixture.finishedBackup),
        throwsA(
          isA<BackupCapacityException>()
              .having((error) => error.measured, 'measured', measured)
              .having((error) => error.limit, 'limit', measured - 1),
        ),
      );
      final gateway = _Gateway();
      final coordinator = ExportCoordinator(
        database,
        bounded,
        gateway: gateway,
        automaticBackup: AutomaticBackupService(database, bounded),
      );
      await expectLater(
        coordinator.shareJsonBackup(subject: 'backup'),
        throwsA(isA<BackupCapacityException>()),
      );
      expect(gateway.shares, 0);
      expect(
        (await database.select(database.matches).get()).single.id,
        fixture.matchId,
      );
      expect(
        (await database.select(database.auditLogs).get()).where(
          (row) => row.action == 'command',
        ),
        hasLength(135),
      );
    },
  );

  test(
    'coverage edits merge onto fresh match IDs without rewriting receipt fingerprints',
    () async {
      final source = await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        await service.start(_start('coverage-merge', redName: 'Imported Red'));
        await service.finish(_finish('coverage-merge'));
        await service.setTrackingCoverage(_coverage('coverage-merge'));
        return JsonBackupCodec(database, appVersion: '2.0.0').export();
      });
      final merged = await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        await service.start(_start('coverage-merge', redName: 'Local Red'));
        await service.finish(_finish('coverage-merge'));
        final localCommand = SetTrackingCoverageCommand(
          commandId: _id('coverage-merge-correction'),
          matchId: _id('coverage-merge'),
          trackingCoverage: TrackingCoverage.locations,
          reason: 'Local completeness confirmed.',
        );
        await service.setTrackingCoverage(localCommand);
        final codec = JsonBackupCodec(database, appVersion: '2.0.0');
        final result = await BackupMergeService.withCodec(
          database,
          codec: codec,
        ).merge(source);
        final importedId = result.idMap['matches']![_id('coverage-merge')]!;
        expect(importedId, isNot(_id('coverage-merge')));
        final audits = await database.select(database.auditLogs).get();
        final correction = _coverage('coverage-merge');
        final editId =
            result.idMap['auditLogs']!['${correction.commandId}:audit']!;
        final edit = audits.singleWhere((row) => row.id == editId);
        expect(edit.matchId, importedId);
        expect(edit.targetId, importedId);
        expect(jsonDecode(edit.beforeJson), {
          'matchId': importedId,
          'trackingCoverage': 'scoresOnly',
        });
        expect(jsonDecode(edit.afterJson), {
          'matchId': importedId,
          'trackingCoverage': 'shotAttempts',
        });
        final receiptId = result.idMap['auditLogs']![correction.commandId]!;
        final receipt = audits.singleWhere((row) => row.id == receiptId);
        expect(
          (jsonDecode(receipt.beforeJson) as Map)['fingerprint'],
          correction.fingerprint,
        );
        expect((jsonDecode(receipt.afterJson) as Map)['matchId'], importedId);
        final originalAuditCount = audits.length;
        await service.setTrackingCoverage(localCommand);
        expect(
          await database.select(database.auditLogs).get(),
          hasLength(originalAuditCount),
        );

        expect(
          (await BackupMergeService.withCodec(
            database,
            codec: codec,
          ).merge(source)).changed,
          isFalse,
        );

        final fresh = SetTrackingCoverageCommand(
          commandId: _id('imported-fresh-correction'),
          matchId: importedId,
          trackingCoverage: TrackingCoverage.scoresOnly,
          reason: 'An attempt was missing.',
        );
        await service.setTrackingCoverage(fresh);
        await service.setTrackingCoverage(fresh);
        return (
          roundTrip: await codec.export(),
          fresh: fresh,
          importedId: importedId,
        );
      });
      final restored = createTestDatabase();
      await JsonBackupCodec(
        restored,
        appVersion: '2.0.0',
      ).restore(merged.roundTrip);
      await MatchCommandService(restored).setTrackingCoverage(merged.fresh);
      final restoredDetail = await MatchRepository(
        restored,
      ).getMatchDetail(merged.importedId);
      expect(
        restoredDetail!.match.trackingCoverage,
        TrackingCoverage.scoresOnly,
      );
      final restoredAudits = await restored.select(restored.auditLogs).get();
      expect(
        restoredAudits.where((row) => row.id == merged.fresh.commandId),
        hasLength(1),
      );
    },
  );
}

Future<_LongMatch> _generateLongMatch(AppDatabase database) async {
  final service = MatchCommandService(
    database,
    now: () => DateTime.utc(2026, 9, 24, 12),
  );
  for (final name in ['red', 'blue']) {
    await database
        .into(database.players)
        .insert(
          PlayerRow(
            id: _id('profile-$name'),
            nickname: 'Player $name',
            createdAt: DateTime.utc(2026, 9, 24),
          ),
        );
  }
  final start = _start('long-match', profiles: true);
  await service.start(start);
  late RecordMatchEventCommand lastRecord;
  for (var index = 0; index < 120; index++) {
    final phase = index % 6;
    final made = phase != 1 && phase != 3;
    final freeThrow = phase == 2 || phase == 3;
    final points = switch (phase) {
      0 => 2,
      2 => 1,
      4 => 3,
      5 => 2,
      _ => 0,
    };
    lastRecord = RecordMatchEventCommand(
      commandId: _id('record-$index'),
      eventId: _id('event-$index'),
      auditId: _id('audit-$index'),
      matchId: start.matchId,
      type: freeThrow ? EventKind.freeThrow : EventKind.fieldGoal,
      side: index.isEven ? TeamSide.red : TeamSide.blue,
      points: points,
      outcome: made ? ShotOutcome.made : ShotOutcome.missed,
      occurredAt: DateTime.utc(
        2026,
        9,
        24,
        9,
      ).add(Duration(seconds: index * 15)),
    );
    await service.record(lastRecord);
    if (index % 10 == 9) {
      await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: _id('undo-$index'),
          auditId: _id('undo-audit-$index'),
          matchId: start.matchId,
          reason: 'Recorded twice.',
        ),
      );
    }
  }
  final codec = JsonBackupCodec(
    database,
    appVersion: '2.0.0',
    now: () => DateTime.utc(2026, 9, 24, 12),
  );
  final activeBackup = await codec.export();
  final finish = FinishMatchCommand(
    commandId: _id('long-finish'),
    matchId: start.matchId,
    endedAt: DateTime.utc(2026, 9, 24, 10),
    confirmFinalScore: true,
    trackingCoverage: TrackingCoverage.shotAttempts,
  );
  await service.finish(finish);
  final correction = SetTrackingCoverageCommand(
    commandId: _id('long-correction'),
    matchId: start.matchId,
    trackingCoverage: TrackingCoverage.scoresOnly,
    reason: 'One early attempt was not recorded.',
  );
  await service.setTrackingCoverage(correction);
  return _LongMatch(
    matchId: start.matchId,
    activeBackup: activeBackup,
    finishedBackup: await codec.export(),
    lastRecord: lastRecord,
    finish: finish,
    correction: correction,
  );
}

StartMatchCommand _start(
  String name, {
  String redName = 'Red',
  bool profiles = false,
}) => StartMatchCommand(
  commandId: _id('$name-start'),
  matchId: _id(name),
  redName: redName,
  blueName: 'Blue',
  redParticipantId: _id('$name-red'),
  blueParticipantId: _id('$name-blue'),
  clockId: _id('$name-clock'),
  redPlayerProfileId: profiles ? _id('profile-red') : null,
  bluePlayerProfileId: profiles ? _id('profile-blue') : null,
  ruleTemplate: const RuleTemplate(
    id: 'free',
    name: 'Free play',
    scoreButtons: [1, 2, 3],
  ),
  recordingMode: RecordingMode.detailed,
  createdAt: DateTime.utc(2026, 9, 24, 9),
  startedAt: DateTime.utc(2026, 9, 24, 9),
);

FinishMatchCommand _finish(String name) => FinishMatchCommand(
  commandId: _id('$name-finish'),
  matchId: _id(name),
  endedAt: DateTime.utc(2026, 9, 24, 10),
  confirmFinalScore: true,
);
SetTrackingCoverageCommand _coverage(String name) => SetTrackingCoverageCommand(
  commandId: _id('$name-correction'),
  matchId: _id(name),
  trackingCoverage: TrackingCoverage.shotAttempts,
  reason: 'Every attempt was recorded.',
);
String _id(String name) =>
    const Uuid().v5(Namespace.url.value, 'https://hooptrace.test/backup/$name');

class _LongMatch {
  const _LongMatch({
    required this.matchId,
    required this.activeBackup,
    required this.finishedBackup,
    required this.lastRecord,
    required this.finish,
    required this.correction,
  });
  final String matchId;
  final String activeBackup;
  final String finishedBackup;
  final RecordMatchEventCommand lastRecord;
  final FinishMatchCommand finish;
  final SetTrackingCoverageCommand correction;
}

class _Gateway implements ExportGateway {
  int shares = 0;
  @override
  Future<ExportArtifact?> pickBackup({String? dialogTitle}) async => null;
  @override
  Future<BackupDirectorySelection?> pickDirectory({
    String? dialogTitle,
  }) async => null;
  @override
  Future<void> share(
    List<ExportArtifact> artifacts, {
    required String subject,
  }) async {
    shares++;
  }
}

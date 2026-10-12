import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart' as domain;
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late MatchRepository repository;

  setUp(() async {
    database = createTestDatabase();
    repository = MatchRepository(database);
    await repository.createMinimalMatch(
      id: 'match-1',
      redName: 'Red',
      blueName: 'Blue',
      createdAt: DateTime.utc(2026),
    );
    await repository.saveEvent(
      MatchEvent.score(
        id: 'global-event-id',
        matchId: 'match-1',
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026),
      ),
    );
    await repository.saveShotLocation(
      domain.ShotLocation(
        id: 'location-1',
        matchId: 'match-1',
        eventId: 'global-event-id',
        point: CourtPoint(x: 0.2, y: 0.3),
        isConfirmed: true,
      ),
    );
  });

  test(
    'moves a confirmed location and audits coordinates atomically',
    () async {
      await repository.moveShotLocation(
        locationId: 'location-1',
        point: CourtPoint(x: 0.8, y: 0.7),
        reason: '录像复核',
      );

      final detail = (await repository.getMatchDetail('match-1'))!;
      expect(detail.shotLocations.single.point.toJson(), {'x': 0.8, 'y': 0.7});
      final audit = (await repository.listAuditLogs('match-1')).single;
      expect(audit.targetId, 'location-1');
      expect(audit.action.name, 'edit');
      expect(audit.reason, '录像复核');
      expect(audit.diff.before, containsPair('x', 0.2));
      expect(audit.diff.after, containsPair('y', 0.7));
    },
  );

  test(
    'soft delete and note edit keep history and write audit snapshots',
    () async {
      await repository.updateEventNote(
        eventId: 'global-event-id',
        note: '右侧出手',
      );
      await repository.softDeleteEvent(
        eventId: 'global-event-id',
        reason: '误触',
      );

      final detail = (await repository.getMatchDetail('match-1'))!;
      expect(detail.events.single.isDeleted, isTrue);
      expect(detail.redScore, 0);
      expect(detail.shotAttemptCount, 0);
      final logs = await repository.listAuditLogs('match-1');
      expect(logs.map((log) => log.targetId), everyElement('global-event-id'));
      expect(logs.map((log) => log.action.name), ['delete', 'edit']);
      expect(jsonEncode(logs.last.diff.after), contains('右侧出手'));
    },
  );

  test('rapid audit entries keep real wall-clock timestamps', () async {
    for (var index = 0; index < 3; index++) {
      await repository.updateEventNote(
        eventId: 'global-event-id',
        note: 'note-$index',
      );
    }
    final recordedBy = DateTime.now().toUtc();

    final logs = await repository.listAuditLogs('match-1');

    for (final log in logs) {
      expect(log.createdAt.isAfter(recordedBy), isFalse);
    }
  });
}

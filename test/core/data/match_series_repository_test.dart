import 'dart:io';
import 'package:drift_dev/api/migrations_native.dart';
import '../../generated_migrations/schema.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart' hide MatchSeries;
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

StartMatchCommand first({String? profile}) => StartMatchCommand(
  redName: 'A',
  blueName: 'B',
  redPlayerProfileId: profile,
  ruleTemplate: const RuleTemplate(
    id: 'free',
    name: 'Free',
    scoreButtons: [1, 2, 3],
  ),
  recordingMode: RecordingMode.simple,
  seriesContext: const SeriesStartContext(
    seriesId: 'series',
    expectedRevision: 0,
    gameNumber: 1,
    create: true,
  ),
);
Future<void> finish(AppDatabase database, String id) =>
    MatchCommandService(database).finish(
      FinishMatchCommand(
        matchId: id,
        endedAt: DateTime.now(),
        confirmFinalScore: true,
      ),
    );
void main() {
  for (final version in [2, 3]) {
    test('schema $version migrates to 4 with an empty series graph', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(version);
      addTearDown(schema.close);
      schema.rawDatabase.execute(
        "INSERT INTO players (id,nickname,created_at) VALUES ('p','Historic player',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO matches (id,lifecycle,rule_template_json,created_at,note) VALUES ('m','finished','{}',1,'Historical match')",
      );
      schema.rawDatabase.execute(
        "INSERT INTO match_participants (id,match_id,side,name_snapshot,player_profile_id) VALUES ('mp','m','red','Name at game','p')",
      );
      final database = AppDatabase(schema.newConnection());
      addTearDown(database.close);
      await verifier.migrateAndValidate(database, 4);
      expect(
        (await database.select(database.matches).getSingle()).note,
        'Historical match',
      );
      expect(
        (await database.select(database.players).getSingle()).nickname,
        'Historic player',
      );
      final participant = await database
          .select(database.matchParticipants)
          .getSingle();
      expect(participant.playerProfileId, 'p');
      expect(participant.nameSnapshot, 'Name at game');
      expect(await database.select(database.matchSeries).get(), isEmpty);
      expect(await database.select(database.seriesMatches).get(), isEmpty);
    });
  }

  test(
    'only eligible imported matches resume, and a committed receipt still resolves after close',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final service = MatchCommandService(database);
      final repo = MatchSeriesRepository(database);
      final member = first();
      final ordinary = StartMatchCommand(
        redName: 'X',
        blueName: 'Y',
        ruleTemplate: member.ruleTemplate,
        recordingMode: RecordingMode.simple,
      );
      Future<void> imported(String id) async {
        await service.abandon(
          AbandonMatchCommand(matchId: id, endedAt: DateTime.now()),
        );
        await (database.update(
          database.matches,
        )..where((t) => t.id.equals(id))).write(
          const MatchesCompanion(note: Value(importedIncompleteNoteMarker)),
        );
      }

      await service.start(ordinary);
      await imported(ordinary.matchId);
      await service.start(member);
      await imported(member.matchId);
      final ordinaryResume = ResumeImportedIncompleteMatchCommand(
        matchId: ordinary.matchId,
      );
      final memberResume = ResumeImportedIncompleteMatchCommand(
        matchId: member.matchId,
      );
      await expectLater(
        service.resumeImportedIncomplete(ordinaryResume),
        throwsA(isA<CommandValidationFailure>()),
      );
      await repo.close(
        seriesId: 'series',
        expectedRevision: 1,
        intentId: 'close',
      );
      await expectLater(
        service.resumeImportedIncomplete(memberResume),
        throwsA(isA<CommandValidationFailure>()),
      );
      expect(await database.select(database.activeSessions).get(), isEmpty);
      await repo.reopen(
        seriesId: 'series',
        expectedRevision: 2,
        intentId: 'reopen',
      );
      await service.resumeImportedIncomplete(memberResume);
      expect(
        (await database.select(database.activeSessions).getSingle()).matchId,
        member.matchId,
      );
      await finish(database, member.matchId);
      await repo.close(
        seriesId: 'series',
        expectedRevision: 3,
        intentId: 'close2',
      );
      await service.resumeImportedIncomplete(memberResume);
      expect(await database.select(database.activeSessions).get(), isEmpty);
      await service.resumeImportedIncomplete(ordinaryResume);
      expect(
        (await database.select(database.activeSessions).getSingle()).matchId,
        ordinary.matchId,
      );
    },
  );
  test(
    'concurrent prepared starts claim precisely one numbered game and abandoned scores do not count',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final repo = MatchSeriesRepository(database);
      final service = MatchCommandService(database);
      final initial = first();
      await service.start(initial);
      await service.record(
        RecordMatchEventCommand(
          matchId: initial.matchId,
          side: TeamSide.red,
          points: 3,
          occurredAt: DateTime.now(),
        ),
      );
      await service.abandon(
        AbandonMatchCommand(matchId: initial.matchId, endedAt: DateTime.now()),
      );
      final before = (await repo.getOpenSeries())!;
      expect(
        [
          before.completedGames,
          before.slotAWins,
          before.slotBWins,
          before.draws,
        ],
        [0, 0, 0, 0],
      );
      final commands = await Future.wait([
        repo.prepareNext('series'),
        repo.prepareNext('series', swapSides: true),
      ]);
      final outcomes = await Future.wait(
        commands.map((command) async {
          try {
            await MatchCommandService(database).start(command);
            return true;
          } on ActiveMatchConflictFailure {
            return false;
          }
        }),
      );
      expect(outcomes.where((ok) => ok), hasLength(1));
      final after = (await repo.getOpenSeries())!;
      expect(after.games.map((g) => g.gameNumber), [1, 2]);
      expect(after.revision, 2);
      expect(after.nextGameNumber, 3);
      expect(await database.select(database.matches).get(), hasLength(2));
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );
    },
  );
  test(
    'active guards, unique open series and reactive edited scores',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final repo = MatchSeriesRepository(database);
      final command = first();
      await MatchCommandService(database).start(command);
      await expectLater(
        repo.close(seriesId: 'series', expectedRevision: 1, intentId: 'active'),
        throwsA(isA<SeriesFailure>()),
      );
      await finish(database, command.matchId);
      final updates = <MatchSeries?>[];
      final subscription = repo.watchSeries('series').listen(updates.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(updates.last!.draws, 1);
      await database
          .into(database.matchEvents)
          .insert(
            MatchEventsCompanion.insert(
              id: 'edit',
              matchId: command.matchId,
              type: 'score',
              side: const Value('blue'),
              points: const Value(2),
              occurredAt: DateTime.now(),
            ),
          );
      await pumpEventQueue();
      expect(updates.last!.slotBWins, 1);
      expect(updates.last!.draws, 0);
      await database.delete(database.matches).go();
      await pumpEventQueue();
      expect(updates.last!.completedGames, 0);
      await expectLater(
        database
            .into(database.matchSeries)
            .insert(
              MatchSeriesCompanion.insert(
                id: 'other',
                slotAName: 'X',
                slotBName: 'Y',
                createdAt: DateTime.now(),
                defaultSetupJson: '{}',
              ),
            ),
        throwsA(anything),
      );
    },
  );

  test(
    'atomic rollback and receipt-first retry preserve series numbering',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final command = first();
      await expectLater(
        MatchCommandService(
          database,
          failureHook: () => throw StateError('fail'),
        ).start(command),
        throwsA(anything),
      );
      expect(await database.select(database.matchSeries).get(), isEmpty);
      expect(await database.select(database.matches).get(), isEmpty);
      await MatchCommandService(database).start(command);
      await finish(database, command.matchId);
      final repo = MatchSeriesRepository(database);
      await repo.close(
        seriesId: 'series',
        expectedRevision: 1,
        intentId: 'close',
      );
      await MatchCommandService(database).start(command);
      expect((await repo.getSeries('series'))!.nextGameNumber, 2);
      await repo.close(
        seriesId: 'series',
        expectedRevision: 1,
        intentId: 'close',
      );
      await repo.reopen(
        seriesId: 'series',
        expectedRevision: 2,
        intentId: 'reopen',
      );
      await repo.close(
        seriesId: 'series',
        expectedRevision: 1,
        intentId: 'close',
      );
      expect((await repo.getSeries('series'))!.isOpen, isTrue);
      await expectLater(
        repo.close(seriesId: 'series', expectedRevision: 1, intentId: 'other'),
        throwsA(isA<SeriesFailure>()),
      );
    },
  );
  test(
    'fixed slots aggregate swapped games, stale starts rejected, empty groups retain defaults',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final repo = MatchSeriesRepository(database);
      final service = MatchCommandService(database);
      final command = first();
      await service.start(command);
      await service.record(
        RecordMatchEventCommand(
          matchId: command.matchId,
          side: TeamSide.red,
          points: 2,
          occurredAt: DateTime.now(),
        ),
      );
      await finish(database, command.matchId);
      final next = await repo.prepareNext('series', swapSides: true);
      expect(next.blueName, 'A');
      expect(next.trackingCoverage, TrackingCoverage.scoresOnly);
      await repo.close(
        seriesId: 'series',
        expectedRevision: 1,
        intentId: 'close',
      );
      await repo.reopen(
        seriesId: 'series',
        expectedRevision: 2,
        intentId: 'reopen',
      );
      await expectLater(service.start(next), throwsA(isA<SeriesFailure>()));
      final current = await repo.prepareNext('series', swapSides: true);
      await service.start(current);
      await service.record(
        RecordMatchEventCommand(
          matchId: current.matchId,
          side: TeamSide.blue,
          points: 3,
          occurredAt: DateTime.now(),
        ),
      );
      await finish(database, current.matchId);
      var group = (await repo.getSeries('series'))!;
      expect(group.slotAWins, 2);
      expect(group.slotBWins, 0);
      await database.delete(database.matches).go();
      group = (await repo.getSeries('series'))!;
      expect(group.games, isEmpty);
      expect(group.nextGameNumber, 3);
      expect(group.completedGames, 0);
      expect(group.draws, 0);
      expect((await repo.prepareNext('series')).blueName, 'A');
      final ordinary = StartMatchCommand(
        redName: 'C',
        blueName: 'D',
        ruleTemplate: current.ruleTemplate,
        recordingMode: RecordingMode.simple,
      );
      expect(ordinary.payload.containsKey('seriesContext'), isFalse);
      await expectLater(service.start(ordinary), throwsA(isA<SeriesFailure>()));
    },
  );
  test(
    'file cold reopen retains lifecycle intents and deleted profile snapshots',
    () async {
      final dir = await Directory.systemTemp.createTemp('series-test-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/series.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      addTearDown(() => database.close());
      await database
          .into(database.players)
          .insert(
            PlayersCompanion.insert(
              id: 'player',
              nickname: 'Profile',
              createdAt: DateTime.now(),
            ),
          );
      final command = first(profile: 'player');
      await MatchCommandService(database).start(command);
      await finish(database, command.matchId);
      await MatchSeriesRepository(
        database,
      ).close(seriesId: 'series', expectedRevision: 1, intentId: 'closed');
      await database.delete(database.players).go();
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      final repo = MatchSeriesRepository(database);
      await repo.close(
        seriesId: 'series',
        expectedRevision: 1,
        intentId: 'closed',
      );
      final group = (await repo.getSeries('series'))!;
      expect(group.slotAName, 'A');
      expect(group.slotAPlayerProfileId, isNull);
      expect(group.isOpen, isFalse);
      await repo.reopen(
        seriesId: 'series',
        expectedRevision: 2,
        intentId: 'reopened',
      );
      await MatchCommandService(
        database,
      ).start(await repo.prepareNext('series'));
    },
  );
}

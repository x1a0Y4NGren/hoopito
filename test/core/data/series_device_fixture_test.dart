import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/settings/scoring_guide_preferences.dart';

import '../../generated_migrations/schema_v3.dart' as legacy;

void main() {
  test(
    'device fixtures retain between-game and active series in a real database',
    () async {
      const output = String.fromEnvironment('SERIES_FIXTURE_DIR');
      final directory = output.isEmpty
          ? await Directory.systemTemp.createTemp('hoopito-series-fixtures-')
          : await Directory(output).create(recursive: true);
      if (output.isEmpty) addTearDown(() => directory.delete(recursive: true));
      final legacyFile = File('${directory.path}/legacy.sqlite');
      if (await legacyFile.exists()) {
        throw StateError('Refusing to overwrite legacy fixture');
      }
      final old = legacy.DatabaseAtV3(NativeDatabase(legacyFile));
      const rule =
          '{"id":"free","name":"自由计分","scoreButtons":[1,2,3],"targetScore":null,"timeLimitSeconds":null,"winByTwo":false,"foulLimit":null,"possessionHintEnabled":false,"possessionPolicy":"manual","customEventTypes":[]}';
      await old.customStatement(
        'INSERT INTO matches (id,lifecycle,rule_template_json,created_at,ended_at,note) VALUES (?,?,?,?,?,?)',
        ['legacy-game', 'finished', rule, 1, 2, '跨升级保留的比赛'],
      );
      for (final side in ['red', 'blue']) {
        await old.customStatement(
          'INSERT INTO match_participants (id,match_id,side,name_snapshot) VALUES (?,?,?,?)',
          ['legacy-$side', 'legacy-game', side, side == 'red' ? '旧红方' : '旧蓝方'],
        );
      }
      await old.customStatement(
        'INSERT INTO match_clocks (id,match_id) VALUES (?,?)',
        ['legacy-clock', 'legacy-game'],
      );
      expect(
        (await old.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        3,
      );
      await old.close();
      for (final active in [false, true]) {
        final file = File(
          '${directory.path}/${active ? 'active' : 'between'}.sqlite',
        );
        if (await file.exists()) {
          throw StateError('Refusing to overwrite fixture $file');
        }
        var database = AppDatabase(NativeDatabase(file));
        final service = MatchCommandService(database);
        final first = StartMatchCommand(
          matchId: 'fixture-first',
          redName: '小陈',
          blueName: '阿林',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: '自由计分',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          seriesContext: const SeriesStartContext(
            seriesId: 'fixture-series',
            expectedRevision: 0,
            gameNumber: 1,
            create: true,
          ),
        );
        await service.start(first);
        await service.record(
          RecordMatchEventCommand(
            matchId: first.matchId,
            side: TeamSide.red,
            points: 2,
            occurredAt: DateTime.now(),
          ),
        );
        await service.finish(
          FinishMatchCommand(
            matchId: first.matchId,
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        if (active) {
          final next = await MatchSeriesRepository(
            database,
          ).prepareNext('fixture-series', swapSides: true);
          await service.start(next);
          await service.record(
            RecordMatchEventCommand(
              matchId: next.matchId,
              side: TeamSide.blue,
              points: 3,
              occurredAt: DateTime.now(),
            ),
          );
        }
        await ScoringGuidePreferences(database).markSeen();
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        final restored = (await MatchSeriesRepository(
          database,
        ).getOpenSeries())!;
        expect(restored.slotAWins, 1);
        expect(restored.games, hasLength(active ? 2 : 1));
        expect(restored.games.last.slotAScore, active ? 3 : 2);
        expect(
          await database.select(database.activeSessions).get(),
          hasLength(active ? 1 : 0),
        );
        await database.close();
      }
    },
  );
}

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain;
import 'package:hoopito/core/domain/entities/match_series.dart'
    show SeriesStartContext;
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

RuleTemplate _rule(ScoringConvention convention) => RuleTemplate(
  id: convention.name,
  name: convention.name,
  scoreButtons: convention.scoreButtons,
  scoringConvention: convention,
);

domain.Match _match(RuleTemplate rule) => domain.Match(
  id: 'match-${rule.id}',
  createdAt: DateTime.utc(2026, 11, 16),
  endedAt: DateTime.utc(2026, 11, 16, 0, 10),
  lifecycle: domain.MatchLifecycle.finished,
  redName: 'Red',
  blueName: 'Blue',
  ruleTemplateSnapshot: rule,
);

void main() {
  for (final convention in ScoringConvention.values) {
    test('persists $convention in templates, snapshots and presets', () async {
      final database = createTestDatabase();
      final rules = RuleTemplateRepository(database);
      final matches = MatchRepository(database);
      final rule = _rule(convention);

      await rules.save(rule);
      await matches.saveMatch(_match(rule));

      expect((await rules.getById(rule.id))!.scoringConvention, convention);
      final detail = (await matches.getMatchDetail('match-${rule.id}'))!;
      expect(detail.match.ruleTemplateSnapshot.scoringConvention, convention);
      expect(
        MatchSetupPreset.fromMatchDetail(detail).rules.scoringConvention,
        convention,
      );
    });

    test('backup replace and merge preserve $convention', () async {
      final rule = _rule(convention);
      final payload = await withTestDatabase((source) async {
        await RuleTemplateRepository(source).save(rule);
        await MatchRepository(source).saveMatch(_match(rule));
        return JsonBackupCodec(source, appVersion: 'test').export();
      });

      for (final replace in [true, false]) {
        await withTestDatabase((destination) async {
          if (replace) {
            await JsonBackupCodec(
              destination,
              appVersion: 'test',
            ).restore(payload);
          } else {
            await BackupMergeService(destination).merge(payload);
          }
          final template = (await RuleTemplateRepository(
            destination,
          ).listAll()).singleWhere((item) => item.id == rule.id);
          expect(template.scoringConvention, convention);
          final row =
              (await destination.select(destination.matches).get()).single;
          final detail = (await MatchRepository(
            destination,
          ).getMatchDetail(row.id))!;
          expect(
            detail.match.ruleTemplateSnapshot.scoringConvention,
            convention,
          );
        });
      }
    });
  }

  test('legacy list and map metadata retain unrestricted meaning', () async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);
    for (final metadata in <Object>[
      <String>[],
      {'eventTypes': <String>[], 'possessionHintEnabled': false},
    ]) {
      await database
          .into(database.ruleTemplates)
          .insertOnConflictUpdate(
            RuleTemplatesCompanion.insert(
              id: 'legacy',
              name: 'Legacy',
              scoreButtonsJson: '[1,3,5]',
              customEventTypesJson: Value(jsonEncode(metadata)),
            ),
          );
      final rule = (await repository.getById('legacy'))!;
      expect(rule.scoringConvention, isNull);
      expect(rule.scoreButtons, [1, 3, 5]);
      await repository.save(rule);
      final saved = await (database.select(
        database.ruleTemplates,
      )..where((row) => row.id.equals('legacy'))).getSingle();
      expect(
        (jsonDecode(saved.customEventTypesJson) as Map).containsKey(
          'scoringConvention',
        ),
        isFalse,
      );
    }
  });

  test(
    'legacy match snapshot omits the new field and stays unrestricted',
    () async {
      final database = createTestDatabase();
      const rule = RuleTemplate(
        id: 'old',
        name: 'Old',
        scoreButtons: [1, 3, 5],
      );
      final repository = MatchRepository(database);
      await repository.saveMatch(_match(rule));
      final row = (await database.select(database.matches).get()).single;
      expect(
        (jsonDecode(row.ruleTemplateJson) as Map).containsKey(
          'scoringConvention',
        ),
        isFalse,
      );
      final detail = (await repository.getMatchDetail(row.id))!;
      expect(detail.match.ruleTemplateSnapshot.scoringConvention, isNull);
      expect(
        MatchSetupPreset.fromMatchDetail(detail).rules.scoringConvention,
        isNull,
      );
    },
  );

  for (final convention in <ScoringConvention?>[
    null,
    ...ScoringConvention.values,
  ]) {
    test('next series game and swapping sides preserve $convention', () async {
      final database = createTestDatabase();
      final commands = MatchCommandService(database);
      final first = StartMatchCommand(
        redName: 'A',
        blueName: 'B',
        ruleTemplate: convention == null
            ? const RuleTemplate(
                id: 'old',
                name: 'Old',
                scoreButtons: [1, 2, 3],
              )
            : _rule(convention),
        recordingMode: domain.RecordingMode.simple,
        seriesContext: const SeriesStartContext(
          seriesId: 'series',
          expectedRevision: 0,
          gameNumber: 1,
          create: true,
        ),
      );
      await commands.start(first);
      await commands.finish(
        FinishMatchCommand(
          matchId: first.matchId,
          endedAt: DateTime.now(),
          confirmFinalScore: true,
        ),
      );
      final next = await MatchSeriesRepository(
        database,
      ).prepareNext('series', swapSides: true);
      expect(next.ruleTemplate.scoringConvention, convention);
      expect(next.redName, 'B');
      expect(next.blueName, 'A');
    });
  }

  for (final invalid in <Object>['unknown', 2, false]) {
    test(
      'backup rejects invalid template scoring convention $invalid',
      () async {
        final database = createTestDatabase();
        await database
            .into(database.ruleTemplates)
            .insert(
              RuleTemplatesCompanion.insert(
                id: 'invalid',
                name: 'Invalid',
                scoreButtonsJson: '[1]',
                customEventTypesJson: Value(
                  jsonEncode({
                    'eventTypes': <String>[],
                    'possessionHintEnabled': false,
                    'scoringConvention': invalid,
                  }),
                ),
              ),
            );
        await expectLater(
          JsonBackupCodec(database, appVersion: 'test').export(),
          throwsA(isA<BackupValidationException>()),
        );
      },
    );

    test(
      'backup rejects invalid snapshot scoring convention $invalid',
      () async {
        final database = createTestDatabase();
        await MatchRepository(
          database,
        ).saveMatch(_match(_rule(ScoringConvention.standard)));
        final row = (await database.select(database.matches).get()).single;
        final snapshot =
            (jsonDecode(row.ruleTemplateJson) as Map<String, dynamic>)
              ..['scoringConvention'] = invalid;
        await (database.update(
          database.matches,
        )..where((match) => match.id.equals(row.id))).write(
          MatchesCompanion(ruleTemplateJson: Value(jsonEncode(snapshot))),
        );
        await expectLater(
          JsonBackupCodec(database, appVersion: 'test').export(),
          throwsA(isA<BackupValidationException>()),
        );
      },
    );
  }
}

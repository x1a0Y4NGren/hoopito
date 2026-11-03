import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/series_routes.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import '../../test_helpers/test_database.dart';

void main() {
  test(
    'stale rendered series cannot prepare next after close and reopen',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final service = MatchCommandService(database);
      final repository = MatchSeriesRepository(database);
      final command = StartMatchCommand(
        redName: 'Alex',
        blueName: 'Bo',
        recordingMode: RecordingMode.simple,
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
        seriesContext: const SeriesStartContext(
          seriesId: 'pair',
          expectedRevision: 0,
          gameNumber: 1,
          create: true,
        ),
      );
      await service.start(command);
      await service.finish(
        FinishMatchCommand(
          matchId: command.matchId,
          endedAt: DateTime.now(),
          confirmFinalScore: true,
        ),
      );
      final rendered = (await repository.getSeries('pair'))!;
      await repository.close(
        seriesId: 'pair',
        expectedRevision: rendered.revision,
        intentId: 'close',
      );
      final closed = (await repository.getSeries('pair'))!;
      await repository.reopen(
        seriesId: 'pair',
        expectedRevision: closed.revision,
        intentId: 'reopen',
      );
      await expectLater(
        prepareSeriesNextForSnapshot(repository, rendered),
        throwsA(
          isA<SeriesFailure>().having((e) => e.reason, 'reason', 'stale'),
        ),
      );
      expect(await database.select(database.activeSessions).get(), isEmpty);
      expect((await repository.getSeries('pair'))!.games, hasLength(1));
      final current = (await repository.getSeries('pair'))!;
      final next = await prepareSeriesNextForSnapshot(repository, current);
      expect(next.seriesContext!.expectedRevision, current.revision);
      expect(next.seriesContext!.gameNumber, current.nextGameNumber);
    },
  );
}

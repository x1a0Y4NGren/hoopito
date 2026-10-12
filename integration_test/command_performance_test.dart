import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:integration_test/integration_test.dart';

const _p95Target = Duration(milliseconds: 100);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('event command p95 stays below 100ms on Android reference run', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('hoopito-command-benchmark-'),
    ))!;
    final database = openAppDatabaseAt(
      File('${directory.path}${Platform.pathSeparator}hooptrace.sqlite'),
    );
    addTearDown(
      () => tester.runAsync(() async {
        await database.close();
        await directory.delete(recursive: true);
      }),
    );
    final service = MatchCommandService(database);
    final startedAt = DateTime.utc(2026, 8, 24, 9);
    await service.start(
      StartMatchCommand(
        commandId: 'benchmark-start',
        matchId: 'benchmark-match',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        startedAt: startedAt,
      ),
    );

    final samples = <Duration>[];
    for (var index = 0; index < 105; index++) {
      final watch = Stopwatch()..start();
      await service.record(
        RecordMatchEventCommand(
          commandId: 'benchmark-command-$index',
          matchId: 'benchmark-match',
          eventId: 'benchmark-event-$index',
          side: index.isEven ? TeamSide.red : TeamSide.blue,
          points: 1,
          occurredAt: startedAt.add(Duration(seconds: index)),
        ),
      );
      watch.stop();
      if (index >= 5) samples.add(watch.elapsed);
    }
    samples.sort();
    final p95 = samples[(samples.length * .95).ceil() - 1];

    debugPrint(
      'TASK15_COMMAND_BENCHMARK p95_ms=${p95.inMicroseconds / 1000} '
      'samples=${samples.length}',
    );

    expect(
      p95,
      lessThan(_p95Target),
      reason: 'event command p95 was ${p95.inMicroseconds / 1000}ms',
    );
  });
}

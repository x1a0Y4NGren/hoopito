import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

import '../test_helpers/test_database.dart';

void main() {
  final l10n = AppLocalizationsZh();

  test(
    'ready startup runs built-ins and automatic backup exactly once',
    () async {
      final database = createTestDatabase();
      var ensureCount = 0;
      var backupCount = 0;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          startupEnsureBuiltInsProvider.overrideWith(
            (ref) =>
                () async => ensureCount++,
          ),
          startupAutomaticBackupProvider.overrideWith(
            (ref) =>
                () async => backupCount++,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final first = await container.read(databaseStartupProvider.future);
      final second = await container.read(databaseStartupProvider.future);
      expect(first.isReady, isTrue);
      expect(second.isReady, isTrue);
      expect(ensureCount, 1);
      expect(backupCount, 1);
    },
  );

  testWidgets('app remains usable when automatic backup startup fails', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          startupEnsureBuiltInsProvider.overrideWith((ref) => () async {}),
          startupAutomaticBackupProvider.overrideWith(
            (ref) =>
                () async => throw StateError('backup directory moved'),
          ),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-start-scoring')));
    expect(find.text('球豆'), findsOneWidget);
  });

  testWidgets('built-in startup failure is shown instead of being swallowed', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          startupEnsureBuiltInsProvider.overrideWith(
            (ref) =>
                () async => throw StateError('built-ins failed'),
          ),
          startupAutomaticBackupProvider.overrideWith((ref) => () async {}),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.text(l10n.bootstrapFailureBody));
    expect(find.text(l10n.bootstrapFailureBody), findsOneWidget);
    expect(find.textContaining('built-ins failed'), findsNothing);
  });

  test('restore is allowed only for settled null active state', () async {
    expect(canRestoreBackupFor(const AsyncData<MatchDetail?>(null)), isTrue);
    expect(canRestoreBackupFor(const AsyncLoading<MatchDetail?>()), isFalse);
    // Riverpod exposes previous-state construction as an internal test seam
    // in 3.3.2; this is the exact transient shape a refreshing provider emits.
    final loadingWithPreviousNull = AsyncLoading<MatchDetail?>()
        // ignore: invalid_use_of_internal_member
        .copyWithPrevious(const AsyncData<MatchDetail?>(null));
    expect(canRestoreBackupFor(loadingWithPreviousNull), isFalse);
    // ignore: invalid_use_of_internal_member
    final errorWithPreviousNull =
        AsyncError<MatchDetail?>(
          StateError('active query failed'),
          StackTrace.current,
        )
        // ignore: invalid_use_of_internal_member
        .copyWithPrevious(const AsyncData<MatchDetail?>(null));
    expect(canRestoreBackupFor(errorWithPreviousNull), isFalse);

    final database = createTestDatabase();
    final now = DateTime.utc(2026, 8, 23, 12);
    await MatchCommandService(database).start(
      StartMatchCommand(
        commandId: 'task6-restore-active-start',
        matchId: 'task6-restore-active',
        redName: '红队',
        blueName: '蓝队',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: '自由计分',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        createdAt: now,
        startedAt: now,
      ),
    );
    final active = await MatchRepository(database).getActiveMatch();
    expect(active, isNotNull);
    expect(canRestoreBackupFor(AsyncData<MatchDetail?>(active)), isFalse);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder');
}

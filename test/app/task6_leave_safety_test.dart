import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

void main() {
  final l10n = AppLocalizationsZh();

  test('unknown async states fail closed before inspecting a projection', () {
    final active = _detail();
    // ignore: invalid_use_of_internal_member
    final loadingWithPrevious = AsyncLoading<MatchDetail?>().copyWithPrevious(
      AsyncData<MatchDetail?>(active),
    );
    // ignore: invalid_use_of_internal_member
    final errorWithPrevious =
        AsyncError<MatchDetail?>(StateError('read failed'), StackTrace.current)
        // ignore: invalid_use_of_internal_member
        .copyWithPrevious(AsyncData<MatchDetail?>(active));

    expect(
      leaveClockTransitionFor(loadingWithPrevious, LeaveScoringAction.pause),
      LeaveClockTransition.unknown,
    );
    expect(
      leaveClockTransitionFor(errorWithPrevious, LeaveScoringAction.keep),
      LeaveClockTransition.unknown,
    );
    expect(
      leaveClockTransitionFor(
        const AsyncData<MatchDetail?>(null),
        LeaveScoringAction.pause,
      ),
      LeaveClockTransition.unknown,
    );
  });

  test('terminal or incomplete active projections fail closed', () {
    expect(
      leaveClockTransitionFor(
        AsyncData<MatchDetail?>(_detail(active: false)),
        LeaveScoringAction.keep,
      ),
      LeaveClockTransition.unknown,
    );
    expect(
      leaveClockTransitionFor(
        AsyncData<MatchDetail?>(_detail(missingClock: true)),
        LeaveScoringAction.pause,
      ),
      LeaveClockTransition.unknown,
    );
  });

  test('settled active projection maps every leave clock transition', () {
    final running = AsyncData<MatchDetail?>(_detail(running: true));
    final paused = AsyncData<MatchDetail?>(_detail(running: false));
    final noTimer = AsyncData<MatchDetail?>(_detail(timerEnabled: false));

    expect(
      leaveClockTransitionFor(running, LeaveScoringAction.keep),
      LeaveClockTransition.noCommand,
    );
    expect(
      leaveClockTransitionFor(running, LeaveScoringAction.pause),
      LeaveClockTransition.pause,
    );
    expect(
      leaveClockTransitionFor(paused, LeaveScoringAction.keep),
      LeaveClockTransition.resume,
    );
    expect(
      leaveClockTransitionFor(paused, LeaveScoringAction.pause),
      LeaveClockTransition.noCommand,
    );
    expect(
      leaveClockTransitionFor(noTimer, LeaveScoringAction.keep),
      LeaveClockTransition.noCommand,
    );
    expect(
      leaveClockTransitionFor(noTimer, LeaveScoringAction.pause),
      LeaveClockTransition.noCommand,
    );
  });

  testWidgets(
    'unresolved action-time projection stays in scoring and shows a snackbar',
    (tester) async {
      final database = AppDatabase.inMemory();
      const matchId = 'leave-safety-widget-match';
      final now = DateTime.utc(2026, 8, 23, 12);
      await MatchCommandService(database).start(
        StartMatchCommand(
          commandId: '$matchId-start',
          matchId: matchId,
          redName: '红队',
          blueName: '蓝队',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: '自由计分',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          timerEnabled: true,
          regulationSeconds: 600,
          createdAt: now,
          startedAt: now,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            leaveScoringProjectionProvider(
              matchId,
            ).overrideWithValue(const AsyncLoading<MatchDetail?>()),
          ],
          child: const HoopitoApp(showEntryAnimation: false),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
      await tester.tap(find.byKey(const Key('home-resume')));
      await _pumpUntilFound(tester, find.byType(ScoringPage));

      await tester.tap(find.byKey(const Key('scoring-leave')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('leave-pause-and-leave')));
      await tester.pump();

      expect(find.byType(ScoringPage), findsOneWidget);
      expect(find.text(l10n.routeClockCheckError), findsAtLeastNWidgets(1));
    },
  );
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

MatchDetail _detail({
  bool active = true,
  bool timerEnabled = true,
  bool running = true,
  bool missingClock = false,
}) {
  final now = DateTime.utc(2026, 8, 23, 12);
  final match = Match(
    id: 'leave-safety-match',
    createdAt: now,
    startedAt: now,
    lifecycle: active ? MatchLifecycle.active : MatchLifecycle.finished,
    redName: '红队',
    blueName: '蓝队',
    timerEnabled: timerEnabled,
    ruleTemplateSnapshot: const RuleTemplate(
      id: 'free',
      name: '自由计分',
      scoreButtons: [1, 2, 3],
    ),
  );
  final clock = missingClock
      ? null
      : ClockEngine().project(
          state: ClockState(
            id: 'leave-safety-clock',
            matchId: match.id,
            mode: ClockMode.countUp,
            phase: ClockPhase.regulation,
            accumulatedSeconds: 0,
            runningSinceUtc: running
                ? now.subtract(const Duration(seconds: 1))
                : null,
          ),
          now: now,
        );
  return MatchDetail(
    match: match,
    events: const [],
    shotLocations: const [],
    redScore: 0,
    blueScore: 0,
    redFouls: 0,
    blueFouls: 0,
    shotAttemptCount: 0,
    locatedShotCount: 0,
    clock: clock,
  );
}

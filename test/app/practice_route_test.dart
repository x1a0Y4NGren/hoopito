import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/practice_providers.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/settings/practice_preferences.dart';
import 'package:hoopito/features/practice/practice_flow_page.dart';
import 'package:hoopito/features/settings/settings_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  for (final failPause in [false, true]) {
    testWidgets(
      'settings practice preserves active match through cancel, ${failPause ? 'failure and retry, ' : ''}pause and reentry',
      (tester) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = createTestDatabase();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        });
        await PracticePreferences(database).markInvitationHandled();
        await MatchCommandService(database).start(
          StartMatchCommand(
            matchId: 'real-route',
            redName: 'Real red',
            blueName: 'Real blue',
            ruleTemplate: const RuleTemplate(
              id: 'free',
              name: 'Free',
              scoreButtons: [1, 2, 3],
            ),
            recordingMode: RecordingMode.simple,
            timerEnabled: true,
          ),
        );
        Future<MatchDetail> realMatch() async => (await tester.runAsync(
          () => MatchRepository(database).getActiveMatch(),
        ))!;
        final before = await realMatch();
        await tester.pumpWidget(
          HoopitoApp(database: database, showEntryAnimation: false),
        );
        await _waitFor(tester, find.byTooltip('设置'));
        await tester.tap(find.byTooltip('设置').first);
        await _waitFor(tester, find.byType(SettingsPage));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsPage)),
          listen: false,
        );

        Future<void> openPractice() async {
          final row = find.byKey(const Key('settings-practice-row'));
          await tester.scrollUntilVisible(
            row,
            250,
            scrollable: find
                .descendant(
                  of: find.byType(SettingsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(row);
          await _waitFor(tester, row.hitTestable());
          await tester.tap(row.hitTestable());
        }

        await openPractice();
        await _waitFor(tester, find.byKey(const Key('practice-pause-confirm')));
        expect(container.read(practiceFlowVisibleProvider), isTrue);
        expect(find.byType(PracticeFlowPage), findsNothing);
        await tester.tap(find.byKey(const Key('practice-entry-exit')));
        await _waitFor(tester, find.byType(SettingsPage));
        await _waitUntil(
          tester,
          () => !container.read(practiceFlowVisibleProvider),
        );
        expect(container.read(practiceFlowVisibleProvider), isFalse);
        final cancelled = await realMatch();
        expect(cancelled.clock!.isRunning, isTrue);
        expect(
          cancelled.events.map((event) => event.id),
          before.events.map((event) => event.id),
        );

        await openPractice();
        await _waitFor(tester, find.byKey(const Key('practice-pause-confirm')));
        if (failPause) {
          // Fail the real pause write without replacing the command service or router.
          await tester.runAsync(
            () => database.customStatement('''
          CREATE TEMP TRIGGER reject_practice_pause BEFORE INSERT ON match_events
          WHEN NEW.custom_label = 'pause'
          BEGIN SELECT RAISE(ABORT, 'synthetic pause failure'); END
        '''),
          );
        }
        await tester.tap(find.byKey(const Key('practice-pause-confirm')));
        if (failPause) {
          await _waitFor(tester, find.text('重试'));
          expect(find.byType(PracticeFlowPage), findsNothing);
          expect(container.read(practiceFlowVisibleProvider), isTrue);
          final failed = await realMatch();
          expect(failed.clock!.isRunning, isTrue);
          expect(
            failed.events.map((event) => event.id),
            before.events.map((event) => event.id),
          );
          await tester.runAsync(
            () =>
                database.customStatement('DROP TRIGGER reject_practice_pause'),
          );
          await tester.tap(find.byKey(const Key('practice-pause-confirm')));
          // Retry rechecks current state and asks for pause consent again.
          await _waitFor(tester, find.text('暂停并练习'));
          await tester.tap(find.byKey(const Key('practice-pause-confirm')));
        }
        await _waitFor(tester, find.byType(PracticeFlowPage));
        final paused = await realMatch();
        expect(paused.match.id, before.match.id);
        expect(paused.clock!.isRunning, isFalse);
        expect(
          paused.events.where((event) => event.customLabel == 'pause'),
          hasLength(1),
        );
        expect(
          paused.events.where((event) => event.customLabel == 'resume'),
          isEmpty,
        );
        await _waitFor(
          tester,
          find.byKey(const Key('practice-exit')).hitTestable(),
        );
        await tester.tap(find.byKey(const Key('practice-exit')).hitTestable());
        await _waitFor(tester, find.byType(SettingsPage));
        await _waitUntil(
          tester,
          () => !container.read(practiceFlowVisibleProvider),
        );
        expect(container.read(practiceFlowVisibleProvider), isFalse);
        await openPractice();
        await _waitFor(tester, find.byType(PracticeFlowPage));
        expect(find.byKey(const Key('practice-pause-confirm')), findsNothing);
        expect(container.read(practiceFlowVisibleProvider), isTrue);
        final reentered = await realMatch();
        expect(reentered.match.id, paused.match.id);
        expect(reentered.clock!.isRunning, isFalse);
        expect(
          reentered.events.map((event) => event.id),
          paused.events.map((event) => event.id),
        );
        expect(
          (await tester.runAsync(
            () => PracticePreferences(database).load(),
          ))!.practiceCompleted,
          isFalse,
        );
        await tester.binding.handlePopRoute();
        await _waitFor(tester, find.byType(SettingsPage));
        await _waitUntil(
          tester,
          () => !container.read(practiceFlowVisibleProvider),
        );
        expect(container.read(practiceFlowVisibleProvider), isFalse);
        expect((await realMatch()).clock!.isRunning, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disposing the entire app during practice releases safely', (
    tester,
  ) async {
    final database = createTestDatabase();
    await PracticePreferences(database).markInvitationHandled();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await _waitFor(tester, find.byTooltip('设置'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    container.read(appRouterProvider).go('/practice');
    await _waitFor(
      tester,
      find.byKey(const Key('practice-exit')).hitTestable(),
    );
    expect(container.read(practiceFlowVisibleProvider), isTrue);
    // Dispose the router and ProviderScope together, then flush the deferred release.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  await _waitUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    description: '$finder',
  );
}

// Active match clocks and streams can keep scheduling frames. Wait for the
// observable route state rather than requiring the entire app to become idle.
Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() ready, {
  String description = 'practice visibility release',
}) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Expected routed practice state: $description');
}

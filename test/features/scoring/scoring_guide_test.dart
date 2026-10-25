import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';

void main() {
  for (final language in ['en', 'zh']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'guide Skip is immediately available at 200% in $language $brightness',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(600, 400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHoopitoTheme(brightness: brightness),
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const ScoringPage(
                matchId: 'large-guide',
                showInitialGuide: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final skip = find.byKey(const Key('scoring-guide-skip'));
          final rect = tester.getRect(skip);
          expect(rect.bottom, lessThanOrEqualTo(400));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.height, greaterThanOrEqualTo(48));
          await tester.tap(find.byKey(const Key('scoring-guide-next')));
          await tester.pump();
          await tester.tap(skip);
          await tester.pump();
          expect(find.byKey(const Key('scoring-guide')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final finish in [false, true]) {
    testWidgets(
      'paused ${finish ? 'finish' : 'home'} removes its owned modal',
      (tester) async {
        final showDestination = ValueNotifier(false);
        addTearDown(showDestination.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: showDestination,
              builder: (context, destination, child) => destination
                  ? const Scaffold(body: Text('Destination'))
                  : ScoringPage(
                      matchId: 'pause-exit',
                      onPauseMatch: () async {},
                      onReturnHomePaused: () async =>
                          showDestination.value = true,
                      onFinishWithCoverage: (red, blue, coverage) async =>
                          showDestination.value = true,
                    ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('scoring-finish')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('match-controls-pause')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
        await tester.tap(
          find.byKey(Key(finish ? 'paused-finish' : 'paused-return-home')),
        );
        await tester.pumpAndSettle();
        if (finish) {
          await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
          await tester.pumpAndSettle();
        }
        expect(find.text('Destination'), findsOneWidget);
        expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('guide leaves scoring active and can skip without data changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ScoringController(matchId: 'guide');
    addTearDown(controller.dispose);
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ScoringPage(
          controller: controller,
          showInitialGuide: true,
          onGuideDismissed: () => dismissed++,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('scoring-guide')), findsOneWidget);
    final before = controller.state.events.length;
    await tester.tap(find.byKey(const Key('scoring-guide-next')));
    await tester.pump();
    expect(controller.state.events.length, before);
    await tester.tap(find.byKey(const Key('scoring-guide-skip')));
    await tester.pump();
    expect(find.byKey(const Key('scoring-guide')), findsNothing);
    expect(dismissed, 1);
    expect(controller.state.events.length, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide allows scoring and can reopen from More', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ScoringController(matchId: 'guide-score');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ScoringPage(controller: controller, showInitialGuide: true),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('red-score-2')));
    await tester.pump();
    expect(controller.state.score.redScore, 2);
    expect(controller.state.events, hasLength(1));
    await tester.tap(find.byKey(const Key('scoring-guide-skip')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('scoring-more')));
    await tester.pumpAndSettle();
    final help = find.byKey(const Key('more-quick-guide'));
    await tester.ensureVisible(help);
    await tester.pumpAndSettle();
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-guide')), findsOneWidget);
    expect(controller.state.events, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

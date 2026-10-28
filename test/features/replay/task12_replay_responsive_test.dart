import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';

void main() {
  testWidgets('replay compacts all app bar actions on narrow large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'responsive',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 2,
        blueScore: 1,
        duration: Duration.zero,
        events: const [],
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: ReplayPage(
            controller: controller,
            onShareSummary: (_, _) async {},
            onFinishMatch: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('replay-actions-menu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replay keeps the split review surface overflow-free at 200 percent text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ReplayController(
        data: ReplayMatchData(
          matchId: 'responsive-split',
          redName: 'Red',
          blueName: 'Blue',
          redScore: 2,
          blueScore: 1,
          duration: Duration.zero,
          events: const [],
        ),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReplayPage(controller: controller),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Game timeline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

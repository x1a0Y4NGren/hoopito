import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

import '../../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(360, 800), const Size(640, 400)]) {
        final name = '$language-${brightness.name}-${size.width.toInt()}';
        testWidgets('timer lives in advanced and keeps its setup $name', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final boundary = GlobalKey();
          MatchSetup? setup;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildHoopitoTheme(brightness: brightness),
              builder: (context, child) => RepaintBoundary(
                key: boundary,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: PregamePage(onStartMatch: (value) => setup = value),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(PregamePage)),
          )!;
          final advanced = find.byKey(const Key('pregame-advanced'));
          final clock = find.byKey(const Key('pregame-clock-section'));
          final timer = find.byKey(const Key('pregame-timer'));
          expect(clock, findsNothing);
          expect(timer, findsNothing);
          expect(find.byKey(const Key('pregame-clock-settings')), findsNothing);
          await tester.ensureVisible(find.text(l10n.pregameAdvanced));
          await tester.pumpAndSettle();
          await _capture(tester, boundary, '$name-collapsed');
          await tester.tap(find.text(l10n.pregameAdvanced));
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: advanced, matching: clock),
            findsOneWidget,
          );
          await tester.ensureVisible(timer);
          await tester.pumpAndSettle();
          expect(timer.hitTestable(), findsOneWidget);
          await _capture(tester, boundary, '$name-expanded');
          await tester.tap(timer);
          await tester.pumpAndSettle();
          final countdown = find.byKey(const Key('pregame-clock-countdown'));
          await tester.ensureVisible(countdown);
          await tester.pumpAndSettle();
          await tester.tap(countdown);
          await tester.pumpAndSettle();
          final minutes = find.byKey(const Key('pregame-countdown-minutes'));
          await tester.ensureVisible(minutes);
          await tester.pumpAndSettle();
          await tester.enterText(minutes, '15');
          await tester.pumpAndSettle();
          final fieldLabel = find.text(l10n.pregameCountdownLabel);
          expect(fieldLabel, findsWidgets);
          expect(tester.takeException(), isNull);
          await _capture(tester, boundary, '$name-countdown');
          await tester.ensureVisible(find.text(l10n.pregameAdvanced));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.pregameAdvanced));
          await tester.pumpAndSettle();
          expect(timer, findsNothing);
          await tester.tap(find.text(l10n.pregameAdvanced));
          await tester.pumpAndSettle();
          expect(tester.widget<SwitchListTile>(timer).value, isTrue);
          expect(tester.widget<TextField>(minutes).controller!.text, '15');
          await tester.tap(find.byKey(const Key('pregame-start-match')));
          await tester.pumpAndSettle();
          expect(setup?.timerEnabled, isTrue);
          expect(setup?.clockMode, ClockMode.countdown);
          expect(setup?.timeLimitMinutes, 15);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (!const bool.fromEnvironment('CAPTURE_PREGAME_REFINEMENT')) return;
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('.superpowers/pregame-refinement/previews/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

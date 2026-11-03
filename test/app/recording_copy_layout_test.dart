import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/recording_confirmation.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

import '../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(360, 800), const Size(640, 400)]) {
        final name = '$language-${brightness.name}-${size.width.toInt()}';
        testWidgets('complete recording choice at 200 percent $name', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final boundary = GlobalKey();
          MatchSetup? setup;
          await tester.pumpWidget(
            _app(
              language,
              brightness,
              boundary,
              PregamePage(onStartMatch: (value) => setup = value),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(PregamePage)),
          )!;
          final choice = find.byKey(const Key('pregame-coverage-shots'));
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(choice.hitTestable(), findsOneWidget);
          final label = find.descendant(
            of: choice,
            matching: find.text(l10n.v2CoverageComplete),
          );
          _expectFullText(tester, label);
          final button = find.descendant(
            of: choice,
            matching: find.byType(OutlinedButton),
          );
          final textRect = tester.getRect(label);
          final buttonRect = tester.getRect(button);
          expect(buttonRect.height, greaterThanOrEqualTo(48));
          expect(textRect.top, greaterThanOrEqualTo(buttonRect.top));
          expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
          await tester.tap(choice);
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(tester.element(label), alignment: 0.5);
          await tester.pumpAndSettle();
          await _capture(tester, boundary, 'pregame-choice-$name');
          final help = find.text(l10n.v2CoverageHelp);
          await Scrollable.ensureVisible(tester.element(help), alignment: 1);
          await tester.pumpAndSettle();
          _expectFullText(tester, help);
          expect(tester.takeException(), isNull);
          await _capture(tester, boundary, 'pregame-$name');
          await tester.tap(find.byKey(const Key('pregame-start-match')));
          await tester.pumpAndSettle();
          expect(setup?.trackingCoverage, TrackingCoverage.shotAttempts);
          expect(tester.takeException(), isNull);
        });

        testWidgets('complete recording confirmation at 200 percent $name', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final boundary = GlobalKey();
          final results = <TrackingCoverage?>[];
          await tester.pumpWidget(
            _app(
              language,
              brightness,
              boundary,
              Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      key: const Key('open-recording-confirmation'),
                      onPressed: () async {
                        final l10n = AppLocalizations.of(context)!;
                        results.add(
                          await confirmRecordingCoverage(
                            context,
                            title: l10n.confirmFinalScoreTitle,
                            confirmLabel: l10n.finishMatch,
                            initial: TrackingCoverage.shotAttempts,
                            confirmKey: const Key('recording-confirm'),
                            cancelKey: const Key('recording-cancel'),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final open = find.byKey(const Key('open-recording-confirmation'));
          for (final cancel in [true, false]) {
            await tester.tap(open);
            await tester.pumpAndSettle();
            final dialog = find.byType(AlertDialog);
            final l10n = AppLocalizations.of(tester.element(dialog))!;
            final complete = find.byKey(
              const Key('confirm-complete-recording'),
            );
            expect(tester.widget<SwitchListTile>(complete).value, isTrue);
            final label = find.descendant(
              of: complete,
              matching: find.text(l10n.v2CoverageComplete),
            );
            await tester.ensureVisible(label);
            await tester.pumpAndSettle();
            _expectFullText(tester, label);
            final help = find.text(l10n.v2CoverageHelp);
            _expectFullText(tester, help);
            expect(MediaQuery.textScalerOf(tester.element(help)).scale(1), 2);
            if (cancel) await _capture(tester, boundary, 'confirm-$name-top');
            final scroll = find.descendant(
              of: dialog,
              matching: find.byType(Scrollable),
            );
            expect(scroll, findsOneWidget);
            await tester.drag(scroll, const Offset(0, -3000));
            await tester.pumpAndSettle();
            final position = tester.state<ScrollableState>(scroll).position;
            expect(position.pixels, closeTo(position.maxScrollExtent, 1));
            expect(
              tester.getBottomRight(help).dy,
              lessThanOrEqualTo(tester.getBottomRight(scroll).dy + 1),
            );
            expect(
              find.byKey(const Key('recording-confirm')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('recording-cancel')).hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            if (cancel) {
              await _capture(tester, boundary, 'confirm-$name-bottom');
            }
            await tester.tap(
              find.byKey(
                Key(cancel ? 'recording-cancel' : 'recording-confirm'),
              ),
            );
            await tester.pumpAndSettle();
          }
          expect(results, [null, TrackingCoverage.shotAttempts]);
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Widget _app(
  String language,
  Brightness brightness,
  GlobalKey boundary,
  Widget home,
) => MaterialApp(
  locale: Locale(language),
  theme: buildHoopitoTheme(brightness: brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => RepaintBoundary(
    key: boundary,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2)),
      child: child!,
    ),
  ),
  home: home,
);

void _expectFullText(WidgetTester tester, Finder text) {
  expect(text, findsOneWidget);
  final rich = find.descendant(of: text, matching: find.byType(RichText));
  final paragraph = tester.renderObject<RenderParagraph>(rich);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.getMaxIntrinsicHeight(paragraph.size.width),
    lessThanOrEqualTo(paragraph.size.height + 0.01),
    reason:
        'The full text must fit vertically at its actual rendered width '
        '${paragraph.size.width}; a null maxLines must not hide clipped lines.',
  );
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (!const bool.fromEnvironment('CAPTURE_COPY_UI')) return;
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File(
      '.superpowers/copy-polish/previews/recording-$name.png',
    );
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

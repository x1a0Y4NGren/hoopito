import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/design_system/editorial_color_helpers.dart'
    as color_helpers;
import 'package:hoopito/app/design_system/editorial_motion.dart' as motion;
import 'package:hoopito/app/design_system/editorial_theme.dart'
    as editorial_theme;
import 'package:hoopito/app/design_system/editorial_tokens.dart' as tokens;

void main() {
  group('editorial theme', () {
    test('focused modules expose tokens while app_theme stays compatible', () {
      const focusedTheme = editorial_theme.HoopitoEditorialTheme.light();
      const focusedMotion = motion.HoopitoMotionTheme.light();
      final assembledTheme = buildHoopitoTheme();

      expect(tokens.HoopitoColors.offWhite, focusedTheme.canvas);
      expect(focusedMotion.scoreFlight, const Duration(milliseconds: 480));
      expect(
        color_helpers.accessibleForegroundFor(focusedTheme.teamBlue),
        Colors.white,
      );
      expect(
        assembledTheme.extension<HoopitoEditorialTheme>()?.canvas,
        focusedTheme.canvas,
      );
    });

    test('light and dark palettes expose the approved semantic colors', () {
      final light = buildHoopitoTheme().extension<HoopitoEditorialTheme>()!;
      final dark = buildHoopitoTheme(
        brightness: Brightness.dark,
      ).extension<HoopitoEditorialTheme>()!;

      expect(light.canvas, const Color(0xFFF4F3EF));
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.ink, const Color(0xFF101112));
      expect(light.arenaAccent, const Color(0xFFFF5A1F));
      expect(dark.canvas, const Color(0xFF0C0D0E));
      expect(dark.surface, const Color(0xFF151719));
      expect(dark.ink, const Color(0xFFF4F3EF));
      expect(dark.arenaAccent, const Color(0xFFFF6A32));

      for (final palette in [light, dark]) {
        expect(
          _contrast(palette.ink, palette.canvas),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(palette.mutedInk, palette.canvas),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(palette.rule, palette.canvas),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrast(palette.foregroundOnTeam, palette.teamBlue),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(palette.foregroundOnTeam, palette.teamRed),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('motion tokens match the editorial choreography', () {
      const motion = HoopitoMotionTheme.light();

      expect(motion.press, const Duration(milliseconds: 90));
      expect(motion.state, const Duration(milliseconds: 180));
      expect(motion.sheet, const Duration(milliseconds: 220));
      expect(motion.pageReveal, const Duration(milliseconds: 220));
      expect(motion.scoreFlight, const Duration(milliseconds: 480));
      expect(motion.impact, const Duration(milliseconds: 180));
      expect(motion.acceleratedScoreFlight, const Duration(milliseconds: 320));
      expect(motion.acceleratedImpact, const Duration(milliseconds: 120));
      expect(motion.reducedReveal, const Duration(milliseconds: 120));
      expect(motion.entry, const Duration(milliseconds: 1000));
      expect(motion.entryReduced, const Duration(milliseconds: 140));
      expect(motion.entrySkip, const Duration(milliseconds: 120));
      expect(motion.entryPreferenceWait, const Duration(milliseconds: 80));
    });
  });

  group('editorial components', () {
    testWidgets(
      'tap targets and index rows expose a solid high-contrast focus outline',
      (tester) async {
        Future<void> expectFocusOutline(
          Widget widget,
          Type componentType,
          Brightness brightness,
        ) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHoopitoTheme(brightness: brightness),
              home: Scaffold(body: widget),
            ),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();

          final context = tester.element(find.byType(componentType));
          final editorial = Theme.of(
            context,
          ).extension<HoopitoEditorialTheme>()!;
          final outlineFinder = find.descendant(
            of: find.byType(componentType),
            matching: find.byWidgetPredicate((widget) {
              if (widget case DecoratedBox(
                decoration: final BoxDecoration decoration,
              )) {
                final border = decoration.border;
                return widget.position == DecorationPosition.foreground &&
                    border is Border &&
                    border.top.color == editorial.focus &&
                    border.top.style == BorderStyle.solid &&
                    border.top.width >= 2;
              }
              return false;
            }),
          );

          expect(outlineFinder, findsOneWidget);
          final backingFinder = find.descendant(
            of: find.byType(componentType),
            matching: find.byWidgetPredicate((widget) {
              if (widget case DecoratedBox(
                decoration: final BoxDecoration decoration,
              )) {
                final border = decoration.border;
                return widget.position == DecorationPosition.foreground &&
                    border is Border &&
                    border.top.color == Colors.black &&
                    border.top.style == BorderStyle.solid &&
                    border.top.width >= 2;
              }
              return false;
            }),
          );
          expect(backingFinder, findsOneWidget);
          expect(
            _contrast(editorial.focus, Colors.black),
            greaterThanOrEqualTo(3),
          );
        }

        for (final brightness in Brightness.values) {
          await expectFocusOutline(
            EditorialTapTarget(
              onPressed: _noop,
              label: 'Open game',
              child: const Text('Open'),
            ),
            EditorialTapTarget,
            brightness,
          );
          await expectFocusOutline(
            EditorialIndexRow(index: '01', title: 'Latest game', onTap: _noop),
            EditorialIndexRow,
            brightness,
          );
        }
      },
    );

    testWidgets('passive editorial labels use muted ink, not arena orange', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                EditorialMasthead(title: 'Hoopito', eyebrow: 'Game desk'),
                EditorialIndexRow(index: '07', title: 'Latest game'),
              ],
            ),
          ),
        ),
      );

      final editorial = Theme.of(
        tester.element(find.text('GAME DESK')),
      ).extension<HoopitoEditorialTheme>()!;
      expect(
        tester.widget<Text>(find.text('GAME DESK')).style?.color,
        editorial.mutedInk,
      );
      expect(
        tester.widget<Text>(find.text('07')).style?.color,
        editorial.mutedInk,
      );
      expect(editorial.mutedInk, isNot(editorial.arenaAccent));
    });

    testWidgets('replacement labels suppress row and score descendants', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                EditorialIndexRow(
                  index: '07',
                  title: 'Latest game',
                  subtitle: 'Final',
                  semanticLabel: 'Open the latest game',
                ),
                ScoreNumeral(value: 108, semanticLabel: 'Blue team score: 108'),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(EditorialIndexRow)).label,
        'Open the latest game',
      );
      expect(
        tester.getSemantics(find.byType(ScoreNumeral)).label,
        'Blue team score: 108',
      );
      semantics.dispose();
    });

    testWidgets('scaffold responds to width and renders both brightnesses', (
      tester,
    ) async {
      Future<EdgeInsets> pumpAt(double width, Brightness brightness) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHoopitoTheme(brightness: brightness),
            home: const EditorialScaffold(body: Text('desk')),
          ),
        );
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        final palette = Theme.of(
          tester.element(find.text('desk')),
        ).extension<HoopitoEditorialTheme>()!;
        expect(scaffold.backgroundColor, palette.canvas);
        return tester
            .widget<Padding>(find.byKey(const Key('editorial-page-padding')))
            .padding
            .resolve(TextDirection.ltr);
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final compact = await pumpAt(360, Brightness.light);
      final wide = await pumpAt(1200, Brightness.dark);

      expect(compact.left, 16);
      expect(wide.left, 40);
    });

    testWidgets('interactive rows and team actions keep 48 dp targets', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: Scaffold(
            body: Column(
              children: [
                EditorialIndexRow(
                  index: '01',
                  title: 'Latest match',
                  onTap: () {},
                ),
                TeamActionRail(
                  teamLabel: 'Blue team',
                  teamColor: const Color(0xFF1757B8),
                  actions: [
                    TeamActionRailItem(
                      label: 'Add two',
                      icon: Icons.add,
                      onPressed: () {},
                    ),
                    const TeamActionRailItem(
                      label: 'Disabled',
                      icon: Icons.block,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(EditorialIndexRow)).height, 64);
      for (final key in const [Key('team-action-0'), Key('team-action-1')]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('team action rail can present identity before actions exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: const TeamActionRail(
            teamLabel: 'Red team',
            teamColor: Color(0xFFA41E29),
            axis: Axis.vertical,
            actions: [],
          ),
        ),
      );

      expect(find.text('Red team'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'display type uses Barlow only for English mastheads and scores',
      (tester) async {
        Future<TextStyle?> mastheadStyle(Locale locale, String label) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: const [Locale('en'), Locale('zh')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: buildHoopitoTheme(),
              home: EditorialMasthead(title: label),
            ),
          );
          return tester.widget<Text>(find.text(label)).style;
        }

        final english = await mastheadStyle(const Locale('en'), 'HOOPITO');
        final chinese = await mastheadStyle(const Locale('zh'), '篮球记录');
        expect(english?.fontFamily, HoopitoTypography.displayFamily);
        expect(chinese?.fontFamily, isNot(HoopitoTypography.displayFamily));
        expect(
          buildHoopitoTheme().textTheme.bodyMedium?.fontFamily,
          isNot(HoopitoTypography.displayFamily),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildHoopitoTheme(),
            home: const ScoreNumeral(value: '108'),
          ),
        );
        expect(
          tester.widget<Text>(find.text('108')).style?.fontFamily,
          HoopitoTypography.displayFamily,
        );
      },
    );

    testWidgets(
      'system-disabled motion wins and completes press state instantly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHoopitoTheme(),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: EditorialTapTarget(onPressed: _noop, child: Text('Press')),
            ),
          ),
        );

        final animatedScale = tester.widget<AnimatedScale>(
          find.byType(AnimatedScale),
        );
        expect(animatedScale.duration, Duration.zero);
      },
    );

    testWidgets('court branding is opt-in on the shared scaffold', (
      tester,
    ) async {
      Future<int> painterCount({required bool enabled}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHoopitoTheme(),
            home: EditorialScaffold(
              showCourtLines: enabled,
              body: const Text('content'),
            ),
          ),
        );
        return find
            .byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is EditorialCourtLinesPainter,
            )
            .evaluate()
            .length;
      }

      expect(await painterCount(enabled: false), 0);
      expect(await painterCount(enabled: true), 1);
    });
  });

  test('court painter records identical geometry across rebuilds', () {
    const painter = EditorialCourtLinesPainter(color: Color(0xFF777B7E));

    final first = _render(painter);
    final second = _render(painter);

    expect(first, orderedEquals(second));
    expect(painter.shouldRepaint(painter), isFalse);
    expect(
      painter.shouldRepaint(
        const EditorialCourtLinesPainter(color: Color(0xFF101112)),
      ),
      isTrue,
    );
  });
}

void _noop() {}

List<String> _render(CustomPainter painter) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, const Size(240, 160));
  return canvas.invocations
      .map((record) {
        final arguments = record.invocation.positionalArguments
            .map((argument) {
              if (argument is Paint) {
                return 'Paint(${argument.color.toARGB32()},${argument.style},'
                    '${argument.strokeWidth},${argument.strokeCap})';
              }
              return '$argument';
            })
            .join(',');
        return '${record.invocation.memberName}:$arguments';
      })
      .toList(growable: false);
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

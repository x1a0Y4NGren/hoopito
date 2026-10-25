import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light and dark themes expose editorial and motion extensions', () {
    final light = buildHoopitoTheme();
    final dark = buildHoopitoTheme(brightness: Brightness.dark);

    final lightVisual = light.extension<HoopitoEditorialTheme>();
    final darkVisual = dark.extension<HoopitoEditorialTheme>();
    final lightMotion = light.extension<HoopitoMotionTheme>();
    final darkMotion = dark.extension<HoopitoMotionTheme>();

    expect(lightVisual, isNotNull);
    expect(darkVisual, isNotNull);
    expect(lightMotion, isNotNull);
    expect(darkMotion, isNotNull);
    expect(lightVisual!.canvas, HoopitoColors.offWhite);
    expect(darkVisual!.canvas, HoopitoColors.charcoal);
    expect(lightMotion!.scoreFlight, const Duration(milliseconds: 480));
    expect(lightMotion.impact, const Duration(milliseconds: 180));
    expect(darkMotion!.scoreFlight, lightMotion.scoreFlight);
  });

  testWidgets(
    'editorial surface, masthead and rule preserve semantic content',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: const Scaffold(
            body: EditorialSurface(
              child: Column(
                children: [
                  EditorialMasthead(title: 'Court notes'),
                  EditorialSectionRule(),
                  Text('Body copy'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Court notes'), findsOneWidget);
      expect(find.text('Body copy'), findsOneWidget);
      expect(find.byType(EditorialSectionRule), findsWidgets);
    },
  );

  testWidgets(
    'editorial target has a 48dp hit target and pressed visual state',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: Scaffold(
            body: EditorialTapTarget(
              label: 'Add point',
              onPressed: () => presses++,
              child: const Text('Add point'),
            ),
          ),
        ),
      );

      final button = find.byType(EditorialTapTarget);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      final before = tester.widget<AnimatedScale>(
        find.descendant(of: button, matching: find.byType(AnimatedScale)),
      );
      expect(before.scale, 1);

      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      final during = tester.widget<AnimatedScale>(
        find.descendant(of: button, matching: find.byType(AnimatedScale)),
      );
      expect(during.scale, lessThan(1));
      expect(tester.getSemantics(button).rect.width, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(button).rect.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.byType(InkWell)).rect.width,
        greaterThanOrEqualTo(48),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(presses, 1);
      semanticsHandle.dispose();

      var calls = 0;
      final disabledHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: Scaffold(
            body: EditorialTapTarget(
              label: 'Disabled',
              enabled: false,
              onPressed: () => calls++,
              child: const Text('Disabled'),
            ),
          ),
        ),
      );
      final disabledButton = find.byType(EditorialTapTarget);
      expect(
        tester.getSemantics(disabledButton).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await tester.tap(disabledButton);
      expect(calls, 0);
      disabledHandle.dispose();
    },
  );

  testWidgets('editorial target is disabled when no callback is supplied', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: Scaffold(
          body: EditorialTapTarget(
            label: 'Unavailable',
            onPressed: null,
            child: const Text('Unavailable'),
          ),
        ),
      ),
    );

    final button = find.byType(EditorialTapTarget);
    expect(
      tester.getSemantics(button).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    await tester.tap(button);
    await tester.pump();
    expect(
      tester
          .widget<AnimatedScale>(
            find.descendant(of: button, matching: find.byType(AnimatedScale)),
          )
          .scale,
      1,
    );
    semanticsHandle.dispose();
  });

  test(
    'bundled paint animations parse as Lottie compositions with named fills',
    () async {
      for (final asset in [
        'assets/animations/paint_ball.json',
        'assets/animations/paint_splash.json',
      ]) {
        final bytes = await rootBundle.load(asset);
        final json =
            jsonDecode(utf8.decode(bytes.buffer.asUint8List()))
                as Map<String, dynamic>;
        final layers = (json['layers'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final names = layers.map((layer) => layer['nm']).whereType<String>();
        expect(names, contains('teamFill'));
        expect(names, contains('inkFill'));
        final teamLayer = layers.firstWhere(
          (layer) => layer['nm'] == 'teamFill',
        );
        final nestedTeamNames = _nestedNames(teamLayer['shapes']);
        expect(nestedTeamNames, contains('teamFill'));
        final inkLayer = layers.firstWhere((layer) => layer['nm'] == 'inkFill');
        expect(_nestedNames(inkLayer['shapes']), contains('inkFill'));
        final composition = await LottieComposition.fromByteData(bytes);
        expect(composition, isNotNull);
        expect(composition.duration, greaterThan(Duration.zero));
      }
    },
  );
}

Set<String> _nestedNames(Object? value) {
  final names = <String>{};
  if (value is List) {
    for (final item in value) {
      names.addAll(_nestedNames(item));
    }
  } else if (value is Map) {
    final name = value['nm'];
    if (name is String) names.add(name);
    for (final child in value.values) {
      names.addAll(_nestedNames(child));
    }
  }
  return names;
}

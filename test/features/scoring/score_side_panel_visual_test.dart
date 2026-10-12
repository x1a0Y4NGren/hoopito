import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/widgets/score_side_panel.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'action rail uses quiet paper surfaces in ${brightness.name} mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHoopitoTheme(brightness: brightness),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 124,
                  height: 291,
                  child: ScoreSidePanel(
                    side: TeamSide.blue,
                    name: 'BLUE TEAM',
                    score: 23,
                    fouls: 4,
                    onScore: (_) {},
                    onMiss: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        final palette = brightness == Brightness.light
            ? const HoopitoEditorialTheme.light()
            : const HoopitoEditorialTheme.dark();
        final expectedRail = brightness == Brightness.dark
            ? palette.surface
            : palette.canvas;
        final expectedButton = brightness == Brightness.dark
            ? Color.alphaBlend(
                palette.ink.withValues(alpha: 0.045),
                palette.surface,
              )
            : palette.surface;
        final rail = tester.widget<Material>(
          find.byKey(const Key('blue-action-rail')),
        );
        expect(rail.color, expectedRail);
        expect(rail.color, isNot(HoopitoColors.ink));
        final divider = rail.shape! as Border;
        expect(divider.right.color, palette.rule);
        expect(divider.right.width, 1);

        final scoreButton = tester.widget<FilledButton>(
          find.byKey(const Key('blue-score-1')),
        );
        final background = scoreButton.style!.backgroundColor!.resolve({});
        final foreground = scoreButton.style!.foregroundColor!.resolve({});
        final border = scoreButton.style!.side!.resolve({})!;
        expect(background, expectedButton);
        expect(foreground, palette.teamBlue);
        expect(border.color, palette.rule);
        expect(border.width, 1);
        expect(scoreButton.style!.elevation!.resolve({}), 0);
        expect(
          scoreButton.style!.shape!.resolve({}),
          isA<BeveledRectangleBorder>(),
        );
        expect(_contrast(foreground!, background!), greaterThanOrEqualTo(4.5));

        final missButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('blue-miss')),
        );
        final missBackground = missButton.style!.backgroundColor!.resolve({})!;
        final missForeground = missButton.style!.foregroundColor!.resolve({})!;
        final missBorder = missButton.style!.side!.resolve({})!;
        expect(missBorder.color, palette.rule);
        expect(
          _contrast(missForeground, missBackground),
          greaterThanOrEqualTo(4.5),
        );

        final identityLines = tester.widgetList<Container>(
          find.byKey(const Key('blue-action-identity-line')),
        );
        expect(identityLines, hasLength(4));
        for (final line in identityLines) {
          expect(line.color, palette.teamBlue);
          expect(line.constraints?.maxWidth, 3);
        }

        // The scoreboard already owns team identity. The rail header only
        // repeats the foul count so the narrow column stays visually quiet.
        expect(find.text('BLUE TEAM'), findsNothing);
        expect(find.text('犯规 4'), findsOneWidget);
        expect(find.text('23'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('four primary actions stay evenly spaced and at least 48dp', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 124,
              height: 291,
              child: ScoreSidePanel(
                side: TeamSide.red,
                name: 'RED TEAM',
                score: 9,
                fouls: 2,
                onScore: (_) {},
                onMiss: () {},
              ),
            ),
          ),
        ),
      ),
    );

    const keys = [
      Key('red-score-1'),
      Key('red-score-2'),
      Key('red-score-3'),
      Key('red-miss'),
    ];
    final rects = [for (final key in keys) tester.getRect(find.byKey(key))];
    for (final rect in rects) {
      expect(rect.height, greaterThanOrEqualTo(48));
    }
    final centerGaps = [
      for (var index = 1; index < rects.length; index++)
        rects[index].center.dy - rects[index - 1].center.dy,
    ];
    expect(centerGaps[1], closeTo(centerGaps[0], 0.01));
    expect(centerGaps[2], closeTo(centerGaps[0], 0.01));
    expect(tester.takeException(), isNull);
  });
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'replay team foregrounds meet normal-text contrast in $brightness',
      (tester) async {
        final theme = buildHoopitoTheme(brightness: brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: ReplayPage(controller: _contrastController()),
          ),
        );
        await tester.pump();

        final blueName = tester.widget<Text>(find.text('Blue'));
        final redName = tester.widget<Text>(find.text('Red'));
        final blueScore = tester.widget<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == '0' &&
                widget.style?.fontWeight == FontWeight.w800,
          ),
        );
        final redScore = tester.widget<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == '2' &&
                widget.style?.fontWeight == FontWeight.w800,
          ),
        );
        final timelineEvent = tester.widget<Text>(find.text('Red · +2 分'));
        final blueColor = teamColorForScheme(TeamSide.blue, theme.colorScheme);
        final redColor = teamColorForScheme(TeamSide.red, theme.colorScheme);

        expect(blueName.style?.color, blueColor);
        expect(redName.style?.color, redColor);
        expect(blueScore.style?.color, blueColor);
        expect(redScore.style?.color, redColor);
        expect(timelineEvent.style?.color, redColor);
        expect(
          _contrast(blueName.style!.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(redName.style!.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(blueScore.style!.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(redScore.style!.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(timelineEvent.style!.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}

ReplayController _contrastController() {
  return ReplayController(
    data: ReplayMatchData(
      matchId: 'contrast',
      redName: 'Red',
      blueName: 'Blue',
      redScore: 2,
      blueScore: 0,
      duration: const Duration(seconds: 2),
      events: [
        ReplayEventData(
          id: 'score',
          kind: ReplayEventKind.score,
          rawKind: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          elapsed: const Duration(seconds: 2),
        ),
      ],
    ),
  );
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

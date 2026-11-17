import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final convention in ScoringConvention.values) {
    testWidgets('offline region scoring on Android: ${convention.name}', (
      tester,
    ) async {
      final db = AppDatabase.inMemory();
      final service = MatchCommandService(db);
      final detail = await service.start(
        StartMatchCommand(
          redName: 'Test Red',
          blueName: 'Test Blue',
          recordingMode: RecordingMode.detailed,
          ruleTemplate: RuleTemplate(
            id: 'device-rules',
            name: 'Device rules',
            scoreButtons: convention.scoreButtons,
            scoringConvention: convention,
          ),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        detail,
        service,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScoringPage(
            controller: controller,
            motionPreference: MotionPreference.reduced,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final outsideValue = switch (convention) {
        ScoringConvention.standard => 3,
        ScoringConvention.onePerBasket => 1,
        ScoringConvention.oneAndTwo => 2,
      };
      await tester.tap(find.byKey(Key('red-score-$outsideValue')));
      await _wait(
        tester,
        () => controller.state.score.redScore == outsideValue,
      );
      final court = find.byType(CourtView);
      Offset position(double x, double y) =>
          tester.getTopLeft(court) +
          HalfCourtGeometry.pointToOffset(
            CourtPoint(x: x, y: y),
            tester.getSize(court),
          );
      if (convention != ScoringConvention.onePerBasket) {
        await tester.tapAt(position(.5, .3));
        await tester.pump(const Duration(milliseconds: 200));
        expect(controller.state.shotLocations, isEmpty);
        expect(controller.state.score.redScore, outsideValue);
      }
      await tester.tapAt(position(.5, .8));
      await _wait(tester, () => controller.state.shotLocations.length == 1);
      expect(controller.state.events.single.type, EventKind.fieldGoal);
      expect(controller.state.score.redScore, outsideValue);

      if (convention == ScoringConvention.standard) {
        await tester.tap(find.byKey(const Key('blue-score-1')));
        await _wait(tester, () => controller.state.score.blueScore == 1);
        expect(controller.state.events.last.type, EventKind.freeThrow);
        expect(controller.locationSupplementWindow, isNull);
        expect(controller.state.shotLocations, hasLength(1));
      }
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _wait(WidgetTester tester, bool Function() completed) async {
  for (var i = 0; i < 80; i++) {
    if (completed()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    completed(),
    isTrue,
    reason: 'Scoring action did not commit within the bounded wait',
  );
}

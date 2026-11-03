import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import '../../test_helpers/test_database.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import '../../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);
  for (final language in ['en', 'zh']) {
    for (final portrait in [false, true]) {
      for (final brightness in Brightness.values) {
        final name =
            'series_clock_${language}_${portrait ? 'portrait' : 'landscape'}_${brightness.name}_200';
        testWidgets(name, (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = portrait
              ? const Size(390, 844)
              : const Size(740, 360);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final semantics = tester.ensureSemantics();

          final anchor = DateTime.utc(2026);
          final database = createTestDatabase();
          final service = MatchCommandService(database, now: () => anchor);
          final detail = await service.start(
            StartMatchCommand(
              matchId: 'clock-size',
              recordingMode: RecordingMode.simple,
              redName: 'Alex',
              blueName: 'Bo',
              ruleTemplate: const RuleTemplate(
                id: 'free',
                name: 'Free',
                scoreButtons: [1, 2, 3],
              ),
              timerEnabled: true,
              clockMode: ClockMode.countUp,
              createdAt: anchor,
              startedAt: anchor,
            ),
          );
          final controller = ScoringController.fromCommittedProjection(
            detail,
            service,
            nowUtc: () => anchor,
          );
          addTearDown(controller.dispose);
          addTearDown(database.close);
          final contextLabel = language == 'zh' ? '连续对局 #3' : 'Series #3';
          Widget page({String? seriesLabel}) => MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildHoopitoTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const Key('clock-golden'),
              child: ScoringPage(
                key: ValueKey(seriesLabel),
                seriesContextLabel: seriesLabel,
                controller: controller,
                clockNowUtc: () => DateTime.utc(2026),
                motionPreference: MotionPreference.reduced,
              ),
            ),
          );
          await tester.pumpWidget(page());
          await tester.pump();
          final clock = find.text('00:00');
          expect(clock, findsOneWidget);
          final clockRect = tester.getRect(clock);
          final clockStyle = tester.widget<Text>(clock).style;
          final headerRect = tester.getRect(
            find.byKey(const Key('scoring-scoreboard')),
          );
          final courtRect = tester.getRect(
            find.byKey(const Key('scoring-court')),
          );
          await tester.pumpWidget(page(seriesLabel: contextLabel));
          await tester.pump();
          expect(
            clock,
            findsOneWidget,
            reason: 'Series metadata must not join or shrink the clock text.',
          );
          expect(tester.getRect(clock), clockRect);
          expect(tester.widget<Text>(clock).style, clockStyle);
          expect(
            tester.getRect(find.byKey(const Key('scoring-scoreboard'))),
            headerRect,
          );
          expect(
            tester.getRect(find.byKey(const Key('scoring-court'))),
            courtRect,
          );
          expect(find.bySemanticsLabel(contextLabel), findsOneWidget);
          final l = AppLocalizations.of(tester.element(clock))!;
          expect(
            find.bySemanticsLabel(l.scoringMatchTime('00:00')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('clock-golden')),
            matchesGoldenFile(hoopitoGoldenFile(name)),
          );
          semantics.dispose();
        });
      }
    }
  }
}

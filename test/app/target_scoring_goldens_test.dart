import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../support/golden_fonts.dart';
import '../test_helpers/test_database.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);
  final anchor = DateTime.utc(2026, 10, 28);
  for (final stage in ['supplement', 'confirm', 'large']) {
    for (final language in ['zh', 'en']) {
      for (final brightness in Brightness.values) {
        final name = 'target_${stage}_${language}_${brightness.name}';
        testWidgets('target scoring golden $name', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = stage == 'large'
              ? const Size(740, 360)
              : const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final database = createTestDatabase();
          final service = MatchCommandService(database, now: () => anchor);
          await service.start(
            StartMatchCommand(
              matchId: 'golden-target',
              redName: 'River',
              blueName: 'Jordan',
              recordingMode: RecordingMode.simple,
              ruleTemplate: const RuleTemplate(
                id: 'eleven',
                name: '11 points',
                scoreButtons: [1, 2, 3],
                targetScore: 11,
              ),
              createdAt: anchor,
              startedAt: anchor,
            ),
          );
          for (var i = 0; i < 4; i++) {
            await service.record(
              RecordMatchEventCommand(
                matchId: 'golden-target',
                side: TeamSide.blue,
                points: 2,
                occurredAt: anchor,
              ),
            );
          }
          for (var i = 0; i < 4; i++) {
            await service.record(
              RecordMatchEventCommand(
                matchId: 'golden-target',
                side: TeamSide.red,
                points: 3,
                occurredAt: anchor,
              ),
            );
          }
          final controller = ScoringController.fromCommittedProjection(
            (await MatchRepository(database).getMatchDetail('golden-target'))!,
            service,
            nowUtc: () => stage == 'supplement'
                ? anchor
                : anchor.add(const Duration(seconds: 11)),
          );
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: buildHoopitoTheme(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(stage == 'large' ? 2 : 1),
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const Key('target-golden'),
                child: ScoringPage(
                  controller: controller,
                  clockNowUtc: () => anchor,
                  motionPreference: MotionPreference.reduced,
                  onFinishDecision: (_, _) async {},
                  onContinueDecision: () async {},
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            find.text(language == 'zh' ? '已达到目标分' : 'Target score reached'),
            findsOneWidget,
          );
          expect(find.textContaining('River 12 : 8 Jordan'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('target-golden')),
            matchesGoldenFile(hoopitoGoldenFile(name)),
          );
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
